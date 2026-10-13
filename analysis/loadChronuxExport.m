function X = loadChronuxExport(file, opts)
%loadChronuxExport  What a <Name>_chronux.mat holds, or a window of one of its signals.
%   X = loadChronuxExport(FILE) reads the file's index and its small
%   variables, never a signal's data:
%     file, bytes, datenum   the file and its size and date
%     hdf5                   true for a -v7.3 file (signals read by parts)
%     export                 the export's provenance (EphysDataset.exportChronux)
%     created, dataset, eventFs   from it
%     signals                one field per signal in the file ("LFP", "MUA",
%                            "SPIKE", "AUX"): fs, nSamples, nChan, labels,
%                            units, durationSec, bytes, windowed (true: its
%                            rows are read with h5read, a block at a time)
%     events                 dig-in lines -> [k x 2] [t_on t_off] s (t = row/eventFs)
%     artifacts              [k x 2] [tStart tEnd) s on the continuous clock
%     units, sp              the sorted units and their Chronux spike trains
%                            ([] when there are none)
%     detected, spDetected   the threshold detections, the same way
%   The index comes from export.layout, which exportChronux writes; a file
%   without it is refused (loadChronuxExport:NoLayout: create it again).
%
%   D = loadChronuxExport(FILE, Signal=SIG, Name=Value) reads rows of one
%   signal: D.data [n x nSel] single (microvolts; AUX volts), fs, row0 (the
%   first row read, 1-based), t0 = (row0-1)/fs, nSamples (the signal's),
%   channels, labels, units, signal.
%     Channels   columns to read (default [] = all), in the order given
%     Rows       [r0 r1] 1-based rows, inclusive (default: all)
%     Span       [t0 t1] s on the continuous clock instead of Rows: the
%                rows (k-1)/fs in it, and one more each side, within the
%                signal
%     Index      X from an earlier call, so the index is not read again
%     MaxMB      refuse (loadChronuxExport:TooLarge) to hold more than this
%                many MB (default Inf); a file read whole (-v7) is checked
%                by the signal's size on disk
%     Check      a function handle called with no input between blocks
%                of rows (default []); it may throw to stop (Cancel)
%     BlockRows  rows per h5read (default 1e6)
%
%   Errors: loadChronuxExport:NoFile, :NoLayout, :NoSignal, :BadChannel,
%   :BadRows, :TooLarge.
%
%   See also EphysDataset.exportChronux, chronuxTimeBase, chronuxSpectrum.

arguments
    file (1,1) string
    opts.Signal (1,1) string = ""
    opts.Channels double = []
    opts.Rows double = []
    opts.Span double = []
    opts.Index = []
    opts.MaxMB (1,1) double {mustBePositive} = Inf
    opts.Check = []
    opts.BlockRows (1,1) double {mustBePositive, mustBeInteger} = 1e6
end

if opts.Signal == ""
    X = readIndex(file);
    return
end
I = opts.Index;
if isempty(I); I = readIndex(file); end
X = readSignal(file, I, opts);
end


function X = readIndex(file)
if ~isfile(file)
    error('loadChronuxExport:NoFile', 'No Chronux file at %s.', file);
end
d = dir(file);
W = whos('-file', file);
names = string({W.name});
small = cellstr(intersect(["export" "events" "artifacts" "units" "sp" "detected" "spDetected"], names, 'stable'));
V = struct();
if ismember("export", names); V = load(file, small{:}); end   % never load(file): that is every signal
if ~isfield(V, 'export') || ~isstruct(V.export) || ~isfield(V.export, 'layout')
    error('loadChronuxExport:NoLayout', ['%s has no export.layout, the index its signals are read by: ' ...
        'create the Chronux file again.'], file);
end
X = struct();
X.file = file;
X.bytes = d.bytes;
X.datenum = d.datenum;
X.hdf5 = isHDF5(file);
X.export = V.export;
X.created = string(field(V.export, 'created', ""));
X.dataset = string(field(V.export, 'dataset', ""));
X.eventFs = double(field(V.export, 'eventFs', NaN));
X.signals = struct();
L = V.export.layout;
for sig = ["LFP" "MUA" "SPIKE" "AUX"]
    if ~ismember(sig, names) || ~isfield(L, sig); continue; end
    s = L.(sig);
    w = W(names == sig);
    labels = reshape(string(s.labels), 1, []);
    if numel(labels) ~= s.nChan; labels = compose("ch%d", 1:s.nChan); end
    X.signals.(sig) = struct('fs', double(s.fs), 'nSamples', double(s.nSamples), 'nChan', double(s.nChan), ...
        'labels', labels, 'units', string(s.units), 'durationSec', double(s.nSamples) / double(s.fs), ...
        'bytes', w.bytes, 'windowed', X.hdf5);
end
X.events = field(V, 'events', struct());
if ~isstruct(X.events); X.events = struct(); end
X.artifacts = zeros(0, 2);
if isfield(V, 'artifacts') && isstruct(V.artifacts) && isfield(V.artifacts, 'intervals')
    X.artifacts = reshape(double(V.artifacts.intervals), [], 2);
end
X.units = field(V, 'units', []);
X.sp = field(V, 'sp', []);
X.detected = field(V, 'detected', []);
X.spDetected = field(V, 'spDetected', []);
end


function D = readSignal(file, I, opts)
sig = opts.Signal;
if ~isfield(I.signals, sig)
    have = string(fieldnames(I.signals)).';
    if isempty(have); have = "none"; end
    error('loadChronuxExport:NoSignal', '%s holds no %s signal (it has: %s).', file, sig, strjoin(have, ", "));
end
L = I.signals.(sig);
ch = opts.Channels;
if isempty(ch); ch = 1:L.nChan; end
ch = reshape(double(ch), 1, []);
if any(ch < 1 | ch > L.nChan | ch ~= round(ch))
    error('loadChronuxExport:BadChannel', 'Channels must be whole numbers from 1 to %d.', L.nChan);
end
if ~isempty(opts.Span)
    sp = double(opts.Span);
    rows = [max(1, floor(sp(1) * L.fs + 1e-6)), min(L.nSamples, ceil(sp(2) * L.fs - 1e-6) + 2)];
elseif ~isempty(opts.Rows)
    rows = double(opts.Rows);
else
    rows = [1 L.nSamples];
end
if numel(rows) ~= 2 || rows(1) < 1 || rows(2) > L.nSamples || rows(2) < rows(1) || any(rows ~= round(rows))
    error('loadChronuxExport:BadRows', 'Rows must be [r0 r1] within 1..%d (got %s).', L.nSamples, mat2str(rows));
end
n = rows(2) - rows(1) + 1;
mb = n * numel(ch) * 4 / 2^20;
if ~L.windowed
    mb = max(mb, L.bytes / 2^20);
end
if mb > opts.MaxMB
    error('loadChronuxExport:TooLarge', ['Reading %s would hold %.0f MB (over %g MB): pick fewer channels or a ' ...
        'shorter stretch.'], sig, mb, opts.MaxMB);
end
data = zeros(n, numel(ch), 'single');
if L.windowed
    c0 = min(ch);
    nc = max(ch) - c0 + 1;
    for b = rows(1):opts.BlockRows:rows(2)
        m = min(opts.BlockRows, rows(2) - b + 1);
        Y = h5read(file, "/" + sig + "/data", [b c0], [m nc]);
        data(b - rows(1) + (1:m), :) = single(Y(:, ch - c0 + 1));
        if ~isempty(opts.Check); opts.Check(); end
    end
else
    S = load(file, sig);
    data(:, :) = single(S.(sig).data(rows(1):rows(2), ch));
    if ~isempty(opts.Check); opts.Check(); end
end
D = struct('signal', sig, 'data', data, 'fs', L.fs, 'row0', rows(1), 't0', (rows(1) - 1) / L.fs, ...
    'nSamples', L.nSamples, 'channels', ch, 'labels', L.labels(ch), 'units', L.units);
end


function v = field(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name)); v = s.(name); end
end


function tf = isHDF5(file)
% True for a -v7.3 MAT-file (an HDF5 file with a MATLAB header).
tf = false;
fid = fopen(file, 'r');
if fid < 0; return; end
hdr = fread(fid, 19, '*char').';
fclose(fid);
tf = startsWith(hdr, 'MATLAB 7.3');
end
