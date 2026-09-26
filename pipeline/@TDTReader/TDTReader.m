classdef TDTReader < EphysReader
    % TDTReader  EphysReader for TDT Synapse (and OpenEx) blocks.
    %   Reads a block folder of a TDT tank, as Synapse writes it:
    %
    %     <name>.tsq    40-byte event headers, in time order: the block start
    %                   and stop marks and one header per stream chunk, snippet,
    %                   epoc event or scalar
    %     <name>.tev    the stream chunks' samples (and snippet waveforms)
    %     <name>.Tbk    store notes (enabled, head name, sampling rate, ...)
    %     *.sev         one file per channel of a stream stored with Discrete
    %                   Files (Synapse) / Unique Channel Files (OpenEx) or by an
    %                   RS4: 40-byte header, then the samples; long recordings
    %                   split by hour ("-1h", "-2h", ...)
    %
    %   The files are read directly (no TDT SDK); the parsing follows TDT's
    %   own readers (TDTbin2mat / SEV2mat, tdt.read_block), and the epocs come
    %   out as they return them.
    %
    %   The block folder is the dataset. The default name pattern for
    %   Synapse's block names ("Subject-yymmdd-hhmmss") is DefaultNamePattern.
    %
    %   Amplifier channels: the channels of one stream store. With
    %   Acquisition.TDT.Stream = "" (default) the stream with the most
    %   channels is read, the one with the highest rate among those
    %   (TDTReader:SeveralStreams warns when more than one stream has that
    %   many channels). Channels are named "Ch<k>" from the store's channel
    %   number k; ChannelNumbers are k-1. Microvolts = stored value *
    %   Acquisition.TDT.GainToMicrovolts; NaN (default) means 1e6 for
    %   float32 / float64 streams (TDT stores them in volts) and is required
    %   for integer formats (TDTReader:NeedGain). A stream stored in the TEV
    %   file is read chunk by chunk (TDT's chunk index from the TSQ); a SEV
    %   stream file by file. Rows are the stored samples; the first is at
    %   StreamStart seconds from the block start (the first chunk's time,
    %   or the RS4 log's start sample; 0 otherwise).
    %
    %   Epocs: every epoc store is one line of the events struct, named by
    %   the store (native = custom; name them with Signals.LineNames,
    %   "PC0_=InTrial"). Each epoc [onset offset] becomes the rows it
    %   covers on the stream's sample grid: the first row at or after the
    %   onset to the last row before the offset (t = row/Fs, as every
    %   reader's events); an Inf offset (an onset-only store's last epoc, or
    %   a strobe still high at the stop) runs to the last row; an epoc
    %   shorter than one sample keeps one row; an epoc that starts after the
    %   last row (or ends before the first) is left out. readEpocs returns
    %   the epocs as TDT's readers do (seconds from the block start, strobe
    %   values) with each one's interval on the recording clock.
    %
    %   Reader options (the pipeline config's Acquisition.TDT section)
    %     Stream            stream store name ("" = automatic, see above)
    %     GainToMicrovolts  microvolts per stored unit (NaN = 1e6 for float
    %                       streams, required for integer streams)
    %
    %   Not read: snippet stores (TDT's online sorting), scalar stores,
    %   Notes.txt, the RS4 "rawpacked" format. TSQ stores the .Tbk marks
    %   disabled (Enabled = 2) are skipped, as TDT's readers skip them.
    %
    %   See also EphysReader, OpenEphysReader, EphysDataset.

    properties (Constant)
        Kind = "tdt"
        % Default Project.NamePattern for Synapse block names ("Subject-yymmdd-hhmmss").
        DefaultNamePattern = "{SubjectID}-{Date:yyMMdd}-{Time:HHmmss}"
    end

    properties (SetAccess = private)
        TsqFile     (1,1) string = ""   % the block's .tsq ("" for a SEV-only block)
        TevFile     (1,1) string = ""   % the block's .tev
        TbkFile     (1,1) string = ""   % the block's .Tbk ("" when absent)
        StartTime   (1,1) double = NaN  % block start, seconds since 1970 (UTC)
        StopTime    (1,1) double = NaN  % block stop (NaN: no stop mark)
        Streams     struct = struct([]) % every readable stream (name, fs, fmt, storage "tev" or "sev", chans, nSamples, t0)
        Stream      struct = struct([]) % the stream read as the amplifier channels
        StreamStart (1,1) double = 0    % seconds from the block start of the first row
        Gain        (1,1) double = NaN  % microvolts per stored unit
        Epocs       struct = struct([]) % epoc stores as TDT's readers return them (see readEpocs)
    end

    properties (Access = private)
        Scan = []                       % tdtScanTsq result
        Notes = struct([])              % .Tbk store notes
        SevFiles = struct([])           % tdtSevFiles result
        Offsets = []                    % TEV chunk offsets of the selected stream (lazy)
    end

    methods
        function obj = TDTReader(folder, options)
            arguments
                folder (1,1) string = ""
                options struct = struct()
            end
            obj.Options = options;
            TDTReader.tdtOptions(options);             % validates
            if folder == ""; return; end
            obj.Folder = string(folder);
            [~, leaf] = fileparts(char(obj.Folder));
            obj.Name = string(leaf);
        end

        function discoverFiles(obj)
            %discoverFiles  The block's files (TSQ, TEV, Tbk, SEV) and its start time.
            obj.RecordingFormat = "unknown";
            obj.Files = string.empty(1, 0);
            obj.NumFiles = 0;
            obj.TsqFile = ""; obj.TevFile = ""; obj.TbkFile = "";
            obj.StartTime = NaN;
            [tsq, sev] = TDTReader.blockFiles(obj.Folder);
            if isscalar(tsq)
                obj.TsqFile = tsq;
                obj.TevFile = regexprep(tsq, '\.tsq$', '.tev', 'ignorecase');
                tbk = regexprep(tsq, '\.tsq$', '.Tbk', 'ignorecase');
                if isfile(tbk); obj.TbkFile = tbk; end
                obj.StartTime = TDTReader.tsqStartTime(tsq);
            elseif isempty(sev)
                return
            end
            files = [obj.TsqFile obj.TevFile obj.TbkFile sev];
            files = files(files ~= "" & arrayfun(@isfile, files));
            names = strings(1, numel(files));
            for k = 1:numel(files)
                [~, n, e] = fileparts(files(k));
                names(k) = n + e;
            end
            obj.Files = names;
            obj.NumFiles = 1;
            obj.RecordingFormat = "tdt";
            if isfinite(obj.StartTime)
                obj.AcqDate = TDTReader.fromPosix(obj.StartTime);
            end
        end

        function refreshMetadata(obj)
            %refreshMetadata  Stores, the amplifier stream, its channels and samples, the epocs.
            obj.discoverFiles();
            if obj.NumFiles == 0
                warning('TDTReader:NoBlock', 'No TDT block found in %s', obj.Folder);
                return
            end
            o = TDTReader.tdtOptions(obj.Options);
            obj.Offsets = [];
            obj.Notes = struct([]);
            if obj.TbkFile ~= ""; obj.Notes = tdtParseTbk(char(obj.TbkFile)); end
            obj.SevFiles = tdtSevFiles(char(obj.Folder));
            if obj.TsqFile ~= ""
                obj.Scan = TDTReader.scanCached(obj.TsqFile);
                obj.StopTime = obj.Scan.stopTime;
                obj.warnScan();
            else
                obj.Scan = [];
                obj.StopTime = NaN;
            end
            obj.Streams = obj.inventory();
            if isempty(obj.Streams)
                error('TDTReader:NoStream', '%s has no stream store to read.', obj.Folder);
            end
            obj.Stream = TDTReader.pickStream(obj.Streams, o.Stream, obj.Folder);
            s = obj.Stream;
            obj.Gain = TDTReader.gainFor(s, o.GainToMicrovolts, obj.Folder);
            obj.StreamStart = s.t0;
            obj.RecordingFormat = "tdt";
            obj.Fs = s.fs;
            obj.NumChannels = numel(s.chans);
            obj.ChannelNames = "Ch" + string(s.chans);
            obj.NativeNames = obj.ChannelNames;
            obj.ChannelNumbers = EphysReader.checkChannelNumbers(s.chans - 1, obj.Folder);
            obj.Duration = s.nSamples / s.fs;

            obj.Epocs = struct('name', {}, 'buddy', {}, 'onset', {}, 'offset', {}, 'value', {}, 'icon', {});
            if ~isempty(obj.Scan)
                [E, msgs] = tdtEpocs(obj.Scan, obj.Notes, obj.enabledStores());
                for m = string(msgs)
                    warning('TDTReader:Epocs', '%s: %s', obj.Name, m);
                end
                obj.Epocs = E;
            end
            obj.DigInNames = string({obj.Epocs.name});
            if isempty(obj.Epocs); obj.DigInNames = string.empty(1, 0); end
            obj.DigInNativeNames = obj.DigInNames;

            dn = NaN; if ~isnat(obj.AcqDate); dn = datenum(obj.AcqDate); end %#ok<DATNM>
            obj.PerFile = struct('name', obj.Name, 'bytesPerBlock', NaN, 'numDataBlocks', NaN, ...
                'numAmplifierSamples', s.nSamples, 'recordTime', s.nSamples / s.fs, ...
                'numAmplifierChannels', numel(s.chans), 'numBoardDigIn', numel(obj.DigInNames), ...
                'headerBytes', NaN, 'datenum', dn, 'partialBlock', false, ...
                'dataPresent', s.nSamples > 0, 'store', string(s.name), 'storage', string(s.storage));
        end

        function plan = streamPlan(obj, opts)
            %streamPlan  Bounded sample windows over the stream (kind "window").
            arguments
                obj (1,1) TDTReader
                opts.Files (1,:) string = string.empty(1,0) %#ok<INUSA>
                opts.MaxChunkSamples (1,1) double = NaN
            end
            if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
            proto = struct('kind', "", 'name', "", 'file', "", 'sampleOffset', 0, 'nSamples', 0);
            total = obj.Stream.nSamples;
            if total == 0
                plan = repmat(proto, 1, 0);
                return
            end
            maxc = opts.MaxChunkSamples;
            if isnan(maxc) || maxc <= 0
                maxc = max(round(obj.Fs), floor(2.5e8 / (max(obj.NumChannels, 1) * 8)));
            end
            maxc = max(1, maxc);
            [off, len] = EphysReader.planWindows(total, maxc, round(obj.Fs));
            plan = repmat(proto, 1, numel(off));
            for i = 1:numel(off)
                plan(i).kind         = "window";
                plan(i).name         = sprintf('samples %d-%d', off(i) + 1, off(i) + len(i));
                plan(i).file         = "";
                plan(i).sampleOffset = off(i);
                plan(i).nSamples     = len(i);
            end
        end

        function X = readChunkUV(obj, chunk)
            arguments
                obj (1,1) TDTReader
                chunk (1,1) struct
            end
            X = obj.readWindowUV(chunk.sampleOffset, chunk.nSamples);
        end

        function tf = supportsRandomAccess(obj) %#ok<MANU>
            tf = true;
        end

        function X = readWindowUV(obj, sampleOffset, nSamp)
            %readWindowUV  Rows [sampleOffset+1 .. sampleOffset+nSamp] in microvolts.
            arguments
                obj (1,1) TDTReader
                sampleOffset (1,1) double {mustBeInteger, mustBeNonnegative}
                nSamp (1,1) double {mustBeInteger, mustBeNonnegative}
            end
            if isnan(obj.Fs); obj.refreshMetadata(); end
            X = obj.readRows(sampleOffset, nSamp, 1:obj.NumChannels);
        end

        function data = readData(obj, opts)
            %readData  The whole recording as the universal data struct (EphysReader).
            %   IncludeADC / IncludeAux return [] (a TDT block has no board
            %   ADC or accelerometer channels of the amplifier stream).
            arguments
                obj (1,1) TDTReader
                opts.Files (1,:) string = string.empty(1,0) %#ok<INUSA>
                opts.KeepChannels (1,:) double {mustBeInteger, mustBePositive} = []
                opts.IncludeADC (1,1) logical = false %#ok<INUSA>
                opts.IncludeAux (1,1) logical = false %#ok<INUSA>
                opts.Concatenate (1,1) logical = true
                opts.ProgressFcn = []
                opts.Precision (1,1) string {mustBeMember(opts.Precision, ["double", "single"])} = "double"
            end
            if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
            if obj.NumFiles == 0 || isempty(obj.Stream)
                error('TDTReader:NoFiles', 'No TDT block in %s', obj.Folder);
            end
            keep = opts.KeepChannels;
            if isempty(keep); keep = 1:obj.NumChannels; end
            if max(keep) > obj.NumChannels
                error('TDTReader:BadKeepChannels', ...
                    'KeepChannels references channel %d but the recording has %d.', max(keep), obj.NumChannels);
            end
            n = obj.Stream.nSamples;
            if ~isempty(opts.ProgressFcn); opts.ProgressFcn(1, 1, obj.Name); end
            amplifier = obj.readRows(0, n, keep);
            if opts.Precision == "single"; amplifier = single(amplifier); end
            if ~opts.Concatenate; amplifier = {amplifier}; end
            E = obj.readDigitalEvents();
            data = struct();
            data.amplifier        = amplifier;
            data.Fs               = obj.Fs;
            if opts.Concatenate; data.t = (0:n-1).' / obj.Fs; else; data.t = []; end
            data.channelNames     = obj.ChannelNames(keep);
            data.nativeNames      = obj.NativeNames(keep);
            data.channelOrder     = keep;
            data.events           = E.events;
            if ~opts.Concatenate; data.events = struct(); end
            data.digInNames       = E.digInNames;
            data.digInNativeNames = E.digInNativeNames;
            data.boardADC         = [];
            data.aux              = [];
            data.auxFs            = NaN;
            data.auxNames         = string.empty(1, 0);
            data.auxNativeNames   = string.empty(1, 0);
            data.files            = obj.Files;
            data.fileSampleCounts = n;
            data.units            = "microvolts";
            data.source           = struct('Folder', obj.Folder, 'Name', obj.Name);
        end

        function E = readDigitalEvents(obj, opts)
            %readDigitalEvents  The epoc stores as [on off] intervals, from the TSQ only.
            %   One line per epoc store (native name = store name); rows as
            %   described in the class help, t = row/Fs.
            arguments
                obj (1,1) TDTReader
                opts.ProgressFcn = []
            end
            if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
            if ~isempty(opts.ProgressFcn); opts.ProgressFcn(1, 1, obj.Name); end
            names = obj.DigInNativeNames;
            events = struct();
            for k = 1:numel(obj.Epocs)
                R = obj.epocRows(obj.Epocs(k));
                R = R(~isnan(R(:, 1)), :);
                events.(EphysReader.eventKey(names(k))) = R ./ obj.Fs;
            end
            E = struct('events', events, 'Fs', obj.Fs, 'nSamples', obj.Stream.nSamples, ...
                'digInNames', names, 'digInNativeNames', names);
        end

        function E = readEpocs(obj)
            %readEpocs  The epoc stores as TDT's readers return them, with their intervals.
            %   E = r.readEpocs() returns a struct array, one element per epoc
            %   store: name, buddy (its offset store), onset / offset (s from
            %   the block start, rounded to TDT's 195312.5 Hz tick; Inf as
            %   TDTbin2mat has it), value (the strobe values), icon (iCon
            %   rule applied: value-3 events are onsets, value-4 events
            %   offsets), and interval, [n x 2] [t_on t_off] seconds on the
            %   recording clock (t = row/Fs, the events' values; NaN rows
            %   for epocs outside the stream, which the events leave out).
            if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
            E = obj.Epocs;
            for k = 1:numel(E)
                E(k).interval = obj.epocRows(E(k)) ./ obj.Fs;
            end
            if isempty(E); E = struct('name', {}, 'buddy', {}, 'onset', {}, 'offset', {}, ...
                    'value', {}, 'icon', {}, 'interval', {}); end
        end

        function row = rowAtOrAfter(obj, t)
            %rowAtOrAfter  First stream row (1-based) at or after block time T (s).
            %   Row r of a chunk starting at time c holds the sample at
            %   c + (j-1)/Fs; a time inside a gap between chunks goes to the
            %   next stored row; a time before the first row gives 1 and one
            %   after the last row nSamples + 1. The fraction of a sample is
            %   rounded to 1e-9 first, as TDT's time2sample does.
            s = obj.Stream;
            [cs, npts] = obj.chunkStarts();
            cs = cs(:);
            row = NaN(size(t));
            fin = isfinite(t);
            row(t == Inf) = s.nSamples + 1;
            row(t == -Inf) = 1;
            u = t(fin);
            k = discretize(u(:) + 1e-9 / s.fs, [cs(:); Inf]);  % the chunk each time falls in
            r = ones(numel(u), 1);                          % before the first chunk: row 1
            in = ~isnan(k);
            kk = k(in);
            uu = u(:);
            j = max(ceil(round((uu(in) - cs(kk)) * s.fs * 1e9) / 1e9), 0);
            ri = (kk - 1) * npts + j + 1;
            late = j >= npts;                               % in the gap after its chunk
            ri(late) = kk(late) * npts + 1;
            r(in) = ri;
            row(fin) = reshape(r, size(u));
            row = min(row, s.nSamples + 1);
        end
    end

    methods (Access = private)
        function X = readRows(obj, sampleOffset, nSamp, keep)
            %readRows  Rows of the amplifier stream, channels KEEP (positions), in microvolts.
            s = obj.Stream;
            nSamp = max(0, min(nSamp, s.nSamples - sampleOffset));
            if s.storage == "tev"
                if isempty(obj.Offsets)
                    obj.Offsets = tdtStreamOffsets(char(obj.TsqFile), s.code, s.allChans, s.allCounts);
                end
                cols = s.cols(keep);
                X = tdtReadTev(char(obj.TevFile), obj.Offsets, s.npts, s.fmt, s.itemSize, ...
                    sampleOffset, nSamp, cols);
            else
                X = tdtReadSev(s.files(keep, :), s.counts(keep, :), s.fmt, s.itemSize, sampleOffset, nSamp);
            end
            X = X .* obj.Gain;
        end

        function [cs, npts] = chunkStarts(obj)
            %chunkStarts  Start time of each stored chunk (s from the block start) and its length.
            s = obj.Stream;
            if s.storage == "tev"
                cs = s.ts(1:ceil(s.nSamples / s.npts));
                npts = s.npts;
            else
                cs = s.t0;
                npts = s.nSamples;
            end
        end

        function R = epocRows(obj, e)
            %epocRows  [n x 2] first / last rows of each epoc; NaN rows when outside the stream.
            n = obj.Stream.nSamples;
            on = obj.rowAtOrAfter(e.onset);
            off = obj.rowAtOrAfter(e.offset) - 1;
            off(isnan(e.offset)) = on(isnan(e.offset));   % no offset: one row
            off = max(off, on);                           % shorter than a sample: one row
            off = min(off, n);
            R = [on(:) off(:)];
            before = ~isnan(e.offset(:)) & e.offset(:) < obj.StreamStart - 1e-9 / obj.Fs;
            R(on(:) > n | before, :) = NaN;               % after the last row / ended before the first
        end

        function keep = enabledStores(obj)
            %enabledStores  False for the TSQ stores the .Tbk marks disabled (Enabled = 2).
            st = obj.Scan.stores;
            keep = true(1, numel(st));
            N = obj.Notes;
            if isempty(N) || ~isfield(N, 'StoreName') || ~isfield(N, 'Enabled'); return; end
            for k = 1:numel(st)
                j = find(strcmp({N.StoreName}, st(k).name), 1);
                if ~isempty(j) && strcmp(N(j).Enabled, '2'); keep(k) = false; end
            end
        end

        function S = inventory(obj)
            %inventory  Every readable stream store (TEV from the TSQ, SEV from the files).
            S = repmat(TDTReader.streamProto(), 1, 0);
            ucfNames = strings(1, 0);
            if ~isempty(obj.Scan)
                st = obj.Scan.stores;
                keep = obj.enabledStores();
                for k = find(strcmp({st.typeStr}, 'streams') & keep)
                    if st(k).ucf
                        ucfNames(end+1) = string(st(k).name); %#ok<AGROW>
                        continue
                    end
                    S(end+1) = obj.tevStream(k); %#ok<AGROW>
                end
            end
            sev = obj.SevFiles;
            names = reshape(unique(string({sev.store}), 'stable'), 1, []);
            for nm = names                                 % as TDT's readers: SEV files are read whatever the .Tbk says
                S(end+1) = obj.sevStream(sev(string({sev.store}) == nm)); %#ok<AGROW>
            end
            for nm = reshape(setdiff(ucfNames, names, 'stable'), 1, [])
                warning('TDTReader:NoSevFiles', ...
                    '%s: stream %s is stored in SEV files but none were found; it is not read.', obj.Name, nm);
            end
        end

        function s = tevStream(obj, k)
            %tevStream  A TEV stream store from the scan.
            st = obj.Scan.stores(k);
            [fmt, itemSize] = TDTReader.formatOf(st.dform);
            if st.sizeMismatch
                error('TDTReader:ChunkSize', '%s: the chunks of stream %s differ in size.', obj.Name, st.name);
            end
            chans = obj.Scan.streamChan{k};
            counts = obj.Scan.streamCount{k};
            npts = (st.size - 10) * 4 / itemSize;
            if npts ~= round(npts) || npts < 1
                error('TDTReader:ChunkSize', '%s: stream %s has chunks of %g samples.', obj.Name, st.name, npts);
            end
            if any(counts ~= counts(1))
                warning('TDTReader:UnequalChannels', ...
                    '%s: the channels of stream %s hold %d to %d chunks; %d chunks (%d samples) are read.', ...
                    obj.Name, st.name, min(counts), max(counts), min(counts), min(counts) * npts);
            end
            nChunks = min(counts);
            ts = obj.Scan.streamTs{k};
            s = TDTReader.streamProto();
            s.name = st.name; s.code = st.code; s.fs = st.fs;
            s.fmt = fmt; s.itemSize = itemSize; s.storage = "tev";
            s.chans = chans; s.nSamples = nChunks * npts; s.npts = npts;
            s.t0 = 0; if ~isempty(ts); s.t0 = ts(1); end
            s.ts = ts; s.cols = 1:numel(chans);
            s.allChans = chans; s.allCounts = counts;
            s.integer = ~ismember(fmt, ["single" "double"]);
            if nChunks > 1
                expect = s.t0 + (0:nChunks-1).' * npts / s.fs;
                dev = (ts(1:nChunks) - expect) * s.fs;
                jump = find(abs(diff(dev)) > 0.5);
                if ~isempty(jump)
                    warning('TDTReader:Gaps', ...
                        ['%s: stream %s has %d gap(s) between its chunks (after rows %s); rows are the ' ...
                         'stored samples and epocs are placed by each chunk''s time.'], ...
                        obj.Name, st.name, numel(jump), strjoin(string(jump(1:min(5, end)) * npts), ", "));
                end
            end
        end

        function s = sevStream(obj, F)
            %sevStream  A SEV stream store from its files.
            nm = string(F(1).store);
            if any([F.version] == 0)
                error('TDTReader:BadSev', '%s: SEV files of %s have an empty header (no rate or format).', obj.Name, nm);
            end
            fmts = unique(string({F.fmt}));
            if ~isscalar(fmts) || fmts == ""
                error('TDTReader:BadSev', '%s: SEV files of %s have format(s) %s.', obj.Name, nm, strjoin(fmts, ", "));
            end
            if fmts == "rawpacked"
                error('TDTReader:Unsupported', '%s: stream %s is in the RS4 "rawpacked" format, which is not read.', obj.Name, nm);
            end
            fsAll = unique([F.fs]);
            if ~isscalar(fsAll)
                error('TDTReader:BadSev', '%s: SEV files of %s have different rates.', obj.Name, nm);
            end
            fs = fsAll;
            N = obj.Notes;
            if ~isempty(N) && isfield(N, 'StoreName') && isfield(N, 'SampleFreq')
                j = find(strcmp({N.StoreName}, char(nm)), 1);
                if ~isempty(j) && ~strcmp(N(j).SampleFreq, '0')
                    expected = str2double(N(j).SampleFreq);
                    if isfinite(expected) && abs(expected - fs) > 1
                        warning('TDTReader:SevRate', ...
                            '%s: the SEV files of %s give %.4f Hz, the .Tbk %.4f Hz; %.4f Hz is used (as TDT''s readers do).', ...
                            obj.Name, nm, fs, expected, expected);
                        fs = expected;
                    end
                end
            end
            if any(arrayfun(@(f) ~isempty(f.gaps), F))
                error('TDTReader:SevGaps', ...
                    '%s: the RS4 log of %s reports gaps in the data; such recordings are not read.', obj.Name, nm);
            end
            if any([F.partial])
                warning('TDTReader:SevPartial', ...
                    '%s: SEV files of %s end with a partial sample; it is not read.', obj.Name, nm);
            end
            chans = unique([F.chan]);
            hours = unique([F.hour]);
            files = cell(numel(chans), numel(hours));
            counts = zeros(numel(chans), numel(hours));
            for c = 1:numel(chans)
                for h = 1:numel(hours)
                    j = find([F.chan] == chans(c) & [F.hour] == hours(h));
                    if ~isscalar(j)
                        error('TDTReader:BadSev', '%s: stream %s channel %d hour %d has %d SEV files.', ...
                            obj.Name, nm, chans(c), hours(h), numel(j));
                    end
                    files{c, h} = F(j).file;
                    counts(c, h) = F(j).npts;
                end
            end
            total = sum(counts, 2);
            if any(total ~= total(1))
                warning('TDTReader:UnequalChannels', ...
                    '%s: the channels of stream %s hold %d to %d samples; %d are read.', ...
                    obj.Name, nm, min(total), max(total), min(total));
            end
            s = TDTReader.streamProto();
            s.name = char(nm); s.fs = fs; s.fmt = char(fmts);
            s.itemSize = F(1).itemSize; s.storage = "sev";
            s.chans = chans; s.nSamples = min(total);
            s.t0 = 0;
            first = F([F.hour] == hours(1));
            if first(1).startSample > 1
                s.t0 = (first(1).startSample - 1) / fs;
            end
            s.files = files; s.counts = counts;
            s.integer = ~ismember(s.fmt, ["single" "double"]);
        end

        function warnScan(obj)
            S = obj.Scan;
            if isnan(S.stopTime)
                warning('TDTReader:NoStopMark', '%s: the block did not end cleanly (no stop mark).', obj.Name);
            end
            if S.nTrailing > 0
                warning('TDTReader:TrailingBytes', '%s: the TSQ ends with a partial header; it is ignored.', obj.Name);
            end
            if S.nBadCodes > 0
                warning('TDTReader:BadHeaders', '%s: %d TSQ headers have code 0; they are ignored.', obj.Name, S.nBadCodes);
            end
        end
    end

    methods (Static)
        function tf = claims(folder)
            %claims  True for a folder with one TSQ file, or with SEV files and no TSQ.
            folder = string(folder);
            tf = false;
            if ~isfolder(folder); return; end
            [tsq, sev] = TDTReader.blockFiles(folder);
            tf = isscalar(tsq) || (isempty(tsq) && ~isempty(sev));
        end

        function folders = findRecordingFolders(root, recursive, options) %#ok<INUSD>
            %findRecordingFolders  Block folders: the folders holding a .tsq or .sev file.
            arguments
                root (1,1) string
                recursive (1,1) logical = true
                options struct = struct()
            end
            folders = string.empty(1, 0);
            if ~isfolder(root); return; end
            if recursive
                D = [dir(fullfile(root, '**', '*.tsq')); dir(fullfile(root, '**', '*.sev'))];
            else
                D = [dir(fullfile(root, '*.tsq')); dir(fullfile(root, '*.sev'))];
            end
            D = D(~[D.isdir]);
            cand = reshape(unique(string({D.folder}), 'stable'), 1, []);
            for f = cand
                if TDTReader.claims(f); folders(end+1) = f; end %#ok<AGROW>
            end
        end

        function o = tdtOptions(options)
            %tdtOptions  The TDT reader options (Acquisition.TDT) with defaults filled in.
            o = struct('Stream', "", 'GainToMicrovolts', NaN);
            s = EphysReader.readerOptions(options, 'TDT');
            if isfield(s, 'Stream') && ~isempty(s.Stream); o.Stream = string(s.Stream); end
            if isfield(s, 'GainToMicrovolts') && ~isempty(s.GainToMicrovolts)
                o.GainToMicrovolts = double(s.GainToMicrovolts);
            end
            if ~isscalar(o.GainToMicrovolts) || ~(isnan(o.GainToMicrovolts) || ...
                    (isfinite(o.GainToMicrovolts) && o.GainToMicrovolts > 0))
                error('TDTReader:BadGain', 'TDT.GainToMicrovolts must be NaN (automatic) or a positive number.');
            end
        end
    end

    methods (Static, Hidden)
        function [tsq, sev] = blockFiles(folder)
            %blockFiles  The folder's .tsq and .sev files (full paths; "._" forks skipped).
            folder = char(folder);
            T = dir(fullfile(folder, '*.tsq'));
            T = T(~[T.isdir] & ~strncmp({T.name}, '._', 2));
            tsq = reshape(string(fullfile(folder, {T.name})), 1, []);
            if isempty(T); tsq = string.empty(1, 0); end
            V = dir(fullfile(folder, '*.sev'));
            V = V(~[V.isdir] & ~strncmp({V.name}, '._', 2));
            sev = reshape(string(fullfile(folder, {V.name})), 1, []);
            if isempty(V); sev = string.empty(1, 0); end
        end

        function t = tsqStartTime(tsq)
            %tsqStartTime  Block start (s since 1970) from the start mark; NaN if absent.
            t = NaN;
            fid = fopen(tsq, 'r', 'ieee-le');
            if fid < 0; return; end
            closer = onCleanup(@() fclose(fid));
            fseek(fid, 48, 'bof');
            code = fread(fid, 1, 'int32=>double');
            if isscalar(code) && code == 1
                fseek(fid, 56, 'bof');
                v = fread(fid, 1, 'double=>double');
                if isscalar(v); t = v; end
            end
        end

        function S = scanCached(tsq)
            %scanCached  tdtScanTsq, reused while the file is unchanged (last 4 blocks).
            persistent cache
            if isempty(cache); cache = struct('file', {}, 'stamp', {}, 'scan', {}); end
            d = dir(tsq);
            stamp = [d.bytes d.datenum];
            k = find(strcmp({cache.file}, char(tsq)), 1);
            if ~isempty(k) && isequal(cache(k).stamp, stamp)
                S = cache(k).scan;
                return
            end
            S = tdtScanTsq(char(tsq));
            if ~isempty(k); cache(k) = []; end
            cache(end+1) = struct('file', char(tsq), 'stamp', stamp, 'scan', S);
            if numel(cache) > 4; cache(1) = []; end
        end

        function s = pickStream(streams, want, folder)
            %pickStream  The named stream, else the most channels, then the highest rate.
            names = string({streams.name});
            if want ~= ""
                k = find(strcmpi(names, want), 1);
                if isempty(k)
                    error('TDTReader:NoStream', '%s has no stream "%s" (streams: %s).', ...
                        folder, want, strjoin(names, ", "));
                end
                s = streams(k);
                return
            end
            nCh = arrayfun(@(x) numel(x.chans), streams);
            fs = [streams.fs];
            top = find(nCh == max(nCh));
            [~, j] = max(fs(top));
            k = top(j);
            if numel(top) > 1
                warning('TDTReader:SeveralStreams', ...
                    '%s: streams %s have %d channels; reading "%s" (set Acquisition.TDT.Stream to choose).', ...
                    folder, strjoin(names(top), ", "), max(nCh), names(k));
            end
            s = streams(k);
        end

        function g = gainFor(s, gain, folder)
            %gainFor  Microvolts per stored unit.
            if ~isnan(gain); g = gain; return; end
            if s.integer
                error('TDTReader:NeedGain', ...
                    ['%s: stream %s is stored as %s, whose scale to volts the block does not record; ' ...
                     'set Acquisition.TDT.GainToMicrovolts.'], folder, s.name, s.fmt);
            end
            g = 1e6;                                     % float streams are in volts
        end

        function [fmt, itemSize] = formatOf(dform)
            %formatOf  MATLAB class and bytes of a TDT data format code.
            formats = ["single" "int32" "int16" "int8" "double" "int64"];
            sizes = [4 4 2 1 8 8];
            if dform < 0 || dform > 5
                error('TDTReader:BadFormat', 'Unknown TDT data format %d.', dform);
            end
            fmt = char(formats(dform + 1));
            itemSize = sizes(dform + 1);
        end

        function s = streamProto()
            s = struct('name', '', 'code', NaN, 'fs', NaN, 'fmt', '', 'itemSize', NaN, 'storage', "", ...
                'chans', [], 'nSamples', 0, 'npts', NaN, 't0', 0, 'ts', zeros(0, 1), 'cols', [], ...
                'allChans', [], 'allCounts', [], 'files', {{}}, 'counts', [], 'integer', false);
        end

        function t = fromPosix(sec)
            %fromPosix  Seconds since 1970 (UTC) -> local datetime without a time zone.
            t = datetime(sec, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
            t.TimeZone = 'local';
            t.TimeZone = '';
            t.Format = 'yyyy-MM-dd HH:mm:ss.SSS';
        end
    end
end
