classdef BinaryReader < EphysReader
    % BinaryReader  EphysReader for the universal "ephys-recording/1" format.
    %   A recording is a folder holding a descriptor named recording.json next
    %   to one flat binary data file:
    %
    %     recording.json
    %     {
    %       "schema":        "ephys-recording/1",
    %       "name":          "subj1_day1",              (optional)
    %       "data_file":     "subj1_day1.bin",          relative to the folder
    %       "dtype":         "int16",                   int16|uint16|int32|single|float32|double
    %       "n_chan":        64,
    %       "fs":            30000,
    %       "n_samples":     18000000,                  (optional; else from the file size)
    %       "byte_order":    "little-endian",           (optional; default)
    %       "gain_to_uV":    0.195,                     microvolts = (raw - offset) * gain_to_uV
    %       "offset":        0,                         raw units subtracted before the gain
    %       "channel_names": ["ch1", ...],              (optional; default "ch1".."chN")
    %       "native_names":  ["A-000", ...],            (optional; default = channel_names)
    %       "dig_in_names":  ["din0", ...],             (optional)
    %       "dig_in_file":   "digitalin.dat",           (optional) uint16 per sample, bit k = line k
    %       "events":        {"din0": [[t_on, t_off], ...]},   (optional) seconds, t = row/Fs
    %       "acq_date":      "2026-09-16 10:00:00",     (optional)
    %       "source":        {...}                      (optional free-form provenance)
    %     }
    %
    %   The data file is channel-major per sample (all channels of sample 1,
    %   then sample 2, ...), i.e. the Kilosort4 / SpikeInterface read_binary
    %   layout, which is also what EphysDataset.toBin writes. Any acquisition
    %   system can therefore be brought into the pipeline by converting its
    %   recording to this layout and writing the descriptor (see
    %   BinaryReader.writeDescriptor); the whole pipeline (artifacts, spike
    %   detection, derived signals, SpikeInterface sorting, exports) then runs
    %   unchanged. Only recording.json is used to recognise a folder, so the
    %   .bin + <name>.json sidecar pairs that toBin writes into output folders
    %   are never mistaken for recordings.
    %
    %   See also EphysReader, IntanReader, EphysDataset.toBin.

    properties (Constant)
        Kind = "binary"
        DescriptorName = "recording.json"
        Schema = "ephys-recording/1"
    end

    properties (SetAccess = private)
        Descriptor struct = struct()   % parsed recording.json
        DataFile (1,1) string = ""      % absolute path of the binary
    end

    methods
        function obj = BinaryReader(folder)
            arguments
                folder (1,1) string = ""
            end
            if folder == ""; return; end
            obj.Folder = string(folder);
            [~, leaf] = fileparts(char(obj.Folder));
            obj.Name = string(leaf);
        end

        function discoverFiles(obj)
            f = fullfile(obj.Folder, BinaryReader.DescriptorName);
            obj.RecordingFormat = "unknown";
            obj.Files = string.empty(1, 0);
            obj.NumFiles = 0;
            obj.Descriptor = struct();
            obj.DataFile = "";
            if ~isfile(f); return; end
            d = BinaryReader.readDescriptor(f);
            obj.Descriptor = d;
            obj.RecordingFormat = "binary";
            obj.DataFile = string(fullfile(obj.Folder, d.data_file));
            obj.Files = [string(BinaryReader.DescriptorName), string(d.data_file)];
            obj.NumFiles = 1;
            if isfield(d, 'name') && strlength(string(d.name)) > 0
                obj.Name = string(d.name);
            end
            if isfield(d, 'acq_date') && strlength(string(d.acq_date)) > 0
                try
                    obj.AcqDate = datetime(string(d.acq_date), 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                catch
                    obj.AcqDate = NaT;
                end
            end
            if isnat(obj.AcqDate)
                s = dir(obj.DataFile);
                if ~isempty(s)
                    obj.AcqDate = datetime(s.datenum, 'ConvertFrom', 'datenum');
                end
            end
        end

        function refreshMetadata(obj)
            if isempty(fieldnames(obj.Descriptor)); obj.discoverFiles(); end
            if obj.RecordingFormat ~= "binary"
                warning('BinaryReader:NoDescriptor', 'No %s in %s', ...
                    BinaryReader.DescriptorName, obj.Folder);
                return
            end
            d = obj.Descriptor;
            obj.Fs          = double(d.fs);
            obj.NumChannels = double(d.n_chan);
            names = BinaryReader.stringList(d, 'channel_names', obj.NumChannels, "ch");
            obj.ChannelNames = names;
            if isfield(d, 'native_names') && ~isempty(d.native_names)
                obj.NativeNames = BinaryReader.stringList(d, 'native_names', obj.NumChannels, "ch");
            else
                obj.NativeNames = names;
            end
            obj.DigInNames = BinaryReader.stringList(d, 'dig_in_names', 0, "din");
            nSamp = obj.sampleCount();
            obj.PerFile = struct( ...
                'name',                 string(d.data_file), ...
                'bytesPerBlock',        NaN, ...
                'numDataBlocks',        NaN, ...
                'numAmplifierSamples',  nSamp, ...
                'recordTime',           nSamp / obj.Fs, ...
                'numAmplifierChannels', obj.NumChannels, ...
                'numBoardDigIn',        numel(obj.DigInNames), ...
                'headerBytes',          NaN, ...
                'datenum',              datenum(obj.AcqDate), ...
                'partialBlock',         false, ...
                'dataPresent',          nSamp > 0);
            obj.Duration = nSamp / obj.Fs;
        end

        function plan = streamPlan(obj, opts)
            arguments
                obj (1,1) BinaryReader
                opts.Files (1,:) string = string.empty(1,0) %#ok<INUSA>
                opts.MaxChunkSamples (1,1) double = NaN
            end
            if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
            proto = struct('kind', "", 'name', "", 'file', "", 'sampleOffset', 0, 'nSamples', 0);
            if obj.RecordingFormat ~= "binary"
                plan = repmat(proto, 1, 0);
                return
            end
            total = obj.sampleCount();
            maxc = opts.MaxChunkSamples;
            if isnan(maxc) || maxc <= 0
                maxc = max(round(obj.Fs), floor(2.5e8 / (max(obj.NumChannels, 1) * 8)));
            end
            maxc = max(1, maxc);
            nChunks = max(1, ceil(total / maxc));
            plan = repmat(proto, 1, nChunks);
            for i = 1:nChunks
                off = (i - 1) * maxc;
                len = min(maxc, total - off);
                plan(i).kind         = "window";
                plan(i).name         = sprintf('samples %d-%d', off + 1, off + len);
                plan(i).file         = obj.DataFile;
                plan(i).sampleOffset = off;
                plan(i).nSamples     = len;
            end
        end

        function X = readChunkUV(obj, chunk)
            arguments
                obj (1,1) BinaryReader
                chunk (1,1) struct
            end
            X = obj.readWindowUV(chunk.sampleOffset, chunk.nSamples);
        end

        function tf = supportsRandomAccess(obj) %#ok<MANU>
            tf = true;
        end

        function X = readWindowUV(obj, sampleOffset, nSamp)
            %readWindowUV  Samples [sampleOffset+1 .. sampleOffset+nSamp] in microvolts.
            arguments
                obj (1,1) BinaryReader
                sampleOffset (1,1) double {mustBeInteger, mustBeNonnegative}
                nSamp (1,1) double {mustBeInteger, mustBeNonnegative}
            end
            if isnan(obj.Fs); obj.refreshMetadata(); end
            d = obj.Descriptor;
            nCh = obj.NumChannels;
            total = obj.sampleCount();
            nSamp = max(0, min(nSamp, total - sampleOffset));
            if nSamp == 0
                X = zeros(0, nCh);
                return
            end
            [prec, bytes] = BinaryReader.precisionFor(string(d.dtype));
            fid = fopen(obj.DataFile, 'r', obj.byteOrder());
            if fid < 0
                error('BinaryReader:OpenFailed', 'Cannot open %s', obj.DataFile);
            end
            closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
            if fseek(fid, sampleOffset * nCh * bytes, 'bof') ~= 0
                error('BinaryReader:SeekFailed', 'Cannot seek to sample %d in %s', ...
                    sampleOffset, obj.DataFile);
            end
            raw = fread(fid, [nCh, nSamp], [prec '=>double']);   % channel-major per sample
            gain = 1; off = 0;
            if isfield(d, 'gain_to_uV'); gain = double(d.gain_to_uV); end
            if isfield(d, 'offset');     off  = double(d.offset);     end
            X = ((raw - off) * gain).';                               % [nSamp x nChan]
        end

        function data = readData(obj, opts)
            arguments
                obj (1,1) BinaryReader
                opts.Files (1,:) string = string.empty(1,0) %#ok<INUSA>
                opts.KeepChannels (1,:) double {mustBeInteger, mustBePositive} = []
                opts.IncludeADC (1,1) logical = false %#ok<INUSA>
                opts.IncludeAux (1,1) logical = false %#ok<INUSA>
                opts.Concatenate (1,1) logical = true %#ok<INUSA>
                opts.ProgressFcn = []
                opts.Precision (1,1) string {mustBeMember(opts.Precision, ["double", "single"])} = "double"
                opts.EventLabelField (1,1) string {mustBeMember(opts.EventLabelField, ...
                    ["custom_channel_name", "native_channel_name"])} = "custom_channel_name"
            end
            if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
            if obj.RecordingFormat ~= "binary"
                error('BinaryReader:NoFiles', 'No %s in %s', BinaryReader.DescriptorName, obj.Folder);
            end
            if ~isempty(opts.ProgressFcn)
                opts.ProgressFcn(1, 1, string(obj.Descriptor.data_file));
            end
            nSamp = obj.sampleCount();
            X = obj.readWindowUV(0, nSamp);
            if opts.Precision == "single"; X = single(X); end
            keep = opts.KeepChannels;
            if ~isempty(keep)
                if max(keep) > obj.NumChannels
                    error('BinaryReader:BadKeepChannels', ...
                        'KeepChannels references channel %d but the recording has %d.', ...
                        max(keep), obj.NumChannels);
                end
                X = X(:, keep);
                channelNames = obj.ChannelNames(keep);
                nativeNames  = obj.NativeNames(keep);
                order = keep;
            else
                channelNames = obj.ChannelNames;
                nativeNames  = obj.NativeNames;
                order = 1:obj.NumChannels;
            end

            [events, digNames] = obj.readEvents(nSamp, opts.EventLabelField);

            data = struct();
            data.amplifier        = X;
            data.Fs               = obj.Fs;
            data.t                = (0:nSamp-1).' / obj.Fs;
            data.channelNames     = channelNames;
            data.nativeNames      = nativeNames;
            data.channelOrder     = order;
            data.events           = events;
            data.digInNames       = digNames;
            data.digInNativeNames = digNames;
            data.boardADC         = [];
            data.aux              = [];
            data.auxFs            = NaN;
            data.auxNames         = string.empty(1,0);
            data.auxNativeNames   = string.empty(1,0);
            data.files            = obj.Files;
            data.fileSampleCounts = nSamp;
            data.units            = "microvolts";
            data.source           = struct('Folder', obj.Folder, 'Name', obj.Name);
        end

        function spec = siRecordingSpec(obj)
            %siRecordingSpec  What run_si_ks4.py needs for spikeinterface.read_binary.
            if isnan(obj.Fs); obj.refreshMetadata(); end
            d = obj.Descriptor;
            gain = 1; off = 0;
            if isfield(d, 'gain_to_uV'); gain = double(d.gain_to_uV); end
            if isfield(d, 'offset');     off  = double(d.offset);     end
            spec = struct('reader', "binary", 'folder', obj.Folder, ...
                'files', {cellstr(obj.Files(:).')}, 'recording_format', "binary", ...
                'file', obj.DataFile, 'dtype', string(d.dtype), ...
                'n_chan', obj.NumChannels, 'fs', obj.Fs, ...
                'gain_to_uV', gain, 'offset', off, ...
                'byte_order', obj.byteOrderName(), ...
                'channel_names', {cellstr(obj.ChannelNames(:).')});
        end
    end

    methods (Access = private)
        function n = sampleCount(obj)
            d = obj.Descriptor;
            if isfield(d, 'n_samples') && ~isempty(d.n_samples) && isfinite(double(d.n_samples))
                n = double(d.n_samples);
                return
            end
            s = dir(obj.DataFile);
            if isempty(s)
                error('BinaryReader:NoDataFile', 'Data file not found: %s', obj.DataFile);
            end
            [~, bytes] = BinaryReader.precisionFor(string(d.dtype));
            n = floor(s.bytes / (bytes * double(d.n_chan)));
        end

        function bo = byteOrder(obj)
            if obj.byteOrderName() == "big-endian"; bo = 'ieee-be'; else; bo = 'ieee-le'; end
        end

        function s = byteOrderName(obj)
            s = "little-endian";
            if isfield(obj.Descriptor, 'byte_order') && strlength(string(obj.Descriptor.byte_order)) > 0
                s = lower(string(obj.Descriptor.byte_order));
            end
        end

        function [events, names] = readEvents(obj, nSamp, labelField) %#ok<INUSD>
            %readEvents  Digital-input intervals from the descriptor or dig_in_file.
            d = obj.Descriptor;
            names = obj.DigInNames;
            events = struct();
            if isfield(d, 'dig_in_file') && strlength(string(d.dig_in_file)) > 0
                f = fullfile(obj.Folder, string(d.dig_in_file));
                if ~isfile(f)
                    warning('BinaryReader:NoDigInFile', 'dig_in_file not found: %s', f);
                else
                    fid = fopen(f, 'r', obj.byteOrder());
                    closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
                    raw = fread(fid, nSamp, 'uint16=>double');
                    nLines = numel(names);
                    if nLines == 0
                        nLines = max(1, ceil(log2(max(raw) + 1)));
                        names = "din" + string(0:nLines-1);
                    end
                    for k = 1:nLines
                        line = bitand(raw, 2^(k-1)) > 0;
                        events.(matlab.lang.makeValidName(char(names(k)))) = ...
                            EphysReader.highSegments(line, obj.Fs);
                    end
                    return
                end
            end
            if isfield(d, 'events') && isstruct(d.events)
                fn = fieldnames(d.events);
                for k = 1:numel(fn)
                    v = d.events.(fn{k});
                    if isempty(v)
                        v = zeros(0, 2);
                    elseif isnumeric(v) && isvector(v) && numel(v) == 2
                        v = double(v(:)).';
                    else
                        v = double(v);
                    end
                    events.(fn{k}) = v;
                end
                if isempty(names); names = string(fn(:).'); end
            end
        end
    end

    methods (Static)
        function tf = claims(folder)
            %claims  True when FOLDER holds a recording.json with this schema.
            f = fullfile(folder, BinaryReader.DescriptorName);
            tf = false;
            if ~isfile(f); return; end
            s = readJsonFile(f, ErrorOnFail=false);
            tf = isstruct(s) && isfield(s, 'schema') && string(s.schema) == BinaryReader.Schema;
        end

        function folders = findRecordingFolders(root, recursive)
            %findRecordingFolders  Folders holding an ephys-recording/1 recording.json.
            arguments
                root (1,1) string
                recursive (1,1) logical = true
            end
            folders = string.empty(1, 0);
            if ~isfolder(root); return; end
            if recursive
                D = dir(fullfile(root, '**', char(BinaryReader.DescriptorName)));
            else
                D = dir(fullfile(root, char(BinaryReader.DescriptorName)));
            end
            for k = 1:numel(D)
                if D(k).isdir; continue; end
                if BinaryReader.claims(D(k).folder)
                    folders(end+1) = string(D(k).folder); %#ok<AGROW>
                end
            end
        end

        function d = readDescriptor(file)
            %readDescriptor  Parse and validate a recording.json.
            d = readJsonFile(file);
            need = ["schema" "data_file" "dtype" "n_chan" "fs"];
            for f = need
                if ~isfield(d, f)
                    error('BinaryReader:BadDescriptor', '%s lacks the required field "%s".', file, f);
                end
            end
            if string(d.schema) ~= BinaryReader.Schema
                error('BinaryReader:BadDescriptor', '%s has schema "%s", expected "%s".', ...
                    file, string(d.schema), BinaryReader.Schema);
            end
            BinaryReader.precisionFor(string(d.dtype));   % validates dtype
            if ~(double(d.n_chan) >= 1) || ~(double(d.fs) > 0)
                error('BinaryReader:BadDescriptor', '%s: n_chan must be >= 1 and fs > 0.', file);
            end
        end

        function file = writeDescriptor(folder, spec)
            %writeDescriptor  Write a validated recording.json into FOLDER.
            %   spec is a struct with at least data_file, dtype, n_chan, fs;
            %   optional gain_to_uV (default 1), offset (0), channel_names,
            %   native_names, dig_in_names, dig_in_file, events, acq_date,
            %   name, source. The schema field is added here.
            arguments
                folder (1,1) string
                spec (1,1) struct
            end
            spec.schema = BinaryReader.Schema;
            if ~isfield(spec, 'gain_to_uV'); spec.gain_to_uV = 1; end
            if ~isfield(spec, 'offset');     spec.offset = 0;     end
            if ~isfile(fullfile(folder, spec.data_file))
                error('BinaryReader:NoDataFile', 'data_file %s does not exist in %s.', ...
                    spec.data_file, folder);
            end
            BinaryReader.precisionFor(string(spec.dtype));
            if ~isfolder(folder); mkdir(folder); end
            file = string(fullfile(folder, BinaryReader.DescriptorName));
            writeJsonFile(file, spec);
        end

        function [prec, bytes] = precisionFor(dtype)
            %precisionFor  fread precision + bytes per sample for a dtype name.
            switch lower(char(dtype))
                case 'int16',                 prec = 'int16';  bytes = 2;
                case 'uint16',                prec = 'uint16'; bytes = 2;
                case 'int32',                 prec = 'int32';  bytes = 4;
                case 'uint32',                prec = 'uint32'; bytes = 4;
                case {'single', 'float32'},   prec = 'single'; bytes = 4;
                case {'double', 'float64'},   prec = 'double'; bytes = 8;
                otherwise
                    error('BinaryReader:BadDtype', 'Unsupported dtype "%s".', dtype);
            end
        end

        function s = stringList(d, field, n, prefix)
            %stringList  Optional string-list field with a "<prefix>k" default.
            if isfield(d, field) && ~isempty(d.(field))
                v = d.(field);
                if iscell(v); s = string(v(:).'); else; s = string(v); s = s(:).'; end
            else
                s = prefix + string(1:n);
                if n == 0; s = string.empty(1, 0); end
            end
        end
    end
end
