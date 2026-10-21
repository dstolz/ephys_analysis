function out = spikesToMat(obj, opts)
%spikesToMat  Threshold-detect spikes over this recording and save a .mat.
%   OUT = ds.spikesToMat(Name=Value) writes one MAT-file per dataset holding
%   voltage-threshold detections over the whole recording, made with
%   EphysDataset.detectSpikes (one entry per channel), with the artifact
%   periods erased first or the events inside them removed (ArtifactMode).
%   Sorted units are not part of it: they stay in the sorting folder, read
%   with EphysDataset.readSortedUnits.
%   The recording files are only read. The file is written atomically (see
%   EphysDataset.saveAtomically), so a failed or canceled run never leaves a
%   complete-looking file behind.
%
%   Variables in the file
%   ---------------------
%     detected    struct: ts {1 x nChan} spike times (s, (index-1)/Fs,
%                 recording-relative), wf {1 x nChan} [nSpikes x nWin] uV or
%                 [] when waveforms were not requested, info (detectSpikes'
%                 info, filtered to the kept events), channels (1-based
%                 recording channels, in order), channelNames, reference
%                 (the common reference detection ran on, as
%                 EphysDataset.referenceInfo gives it: mode, channels, and
%                 wcar for the weighted CAR) and detection (the options
%                 used, artifactMode, the artifact intervals applied and
%                 nRejectedArtifact per channel; with "erase" info.artifacts
%                 says how many samples were erased; coincidence: the
%                 Coincidence asked for, the probe file the sites came from
%                 and a note when it could not run). info.coincidence says
%                 what ran and found; with "tag", info.eventId and
%                 info.primary number each event
%     conversion  provenance (tool, created, dataset, sourceFolder, ...)
%
%   ds.Processing.spikes records how the detections were made (every option
%   as run, the reference, the channels, the artifact handling) for the
%   manifest's processing block.
%
%   Options
%   -------
%     File              target path (default <outputFolder>/<Name>_spikes.mat)
%     DetectOptions     struct of detectSpikes options (Filter, Band,
%                       ThresholdMethod, Threshold, ThresholdScope,
%                       Waveforms, WindowMs, MaxChunkSamples, UseParallel,
%                       MaxWorkers, Coincidence, ...). Do not include Fs,
%                       ChannelOrder, ProgressFcn or SitePositions here.
%                       detected.info.thresholdScope says whether the
%                       thresholds are per chunk or recording-wide.
%     Channels          1-based recording channels to detect on, in order
%                       ([] = all)
%     ProbeFile         the probe the sites of DetectOptions.Coincidence
%                       come from ("" = ds.ProbeFile; EphysPipeline.probeFor
%                       resolves a dataset's own, a rule's or the default
%                       probe). With no readable probe, coincident events
%                       are kept as detected, with a warning
%                       (EphysDataset:spikesToMat:NoProbe) and a note in
%                       detected.detection.coincidence. A channel off the
%                       probe has no neighbors.
%     ArtifactMode      what detection does with the artifact periods
%                       (ArtifactIntervals, else ds.artifactIntervals():
%                       manual periods always, the automatic detector when
%                       ds.ArtifactConfig.Enabled):
%                         "reject" (default) detect on the recording as
%                                  read, then drop the events inside a period
%                         "erase"  erase the periods before detection
%                                  (detectSpikes' ArtifactIntervals: NaN, left
%                                  out of the thresholds, a line for the
%                                  band-pass), so detection runs on the
%                                  cleaned recording: no event lies inside a
%                                  period and no artifact rings into the
%                                  samples around it
%                         "none"   ignore them
%     ArtifactIntervals [k x 2] seconds to use instead of ds.artifactIntervals()
%                       ([] = none; default NaN = ds.artifactIntervals())
%     MatVersion        "-v7.3" (default) | "-v7"
%     Overwrite         false (default): error if File already exists
%     ProgressFcn       ProgressFcn(nDone, nTotal, message); may throw to abort
%
%   OUT: file, bytes, seconds, nChannels, nDetected (per channel),
%   nRejectedArtifact (per channel), coincidence (the mode that ran),
%   nCoincident (per channel: copies removed, or tagged), coincidenceNote
%   (why the Coincidence asked for did not run; "" when it did), matVersion.
%
%   See also EphysDataset.detectSpikes, EphysDataset.readSortedUnits,
%   EphysDataset.artifactIntervals, EphysDataset.toMat.

