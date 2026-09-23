function onDetectArtifacts(obj)
%onDetectArtifacts  Run the artifact detector over a dataset and show the summary.
%   Pushes the current detection settings onto every scanned dataset, then
%   streams the active dataset one *.rhd file at a time
%   (EphysDataset.analyzeArtifacts) and fills the per-channel table
%   (refreshArtChannelTable, from ArtView.summary) and summary label with the
%   number of samples flagged per channel and the percent of the recording
%   that would be blanked, then shows the first detected artifact in the
%   viewer (showArtifactView). Read-only: nothing is written to disk.
%
%   See also EphysDataset.analyzeArtifacts, buildArtifactsTab, showArtifactView.

if obj.refuseWhileRunning("Detect / Preview"); return; end
d = obj.currentDataset();
if isempty(d)
    uialert(obj.Fig, "Scan a project first.", "Artifacts");
    return
end

% Make sure Fs / per-file counts are known (needed to convert the RMS window
% from ms to samples and to report duration).
if isnan(d.Fs) || isempty(d.PerFile) || ~isfield(d.PerFile, 'numAmplifierSamples')
    d.refreshMetadata();
end

% Persist the current settings onto every dataset so the batch write matches.
obj.applyArtifactConfigToProject();

obj.ArtDetectButton.Enable = "off";
cleanup = onCleanup(@() set(obj.ArtDetectButton, "Enable", "on"));
dlg = uiprogressdlg(obj.Fig, "Title", "Detecting artifacts", ...
    "Message", "Reading data...", "Value", 0, "Cancelable", "off");

try
    progress = @(i, n, name) updateProgress(dlg, i, n, name);
    popt = namedargs2cell(EphysPipelineConfig.parallelOptions(obj.Config.Parallel));
    summary = d.analyzeArtifacts('ProgressFcn', progress, popt{:});   % settings from d.ArtifactConfig

    if isvalid(dlg); close(dlg); end
    obj.refreshReferencePanel();   % a first referenced read suggests the channels left out

    obj.ArtView.summary = summary;
    obj.refreshArtChannelTable();
    obj.ArtSummaryLabel.Text = summaryText(summary, ...
        logical(obj.ArtEnableCheckBox.Value));
    obj.ArtStatusLabel.Text = sprintf("Analyzed %s (%d file(s)).", ...
        d.Name, numel(summary.files));

    % The viewer steps through what was just detected, from the first.
    obj.ArtView.intervals = summary.intervals;
    obj.ArtView.previewed = true;
    obj.ArtView.settings = EphysDataset.normalizeArtifactConfig(d.ArtifactConfig);
    obj.ArtViewSpinner.Value = 1;
    obj.showArtifactView();

    if logical(obj.ArtEnableCheckBox.Value)
        artHint = "Automatic detection is enabled; it applies on the next run.";
    else
        artHint = "Enable automatic detection above to apply it on a run.";
    end
    obj.setStatus(sprintf("Analyzed %s: %.3f%% flagged in %d interval(s).", ...
        d.Name, summary.pctDuration, summary.nIntervals), artHint);
catch ME
    if isvalid(dlg); close(dlg); end
    uialert(obj.Fig, ME.message, "Detect failed");
    obj.setStatus("Artifact detection failed: " + string(ME.message));
end
end


function updateProgress(dlg, i, n, name)
if ~isvalid(dlg); return; end
dlg.Value   = max(0, min(1, (i - 1) / max(n, 1)));
dlg.Message = sprintf("Chunk %d/%d: %s", i, n, name);
end


function t = summaryText(s, enabled)
%summaryText  Aggregate artifact statistics as a monospaced block, its lines
%   short enough for the Artifacts tab's right column.
if s.nChan > 0
    [pkPct, pkCh] = max(s.channelPct);
else
    pkPct = 0; pkCh = 0;
end
if strcmp(char(s.method), 'rms') && ~isnan(s.rmsWindowMs)
    winStr = sprintf('%.2f ms', s.rmsWindowMs);
else
    winStr = 'n/a';
end
lines = {
    sprintf('Method      %s, threshold %g', char(s.method), s.threshold)
    sprintf('RMS window  %s', winStr)
    sprintf('Stitch gap  %g ms, pad %g ms', s.mergeGapMs, s.padMs)
    sprintf('Min chans   %d', s.minChannels)
    sprintf('Duration    %.2f s, %d ch', s.durationSec, s.nChan)
    sprintf('            %d samples, %g Hz', s.nSamples, s.fs)
    ''
    sprintf('Blanked     %d samples (%.3f%%)', s.nBlanked, s.pctDuration)
    sprintf('Intervals   %d', s.nIntervals)
    sprintf('Worst ch    %d (%.3f%% flagged)', pkCh, pkPct)
    ''
    sprintf('On a run    %s', ternary(enabled, 'applied: detection is on', ...
        'not applied: detection is off'))
    };
t = strjoin(lines, newline);
end


function out = ternary(c, a, b)
if c; out = a; else; out = b; end
end
