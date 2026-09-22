function out = spikesToMat(obj, opts)
%spikesToMat  Detect and/or load spikes for this recording and save a .mat.
%   OUT = ds.spikesToMat(Name=Value) writes one MAT-file per dataset holding
%   spike events from up to two sources:
%     * "detect"  voltage-threshold detection over the whole recording with
%                 EphysDataset.detectSpikes (one entry per channel), with
%                 events inside artifact periods removed;
%     * "sorted"  the sorted units associated with the dataset, read with
%                 EphysDataset.readSortedUnits (Kilosort4 / phy output, with
%                 phy-curated labels).
%   The recording files are only read. The file is written atomically (see
%   EphysDataset.saveAtomically), so a failed or cancelled run never leaves a
%   complete-looking file behind. The file is rewritten as a whole: whichever
%   sources are enabled are present, the others are stored as [].
%
%   Variables in the file
%   ---------------------
%     detected    struct or []: ts {1 x nChan} spike times (s, (index-1)/Fs,
%                 recording-relative), wf {1 x nChan} [nSpikes x nWin] uV or
%                 [] when waveforms were not requested, info (detectSpikes'
%                 info, filtered to the kept events), channels (1-based
%                 recording channels, in order), channelNames, and detection
%                 (the options used, the artifact intervals applied and
%                 nRejectedArtifact per channel)
%     units       struct or []: the readSortedUnits struct (unitId, group,
%                 times, samples, channel, templateWaveform, ...)
%     conversion  provenance (tool, created, dataset, sourceFolder, ...)
%
%   Options
%   -------
%     File              target path (default <outputFolder>/<Name>_spikes.mat)
%     Source            "detect" (default) | "sorted" | "both"
%     DetectOptions     struct of detectSpikes options (Filter, Band,
%                       ThresholdMethod, Threshold, Waveforms, WindowMs,
%                       MaxChunkSamples, UseParallel, MaxWorkers, ...). Do not
%                       include Fs, ChannelOrder or ProgressFcn here.
%     Channels          1-based recording channels to detect on, in order
%                       ([] = all)
%     RejectArtifacts   true (default): drop detected events inside the
%                       artifact periods (ArtifactIntervals, else
%                       ds.artifactIntervals(): manual periods always, the
%                       automatic detector when ds.ArtifactConfig.Enabled)
%     ArtifactIntervals [k x 2] seconds to use instead of ds.artifactIntervals()
%                       ([] = none; default NaN = ds.artifactIntervals())
%     Groups            sorted units to keep by phy label (default ["good" "mua"])
%     IncludeNoise      keep clusters labelled "noise" (default false)
%     Templates         read template waveforms for sorted units (default true)
%     MatVersion        "-v7.3" (default) | "-v7"
%     Overwrite         false (default): error if File already exists
%     ProgressFcn       ProgressFcn(nDone, nTotal, message); may throw to abort
%
%   OUT: file, bytes, seconds, source, nChannels, nDetected (per channel),
%   nRejectedArtifact (per channel), nUnits, matVersion.
%
%   See also EphysDataset.detectSpikes, EphysDataset.readSortedUnits,
%   EphysDataset.artifactIntervals, EphysDataset.toMat.

arguments
    obj (1,1) EphysDataset
    opts.File (1,1) string = ""
    opts.Source (1,1) string {mustBeMember(opts.Source, ["detect","sorted","both"])} = "detect"
    opts.DetectOptions (1,1) struct = struct()
    opts.Channels (1,:) double {mustBeInteger, mustBePositive} = []
    opts.RejectArtifacts (1,1) logical = true
    opts.ArtifactIntervals double = NaN
    opts.Groups (1,:) string = ["good" "mua"]
    opts.IncludeNoise (1,1) logical = false
    opts.Templates (1,1) logical = true
    opts.MatVersion (1,1) string {mustBeMember(opts.MatVersion, ["-v7.3", "-v7"])} = "-v7.3"
    opts.Overwrite (1,1) logical = false
    opts.ProgressFcn = []
end

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
for bad = ["Fs" "ChannelOrder" "ProgressFcn" "Files"]
    if isfield(opts.DetectOptions, bad)
        error('EphysDataset:spikesToMat:DetectOption', ...
            'Pass %s to spikesToMat itself (Channels / ProgressFcn), not inside DetectOptions.', bad);
    end
end

doDetect = opts.Source ~= "sorted";
doSorted = opts.Source ~= "detect";
nSteps = double(doDetect) * 2 + double(doSorted) + 1;   % artifacts+detect, units, save
step = 0;   % stages done so far; passed as it stands at each report