arguments
    obj (1,1) EphysDataset
    opts.File (1,1) string = ""
    opts.DetectOptions (1,1) struct = struct()
    opts.Channels (1,:) double {mustBeInteger, mustBePositive} = []
    opts.ProbeFile (1,1) string = ""
    opts.ArtifactMode (1,1) string {mustBeMember(opts.ArtifactMode, ["reject","erase","none"])} = "reject"
    opts.ArtifactIntervals double = NaN
    opts.MatVersion (1,1) string {mustBeMember(opts.MatVersion, ["-v7.3", "-v7"])} = "-v7.3"
    opts.Overwrite (1,1) logical = false
    opts.ProgressFcn = []
    opts.Provenance = []   % ephysProvenance() of the run writing it ([] = made here)
end
prov = opts.Provenance;
if isempty(prov); prov = ephysProvenance(); end

t0 = tic;
file = opts.File;
if file == ""
    file = string(fullfile(obj.outputFolder(), obj.Name + "_spikes.mat"));
end
if isfile(file) && ~opts.Overwrite
    error('EphysDataset:spikesToMat:Exists', ...
        '%s already exists (pass Overwrite=true to replace it).', file);
end
outDir = fileparts(file);
if strlength(outDir) > 0 && ~isfolder(outDir)
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('EphysDataset:spikesToMat:MkdirFailed', 'Could not create %s: %s', outDir, msg);
    end
end
for bad = ["Fs" "ChannelOrder" "ProgressFcn" "Files" "ArtifactIntervals" "SitePositions"]
    if isfield(opts.DetectOptions, bad)
        error('EphysDataset:spikesToMat:DetectOption', ...
            ['Pass %s to spikesToMat itself (Channels / ProgressFcn / ArtifactMode ' ...
             'and ArtifactIntervals / ProbeFile), not inside DetectOptions.'], bad);
    end
end

nSteps = 3;   % artifacts, detect, save
step = 0;     % stages done so far; passed as it stands at each report

% --- threshold detection ----------------------------------------------------
if obj.NumFiles == 0; obj.discoverFiles(); end
if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end

iv = zeros(0, 2);
if opts.ArtifactMode ~= "none"
    [iv, given] = explicitIntervals(opts.ArtifactIntervals);
    if ~given
        progress(opts.ProgressFcn, step, nSteps, "Resolving artifact periods");
        iv = obj.artifactIntervals();
    end
end
step = step + 1;

channels = opts.Channels;
if isempty(channels); channels = 1:obj.NumChannels; end
if any(channels > obj.NumChannels)
    error('EphysDataset:spikesToMat:Channels', ...
        'Channels must be <= %d for %s.', obj.NumChannels, obj.Name);
end

dopts = opts.DetectOptions;
wantWf = isfield(dopts, 'Waveforms') && logical(dopts.Waveforms);
dopts.Waveforms = wantWf;
if opts.ArtifactMode == "erase"
    dopts.ArtifactIntervals = iv;   % detection runs on the cleaned recording
end
% Coincident events: the channels' sites on the probe, or every copy kept
% when there is no probe to say which sites are neighbors.
coinc = struct('requested', "none", 'probeFile', "", 'note', "");
if isfield(dopts, 'Coincidence'); coinc.requested = string(dopts.Coincidence); end
if coinc.requested ~= "none"
    coinc.probeFile = opts.ProbeFile;
    if coinc.probeFile == ""; coinc.probeFile = obj.ProbeFile; end
    L = obj.channelLayout(ProbeFile=coinc.probeFile);
    if L.hasProbe
        dopts.SitePositions = [L.x(channels); L.y(channels)].';
    else
        if coinc.probeFile == ""
            coinc.note = "no probe";
        elseif ~isfile(coinc.probeFile)
            coinc.note = "the probe file " + coinc.probeFile + " is missing";
        else
            coinc.note = "no channel placed on the probe " + coinc.probeFile;
        end
        warning('EphysDataset:spikesToMat:NoProbe', ...
            '%s: %s, so coincident spikes are kept on every channel that detected them.', ...
            obj.Name, coinc.note);
        dopts.Coincidence = "none";
    end
