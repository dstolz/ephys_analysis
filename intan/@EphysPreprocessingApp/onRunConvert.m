function onRunConvert(obj)
%onRunConvert  Batch EphysDataset.toMat over the selected datasets; one .mat each.
%   For each dataset ticked on the Datasets tab (none ticked = all), calls
%   EphysDataset.toMat with the Convert-tab options: the dataset reads its
%   recording (any supported layout), derives the signals with
%   EphysDataset.deriveSignals (the intan2matlab processing) and saves Y,
%   events, info and a "conversion" provenance struct to
%   <Output folder>/<Name><Suffix>.mat. A blank Output folder writes next to
%   the raw data (the dataset folder). The recording files are only read.
%
%   Safeguards
%   ----------
%     * Existing .mat files are skipped unless "Overwrite" is ticked (toMat
%       also refuses to overwrite unless told to).
%     * Folders with no recognized Intan files are skipped, reason logged.
%     * Two datasets that would write the same file stop the run before it
%       starts.
%     * toMat writes "~<name>.partial.mat" and renames it only after save()
%       finishes without warnings and every variable is confirmed present, so
%       a failed or cancelled run never leaves a complete-looking file behind.
%
%   Progress (overall + per-step bars, status table, log) is driven by the
%   toMat/deriveSignals ProgressFcn; Cancel stops at the next step boundary
%   (between files / processing stages / before the save).
%
%   The option validation / mapping is EphysPipelineConfig.signalOptions, the
%   same code the headless pipeline uses.
%
%   See also EphysDataset.toMat, EphysDataset.deriveSignals, buildConvertTab,
%   gatherConvertConfig, EphysPipelineConfig.signalOptions.

if obj.ConvRunning; return; end
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    uialert(obj.Fig, "Scan a parent directory first (Datasets tab).", "Convert");
    return
end

cfg = obj.gatherConvertConfig();
obj.savePreferences();

% --- validate options before touching anything (shared with the pipeline) ---
try
    sigOpts = EphysPipelineConfig.signalOptions(cfg);
catch ME
    uialert(obj.Fig, ME.message, "Convert: invalid options");
    return
end

T = obj.convertTargets(cfg);
n = height(T);
if n == 0
    uialert(obj.Fig, "No datasets selected.", "Convert");
    return
end

% Two datasets must never write the same file (case-insensitive: Windows).
key = lower(T.OutputFile);
[~, first] = unique(key, 'stable');
dupKeys = key(setdiff(1:n, first));
if ~isempty(dupKeys)
    names = T.Dataset(ismember(key, dupKeys));
    uialert(obj.Fig, "These datasets would write the same output file: " + ...
        strjoin(names, ", ") + ". Leave the output folder blank (save next " + ...
        "to each dataset) or convert them separately.", "Convert");
    return
end

% A user-specified output folder is created if it does not exist yet.
if cfg.OutputDir ~= "" && ~isfolder(cfg.OutputDir)
    [ok, msg] = mkdir(cfg.OutputDir);
    if ~ok
        uialert(obj.Fig, "Could not create output folder: " + string(msg), "Convert");
        return
    end
    obj.convLog("Created output folder %s", cfg.OutputDir);
end

% --- run state ---
obj.ConvRunning = true;
obj.ConvCancelRequested = false;
obj.ConvRunButton.Enable = "off";
obj.ConvCancelButton.Enable = "on";
cleanup = onCleanup(@() finishRun(obj));

obj.ConvTargetsTable.Data = T(:, {'Dataset', 'Format', 'OutputFile', 'Status'});
touched = false(1, n);   % rows whose status this run has set

obj.convLog("=== Convert batch (EphysDataset.toMat): %d dataset(s) ===", n);
obj.convLog("Signal options: %s", formatOptions(sigOpts));
obj.convLog("Saving with %s; overwrite existing = %s", cfg.MatVersion, string(cfg.Overwrite));
obj.setStatus(sprintf("Convert: deriving signals for %d dataset(s)...", n), "");

nOK = 0; nSkip = 0; nFail = 0; cancelled = false;
for j = 1:n
    if obj.ConvCancelRequested
        cancelled = true;
        break
    end
    d = obj.Project.Datasets(T.DatasetIdx(j));
    outFile = T.OutputFile(j);
    showProgress(obj, j, n, 0, 1, d.Name + ": starting");
    obj.convLog("[%d/%d] %s  (%s, %s)", j, n, d.Name, d.RecordingFormat, d.Folder);
    touched(j) = true;

    if d.RecordingFormat == "unknown"
        nSkip = nSkip + 1;
        showProgress(obj, j, n, 1, 1, d.Name + ": skipped");
        setRowStatus(obj, j, "skipped: no Intan files");
        obj.convLog("    SKIPPED: no recognized Intan recording files in the folder.");
        continue
    end
    if isfile(outFile) && ~cfg.Overwrite
        nSkip = nSkip + 1;
        showProgress(obj, j, n, 1, 1, d.Name + ": skipped");
        setRowStatus(obj, j, "skipped: output exists");
        obj.convLog("    SKIPPED: %s already exists (tick Overwrite to replace it).", outFile);
        continue
    end

    setRowStatus(obj, j, "running");
    try
        cb = @(done, total, msg) onProgress(obj, j, n, d.Name, done, total, msg);
        out = d.toMat(File=outFile, SignalOptions=sigOpts, ...
            MatVersion=cfg.MatVersion, Overwrite=cfg.Overwrite, ProgressFcn=cb);

        logSummary(obj, out, cfg);
        obj.convLog("    saved %s (%.1f MB) in %.1f s", out.file, out.bytes / 2^20, out.seconds);
        setRowStatus(obj, j, "done");
        nOK = nOK + 1;
    catch ME
        if strcmp(ME.identifier, 'EphysPreprocessingApp:ConvertCancelled')
            cancelled = true;
            setRowStatus(obj, j, "cancelled (nothing written)");
            obj.convLog("    CANCELLED during %s; no output written for it.", d.Name);
            break
        end
        nFail = nFail + 1;
        setRowStatus(obj, j, "FAILED");
        obj.convLog("    ERROR: %s", ME.message);
    end
