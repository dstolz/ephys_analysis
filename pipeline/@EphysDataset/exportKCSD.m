function out = exportKCSD(obj, opts)
%exportKCSD  Write this dataset's LFP and probe geometry for kCSD-python.
%   OUT = ds.exportKCSD(Name=Value) writes the derived LFP and the probe
%   positions of its channels to one NumPy .npz whose arrays go straight
%   into kCSD-python's estimators (https://github.com/Neuroinflab/kCSD-python)
%   outside this app:
%
%       import json, numpy as np
%       from kcsd import KCSD1D, KCSD2D
%       d = np.load("<Name>_kcsd.npz")
%       i0 = d["event_onset_sample"][0]              # e.g. one stimulus onset
%       seg = d["pots"][:, i0 - 50 : i0 + 200]       # [n_ele x n_time] mV
%       K = KCSD1D if d["ele_pos"].shape[1] == 1 else KCSD2D
%       k = K(d["ele_pos"], seg, sigma=0.3)          # mm, mV, S/m
%       meta = json.loads(d["meta"].item())
%
%   Packaging is done by KCSDExport; Python is never needed here. Only the
%   LFP is written (kCSD estimates the sources of the LFP); sorted units,
%   detected spikes and behavior have their own exports.
%
%   Arrays in the file (n = electrodes, N = LFP samples)
%   ------------------
%     ele_pos     [n x dim] float64, mm: dim 1 = position along the shank
%                 (the probe's yc), dim 2 = (xc, yc). Electrodes are the LFP
%                 channels on the probe less the interpolated bad channels,
%                 in probe order (by shank, top of the shank down, left to
%                 right). See KCSDExport.electrodes
%     pots        [n x N] float32, mV; sample i (0-based) at t = i/fs s on
%                 the continuous clock (the extract's row i+1)
%     fs          0-d float64, the LFP rate (Hz)
%     label, shank, x_um, y_um, extract_column, recording_channel   [n]
%                 per electrode (the column and channel are 1-based: the
%                 LFP column of the MATLAB extract and the amplifier channel)
%     excluded_label, excluded_recording_channel, excluded_reason   the LFP
%                 channels left out and why
%     event_names [L] the dig-in lines; event_line [n_ev] 0-based index into
%                 it; event_onset_s / event_offset_s seconds (t = row/eventFs
%                 on the recording clock); event_onset_sample /
%                 event_offset_sample int64 0-based LFP samples,
%                 round((t - 1/eventFs)*fs), sorted by onset
%     artifact_s  [k x 2] the artifact periods erased before the LFP was
%                 derived, [tStart tEnd) s; artifact_samples [m x 2] int64
%                 0-based [start stop) samples every period touches, merged
%     meta        0-d unicode JSON: tool, created, dataset, sourceFolder,
%                 sources (extractFile, probeFile), units, the LFP filter
%                 and reference, eventFs, dim and the time conventions
%
%   Options
%   -------
%     File       target (default <outputFolder>/<Name>_kcsd.npz)
%     Extract    "" (default: <outputFolder>/<Name>_extract.mat, else the
%                per-type <Name>_extract_LFP.mat), other extract file(s),
%                or a toMat-shaped struct (Y, events, info) holding LFP
%     ProbeFile  "" (default: the dataset's ProbeFile) or the probe .json the
%                dataset is used with (EphysPipeline.probeFor: its own, a
%                rule's or the default probe). kCSD needs the positions, so
%                there is no export without a probe
%     Dim        "auto" (default: 1 on a single column of one shank, else 2)
%                | 1 | 2
%     Sources    provenance to record for an extract passed as a struct
%                (extractFile)
%     Events     true (default) | false
%     Overwrite  false (default): error if File exists
%
%   OUT: file, bytes, seconds, signals ("LFP"), nElectrodes, dim,
%   nExcluded, excluded (table: column, recordingChannel, label, reason),
%   nEvents, probeFile, sources.
%
%   The .npz is written as "~<name>.partial.npz" next to File and renamed
%   into place once complete.
%
%   See also KCSDExport, writeNPZ, EphysDataset.channelLayout,
%   EphysDataset.exportChronux, EphysDataset.exportFieldTrip.

arguments
    obj (1,1) EphysDataset
    opts.File (1,1) string = ""
    opts.Extract = ""
    opts.ProbeFile (1,1) string = ""
    opts.Dim = "auto"
    opts.Sources struct = struct()
    opts.Events (1,1) logical = true
    opts.Overwrite (1,1) logical = false
end

t0 = tic;
file = opts.File;
if file == ""
    file = string(fullfile(obj.outputFolder(), obj.Name + "_kcsd.npz"));
end
if isfile(file) && ~opts.Overwrite
    error('EphysDataset:exportKCSD:Exists', ...
        '%s already exists (pass Overwrite=true to replace it).', file);
end
probeFile = opts.ProbeFile;
if probeFile == ""; probeFile = obj.ProbeFile; end
if probeFile == ""
    error('EphysDataset:exportKCSD:NoProbe', ...
        '%s has no probe: kCSD needs the electrode positions. Assign a probe, or pass ProbeFile=.', obj.Name);
end
layout = obj.channelLayout(ProbeFile=probeFile);
if ~layout.hasProbe
    error('EphysDataset:exportKCSD:NoProbe', ...
        'The probe %s places none of %s''s channels (unreadable, or no chanMap entry for them).', probeFile, obj.Name);
end

ro = struct('Extract', {opts.Extract}, 'Signals', "LFP", 'Units', false, 'Detected', false, ...
    'Events', opts.Events, 'Groups', string.empty(1,0), 'Sources', opts.Sources);
in = resolveExportInputs(obj, ro, 'exportKCSD');
S = in.S;
fs = double(S.info.LFP.Fs);
nSamples = size(S.Y.LFP, 1);

el = KCSDExport.electrodes(S, layout, Dim=opts.Dim);
ev = KCSDExport.events(in.events, fs, in.eventFs);
art = KCSDExport.artifacts(double(in.artifacts.intervals), fs, nSamples);

meta = struct( ...
    'tool',         "EphysDataset.exportKCSD", ...
    'created',      string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',      obj.Name, ...
    'sourceFolder', obj.Folder, ...
    'sources',      struct('extractFile', in.sources.extractFile, 'probeFile', probeFile), ...
    'signal',       "LFP", ...
    'fs',           fs, ...
    'eventFs',      in.eventFs, ...
    'nSamples',     nSamples, ...
    'nElectrodes',  numel(el.column), ...
    'dim',          el.dim, ...
    'elePosAxes',   {cellstr(ternary(el.dim == 1, "y", ["x" "y"]))}, ...
    'units',        struct('ele_pos', "mm", 'pots', "mV", 'x_um', "um", 'y_um', "um", ...
                        'fs', "Hz", 'times', "s"), ...
    'lfp',          lfpInfo(S.info), ...
    'artifactFill', artifactFill(in.artifacts), ...
    'timeConventions', struct( ...
        'pots', "sample i (0-based) at t = i/fs s on the continuous clock", ...
        'events', "t = row/eventFs (1-based row of the recording); sample = round((t - 1/eventFs)*fs), 0-based", ...
        'artifacts', "[tStart tEnd) s on the continuous clock; samples [start stop) 0-based, every sample a period touches"));
provenance = in.sources;

A = struct();
A.ele_pos = el.ele_pos;
A.pots = KCSDExport.pots(S, el.column);
clear S in                             % the extract: only the potentials are needed now
A.fs = fs;
A.label = el.label;
A.shank = int64(el.shank);
A.x_um = el.x_um;
A.y_um = el.y_um;
A.extract_column = int64(el.column);
A.recording_channel = int64(el.recordingChannel);
A.excluded_label = el.excluded.label;
A.excluded_recording_channel = int64(el.excluded.recordingChannel);
A.excluded_reason = el.excluded.reason;
A.event_names = ev.names;
A.event_line = ev.line;
A.event_onset_s = ev.onset_s;
A.event_offset_s = ev.offset_s;
A.event_onset_sample = ev.onset_sample;
A.event_offset_sample = ev.offset_sample;
A.artifact_s = art.s;
A.artifact_samples = art.samples;
A.meta = string(jsonencode(meta, 'PrettyPrint', true));

shapes = struct('ele_pos', "full", 'pots', "transpose", 'fs', "scalar", 'meta', "scalar", ...
    'artifact_s', "full", 'artifact_samples', "full");
for f = ["label" "shank" "x_um" "y_um" "extract_column" "recording_channel" ...
        "excluded_label" "excluded_recording_channel" "excluded_reason" "event_names" ...
        "event_line" "event_onset_s" "event_offset_s" "event_onset_sample" "event_offset_sample"]
    shapes.(f) = "vector";
end

[outDir, base] = fileparts(file);
if strlength(outDir) > 0 && ~isfolder(outDir)
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('EphysDataset:exportKCSD:MkdirFailed', 'Could not create %s: %s', outDir, msg);
    end
end
tmp = fullfile(outDir, "~" + base + ".partial.npz");
if isfile(tmp); delete(tmp); end
try
    writeNPZ(tmp, A, Shapes=shapes);
    [ok, msg] = movefile(tmp, file, 'f');
    if ~ok
        error('EphysDataset:exportKCSD:RenameFailed', 'Could not move %s to %s: %s', tmp, file, msg);
    end
catch ME
    if isfile(tmp); delete(tmp); end
    rethrow(ME);
end

d = dir(file);
out = struct('file', file, 'bytes', d.bytes, 'seconds', toc(t0), 'signals', "LFP", ...
    'nElectrodes', numel(el.column), 'dim', el.dim, 'nExcluded', height(el.excluded), ...
    'excluded', el.excluded, 'nEvents', numel(ev.line), 'probeFile', probeFile, ...
    'sources', provenance);
end


function L = lfpInfo(info)
%lfpInfo  The LFP's filter / rate description and the common reference, for meta.
L = struct();
if isfield(info, 'LFP') && isstruct(info.LFP)
    for f = ["Fs" "bpLoHi" "NotchHz" "NotchBW" "filter" "reference"]
        if isfield(info.LFP, f); L.(f) = info.LFP.(f); end
    end
end
if isfield(info, 'reference') && isstruct(info.reference) && isfield(info.reference, 'mode')
    L.referenceMode = info.reference.mode;
    if isfield(info.reference, 'channels'); L.referenceChannels = info.reference.channels; end
end
if isfield(info, 'origFs'); L.recordingFs = info.origFs; end
end


function f = artifactFill(a)
f = "none";
if isstruct(a) && isfield(a, 'fill'); f = string(a.fill); end
end


function out = ternary(cond, a, b)
if cond; out = a; else; out = b; end
end