end
args = namedargs2cell(dopts);
cb = [];
if ~isempty(opts.ProgressFcn)
    cb = @(i, n, name) progress(opts.ProgressFcn, step + (i - 1) / max(n, 1), nSteps, ...
        "Detecting spikes: " + string(name));
end
[ts, wf, info] = obj.detectSpikes(args{:}, 'ChannelOrder', channels, 'ProgressFcn', cb);
step = step + 1;

% Drop events inside artifact periods, keeping every per-channel array
% (times, waveforms, indices, amplitudes, counts) consistent. After an
% erase there are none: an erased sample never crosses threshold.
[ivStart, ivEnd] = sampleIntervals(iv, obj.Fs);
nCh = numel(ts);
nRej = zeros(1, nCh);
for c = 1:nCh
    keep = ~inIntervals(ts{c}, ivStart, ivEnd, obj.Fs);
    nRej(c) = nnz(~keep);
    if all(keep); continue; end
    ts{c} = ts{c}(keep);
    if wantWf && numel(wf) >= c && ~isempty(wf{c}); wf{c} = wf{c}(keep, :); end
    info = filterInfo(info, c, keep);
end
if isfield(info, 'count') && isfield(info, 'durationSec') && info.durationSec > 0
    info.rate = info.count / info.durationSec;
end
if ~wantWf; wf = []; end

detected = struct();
detected.ts           = ts;
detected.wf           = wf;
detected.info         = info;
detected.channels     = channels;
detected.channelNames = channelNamesFor(obj, channels);
detected.reference    = obj.referenceInfo();   % the common reference detection ran on
detected.detection    = struct( ...
    'options',           opts.DetectOptions, ...
    'artifactMode',      opts.ArtifactMode, ...
    'artifactIntervals', iv, ...
    'nRejectedArtifact', nRej, ...
    'coincidence',       coinc, ...
    'timeConvention',    "t = (index-1)/Fs, recording-relative");

% --- save -------------------------------------------------------------------
progress(opts.ProgressFcn, step, nSteps, "Saving " + file);
S = struct();
S.detected   = detected;
S.conversion = struct( ...
    'tool',            "EphysDataset.spikesToMat", ...
    'created',         string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',         obj.Name, ...
    'sourceFolder',    obj.Folder, ...
    'recordingFormat', obj.RecordingFormat, ...
    'fs',              obj.Fs, ...
    'matFileVersion',  opts.MatVersion, ...
    'matlabVersion',   string(version));
S.conversion.provenance = prov;
EphysDataset.saveAtomically(file, S, opts.MatVersion);

d = dir(file);
out = struct();
out.file              = file;
out.bytes             = d.bytes;
out.seconds           = toc(t0);
out.matVersion        = opts.MatVersion;
out.nChannels         = numel(detected.channels);
out.nDetected         = cellfun(@numel, detected.ts);
out.nRejectedArtifact = detected.detection.nRejectedArtifact;
out.coincidence       = info.coincidence.mode;
out.nCoincident       = info.coincidence.nCopies;
out.coincidenceNote   = coinc.note;

if ~isempty(obj.Manifest) && isa(obj.Manifest, 'Manifest')
    obj.Manifest.add("spikesToMat", "Wrote spikes .mat", ...
        struct('file', file, 'bytes', out.bytes));
