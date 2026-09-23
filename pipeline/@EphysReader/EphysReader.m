classdef (Abstract) EphysReader < handle
    % EphysReader  Contract between an acquisition system and the pipeline.
    %   Everything above the raw-data layer (artifacts, spike detection,
    %   derived signals, sorting, manifests, exports, the GUI) talks to an
    %   EphysDataset, and the dataset talks to a reader. A reader knows one
    %   on-disk format and answers five questions:
    %
    %     discoverFiles()      which files in Folder make up the recording
    %     refreshMetadata()    header-only metadata (Fs, channels, duration)
    %     streamPlan(...)      how to read the recording one bounded chunk at a
    %                          time (kind, name, file, sampleOffset, nSamples)
    %     readChunkUV(chunk)   one chunk as [nSamples x nChan] double MICROVOLTS
    %     readData(...)        the whole recording as the universal data struct
    %
    %   Optional: readWindowUV(sampleOffset, nSamp) with supportsRandomAccess()
    %   true (bounded random access, used to carry context across chunks),
    %   readDigitalEvents() when the digital lines can be decoded without the
    %   amplifier data.
    %
    %   Channel numbers
    %   ---------------
    %   ChannelNumbers holds the 0-based hardware number of each amplifier
    %   channel, reported with sorted units (units.channelNumber). A probe's
    %   chanMap does not refer to them: its values are .bin rows (recording
    %   order, 0-based), for sorting and every probe display alike. They are
    %   unique; a reader that cannot make them unique numbers the channels by
    %   position (0..n-1) and warns EphysReader:ChannelNumbersNotUnique. Intan: the trailing
    %   digits of the native name ("A-012" -> 12); Open Ephys: "CH13" -> 12;
    %   recording.json: its channel_numbers, else 0..n-1.
    %
    %   Universal data struct (what readData returns, for every reader)
    %   ---------------------------------------------------------------
    %     amplifier        [nSamples x nChan] double or single, microvolts
    %     Fs               amplifier sample rate (Hz)
    %     t                [nSamples x 1] seconds, t = (row-1)/Fs
    %     channelNames     1 x nChan custom names
    %     nativeNames      1 x nChan native/hardware names
    %     channelOrder     1 x nChan indices into the recording's channels
    %     events           struct, one field per digital-input line, keyed by
    %                      the line's NATIVE name (matlab.lang.makeValidName) ->
    %                      [k x 2] [t_on t_off] seconds, t = row/Fs (1-based
    %                      row). EphysDataset renames the lines (LabelField,
    %                      LineNames); see EphysDataset.readData.
    %     digInNames / digInNativeNames   aligned custom / native line names
    %                      (the custom name equals the native one when the
    %                      format has none)
    %     boardADC / aux / auxFs    [] when not requested or not present; aux
    %                      is [nAuxSamples x nAux] volts at auxFs (accelerometer)
    %     auxNames / auxNativeNames   aux channel names (empty without aux)
    %     files            files read (chronological)
    %     fileSampleCounts per-file amplifier sample counts
    %     units            "microvolts"
    %     source           struct('Folder', ..., 'Name', ...)
    %
    %   Reader options
    %   --------------
    %   Readers are built as READER(folder, options), where OPTIONS is the
    %   pipeline config's Acquisition section (e.g. options.OpenEphys holds the
    %   Open Ephys recording mode, record node and stream). A reader reads its
    %   own sub-struct and ignores the rest.
    %
    %   Registry
    %   --------
    %   Readers are found by EphysReader.forFolder(folder), which asks each
    %   class in EphysReader.readerClasses() whether it claims the folder.
    %   Built-in: IntanReader (Intan RHD2000 *.rhd, info.rhd + .dat layouts),
    %   BinaryReader (the universal recording.json + flat binary format, see
    %   BinaryReader) and OpenEphysReader (Open Ephys GUI sessions: Binary,
    %   Open Ephys and NWB formats). Add your own with
    %   EphysReader.register("MyReader").
    %
    %   See also EphysDataset, IntanReader, BinaryReader, OpenEphysReader.

    properties (SetAccess = protected)
        Folder          (1,1) string = ""      % recording folder
        Name            (1,1) string = ""      % folder leaf (display name)
        RecordingFormat (1,1) string = "unknown"
        Files           (1,:) string = string.empty(1,0)
        NumFiles        (1,1) double = 0
        Options         struct = struct()       % reader options (config Acquisition section)

        % Header metadata (filled by refreshMetadata)
        Fs               (1,1) double = NaN
        NumChannels      (1,1) double = NaN
        ChannelNames     (1,:) string = string.empty(1,0)
        NativeNames      (1,:) string = string.empty(1,0)
        ChannelNumbers   (1,:) double = double.empty(1,0)   % 0-based hardware numbers (not probe chanMap values: those are .bin rows)
        DigInNames       (1,:) string = string.empty(1,0)
        DigInNativeNames (1,:) string = string.empty(1,0)
        Duration         (1,1) double = NaN
        AcqDate          datetime = NaT
        PerFile          struct = struct([])       % per-file summary; name + numAmplifierSamples at least
    end

    properties (Abstract, Constant)
        Kind    % short reader id, e.g. "intan", "binary", "openephys"
    end

    methods (Abstract)
        discoverFiles(obj)
        refreshMetadata(obj)
        plan = streamPlan(obj, opts)
        X    = readChunkUV(obj, chunk)
        data = readData(obj, opts)
    end

    methods (Abstract, Static)
        tf = claims(folder)
        folders = findRecordingFolders(root, recursive, options)
    end

    methods
        function tf = supportsRandomAccess(obj) %#ok<MANU>
            %supportsRandomAccess  True when readWindowUV is implemented.
            tf = false;
        end

        function X = readWindowUV(obj, sampleOffset, nSamp) %#ok<INUSD,STOUT>
            %readWindowUV  Bounded random-access read (override when supported).
            error('EphysReader:NotSupported', ...
                '%s does not support random-access reads.', class(obj));
        end

        function E = readDigitalEvents(obj, opts)
            %readDigitalEvents  Digital-input events without keeping amplifier data.
            %   E = r.readDigitalEvents() returns struct events (native-keyed,
            %   as in readData), Fs, nSamples, digInNames and digInNativeNames.
            %   The default reads the recording through readData keeping one
            %   amplifier channel (ProgressFcn forwarded); readers that can
            %   decode the digital lines alone should override it.
            %   EphysDataset.digitalEvents caches the result.
            arguments
                obj (1,1) EphysReader
                opts.ProgressFcn = []
            end
            data = obj.readData(KeepChannels=1, Precision="single", ProgressFcn=opts.ProgressFcn);
            E = struct('events', data.events, 'Fs', data.Fs, ...
                'nSamples', size(data.amplifier, 1), 'digInNames', string(data.digInNames), ...
                'digInNativeNames', string(data.digInNativeNames));
        end

        function m = metadataStruct(obj)
            %metadataStruct  The header metadata as one struct.
            m = struct('Fs', obj.Fs, 'NumChannels', obj.NumChannels, ...
                'ChannelNames', obj.ChannelNames, 'NativeNames', obj.NativeNames, ...
                'ChannelNumbers', obj.ChannelNumbers, ...
                'DigInNames', obj.DigInNames, 'DigInNativeNames', obj.DigInNativeNames, ...
                'Duration', obj.Duration, ...
                'AcqDate', obj.AcqDate, 'NumFiles', obj.NumFiles, ...
                'PerFile', obj.PerFile, 'RecordingFormat', obj.RecordingFormat);
        end
    end

    methods (Static)
        function classes = readerClasses()
            %readerClasses  Reader class names, built-ins first, then registered.
            classes = ["IntanReader", "BinaryReader", "OpenEphysReader", EphysReader.registered()];
        end

        function register(className)
            %register  Add a reader class (a subclass of EphysReader) to the registry.
            arguments
                className (1,1) string
            end
            if ~exist(className, 'class')
                error('EphysReader:NoSuchClass', 'No class named %s on the path.', className);
            end
            EphysReader.registered(className);
        end

        function r = forFolder(folder, opts)
            %forFolder  The first registered reader that claims FOLDER, or [].
            %   r = EphysReader.forFolder(folder, Options=acquisition) builds
            %   the reader with the reader options (the config's Acquisition
            %   section) and discovers its files.
            arguments
                folder (1,1) string
                opts.Options struct = struct()
            end
            r = [];
            if folder == "" || ~isfolder(folder); return; end
            for c = EphysReader.readerClasses()
                try
                    if feval(c + ".claims", folder)
                        r = feval(c, folder, opts.Options);
                        r.discoverFiles();
                        return
                    end
                catch ME
                    r = [];
                    warning('EphysReader:ReaderFailed', ...
                        'Reader %s failed on %s: %s', c, folder, ME.message);
                end
            end
        end

        function folders = findAllRecordingFolders(root, recursive, opts)
            %findAllRecordingFolders  Union of every reader's recording folders.
            %   Options is the reader options struct (see forFolder); readers
            %   whose folder layout depends on it (Open Ephys recording modes)
            %   use it.
            arguments
                root (1,1) string
                recursive (1,1) logical = true
                opts.Options struct = struct()
            end
            folders = string.empty(1, 0);
            for c = EphysReader.readerClasses()
                try
                    f = feval(c + ".findRecordingFolders", root, recursive, opts.Options);
                catch ME
                    warning('EphysReader:ReaderFailed', ...
                        'Reader %s failed to scan %s: %s', c, root, ME.message);
                    continue
                end
                folders = [folders, reshape(string(f), 1, [])]; %#ok<AGROW>
            end
            folders = unique(folders, 'stable');
        end

        function iv = highSegments(x, Fs)
            %highSegments  [k x 2] [t_on t_off] (s) for contiguous high runs of x.
            %   Times use the 1-based row index divided by Fs (t = row/Fs), the
            %   convention every reader's digital-input events follow.
            iv = EphysReader.highRuns(x) ./ Fs;
        end

        function R = highRuns(x, offset)
            %highRuns  [k x 2] [first last] rows of the contiguous high runs of x.
            %   R = EphysReader.highRuns(x) lists the runs of x > 0 as 1-based
            %   row pairs; highRuns(x, OFFSET) adds OFFSET to both, so a long
            %   line can be decoded one block at a time: take each block's
            %   runs with its offset (the rows before it) and join them with
            %   joinRuns. Only logical temporaries are made (1 byte a sample).
            if nargin < 2; offset = 0; end
            x = x(:) > 0;
            if isempty(x)
                R = zeros(0, 2);
                return
            end
            on  = find(x & ~[false; x(1:end-1)]);
            off = find(x & ~[x(2:end); false]);
            R = [on off] + offset;
        end

        function R = joinRuns(parts)
            %joinRuns  The runs of a whole line from the runs of its blocks.
            %   R = EphysReader.joinRuns(PARTS) stacks the cell PARTS of [k x 2]
            %   row runs (highRuns of consecutive blocks, in order, each with
            %   its offset) and joins a run that ends on a block's last row
            %   with the run that starts on the next block's first row.
            R = vertcat(zeros(0, 2), parts{:});
            if size(R, 1) < 2; return; end
            cont = R(2:end, 1) == R(1:end-1, 2) + 1;    % run k+1 continues run k
            if any(cont)
                R = [R([true; ~cont], 1), R([~cont; true], 2)];
            end
        end

        function x = wordBit(w, bit)
            %wordBit  True where bit BIT (0-based) of the uint16 words W is set.
            %   A 16-bit digital word has no bit outside 0..15; such a line
            %   is never high.
            if bit >= 0 && bit < 16 && bit == round(bit)
                x = bitand(w, uint16(2^bit)) > 0;
            else
                x = false(size(w));
            end
        end

        function [off, len] = planWindows(total, maxChunk, minLast)
            %planWindows  0-based offsets and lengths of a streamPlan's sample windows.
            %   [OFF, LEN] = EphysReader.planWindows(TOTAL, MAXCHUNK, MINLAST)
            %   cuts TOTAL samples into windows of MAXCHUNK samples, the last
            %   one holding what is left. A leftover (a last window shorter
            %   than MAXCHUNK) shorter than MINLAST - the plans pass one
            %   second of samples - joins the window before it, so no chunk
            %   is too short for the streaming passes' filters (filtfilt needs
            %   more samples than three times the filter order). TOTAL = 0
            %   gives one empty window.
            n = max(1, ceil(total / maxChunk));
            off = (0:n-1) * maxChunk;
            len = min(maxChunk, total - off);
            if n > 1 && len(end) < maxChunk && len(end) < minLast
                len(end-1) = len(end-1) + len(end);
                off(end) = [];
                len(end) = [];
            end
        end

        function key = eventKey(name)
            %eventKey  Field name of a digital line in an events struct.
            key = string(matlab.lang.makeValidName(char(string(name))));
        end

        function nums = trailingNumbers(names)
            %trailingNumbers  The trailing digits of each name as a number (NaN if none).
            names = string(names);
            nums = NaN(1, numel(names));
            for k = 1:numel(names)
                tok = regexp(char(names(k)), '(\d+)$', 'tokens', 'once');
                if ~isempty(tok); nums(k) = str2double(tok{1}); end
            end
        end

        function nums = checkChannelNumbers(nums, where)
            %checkChannelNumbers  NUMS when they are unique whole numbers >= 0, else 0..n-1.
            %   The fallback warns EphysReader:ChannelNumbersNotUnique naming
            %   WHERE (the recording), because the hardware numbers reported
            %   with sorted units are then channel positions.
            nums = double(reshape(nums, 1, []));
            n = numel(nums);
            if n == 0; nums = double.empty(1, 0); return; end
            ok = all(isfinite(nums)) && all(nums >= 0) && all(nums == round(nums)) ...
                && numel(unique(nums)) == n;
            if ~ok
                warning('EphysReader:ChannelNumbersNotUnique', ...
                    ['%s: the channel names do not give %d distinct channel numbers; ' ...
                     'channels are numbered by position (0..%d).'], ...
                    where, n, n - 1);
                nums = 0:n-1;
            end
        end

        function s = readerOptions(options, key)
            %readerOptions  A reader's sub-struct of the reader options ([] fields -> struct()).
            s = struct();
            if isstruct(options) && isscalar(options) && isfield(options, key) && isstruct(options.(key))
                s = options.(key);
            end
        end
    end

    methods (Static, Access = private)
        function out = registered(add)
            persistent extra
            if isempty(extra); extra = string.empty(1, 0); end
            if nargin > 0 && ~ismember(add, extra)
                extra(end+1) = add;
            end
            out = extra;
        end
    end
end
