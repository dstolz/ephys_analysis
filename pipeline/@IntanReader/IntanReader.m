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
    %   above EphysDataset touches them.
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
    end

    methods
        % --- methods defined in separate files ---
        refreshMetadata(obj)
        plan = streamPlan(obj, opts)
        X    = readChunkUV(obj, chunk)
        data = readData(obj, opts)
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
            obj.RecordingFormat = IntanReader.detectFormat(obj.Folder);
            obj.pSplitLayout = [];

            switch obj.RecordingFormat
                case {"one-file-per-signal", "one-file-per-channel"}
                    obj.Files = "info.rhd";
                    obj.NumFiles = 1;
                    d = dir(fullfile(obj.Folder, 'info.rhd'));
                    if ~isempty(d)
                        obj.AcqDate = datetime(d.datenum, 'ConvertFrom', 'datenum');
                    end

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
                    obj.AcqDate = datetime(min([D.datenum]), 'ConvertFrom', 'datenum');

                otherwise
                    obj.Files = string.empty(1,0);
                    obj.NumFiles = 0;
            end
        end

        function tf = supportsRandomAccess(obj)
            %supportsRandomAccess  The split layouts allow bounded window reads.
            tf = obj.RecordingFormat == "one-file-per-signal" || ...
                 obj.RecordingFormat == "one-file-per-channel";
        end

        function X = readWindowUV(obj, sampleOffset, nSamp)
            %readWindowUV  Bounded window from a split-format recording (microvolts).
            X = obj.readSplitWindow(sampleOffset, nSamp);
        end
    end

    methods (Static)
        hdr = parseIntanHeader(ffn)

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