end
% How the detections were made, for the manifest (Processing): every
% detectSpikes option as run, spikesToMat's own, the reference, the
% threshold each method stood for and the artifact periods.
o = rmfield(info.options, 'SitePositions');   % the probe file below says where they came from
o.ArtifactMode = opts.ArtifactMode;
o.MatVersion = opts.MatVersion;
r = EphysDataset.processingRecord("file", file, prov, o);
r.reference = EphysDataset.referenceRecord(detected.reference);
r.channels = EphysDataset.formatChannelList(channels);
r.threshold_input = [];   % the multiplier (or uV) Threshold stood for
if isfield(info, 'thresholdInput'); r.threshold_input = info.thresholdInput; end
erased = 0;
if isfield(info, 'artifacts') && isfield(info.artifacts, 'nSamples'); erased = info.artifacts.nSamples / obj.Fs; end
r.artifacts = struct('mode', opts.ArtifactMode, 'periods', size(iv, 1), ...
    'rejected', sum(nRej), 'erased_s', erased);
C = info.coincidence;
r.coincidence = stringifyNonFinite(struct('mode', C.mode, 'requested', coinc.requested, ...
    'probe', coinc.probeFile, 'radius_um', C.radiusUm, 'jitter_ms', C.jitterMs, ...
    'copies', sum(C.nCopies), 'note', coinc.note));
obj.Processing.spikes = r;
try
    progress(opts.ProgressFcn, nSteps, nSteps, "Done");
catch
    % The file is complete; a cancel raised here must not fail the run.
end
end


%% ---------------------------------------------------------------------------
function progress(fcn, done, total, msg)
if ~isempty(fcn); fcn(done, total, msg); end
end


function [s, e] = sampleIntervals(iv, Fs)
%sampleIntervals  [t0 t1) second periods as sorted, disjoint sample ranges.
%   Each period covers samples round(t0*Fs) up to but not including
%   round(t1*Fs), as manualArtifactMask counts them (t = index/Fs, 0-based).
%   Empty ranges are dropped and overlapping or touching ones merged, so S is
%   strictly increasing and every sample lies in at most one [S(k), E(k)).
s = zeros(0, 1);
e = zeros(0, 1);
if isempty(iv)
    return
end
r = round(iv * Fs);
r = sortrows(r(r(:, 2) > r(:, 1), :), 1);
for k = 1:size(r, 1)
    if ~isempty(s) && r(k, 1) <= e(end)
        e(end) = max(e(end), r(k, 2));
    else
        s(end+1, 1) = r(k, 1); %#ok<AGROW>
        e(end+1, 1) = r(k, 2); %#ok<AGROW>
    end
end
end


function tf = inIntervals(t, s, e, Fs)
%inIntervals  True for each event on a sample inside a [S(k), E(k)) range.
%   S, E from sampleIntervals. Each event is looked up in the sorted starts
%   (the last range starting at or before its sample) rather than tested
%   against every range.
g = round(t * Fs);
tf = false(size(t));
if isempty(s) || isempty(g)
    return
end
k = discretize(g, [s; Inf]);         % NaN before the first range
ok = ~isnan(k);
tf(ok) = g(ok) < e(k(ok));
end


function info = filterInfo(info, c, keep)
%filterInfo  Apply a per-event keep mask to detectSpikes' per-channel arrays.
n = numel(keep);
for f = ["index" "amplitude" "rejectedIndex" "droppedEdgeIndex" "eventId" "primary"]
    if isfield(info, f) && iscell(info.(f)) && numel(info.(f)) >= c ...
            && numel(info.(f){c}) == n
        v = info.(f){c};
        info.(f){c} = v(keep);
    end
end
if isfield(info, 'count') && numel(info.count) >= c
    info.count(c) = nnz(keep);
end
if isfield(info, 'primary') && numel(info.primary) >= c   % "tag": the copies still in the file
    info.coincidence.nCopies(c) = nnz(~info.primary{c});
end
end


function names = channelNamesFor(obj, channels)
names = strings(1, numel(channels));
cn = obj.ChannelNames;
ok = channels <= numel(cn);
names(ok) = cn(channels(ok));
names(~ok) = "ch" + string(channels(~ok));
end
