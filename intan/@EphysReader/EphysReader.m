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
    %   true (bounded random access, used to carry context across chunks), and
    %   siRecordingSpec() describing the recording for the SpikeInterface
    %   driver (run_si_ks4.py).
    %
    %   Universal data struct (what readData returns, for every reader)
    %   ---------------------------------------------------------------
    %     amplifier        [nSamples x nChan] double or single, microvolts
    %     Fs               amplifier sample rate (Hz)
    %     t                [nSamples x 1] seconds, t = (row-1)/Fs
    %     channelNames     1 x nChan custom names
    %     nativeNames      1 x nChan native/hardware names
    %     channelOrder     1 x nChan indices into the recording's channels
    %     events           struct, one field per digital-input line ->
    %                      [k x 2] [t_on t_off] seconds, t = row/Fs (1-based row)
    %     digInNames / digInNativeNames
    %     boardADC / aux / auxFs    [] when not requested or not present; aux
    %                      is [nAuxSamples x nAux] volts at auxFs (accelerometer)
    %     auxNames / auxNativeNames   aux channel names (empty without aux)
    %     files            files read (chronological)
    %     fileSampleCounts per-file amplifier sample counts
    %     units            "microvolts"
    %     source           struct('Folder', ..., 'Name', ...)
    %
    %   Registry
    %   --------
    %   Readers are found by EphysReader.forFolder(folder), which asks each
    %   class in EphysReader.readerClasses() whether it claims the folder.
    %   Built-in: IntanReader (Intan RHD2000 *.rhd, info.rhd + .dat layouts)
    %   and BinaryReader (the universal recording.json + flat binary format,
    %   see BinaryReader). Add your own with EphysReader.register("MyReader").
    %
    %   See also EphysDataset, IntanReader, BinaryReader.

    properties (SetAccess = protected)
        Folder          (1,1) string = ""      % recording folder
        Name            (1,1) string = ""      % folder leaf (display name)
        RecordingFormat (1,1) string = "unknown"
        Files           (1,:) string = string.empty(1,0)
        NumFiles        (1,1) double = 0

        % Header metadata (filled by refreshMetadata)
        Fs           (1,1) double = NaN
        NumChannels  (1,1) double = NaN
        ChannelNames (1,:) string = string.empty(1,0)
        NativeNames  (1,:) string = string.empty(1,0)
        DigInNames   (1,:) string = string.empty(1,0)
        Duration     (1,1) double = NaN
        AcqDate      datetime = NaT
        PerFile      struct = struct([])       % per-file summary; name + numAmplifierSamples at least
    end

    properties (Abstract, Constant)
        Kind    % short reader id, e.g. "intan", "binary"
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
        folders = findRecordingFolders(root, recursive)
    end

    methods
        function tf = supportsRandomAccess(obj) %#ok<MANU>
            %supportsRandomAccess  True when readWindowUV is implemented.
            tf = false;
        end

        function X = readWindowUV(obj, sampleOffset, nSamp) %#ok<INUSD>
            %readWindowUV  Bounded random-access read (override when supported).
            error('EphysReader:NotSupported', ...
                '%s does not support random-access reads.', class(obj));
        end

        function E = readDigitalEvents(obj, opts)
            %readDigitalEvents  Digital-input events without keeping amplifier data.
            %   E = r.readDigitalEvents(EventLabelField=...) returns struct
            %   events (as in readData), Fs, nSamples and digInNames. The
            %   default reads the recording through readData keeping one
            %   amplifier channel; readers that can decode the digital lines
            %   alone should override it. EphysDataset.digitalEvents caches it.
            arguments
                obj (1,1) EphysReader
                opts.EventLabelField (1,1) string = "custom_channel_name"
            end
            data = obj.readData(KeepChannels=1, Precision="single", ...
                EventLabelField=opts.EventLabelField);
            E = struct('events', data.events, 'Fs', data.Fs, ...
                'nSamples', size(data.amplifier, 1), 'digInNames', string(data.digInNames));
        end

        function spec = siRecordingSpec(obj)
            %siRecordingSpec  How run_si_ks4.py should load this recording.
            %   Default: the reader kind plus folder/files/format. Readers
            %   override to add what their SpikeInterface extractor needs.
            spec = struct('reader', string(obj.Kind), 'folder', obj.Folder, ...
                'files', {cellstr(obj.Files(:).')}, 'recording_format', obj.RecordingFormat);
        end

        function m = metadataStruct(obj)
            %metadataStruct  The header metadata as one struct.
            m = struct('Fs', obj.Fs, 'NumChannels', obj.NumChannels, ...
                'ChannelNames', obj.ChannelNames, 'NativeNames', obj.NativeNames, ...
                'DigInNames', obj.DigInNames, 'Duration', obj.Duration, ...
                'AcqDate', obj.AcqDate, 'NumFiles', obj.NumFiles, ...
                'PerFile', obj.PerFile, 'RecordingFormat', obj.RecordingFormat);
        end
    end

    methods (Static)
        function classes = readerClasses()
            %readerClasses  Reader class names, built-ins first, then registered.
            classes = ["IntanReader", "BinaryReader", EphysReader.registered()];
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

        function r = forFolder(folder)
            %forFolder  The first registered reader that claims FOLDER, or [].
            %   The reader is returned with its files discovered.
            arguments
                folder (1,1) string
            end
            r = [];
            if folder == "" || ~isfolder(folder); return; end
            for c = EphysReader.readerClasses()
                try
                    if feval(c + ".claims", folder)
                        r = feval(c, folder);
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

        function folders = findAllRecordingFolders(root, recursive)
            %findAllRecordingFolders  Union of every reader's recording folders.
            arguments
                root (1,1) string
                recursive (1,1) logical = true
            end
            folders = string.empty(1, 0);
            for c = EphysReader.readerClasses()
                try
                    f = feval(c + ".findRecordingFolders", root, recursive);
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
            x = x(:) > 0;
            d = diff([0; x; 0]);
            on  = find(d == 1);
            off = find(d == -1) - 1;
            if isempty(on)
                iv = zeros(0, 2);
            else
                iv = [on off] ./ Fs;
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