detected = [];
units    = [];

% --- threshold detection ----------------------------------------------------
if doDetect
    if obj.NumFiles == 0; obj.discoverFiles(); end
    if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end

    iv = zeros(0, 2);
    if opts.RejectArtifacts
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
    args = namedargs2cell(dopts);
    cb = [];
    if ~isempty(opts.ProgressFcn)
        cb = @(i, n, name) progress(opts.ProgressFcn, step + (i - 1) / max(n, 1), nSteps, ...
            "Detecting spikes: " + string(name));
    end
    [ts, wf, info] = obj.detectSpikes(args{:}, 'ChannelOrder', channels, 'ProgressFcn', cb);
    step = step + 1;

    % Drop events inside artifact periods, keeping every per-channel array
    % (times, waveforms, indices, amplitudes, counts) consistent.
    nCh = numel(ts);
    nRej = zeros(1, nCh);
    for c = 1:nCh
        keep = ~inIntervals(ts{c}, iv, obj.Fs);
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
    detected.detection    = struct( ...
        'options',           opts.DetectOptions, ...
        'rejectArtifacts',   opts.RejectArtifacts, ...
        'artifactIntervals', iv, ...
        'nRejectedArtifact', nRej, ...
        'timeConvention',    "t = (index-1)/Fs, recording-relative");
end

% --- sorted units -----------------------------------------------------------
if doSorted
    progress(opts.ProgressFcn, step, nSteps, "Reading sorted units");
    units = obj.readSortedUnits(Groups=opts.Groups, IncludeNoise=opts.IncludeNoise, ...
        Templates=opts.Templates);
    step = step + 1;
end

% --- save -------------------------------------------------------------------
progress(opts.ProgressFcn, step, nSteps, "Saving " + file);
S = struct();
S.detected   = detected;
S.units      = units;
S.conversion = struct( ...
    'tool',            "EphysDataset.spikesToMat", ...
    'created',         string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',         obj.Name, ...
    'sourceFolder',    obj.Folder, ...
    'recordingFormat', obj.RecordingFormat, ...
    'fs',              obj.Fs, ...
    'source',          opts.Source, ...
    'sortingDir',      string(obj.sortingResultsDir()), ...
    'matFileVersion',  opts.MatVersion, ...
    'matlabVersion',   string(version));
EphysDataset.saveAtomically(file, S, opts.MatVersion);

d = dir(file);
out = struct();
out.file       = file;
out.bytes      = d.bytes;
out.seconds    = toc(t0);
out.source     = opts.Source;
out.matVersion = opts.MatVersion;
if doDetect
    out.nChannels         = numel(detected.channels);
    out.nDetected         = cellfun(@numel, detected.ts);
    out.nRejectedArtifact = detected.detection.nRejectedArtifact;
else
    out.nChannels = 0; out.nDetected = zeros(1, 0); out.nRejectedArtifact = zeros(1, 0);
end
if doSorted
    out.nUnits = numel(units.unitId);
else
    out.nUnits = 0;
end

if ~isempty(obj.Manifest) && isa(obj.Manifest, 'Manifest')
    obj.Manifest.add("spikesToMat", "Wrote spikes .mat", ...
        struct('file', file, 'source', opts.Source, 'bytes', out.bytes));
end
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


function tf = inIntervals(t, iv, Fs)
%inIntervals  True for each event on a sample inside any [t0 t1) period.
%   Compared in samples (t = index/Fs, 0-based), as manualArtifactMask counts
%   them: round(t0*Fs) up to but not including round(t1*Fs).
g = round(t * Fs);
tf = false(size(t));
for k = 1:size(iv, 1)
    tf = tf | (g >= round(iv(k, 1) * Fs) & g < round(iv(k, 2) * Fs));
end
end


function info = filterInfo(info, c, keep)
%filterInfo  Apply a per-event keep mask to detectSpikes' per-channel arrays.
n = numel(keep);
for f = ["index" "amplitude" "rejectedIndex" "droppedEdgeIndex"]
    if isfield(info, f) && iscell(info.(f)) && numel(info.(f)) >= c ...
            && numel(info.(f){c}) == n
        v = info.(f){c};
        info.(f){c} = v(keep);
    end
end
if isfield(info, 'count') && numel(info.count) >= c
    info.count(c) = nnz(keep);
end
end


function names = channelNamesFor(obj, channels)
names = strings(1, numel(channels));
cn = obj.ChannelNames;
ok = channels <= numel(cn);
names(ok) = cn(channels(ok));
names(~ok) = "ch" + string(channels(~ok));
end
