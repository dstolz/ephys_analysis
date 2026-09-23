classdef IntanReader < EphysReader
    % IntanReader  EphysReader for Intan RHD2000 recordings.
    %   Supports the three Intan layouts:
    %     "traditional"          one or more *.rhd files with embedded data
    %                            (microvolts = 0.195 * (uint16 - 32768))
    %     "one-file-per-signal"  info.rhd + amplifier.dat (+ time/digitalin/...)
    %     "one-file-per-channel" info.rhd + amp-<native>.dat per channel
    %                            (microvolts = 0.195 * int16, no offset)
    %   The header parser (parseIntanHeader), the split-format layout resolver
    %   (splitLayout) and the readers live in this class folder; nothing
    %   above EphysDataset touches them. Every layout allows bounded window
    %   reads (readWindowUV): traditional files are read block by block
    %   (sliceDataBlocks), the split layouts straight from the .dat files.
    %
    %   The recording start (AcqDate) is the time RHX puts in its names
    %   (<prefix>_yyMMdd_HHmmss.rhd; a split recording's folder
    %   <prefix>_yyMMdd_HHmmss), else a modification time less the data it
    %   ends: RHX stamps a file when it closes it.
    %
    %   See also EphysReader, EphysDataset, READ_INTAN_RHD2000_FILE_MODIFIED.

    properties (Constant)
        Kind = "intan"
    end

    properties (Access = private, Transient)
        % Cached split-format layout (info.rhd header + .dat file map + sample
        % count) so the per-window readers do not re-parse on every chunk.
        % Built lazily by splitLayout; cleared by discoverFiles.
        pSplitLayout = []
        % Cached parseIntanHeader structs of the traditional files read so
        % far (block layout for the window reads). Filled by refreshMetadata
        % and rhdHeader; cleared by discoverFiles.
        pHeaders = []
    end

    methods
        % --- methods defined in separate files ---
        refreshMetadata(obj)
        plan = streamPlan(obj, opts)
        X    = readChunkUV(obj, chunk)
        data = readData(obj, opts)
        E    = readDigitalEvents(obj, opts)
        data = readSplitAll(obj, opts)
        X    = readSplitWindow(obj, sampleOffset, nSamp)
        L    = splitLayout(obj)

        function obj = IntanReader(folder, options)
            arguments
                folder (1,1) string = ""
                options struct = struct()   % reader options (unused by Intan)
            end
            obj.Options = options;
            if folder == ""; return; end
            obj.Folder = string(folder);
            [~, leaf] = fileparts(char(obj.Folder));
            obj.Name = string(leaf);
        end

        function discoverFiles(obj)
            %discoverFiles  Inventory the recording folder for the detected layout.
            %   Traditional: every *.rhd data file, sorted chronologically by
            %   datenum. Split formats: the single info.rhd header stands in as
            %   the one "file"; the amplifier sample count comes from the .dat
            %   file(s) at metadata time (see refreshMetadata / splitLayout).
            %   AcqDate is the recording start (see startTime).
            obj.RecordingFormat = IntanReader.detectFormat(obj.Folder);
            obj.pSplitLayout = [];
            obj.pHeaders = [];
            obj.AcqDate = NaT;

            switch obj.RecordingFormat
                case {"one-file-per-signal", "one-file-per-channel"}
                    obj.Files = "info.rhd";
                    obj.NumFiles = 1;

                case "traditional"
                    D = dir(fullfile(obj.Folder, '*.rhd'));
                    if isempty(D)
                        obj.Files = string.empty(1,0);
                        obj.NumFiles = 0;
                        return
                    end
                    [~, ix] = sort([D.datenum]);
                    D = D(ix);
                    obj.Files = string({D.name});
                    obj.NumFiles = numel(D);

                otherwise
                    obj.Files = string.empty(1,0);
                    obj.NumFiles = 0;
                    return
            end
            obj.AcqDate = obj.startTime();
        end

        function tf = supportsRandomAccess(obj)
            %supportsRandomAccess  Every Intan layout allows bounded window reads.
            tf = ismember(obj.RecordingFormat, ["traditional" "one-file-per-signal" "one-file-per-channel"]);
        end

        function X = readWindowUV(obj, sampleOffset, nSamp)
            %readWindowUV  Samples [sampleOffset+1 .. sampleOffset+nSamp] in microvolts.
            %   Rows of the whole recording (every file, in order), all
            %   amplifier channels in header order; a window running past
            %   the end returns the rows there are. Traditional files are
            %   read from the data blocks the window covers (rhdRows), so a
            %   window costs its own size, not whole files; split layouts
            %   read the .dat files (readSplitWindow).
            arguments
                obj (1,1) IntanReader
                sampleOffset (1,1) double {mustBeInteger, mustBeNonnegative}
                nSamp (1,1) double {mustBeInteger, mustBeNonnegative}
            end
            if obj.RecordingFormat ~= "traditional"
                X = obj.readSplitWindow(sampleOffset, nSamp);
                return
            end
            if isnan(obj.Fs) || isempty(obj.PerFile)
                obj.refreshMetadata();
            end
            counts = [obj.PerFile.numAmplifierSamples];
            ends = cumsum(counts);
            nSamp = max(0, min(nSamp, sum(counts) - sampleOffset));
            X = zeros(nSamp, obj.NumChannels);
            a = sampleOffset + 1; b = sampleOffset + nSamp;       % recording rows
            for k = find(counts > 0 & ends >= a & ends - counts < b)
                lo = max(a, ends(k) - counts(k) + 1); hi = min(b, ends(k));
                X(lo - a + 1 : hi - a + 1, :) = obj.rhdRows(obj.PerFile(k).name, ...
                    lo - (ends(k) - counts(k)), hi - (ends(k) - counts(k)));
            end
        end
    end

    methods (Access = private)
        X = rhdRows(obj, name, lo, hi)
        [ev, names, native] = splitDigitalEvents(obj, nSamp)

        function hdr = rhdHeader(obj, name)
            %rhdHeader  parseIntanHeader of the traditional file NAME (cached).
            hdr = [];
            if ~isempty(obj.pHeaders)
                hdr = obj.pHeaders([obj.pHeaders.name] == string(name));
            end
            if isempty(hdr)
                hdr = IntanReader.parseIntanHeader(fullfile(obj.Folder, name));
                obj.pHeaders = [obj.pHeaders, hdr];
            end
            hdr = hdr(1);
        end

        function t = startTime(obj)
            %startTime  When the recording started (NaT when it cannot be told).
            %   RHX names a traditional file <prefix>_yyMMdd_HHmmss.rhd and a
            %   split recording's folder <prefix>_yyMMdd_HHmmss after the time
            %   it started, so that time is used when the name carries it.
            %   Otherwise the start is worked back from a modification time
            %   (to the second), which RHX sets when it closes a file: the
            %   first file's less that file's duration (traditional), or
            %   amplifier.dat's (the first amplifier file's) less the
            %   recording's duration (split).
            if obj.RecordingFormat == "traditional"
                [~, stem] = fileparts(obj.Files(1));
                t = IntanReader.nameTime(stem);
            else
                t = IntanReader.nameTime(obj.Name);
            end
            if ~isnat(t); return; end
            try
                if obj.RecordingFormat == "traditional"
                    hdr = obj.rhdHeader(obj.Files(1));
                    t = datetime(hdr.datenum, 'ConvertFrom', 'datenum') - seconds(hdr.recordTime);
                else
                    L = obj.splitLayout();
                    t = datetime(L.ampDatenum, 'ConvertFrom', 'datenum') - seconds(L.nSamp / L.Fs);
                end
            catch
                t = NaT;
            end
        end
    end

    methods (Static)
        hdr = parseIntanHeader(ffn)
        S   = sliceDataBlocks(raw, hdr, signals)

        function t = nameTime(name)
            %nameTime  The start time RHX puts at the end of a name (NaT if none).
            %   "rat01_260922_100000" -> 22-Sep-2026 10:00:00: the name's
            %   trailing _yyMMdd_HHmmss (a file name without its extension, or
            %   a folder name).
            t = NaT;
            tok = regexp(char(name), '_(\d{6}_\d{6})$', 'tokens', 'once');
            if isempty(tok); return; end
            try
                t = datetime(tok{1}, 'InputFormat', 'yyMMdd_HHmmss');
                t.Format = 'default';
            catch
                t = NaT;
            end
        end

        function nums = channelNumbersFor(nativeNames, where)
            %channelNumbersFor  Hardware numbers from native names ("A-012" -> 12).
            %   A multi-port recording repeats numbers (A-000, B-000), so the
            %   channels are then numbered by position (see
            %   EphysReader.checkChannelNumbers).
            nums = EphysReader.checkChannelNumbers(EphysReader.trailingNumbers(nativeNames), where);
        end

        function tf = claims(folder)
            %claims  True when FOLDER holds an Intan recording in any layout.
            tf = IntanReader.detectFormat(folder) ~= "unknown";
        end

        function folders = findRecordingFolders(root, recursive, options) %#ok<INUSD>
            %findRecordingFolders  Folders directly containing >=1 *.rhd file.
            %   info.rhd matches too, so the split layouts are found as well.
            arguments
                root (1,1) string
                recursive (1,1) logical = true
                options struct = struct()
            end
            folders = string.empty(1, 0);
            if ~isfolder(root); return; end
            if recursive
                D = dir(fullfile(root, '**', '*.rhd'));
            else
                D = dir(fullfile(root, '*.rhd'));
            end
            if isempty(D); return; end
            D = D(~[D.isdir]);
            if isempty(D); return; end
            folders = unique(string({D.folder}), 'stable');
        end

        function fmt = detectFormat(folder)
            %detectFormat  Classify a folder's Intan acquisition file layout.
            %   "one-file-per-signal"  info.rhd + amplifier.dat
            %   "one-file-per-channel" info.rhd + amp-*.dat
            %   "traditional"          one or more *.rhd files (embedded data)
            %   "unknown"              no recognized Intan files
            arguments
                folder (1,1) string
            end
            folder = char(folder);
            if isfile(fullfile(folder, 'info.rhd'))
                if isfile(fullfile(folder, 'amplifier.dat'))
                    fmt = "one-file-per-signal";
                    return
                end
                if ~isempty(dir(fullfile(folder, 'amp-*.dat')))
                    fmt = "one-file-per-channel";
                    return
                end
            end
            if ~isempty(dir(fullfile(folder, '*.rhd')))
                fmt = "traditional";
            else
                fmt = "unknown";
            end
        end
    end
end