end

if ~isvalid(obj.Fig); return; end

if cancelled
    for r = find(~touched)
        setRowStatus(obj, r, "not run (cancelled)");
    end
else
    obj.setConvertBar(obj.ConvOverallBar, 1);
    obj.ConvOverallText.Text = sprintf('%d/%d datasets', n, n);
end

summary = sprintf("%d converted, %d skipped, %d failed", nOK, nSkip, nFail);
if cancelled; summary = summary + ", cancelled by user"; end
obj.convLog("=== finished: %s ===", summary);
obj.ConvStepLabel.Text = char("Finished: " + summary + ".");
obj.setStatus("Convert: " + summary + ".", "");
end


%% ---- progress ---------------------------------------------------------

function onProgress(obj, j, n, name, done, total, msg)
%onProgress  toMat/deriveSignals ProgressFcn: update the tab, honor Cancel.
%   Per-file read steps update the bars only (they can number in the
%   thousands); the first read and every processing stage are also logged.
if ~isvalid(obj) || isempty(obj.Fig) || ~isvalid(obj.Fig)
    error('EphysPreprocessingApp:ConvertCancelled', 'The app was closed.');
end
msg = string(msg);
showProgress(obj, j, n, done, total, name + ": " + msg);
if done == 0 || ~startsWith(msg, "Reading file")
    obj.convLog("    %s", msg);
end
drawnow;   % render, and let a pending Cancel click run
if obj.ConvCancelRequested
    error('EphysPreprocessingApp:ConvertCancelled', 'Cancelled by user.');
end
end


function showProgress(obj, j, n, done, total, msg)
%showProgress  Set both bars + texts. Overall = finished datasets plus the
%   completed fraction of steps of the current one.
if ~isvalid(obj.Fig); return; end
frac = done / max(total, 1);
obj.setConvertBar(obj.ConvOverallBar, (j - 1 + frac) / n);
obj.ConvOverallText.Text = sprintf('dataset %d/%d', j, n);
obj.setConvertBar(obj.ConvStepBar, frac);
obj.ConvStepText.Text = sprintf('step %d/%d', done, total);
obj.ConvStepLabel.Text = char(msg);
end


function setRowStatus(obj, row, status)
%setRowStatus  Update the Status cell of one targets-table row.
if isempty(obj.ConvTargetsTable) || ~isvalid(obj.ConvTargetsTable); return; end
D = obj.ConvTargetsTable.Data;
if istable(D) && row <= height(D)
    D.Status(row) = string(status);
    obj.ConvTargetsTable.Data = D;
end
end


function finishRun(obj)
%finishRun  Clear the running state and restore the buttons (onCleanup).
if ~isvalid(obj); return; end
obj.ConvRunning = false;
obj.ConvCancelRequested = false;
if ~isempty(obj.ConvRunButton) && isvalid(obj.ConvRunButton)
    obj.ConvRunButton.Enable = "on";
end
if ~isempty(obj.ConvCancelButton) && isvalid(obj.ConvCancelButton)
    obj.ConvCancelButton.Enable = "off";
end
end



function s = formatOptions(opts)
%formatOptions  Render a name-value struct as "name=value, ..." for the log.
fn = fieldnames(opts);
parts = strings(1, numel(fn));
for k = 1:numel(fn)
    v = opts.(fn{k});
    if isstring(v) || ischar(v)
        v = string(v);
        if isscalar(v)
            vs = """" + v + """";
        else
            vs = "[""" + strjoin(v, """ """) + """]";
        end
    else
        vs = string(mat2str(v));
    end
    parts(k) = string(fn{k}) + "=" + vs;
end
s = strjoin(parts, ", ");
end


%% ---- output -----------------------------------------------------------

function logSummary(obj, out, cfg)
%logSummary  Log what toMat actually produced (sizes, rates, events, bad chans).
for s = out.signals
    obj.convLog("    %s: %d samples x %d channels (%s) @ %g Hz", ...
        s.name, s.nSamples, s.nChannels, s.class, s.Fs);
end

if isempty(out.events)
    obj.convLog("    digital events: no dig-in lines recorded");
else
    obj.convLog("    digital events: %s", ...
        strjoin(compose("%s (%d)", [out.events.name]', [out.events.count]'), ", "));
end

switch string(cfg.BadMode)
    case "auto"
        if isempty(out.badChannels)
            obj.convLog("    auto bad-channel detection flagged no channels (|z| > %g)", cfg.BadThreshold);
        else
            obj.convLog("    auto-flagged and interpolated channels (kept-channel indices, pre-remap): %s", ...
                mat2str(out.badChannels));
        end
    case "manual"
        obj.convLog("    interpolated channels (kept-channel indices, pre-remap): %s", ...
            mat2str(out.badChannels));
end
end
