classdef EphysTraceSource < handle
    % EphysTraceSource  One continuous signal of a dataset, read a window at a time.
    %   An EphysTraceSource is what the app's Visualize tab (EphysTraceViewer)
    %   draws: the recording itself, the Kilosort4 .bin the Sorting step
    %   wrote, or one derived signal of the Signals step (LFP, MUA, SPIKE,
    %   AUX). Every kind answers the same question -
    %
    %     X = src.read(r0, n)     rows r0 .. r0+n-1 (0-based) of every channel,
    %                             [n x NumChannels] single, in Units
    %
    %   - reading only those rows from disk wherever the format allows it,
    %   so a window of a long recording costs about what the window holds:
    %
    %     "recording"  the dataset's reader: readWindowUV for readers with
    %                  random access, else the streamPlan chunks (one *.rhd
    %                  file) holding the window, the last ones kept in memory.
    %                  Reference "pipeline" reads it with the dataset's common
    %                  reference (as every step reads it), "none" as stored.
    %     "bin"        the int16 .bin (EphysDataset.toBin): channel-major
    %                  samples, read with fread, microvolts = (raw - offset) /
    %                  scale from its JSON sidecar. It is what Kilosort4
    %                  sorted: artifact periods filled, the common reference
    %                  subtracted when one was on.
    %     "signal"     Y.<TYPE> of an extract file (EphysDataset.toMat). A
    %                  -v7.3 file is HDF5 and its rows are read with h5read;
    %                  a -v7 file is loaded once and kept.
    %
    %   Row k (1-based) of every kind is at (k-1)/Fs seconds on the
    %   recording's clock, as sorted spike times and the artifact periods.
    %   RecordingChannels gives the recording channel (1-based) each column
    %   holds, so probe layouts and the peak channels of sorted units apply
    %   to any kind (NaN for AUX inputs).
    %
    %   Sources are built with the static constructors:
    %
    %     S   = EphysTraceSource.forDataset(ds)    every kind the dataset has
    %     src = EphysTraceSource.recording(ds)
    %     src = EphysTraceSource.binFile(ds)       or binFile(file) for any .bin
    %     src = EphysTraceSource.signal(file, "LFP")
    %
    %   Nothing is ever written, and no file is held open between reads.
    %
    %   See also EphysTraceViewer, EphysDataset.readWindowUV,
    %   EphysDataset.toBin, EphysDataset.toMat, DatasetOutputs.

    properties (SetAccess = private)
        Kind (1,1) string = ""                 % "recording" | "bin" | "signal"
        Name (1,1) string = ""                 % "Recording", "Sorting .bin", "LFP", ...
        Note (1,1) string = ""                 % what the signal is, in words
        File (1,1) string = ""                 % the file read ("" for the recording)
        Fs (1,1) double = NaN                  % sample rate (Hz)
        NumSamples (1,1) double = 0            % rows
        NumChannels (1,1) double = 0           % columns
        ChannelNames (1,:) string = string.empty(1,0)
        RecordingChannels (1,:) double = double.empty(1,0)   % recording channel of each column
        Units (1,1) string = "uV"              % "uV", or "V" for AUX inputs
        Dataset = []                           % the EphysDataset it belongs to ([] = a bare file)
    end

    properties
        % Recording only: "pipeline" reads with the dataset's common
        % reference (Artifacts.Reference), "none" as stored.
        Reference (1,1) string {mustBeMember(Reference, ["pipeline" "none"])} = "pipeline"
        % Recording chunks kept in memory for readers without random access (bytes).
        ChunkCacheBytes (1,1) double = 1.5e9
    end

    properties (Dependent)
        Duration        % NumSamples / Fs (s)
    end

    properties (Access = private)
        Bin = struct()                         % dtype, bytes, scale, offset
        H5Path (1,1) string = ""               % dataset inside a -v7.3 extract
        SignalType (1,1) string = ""
        Loaded = []                            % a -v7 extract's signal, once loaded
        Plan = []                              % streamPlan (readers without random access)
        PlanStarts = []                        % first row of each chunk
        Chunks = struct('index', {}, 'reference', {}, 'X', {})   % most recent last
    end

    methods
        function d = get.Duration(obj)
            d = obj.NumSamples / obj.Fs;
        end

        function X = read(obj, r0, n)
            %read  Rows R0 .. R0+N-1 (0-based) of every channel, [n x NumChannels] single.
            %   Clipped to the source: fewer rows (possibly none) come back
            %   past its end, and R0 < 0 starts at row 0.
            r0 = max(0, floor(r0));
            n = min(floor(n), obj.NumSamples - r0);
            if n <= 0
                X = zeros(0, obj.NumChannels, 'single');
                return
            end
            switch obj.Kind
                case "recording"
                    X = readRecording(obj, r0, n);
                case "bin"
                    X = readBin(obj, r0, n);
                case "signal"
                    X = readSignal(obj, r0, n);
                otherwise
                    error('EphysTraceSource:Empty', 'The source holds no signal.');
            end
        end

        function [mn, mx] = readMinMax(obj, r0, n, b, cols)
            %readMinMax  Min and max of every B rows of rows R0 .. R0+N-1, columns COLS.
            %   [nBins x numel(COLS)] single each; the last bin may be short.
            %   The same as binMinMax(read(r0, n)(:, cols), b), but a .bin
            %   takes them on its stored integers, before any conversion.
            r0 = max(0, floor(r0));
            n = min(floor(n), obj.NumSamples - r0);
            if n <= 0
                mn = zeros(0, numel(cols), 'single');
                mx = mn;
                return
            end
            if obj.Kind ~= "bin"
                X = obj.read(r0, n);
                [mn, mx] = EphysTraceSource.binMinMax(X(:, cols), b);
                return
            end
            raw = readBinRaw(obj, r0, n);            % [nChan x n], stored type
            if ~isequal(cols(:).', 1:obj.NumChannels)
                raw = raw(cols, :);
            end
            full = floor(n / b) * b;
            R = reshape(raw(:, 1:full), numel(cols), b, []);
            lo = reshape(min(R, [], 2), numel(cols), []);
            hi = reshape(max(R, [], 2), numel(cols), []);
            if full < n                              % the short last bin
                lo(:, end+1) = min(raw(:, full+1:end), [], 2);
                hi(:, end+1) = max(raw(:, full+1:end), [], 2);
            end
            s = single(obj.Bin.scale);
            o = single(obj.Bin.offset);
            mn = (single(lo).' - o) / s;
            mx = (single(hi).' - o) / s;
            if s < 0
                [mn, mx] = deal(mx, mn);
            end
        end

        function k = key(obj)
            %key  Text that changes whenever what read() returns may change.
            k = obj.Kind + "|" + obj.File + "|" + obj.SignalType + "|" + obj.Reference;
            if obj.Kind == "recording" && ~isempty(obj.Dataset)
                d = obj.Dataset;
                acfg = EphysDataset.normalizeArtifactConfig(d.ArtifactConfig);
                k = k + "|" + d.Folder + "|" + string(acfg.Reference) + "|" ...
                    + strjoin(string(d.referenceChannels()), ",");
            end
        end

        function clearCache(obj)
            %clearCache  Let go of the recording chunks and a loaded -v7 signal.
            obj.Chunks = obj.Chunks([]);
            obj.Loaded = [];
        end
    end

    methods (Static)
        function [mn, mx] = binMinMax(X, b)
            %binMinMax  Min and max of every B rows of X (the last bin may be short).
            if b <= 1
                mn = X;
                mx = X;
                return
            end
            [n, c] = size(X);
            nb = ceil(n / b);
            if nb * b > n
                X(nb * b, c) = NaN;          % min / max leave NaN out
                X(n + 1:end, :) = NaN;
            end
            R = reshape(X, b, nb, c);
            mn = reshape(min(R, [], 1), nb, c);
            mx = reshape(max(R, [], 1), nb, c);
        end

        function [S, skipped] = forDataset(ds, opts)
            %forDataset  Every source a dataset has: recording, .bin, signals.
            %   S = EphysTraceSource.forDataset(DS) returns a 1 x k array, the
            %   recording first when its files can be read, then the .bin
            %   (DS.BinFile) when it exists, then the extract's LFP, MUA,
            %   SPIKE and AUX (DatasetOutputs.signalFile). A source that
            %   cannot be opened is left out: SKIPPED says why, one string
            %   each, or without that output a warning does
            %   (EphysTraceSource:Skipped). Outputs=OUT reuses a
            %   DatasetOutputs of DS instead of scanning again.
            arguments
                ds (1,1) EphysDataset
                opts.Outputs = []
            end
            S = EphysTraceSource.empty(1, 0);
            skipped = strings(1, 0);
            skip = @(what, ME) "Cannot read " + what + ": " + string(ME.message);
            try
                if ds.NumFiles == 0; ds.discoverFiles(); end
                if ds.NumFiles > 0 && isfinite(ds.Fs) && isfinite(ds.NumSamples)
                    S(end+1) = EphysTraceSource.recording(ds);
                end
            catch ME
                skipped(end+1) = skip("the recording", ME);
            end
            if isfile(ds.BinFile)
                try
                    S(end+1) = EphysTraceSource.binFile(ds);
                catch ME
                    skipped(end+1) = skip(ds.BinFile, ME);
                end
            end
            out = opts.Outputs;
            if isempty(out)
                out = ds.outputs();
            end
            for type = DatasetOutputs.SignalTypes
                f = out.signalFile(type);
                if isempty(f); continue; end
                try
                    S(end+1) = EphysTraceSource.signal(f, type, Dataset=ds); %#ok<AGROW>
                catch ME
                    skipped(end+1) = skip(f + " (" + type + ")", ME); %#ok<AGROW>
                end
            end
            if nargout < 2
                for m = skipped
                    warning('EphysTraceSource:Skipped', '%s', m);
                end
            end
        end

        function src = recording(ds, opts)
            %recording  The dataset's recording, read through its reader.
            arguments
                ds (1,1) EphysDataset
                opts.Reference (1,1) string = "pipeline"
            end
            if isnan(ds.Fs) || isempty(ds.PerFile)
                ds.refreshMetadata();
            end
            src = EphysTraceSource();
            src.Kind = "recording";
            src.Name = "Recording";
            src.Dataset = ds;
            src.Fs = ds.Fs;
            src.NumSamples = ds.NumSamples;
            src.NumChannels = ds.NumChannels;
            src.ChannelNames = channelNames(ds.ChannelNames, ds.NumChannels);
            src.RecordingChannels = 1:ds.NumChannels;
            src.Reference = opts.Reference;
            src.Note = "the recording as read by every step";
            if ~ds.supportsRandomAccess()
                plan = ds.streamPlan();
                ns = [plan.nSamples];
                ns(~isfinite(ns)) = 0;
                src.Plan = plan;
                src.PlanStarts = [0, cumsum(ns)];
            end
        end

        function src = binFile(target)
            %binFile  The int16 .bin the Sorting step wrote, or any toBin .bin.
            %   binFile(DS) reads DS.BinFile; binFile(FILE) a .bin file. The
            %   JSON sidecar (<file>.json) gives the channel count, rate,
            %   type and scale; without one they come from the dataset.
            ds = [];
            if isa(target, 'EphysDataset')
                ds = target;
                file = string(ds.BinFile);
            else
                file = string(target);
            end
            if ~isfile(file)
                error('EphysTraceSource:NoFile', 'No .bin file at %s.', file);
            end
            [p, stem] = fileparts(file);
            meta = struct();
            side = fullfile(p, stem + ".json");
            if isfile(side)
                m = readJsonFile(side, ErrorOnFail=false);
                if isstruct(m); meta = m; end
            end
            nChan = field(meta, 'n_chan_bin', NaN);
            fs = field(meta, 'fs', NaN);
            dtype = string(field(meta, 'dtype', "int16"));
            scale = field(meta, 'scale', NaN);
            offset = field(meta, 'offset', 0);
            if ~isempty(ds)
                if isnan(ds.Fs); ds.refreshMetadata(); end
                if isnan(nChan); nChan = ds.NumChannels; end
                if isnan(fs); fs = ds.Fs; end
                if isnan(scale); scale = ds.Scale; end
            end
            if ~(nChan >= 1 && fs > 0 && scale ~= 0)
                error('EphysTraceSource:BinLayout', ...
                    'The channel count, rate or scale of %s is unknown (no JSON sidecar and no dataset).', file);
            end
            bytes = bytesOf(dtype);
            info = dir(file);
            src = EphysTraceSource();
            src.Kind = "bin";
            src.Name = "Sorting .bin";
            src.File = file;
            src.Dataset = ds;
            src.Fs = fs;
            src.NumChannels = nChan;
            src.NumSamples = floor(info.bytes / (bytes * nChan));
            src.RecordingChannels = 1:nChan;
            names = string.empty(1, 0);
            if ~isempty(ds) && ds.NumChannels == nChan; names = ds.ChannelNames; end
            src.ChannelNames = channelNames(names, nChan);
            src.Bin = struct('dtype', dtype, 'bytes', bytes, 'scale', scale, 'offset', offset);
            src.Note = binNote(meta);
        end

        function src = signal(file, type, opts)
            %signal  Derived signal TYPE ("LFP" | "MUA" | "SPIKE" | "AUX") of an extract file.
            %   Dataset=DS names the channels as DS does when the file has no labels.
            arguments
                file (1,1) string
                type (1,1) string {mustBeMember(type, ["LFP" "MUA" "SPIKE" "AUX"])}
                opts.Dataset = []
            end
            if ~isfile(file)
                error('EphysTraceSource:NoFile', 'No extract file at %s.', file);
            end
            I = load(file, 'info');
            if ~isfield(I, 'info') || ~isfield(I.info, type) || ~isfield(I.info.(type), 'Fs')
                error('EphysTraceSource:NoSignal', '%s holds no %s signal.', file, type);
            end
            info = I.info;
            src = EphysTraceSource();
            src.Kind = "signal";
            src.Name = type;
            src.File = file;
            src.SignalType = type;
            src.Dataset = opts.Dataset;
            src.Fs = double(info.(type).Fs);
            h5 = "/Y/" + type;
            nRows = NaN; nCols = NaN;
            if isHDF5(file)
                try
                    D = h5info(file, h5);
                    sz = double(D.Dataspace.Size);   % as h5read returns it: [rows cols]
                    nRows = sz(1);
                    nCols = 1;
                    if numel(sz) > 1; nCols = sz(2); end
                    src.H5Path = h5;
                catch
                end
            end
            if src.H5Path == ""
                W = whos('-file', file, 'Y');
                if isempty(W)
                    error('EphysTraceSource:NoSignal', '%s holds no Y variable.', file);
                end
                src.Loaded = [];      % loaded at the first read
            end
            if isnan(nRows)
                nRows = field(info.(type), 'nSamples', NaN);
                if isnan(nRows)       % an old file: load the signal to size it
                    Y = load(file, 'Y');
                    src.Loaded = single(Y.Y.(type));
                    nRows = size(src.Loaded, 1);
                    nCols = size(src.Loaded, 2);
                end
            end
            src.NumSamples = nRows;
            if type == "AUX"
                labels = string(field(info.AUX, 'labels', strings(0, 1)));
                src.Units = "V";
                src.Note = "auxiliary inputs (volts)";
            else
                labels = string(field(info, 'labels', strings(0, 1)));
                src.Note = signalNote(info, type);
            end
            if isnan(nCols); nCols = numel(labels); end
            if isnan(nCols) || nCols == 0
                Y = load(file, 'Y');
                src.Loaded = single(Y.Y.(type));
                nCols = size(src.Loaded, 2);
            end
            src.NumChannels = nCols;
            src.ChannelNames = channelNames(reshape(labels, 1, []), nCols);
            if type == "AUX"
                src.RecordingChannels = NaN(1, nCols);
            else
                src.RecordingChannels = recordingChannels(info, nCols);
            end
        end
    end

    methods (Access = private)
        function X = readRecording(obj, r0, n)
            d = obj.Dataset;
            ref = obj.Reference == "pipeline";
            if isempty(obj.Plan)
                X = single(d.readWindowUV(r0, n, Reference=ref));
                return
            end
            X = zeros(n, obj.NumChannels, 'single');
            starts = obj.PlanStarts;
            first = find(starts(1:end-1) <= r0, 1, 'last');
            last = find(starts(1:end-1) < r0 + n, 1, 'last');
            for i = first:last
                C = chunk(obj, i);
                a = max(r0, starts(i));
                b = min(r0 + n, starts(i) + size(C, 1));
                if b > a
                    X(a - r0 + 1 : b - r0, :) = C(a - starts(i) + 1 : b - starts(i), :);
                end
            end
        end

        function C = chunk(obj, i)
            % Chunk I of the stream plan as single, from memory when it was read lately.
            for j = numel(obj.Chunks):-1:1
                if obj.Chunks(j).index == i && obj.Chunks(j).reference == obj.Reference
                    c = obj.Chunks(j);
                    obj.Chunks(j) = [];
                    obj.Chunks(end+1) = c;     % most recent last
                    C = c.X;
                    return
                end
            end
            C = single(obj.Dataset.readChunkUV(obj.Plan(i), Reference=obj.Reference == "pipeline"));
            obj.Chunks(end+1) = struct('index', i, 'reference', obj.Reference, 'X', C);
            % Keep the latest chunks within the budget (at least the two newest,
            % so a window across a chunk boundary is not read twice).
            while numel(obj.Chunks) > 2 && sum(arrayfun(@(c) numel(c.X) * 4, obj.Chunks)) > obj.ChunkCacheBytes
                obj.Chunks(1) = [];
            end
        end

        function X = readBin(obj, r0, n)
            % Read in the stored type and convert once: several times faster
            % than fread converting as it reads.
            b = obj.Bin;
            X = single(readBinRaw(obj, r0, n).');
            if b.offset ~= 0
                X = X - single(b.offset);
            end
            X = X * single(1 / b.scale);
        end

        function raw = readBinRaw(obj, r0, n)
            % Rows r0 .. r0+n-1 of the .bin as stored, [nChan x n].
            b = obj.Bin;
            fid = fopen(obj.File, 'r', 'ieee-le');
            if fid < 0
                error('EphysTraceSource:Open', 'Could not open %s.', obj.File);
            end
            closer = onCleanup(@() fclose(fid));
            fseek(fid, r0 * obj.NumChannels * b.bytes, 'bof');
            raw = fread(fid, [obj.NumChannels, n], char("*" + b.dtype));
            if size(raw, 2) < n
                error('EphysTraceSource:Short', 'Only %d of %d rows could be read from %s.', ...
                    size(raw, 2), n, obj.File);
            end
        end

        function X = readSignal(obj, r0, n)
            if obj.H5Path ~= ""
                X = h5read(obj.File, obj.H5Path, [r0 + 1, 1], [n, obj.NumChannels]);
                X = single(X);
                return
            end
            if isempty(obj.Loaded)
                Y = load(obj.File, 'Y');
                obj.Loaded = single(Y.Y.(obj.SignalType));
            end
            X = obj.Loaded(r0 + 1 : r0 + n, :);
        end
    end
end


function v = field(s, name, default)
% S.NAME when it is there and not empty, else DEFAULT.
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
    if isnumeric(default) && ~isnumeric(v); v = default; end
end
end


function names = channelNames(names, n)
% N channel names: NAMES when there are N of them, else "ch1".."chN".
names = reshape(string(names), 1, []);
if numel(names) ~= n || any(names == "")
    names = compose("ch%d", 1:n);
end
end


function b = bytesOf(dtype)
switch dtype
    case {"int16", "uint16"}, b = 2;
    case {"int32", "uint32", "single", "float32"}, b = 4;
    case {"double", "float64"}, b = 8;
    otherwise
        error('EphysTraceSource:Dtype', 'Unsupported .bin data type "%s".', dtype);
end
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


function ch = recordingChannels(info, nCols)
% The recording channel of each column: keepAmpChannels, then channelRemap
% (EphysDataset.deriveSignals), else 1..nCols.
ch = 1:nCols;
if ~isfield(info, 'importOptions') || ~isstruct(info.importOptions); return; end
o = info.importOptions;
keep = [];
if isfield(o, 'keepAmpChannels'); keep = double(o.keepAmpChannels(:).'); end
remap = [];
if isfield(o, 'channelRemap'); remap = double(o.channelRemap(:).'); end
if isempty(keep)
    keep = 1:max([nCols, remap]);
end
if ~isempty(remap) && all(remap <= numel(keep))
    keep = keep(remap);
end
if numel(keep) == nCols
    ch = keep;
end
end


function s = binNote(meta)
% What was done to the .bin's samples, from its sidecar.
parts = "what Kilosort4 sorted";
if isfield(meta, 'reference') && isstruct(meta.reference) && isfield(meta.reference, 'mode')
    mode = string(meta.reference.mode);
    if mode == "car"
        parts(end+1) = "common average reference";
    elseif mode == "cmr"
        parts(end+1) = "common median reference";
    end
end
if isfield(meta, 'artifact_fill')
    parts(end+1) = "artifact periods filled (" + string(meta.artifact_fill) + ")";
end
s = strjoin(parts, "; ");
end


function s = signalNote(info, type)
% What the derived signal is: its band, its reference and the artifact erase.
parts = strings(1, 0);
band = [];
if isfield(info, type) && isfield(info.(type), 'bpLoHi'); band = double(info.(type).bpLoHi); end
if numel(band) == 2
    if band(1) > 0 && isfinite(band(2))
        parts(end+1) = sprintf("%g-%g Hz", band(1), band(2));
    elseif band(1) > 0
        parts(end+1) = sprintf("above %g Hz", band(1));
    elseif isfinite(band(2))
        parts(end+1) = sprintf("below %g Hz", band(2));
    else
        parts(end+1) = "broadband";
    end
end
if type == "MUA" && isfield(info.MUA, 'IntegrationHz') && ~isempty(info.MUA.IntegrationHz)
    parts(end+1) = sprintf("rectified, smoothed below %g Hz", info.MUA.IntegrationHz);
end
if isfield(info, 'reference') && isstruct(info.reference) && isfield(info.reference, 'signals') ...
        && any(string(info.reference.signals) == type) && isfield(info.reference, 'mode')
    parts(end+1) = upper(string(info.reference.mode)) + " referenced";
end
if isfield(info, 'artifacts') && isstruct(info.artifacts) && isfield(info.artifacts, 'intervals') ...
        && ~isempty(info.artifacts.intervals)
    parts(end+1) = sprintf("%d artifact period(s) erased", size(info.artifacts.intervals, 1));
end
s = strjoin(parts, "; ");
end
