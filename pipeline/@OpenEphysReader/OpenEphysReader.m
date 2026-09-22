classdef OpenEphysReader < EphysReader
    % OpenEphysReader  EphysReader for Open Ephys GUI sessions.
    %   Reads a session folder written by the Open Ephys GUI (0.6 and later,
    %   plus the older Open Ephys format) in any of its record engines:
    %
    %     "openephys-binary"   Binary (the GUI default): Record Node <id>/
    %                          experiment<E>/recording<R>/structure.oebin,
    %                          continuous/<stream>/continuous.dat (int16,
    %                          channel-interleaved) + sample_numbers.npy,
    %                          events/<stream>/TTL/states + sample_numbers +
    %                          full_words.npy, sync_messages.txt
    %     "openephys-legacy"   Open Ephys format: one <proc>_<stream>_<channel>
    %                          [_<E>].continuous file per channel (1024-byte
    %                          header, 2070-byte records of 1024 big-endian
    %                          int16), <proc>_<stream>[_<E>].events (or
    %                          all_channels[_<E>].events before GUI 0.6),
    %                          messages[_<E>].events; GUI 0.4/0.5 sessions too
    %     "openephys-nwb"      NWB 2 (plugin): one experiment<E>.nwb (HDF5) per
    %                          experiment, recordings appended in /acquisition
    %
    %   A session folder is the folder the GUI names from the prepend text and
    %   the start time (e.g. "SUBJ01_2026-09-17_10-30-00", with any appended
    %   text); it holds one "Record Node <id>" folder per Record Node. The
    %   default name pattern for such folders is DefaultNamePattern.
    %
    %   Channels: the headstage channels of one continuous stream are the
    %   amplifier channels (microvolts = int16 * bit_volts); AUX channels
    %   (volts) are the accelerometer inputs and ADC channels (volts) the
    %   board ADC. Channel numbers (what a probe chanMap refers to) are "CH13"
    %   -> 12, else the name's trailing digits, else the position. Digital
    %   lines are named TTL1..TTLn (native = custom); name them with
    %   Signals.LineNames ("TTL4=InTrial").
    %
    %   Reader options (the pipeline config's Acquisition.OpenEphys section)
    %     Recordings  "concatenate" (default): every recording of the session
    %                 (all experiments and recordings, in order) is one
    %                 dataset, joined end to end (a warning names the wall-
    %                 clock gap at each boundary);
    %                 "separate": a session with several recordings becomes
    %                 one dataset per recording, each in a part folder inside
    %                 the session folder (openephys-part.json; created by the
    %                 scan) named from the recording's own start time;
    %                 "single": a session must hold one recording (refreshing
    %                 one with more throws OpenEphysReader:MultipleRecordings)
    %     RecordNode  Record Node id ("" = the only one; the lowest id, with a
    %                 warning, when there are several)
    %     Stream      continuous stream name ("" = the one with the most
    %                 headstage channels, with a warning when several have them)
    %
    %   Samples are read as stored: a recording's rows are its stored samples
    %   (dropped samples are not zero-filled; a warning lists the gaps), and
    %   TTL edges are placed on that row grid. The last record of each
    %   recording in the Open Ephys format is zero-padded to 1024 samples by
    %   the GUI; those samples are part of the data. The AUX inputs of the
    %   Intan Acquisition Board are updated every 4 samples; when every AUX
    %   channel holds its value for 4 samples readData returns them at Fs/4.
    %
    %   See also EphysReader, IntanReader, BinaryReader, EphysDataset.

    properties (Constant)
        Kind = "openephys"
        % Default Project.NamePattern for GUI-named session folders.
        DefaultNamePattern = "{SubjectID}_{Date:yyyy-MM-dd}_{Time:HH-mm-ss}*"
        PartFile = "openephys-part.json"
        PartSchema = "openephys-part/1"
        RecordingModes = ["concatenate" "separate" "single"]
    end

    properties (SetAccess = private)
        SessionFolder (1,1) string = ""        % folder holding the Record Node folder(s)
        Node          struct = struct([])      % selected node: id, folder, format
        Stream        struct = struct([])      % selected continuous stream (name, Fs, channels, ...)
        Parts         struct = struct([])      % selected recordings, in order (see oePartDetails)
        PartSelection struct = struct([])      % part folder: record_node, experiment, recording
        Mode          (1,1) string = "concatenate"
    end

    methods
        function obj = OpenEphysReader(folder, options)
            arguments
                folder (1,1) string = ""
                options struct = struct()
            end
            obj.Options = options;
            o = OpenEphysReader.modeOptions(options);
            obj.Mode = o.Recordings;
            if folder == ""; return; end
            obj.Folder = string(folder);
            [~, leaf] = fileparts(char(obj.Folder));
            obj.Name = string(leaf);
        end

        function discoverFiles(obj)
            %discoverFiles  Pick node, stream and recordings; list their files.
            obj.RecordingFormat = "unknown";
            obj.Files = string.empty(1, 0);
            obj.NumFiles = 0;
            obj.Parts = struct([]);
            obj.Node = struct([]);
            obj.Stream = struct([]);
            [obj.SessionFolder, obj.PartSelection] = OpenEphysReader.sessionOf(obj.Folder);
            if obj.SessionFolder == ""; return; end
            [node, inv, stream, parts] = OpenEphysReader.resolve(obj.SessionFolder, obj.Options, obj.PartSelection);
            if isempty(node) || isempty(stream); return; end
            obj.Node = node;
            obj.Stream = stream;
            obj.Parts = parts;
            obj.RecordingFormat = "openephys-" + inv.format;
            files = string.empty(1, 0);
            for k = 1:numel(parts)
                files = [files, reshape(parts(k).files, 1, [])]; %#ok<AGROW>
            end
            files = unique(files, 'stable');
            obj.Files = OpenEphysReader.relativeTo(obj.Folder, files);
            obj.NumFiles = numel(parts);
            if ~isempty(parts) && ~isnat(parts(1).start)
                obj.AcqDate = parts(1).start;
            end
        end

        function refreshMetadata(obj)
            %refreshMetadata  Channels, rate, per-recording sample counts, TTL lines.
            obj.discoverFiles();
            if isempty(obj.Parts)
                warning('OpenEphysReader:NoRecording', 'No Open Ephys recording found in %s', obj.Folder);
                return
            end
            if obj.Mode == "single" && numel(obj.Parts) > 1 && isempty(obj.PartSelection)
                error('OpenEphysReader:MultipleRecordings', ...
                    ['%s holds %d recordings (%s) but Acquisition.OpenEphys.Recordings is "single". ' ...
                     'Use "concatenate" (one dataset) or "separate" (one dataset per recording).'], ...
                    obj.Folder, numel(obj.Parts), strjoin([obj.Parts.label], ", "));
            end
            s = obj.Stream;
            hs = find([s.channels.type] == "headstage");
            obj.Fs = s.Fs;
            obj.NumChannels = numel(hs);
            obj.ChannelNames = [s.channels(hs).name];
            obj.NativeNames = obj.ChannelNames;
            obj.ChannelNumbers = OpenEphysReader.channelNumbersFor(obj.ChannelNames, obj.Folder);
            nLines = 0;
            for k = 1:numel(obj.Parts)
                ev = oeReadEvents(obj.formatName(), obj.Parts(k), s);
                nLines = max([nLines; ev.line(:); highBits(ev.initialWord); fullWordBits(ev.fullWord)]);
            end
            obj.DigInNames = "TTL" + string(1:nLines);
            if nLines == 0; obj.DigInNames = string.empty(1, 0); end
            obj.DigInNativeNames = obj.DigInNames;
            pf = struct('name', {}, 'bytesPerBlock', {}, 'numDataBlocks', {}, ...
                'numAmplifierSamples', {}, 'recordTime', {}, 'numAmplifierChannels', {}, ...
                'numBoardDigIn', {}, 'headerBytes', {}, 'datenum', {}, 'partialBlock', {}, ...
                'dataPresent', {}, 'experiment', {}, 'recording', {}, 'numGaps', {});
            for k = 1:numel(obj.Parts)
                p = obj.Parts(k);
                dn = NaN; if ~isnat(p.start); dn = datenum(p.start); end %#ok<DATNM>
                pf(k) = struct('name', p.label, 'bytesPerBlock', NaN, 'numDataBlocks', NaN, ...
                    'numAmplifierSamples', p.nSamples, 'recordTime', p.nSamples / s.Fs, ...
                    'numAmplifierChannels', numel(hs), 'numBoardDigIn', nLines, 'headerBytes', NaN, ...
                    'datenum', dn, 'partialBlock', false, 'dataPresent', p.nSamples > 0, ...
                    'experiment', p.experiment, 'recording', p.recording, 'numGaps', size(p.runs, 1) - 1);
            end
            obj.PerFile = pf;
            obj.Duration = sum([obj.Parts.nSamples]) / s.Fs;
            obj.warnLayout();
        end

        function plan = streamPlan(obj, opts)
            %streamPlan  Bounded sample windows over all recordings (kind "window").
            arguments
                obj (1,1) OpenEphysReader
                opts.Files (1,:) string = string.empty(1,0) %#ok<INUSA>
                opts.MaxChunkSamples (1,1) double = NaN
            end
            if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
            proto = struct('kind', "", 'name', "", 'file', "", 'sampleOffset', 0, 'nSamples', 0);
            total = obj.totalSamples();
            if total == 0
                plan = repmat(proto, 1, 0);
                return
            end
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
                plan(i).file         = "";
                plan(i).sampleOffset = off;
                plan(i).nSamples     = len;
            end
        end

        function X = readChunkUV(obj, chunk)
            arguments
                obj (1,1) OpenEphysReader
                chunk (1,1) struct
            end
            X = obj.readWindowUV(chunk.sampleOffset, chunk.nSamples);
        end

        function tf = supportsRandomAccess(obj) %#ok<MANU>
            tf = true;
        end

        function X = readWindowUV(obj, sampleOffset, nSamp)
            %readWindowUV  Rows [sampleOffset+1 .. sampleOffset+nSamp] in microvolts (headstage channels).
            arguments
                obj (1,1) OpenEphysReader
                sampleOffset (1,1) double {mustBeInteger, mustBeNonnegative}
                nSamp (1,1) double {mustBeInteger, mustBeNonnegative}
            end
            if isnan(obj.Fs); obj.refreshMetadata(); end
            hs = obj.channelsOfType("headstage");
            X = obj.readScaled(sampleOffset, nSamp, hs);
        end

        function data = readData(obj, opts)
            %readData  The whole recording as the universal data struct (EphysReader).
            arguments
                obj (1,1) OpenEphysReader
                opts.Files (1,:) string = string.empty(1,0) %#ok<INUSA>
                opts.KeepChannels (1,:) double {mustBeInteger, mustBePositive} = []
                opts.IncludeADC (1,1) logical = false
                opts.IncludeAux (1,1) logical = false
                opts.Concatenate (1,1) logical = true
                opts.ProgressFcn = []
                opts.Precision (1,1) string {mustBeMember(opts.Precision, ["double", "single"])} = "double"
            end
            if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
            if isempty(obj.Parts)
                error('OpenEphysReader:NoFiles', 'No Open Ephys recording in %s', obj.Folder);
            end
            hs = obj.channelsOfType("headstage");
            keep = opts.KeepChannels;
            if isempty(keep); keep = 1:numel(hs); end
            if max(keep) > numel(hs)
                error('OpenEphysReader:BadKeepChannels', ...
                    'KeepChannels references channel %d but the recording has %d.', max(keep), numel(hs));
            end
            nParts = numel(obj.Parts);
            counts = [obj.Parts.nSamples];
            offsets = [0 cumsum(counts)];
            AMP = cell(1, nParts);
            for k = 1:nParts
                if ~isempty(opts.ProgressFcn)
                    opts.ProgressFcn(k, nParts, obj.Parts(k).label);
                end
                X = obj.readScaled(offsets(k), counts(k), hs(keep));
                if opts.Precision == "single"; X = single(X); end
                AMP{k} = X;
            end
            if opts.Concatenate
                amplifier = cat(1, AMP{:});
                if isempty(amplifier); amplifier = zeros(0, numel(keep)); end
            else
                amplifier = AMP;
            end
            clear AMP
            E = obj.readDigitalEvents();
            boardADC = [];
            if opts.IncludeADC
                adc = obj.channelsOfType("adc");
                if ~isempty(adc); boardADC = obj.readScaled(0, sum(counts), adc); end
            end
            aux = []; auxFs = NaN; auxNames = string.empty(1, 0);
            if opts.IncludeAux
                ax = obj.channelsOfType("aux");
                if ~isempty(ax)
                    aux = obj.readScaled(0, sum(counts), ax);
                    [aux, auxFs] = OpenEphysReader.decimateHeldAux(aux, obj.Fs);
                    auxNames = [obj.Stream.channels(ax).name];
                end
            end
            n = sum(counts);
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
            data.boardADC         = boardADC;
            data.aux              = aux;
            data.auxFs            = auxFs;
            data.auxNames         = auxNames;
            data.auxNativeNames   = auxNames;
            data.files            = obj.Files;
            data.fileSampleCounts = counts;
            data.units            = "microvolts";
            data.source           = struct('Folder', obj.Folder, 'Name', obj.Name);
        end

        function E = readDigitalEvents(obj, opts)
            %readDigitalEvents  TTL intervals of every recording, from the event files only.
            %   Each recording's edges become [on off] rows on its own stored-
            %   sample grid, then shift by the rows of the recordings before
            %   it. A line high across a recording boundary is split there
            %   (with a warning).
            arguments
                obj (1,1) OpenEphysReader
                opts.ProgressFcn = []
            end
            if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
            names = obj.DigInNativeNames;
            nLines = numel(names);
            acc = repmat({zeros(0, 2)}, 1, nLines);
            offset = 0;
            nParts = numel(obj.Parts);
            highAtEnd = false(1, nLines);
            for k = 1:nParts
                p = obj.Parts(k);
                if ~isempty(opts.ProgressFcn); opts.ProgressFcn(k, nParts, p.label); end
                ev = oeReadEvents(obj.formatName(), p, obj.Stream);
                iv = oeIntervals(ev, p.runs, p.nSamples, nLines, obj.Name + " " + p.label);
                for L = 1:nLines
                    x = iv{L};
                    if k > 1 && highAtEnd(L) && ~isempty(x) && x(1, 1) == 1
                        warning('OpenEphysReader:LineAcrossBoundary', ...
                            '%s: %s is high across the start of %s; the interval is split there.', ...
                            obj.Name, names(L), p.label);
                    end
                    highAtEnd(L) = ~isempty(x) && x(end, 2) == p.nSamples;
                    acc{L} = [acc{L}; x + offset];
                end
                offset = offset + p.nSamples;
            end
            events = struct();
            for L = 1:nLines
                events.(EphysReader.eventKey(names(L))) = acc{L} ./ obj.Fs;
            end
            E = struct('events', events, 'Fs', obj.Fs, 'nSamples', offset, ...
                'digInNames', names, 'digInNativeNames', names);
        end
    end

    methods (Access = private)
        function f = formatName(obj)
            f = obj.Node.format;
        end

        function n = totalSamples(obj)
            n = 0;
            if ~isempty(obj.Parts); n = sum([obj.Parts.nSamples]); end
        end

        function idx = channelsOfType(obj, type)
            idx = find([obj.Stream.channels.type] == type);
        end

        function X = readScaled(obj, sampleOffset, nSamp, chanIdx)
            %readScaled  Rows of the concatenated recording, stream channels CHANIDX,
            %   scaled by bit_volts (microvolts for headstage, volts for AUX/ADC).
            total = obj.totalSamples();
            nSamp = max(0, min(nSamp, total - sampleOffset));
            X = zeros(nSamp, numel(chanIdx));
            if nSamp == 0 || isempty(chanIdx); return; end
            gain = [obj.Stream.channels(chanIdx).bitVolts];
            offsets = [0 cumsum([obj.Parts.nSamples])];
            a = sampleOffset + 1; b = sampleOffset + nSamp;       % global rows
            for k = 1:numel(obj.Parts)
                lo = max(a, offsets(k) + 1); hi = min(b, offsets(k + 1));
                if hi < lo; continue; end
                raw = oeReadRows(obj.formatName(), obj.Parts(k), lo - offsets(k), hi - lo + 1, chanIdx);
                X(lo - a + 1 : hi - a + 1, :) = double(raw) .* gain;
            end
        end

        function warnLayout(obj)
            %warnLayout  One warning per recording boundary (concatenate) and per recording with gaps.
            P = obj.Parts;
            for k = 1:numel(P)
                if size(P(k).runs, 1) > 1
                    r = P(k).runs;
                    lost = r(2:end, 3) - (r(1:end-1, 3) + r(1:end-1, 2) - r(1:end-1, 1) + 1);
                    warning('OpenEphysReader:Gaps', ...
                        '%s %s: %d gap(s) in the stored samples (at rows %s; %s samples missing); rows are the stored samples.', ...
                        obj.Name, P(k).label, numel(lost), strjoin(string(r(2:end, 1)), ", "), ...
                        strjoin(string(lost), ", "));
                end
                if k > 1
                    gapS = seconds(P(k).start - (P(k-1).start + seconds(P(k-1).nSamples / obj.Fs)));
                    txt = "an unknown time";
                    if isfinite(gapS); txt = sprintf("%.1f s", gapS); end
                    warning('OpenEphysReader:Concatenated', ...
                        '%s: %s follows %s directly; %s of wall-clock time between them is not in the data.', ...
                        obj.Name, P(k).label, P(k-1).label, txt);
                end
            end
        end
    end

    methods (Static)
        function tf = claims(folder)
            %claims  True for an Open Ephys session folder or a part folder.
            tf = false;
            folder = string(folder);
            if ~isfolder(folder); return; end
            [session, ~] = OpenEphysReader.sessionOf(folder);
            tf = session ~= "";
        end

        function folders = findRecordingFolders(root, recursive, options)
            %findRecordingFolders  Session folders (or part folders in "separate" mode).
            %   Sessions are found by their data files (structure.oebin,
            %   *.continuous, experiment*.nwb) inside a "Record Node" folder.
            %   In "separate" mode a session with several recordings is
            %   replaced by its part folders, which are created as needed.
            arguments
                root (1,1) string
                recursive (1,1) logical = true
                options struct = struct()
            end
            folders = string.empty(1, 0);
            if ~isfolder(root); return; end
            if recursive
                nodes = strings(0, 1);
                D = dir(fullfile(root, '**', 'structure.oebin'));
                for k = 1:numel(D)
                    nodes(end+1, 1) = string(fileparts(fileparts(D(k).folder))); %#ok<AGROW>
                end
                D = [dir(fullfile(root, '**', '*.continuous')); dir(fullfile(root, '**', 'experiment*.nwb'))];
                for k = 1:numel(D)
                    nodes(end+1, 1) = string(D(k).folder); %#ok<AGROW>
                end
                nodes = unique(nodes, 'stable');
                sessions = strings(0, 1);
                for k = 1:numel(nodes)
                    [p, leaf] = fileparts(char(nodes(k)));
                    if ~isempty(regexp(leaf, '^Record Node', 'once', 'ignorecase'))
                        sessions(end+1, 1) = string(p); %#ok<AGROW>
                    else
                        sessions(end+1, 1) = nodes(k); %#ok<AGROW>
                    end
                end
                sessions = unique(sessions, 'stable');
                sessions = sessions(arrayfun(@(s) ~isempty(oeNodes(s)), sessions));
            else
                sessions = strings(0, 1);
                if ~isempty(oeNodes(root)); sessions = root; end
            end
            o = OpenEphysReader.modeOptions(options);
            for s = reshape(sessions, 1, [])
                if o.Recordings == "separate"
                    folders = [folders, OpenEphysReader.partFolders(s, options)]; %#ok<AGROW>
                else
                    folders(end+1) = s; %#ok<AGROW>
                end
            end
        end

        function folders = partFolders(session, options)
            %partFolders  The session itself (one recording) or its part folders.
            %   Creates <session>/<part name>/openephys-part.json for every
            %   recording of a multi-recording session, named from the
            %   session leaf with its GUI timestamp replaced by the
            %   recording's own start time (see partName).
            arguments
                session (1,1) string
                options struct = struct()
            end
            folders = string.empty(1, 0);
            try
                [node, ~, ~, parts] = OpenEphysReader.resolve(session, options, struct([]));
            catch ME
                warning('OpenEphysReader:ReaderFailed', '%s: %s', session, ME.message);
                return
            end
            if isempty(node) || isempty(parts); return; end
            if numel(parts) == 1
                folders = session;
                return
            end
            [~, leaf] = fileparts(char(session));
            names = OpenEphysReader.partNames(string(leaf), parts);
            for k = 1:numel(parts)
                f = string(fullfile(session, names(k)));
                pf = fullfile(f, OpenEphysReader.PartFile);
                want = struct('schema', OpenEphysReader.PartSchema, 'record_node', node.id, ...
                    'experiment', parts(k).experiment, 'recording', parts(k).recording);
                if ~isfile(pf)
                    try
                        if ~isfolder(f); mkdir(f); end
                        writeJsonFile(pf, want);
                    catch ME
                        warning('OpenEphysReader:PartFolder', ...
                            'Cannot create the part folder %s (read-only session?): %s', f, ME.message);
                        continue
                    end
                end
                folders(end+1) = f; %#ok<AGROW>
            end
        end

        function names = partNames(leaf, parts)
            %partNames  Part folder names: the leaf with its GUI timestamp replaced by each start.
            %   "SUBJ01_2026-09-17_10-30-00_x" -> "SUBJ01_2026-09-17_10-47-12_x";
            %   without a GUI timestamp (or start time) "<leaf>_exp<E>_rec<R>";
            %   a same-second clash appends "_rec<R>".
            pat = '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}';
            names = strings(1, numel(parts));
            for k = 1:numel(parts)
                t = parts(k).start;
                if ~isempty(regexp(leaf, pat, 'once')) && ~isnat(t)
                    t.Format = 'yyyy-MM-dd_HH-mm-ss';
                    names(k) = string(regexprep(char(leaf), pat, char(string(t)), 'once'));
                else
                    names(k) = leaf + "_exp" + parts(k).experiment + "_rec" + parts(k).recording;
                end
            end
            [u, ~, g] = unique(names);
            if numel(u) < numel(names)
                counts = accumarray(g(:), 1);
                for k = find(counts(g) > 1).'
                    names(k) = names(k) + "_exp" + parts(k).experiment + "_rec" + parts(k).recording;
                end
            end
        end

        function [node, inv, stream, parts] = resolve(session, options, selection)
            %resolve  Node, inventory, stream and (detailed) recordings of a session.
            node = []; inv = []; stream = []; parts = struct([]);
            o = OpenEphysReader.modeOptions(options);
            nodes = oeNodes(session);
            if isempty(nodes); return; end
            ids = [nodes.id];
            if ~isempty(selection) && isfield(selection, 'record_node')
                want = string(selection.record_node);
                node = nodes(ids == want);
                if isempty(node)
                    error('OpenEphysReader:NoNode', '%s has no Record Node %s.', session, want);
                end
            elseif o.RecordNode ~= ""
                node = nodes(ids == o.RecordNode);
                if isempty(node)
                    error('OpenEphysReader:NoNode', '%s has no Record Node %s (it has %s).', ...
                        session, o.RecordNode, strjoin("Record Node " + ids, ", "));
                end
            else
                node = nodes(1);
                if numel(nodes) > 1
                    warning('OpenEphysReader:SeveralNodes', ...
                        '%s has %d Record Nodes; reading Record Node %s (set Acquisition.OpenEphys.RecordNode to choose).', ...
                        session, numel(nodes), node.id);
                end
            end
            inv = oeInventory(node);
            stream = OpenEphysReader.pickStream(inv.streams, o.Stream, session);
            if isempty(stream) || isempty(inv.parts); return; end
            all = inv.parts;
            ordinal = zeros(1, numel(all));
            for k = 1:numel(all)
                ordinal(k) = sum([all(1:k).experiment] == all(k).experiment);
            end
            pick = 1:numel(all);
            if ~isempty(selection) && isfield(selection, 'experiment')
                pick = find([all.experiment] == double(selection.experiment) ...
                    & [all.recording] == double(selection.recording));
                if isempty(pick)
                    error('OpenEphysReader:NoRecording', '%s has no experiment %d recording %d.', ...
                        session, double(selection.experiment), double(selection.recording));
                end
            end
            for k = pick
                d = oePartDetails(inv, all(k), stream, ordinal(k));
                if d.nSamples == 0
                    warning('OpenEphysReader:EmptyRecording', '%s: %s holds no samples; skipped.', session, all(k).label);
                    continue
                end
                p = struct('experiment', all(k).experiment, 'recording', all(k).recording, ...
                    'label', all(k).label);
                for f = string(fieldnames(d)).'
                    p.(f) = d.(f);
                end
                if isempty(parts); parts = p; else; parts(end+1) = p; end %#ok<AGROW>
            end
        end

        function s = pickStream(streams, want, session)
            %pickStream  The named stream, else the one with the most headstage channels.
            s = [];
            if isempty(streams); return; end
            nHs = arrayfun(@(x) sum([x.channels.type] == "headstage"), streams);
            if want ~= ""
                k = find(strcmpi([streams.name], want) | strcmpi([streams.key], want), 1);
                if isempty(k)
                    error('OpenEphysReader:NoStream', '%s has no stream "%s" (streams: %s).', ...
                        session, want, strjoin([streams.name], ", "));
                end
                s = streams(k);
                return
            end
            [m, k] = max(nHs);
            if m == 0
                warning('OpenEphysReader:NoHeadstage', '%s: no stream has headstage channels.', session);
                return
            end
            if sum(nHs > 0) > 1
                warning('OpenEphysReader:SeveralStreams', ...
                    '%s: streams %s have headstage channels; reading "%s" (set Acquisition.OpenEphys.Stream to choose).', ...
                    session, strjoin([streams(nHs > 0).name], ", "), streams(k).name);
            end
            s = streams(k);
        end

        function [session, selection] = sessionOf(folder)
            %sessionOf  Session folder of FOLDER ("" if none) and a part folder's selection.
            session = ""; selection = struct([]);
            folder = string(folder);
            pf = fullfile(folder, OpenEphysReader.PartFile);
            if isfile(pf)
                s = readJsonFile(pf, ErrorOnFail=false);
                if isstruct(s) && isfield(s, 'schema') && string(s.schema) == OpenEphysReader.PartSchema ...
                        && all(isfield(s, {'record_node', 'experiment', 'recording'}))
                    parent = string(fileparts(char(folder)));
                    if ~isempty(oeNodes(parent))
                        session = parent;
                        selection = struct('record_node', string(s.record_node), ...
                            'experiment', double(s.experiment), 'recording', double(s.recording));
                    end
                end
                return
            end
            if ~isempty(oeNodes(folder)); session = folder; end
        end

        function o = modeOptions(options)
            %modeOptions  The OpenEphys reader options with defaults filled in.
            o = struct('Recordings', "concatenate", 'RecordNode', "", 'Stream', "");
            s = EphysReader.readerOptions(options, 'OpenEphys');
            for f = string(fieldnames(o)).'
                if isfield(s, f) && ~isempty(s.(f)); o.(f) = string(s.(f)); end
            end
            if ~ismember(o.Recordings, OpenEphysReader.RecordingModes)
                error('OpenEphysReader:BadMode', 'OpenEphys.Recordings must be one of %s.', ...
                    strjoin(OpenEphysReader.RecordingModes, ", "));
            end
        end

        function nums = channelNumbersFor(names, where)
            %channelNumbersFor  "CH13" -> 12, else trailing digits, else position.
            names = string(names);
            nums = EphysReader.trailingNumbers(names);
            isCH = ~cellfun('isempty', regexp(cellstr(names), '^CH\d+$', 'ignorecase', 'once'));
            nums(isCH) = nums(isCH) - 1;
            nums = EphysReader.checkChannelNumbers(nums, where);
        end

        function [aux, auxFs] = decimateHeldAux(aux, Fs)
            %decimateHeldAux  AUX at Fs/4 when every channel holds each value for 4 rows.
            %   The Acquisition Board updates its AUX inputs every 4 samples.
            %   The hold is tested on the first 10 s for each phase 0..3 (a
            %   constant channel passes); when found, the held values are
            %   returned at Fs/4 (lossless), else AUX stays at Fs.
            auxFs = Fs;
            n = size(aux, 1);
            if n < 8; return; end
            m = min(n, round(10 * Fs));
            A = aux(1:m, :);
            for p = 0:3
                nGroups = floor((m - p) / 4);
                if nGroups < 2; continue; end
                G = reshape(A(p + 1 : p + 4 * nGroups, :), 4, nGroups, []);
                if all(G == G(1, :, :), 'all')
                    aux = aux(p + 1 : 4 : end, :);
                    auxFs = Fs / 4;
                    return
                end
            end
        end
    end

    methods (Static, Hidden)
        function fmt = nodeFormat(folder)
            %nodeFormat  "binary" | "legacy" | "nwb" | "" for a Record Node folder.
            fmt = "";
            folder = string(folder);
            E = dir(fullfile(folder, 'experiment*'));
            for e = reshape(E([E.isdir]), 1, [])
                R = dir(fullfile(e.folder, e.name, 'recording*'));
                for r = reshape(R([R.isdir]), 1, [])
                    if isfile(fullfile(r.folder, r.name, 'structure.oebin')); fmt = "binary"; return; end
                end
            end
            if ~isempty(dir(fullfile(folder, '*.continuous'))); fmt = "legacy"; return; end
            if ~isempty(dir(fullfile(folder, 'experiment*.nwb'))); fmt = "nwb"; end
        end

        function h = continuousHeader(file)
            %continuousHeader  channel, sampleRate, bitVolts, created from a 1024-byte header.
            h = struct('channel', "", 'sampleRate', NaN, 'bitVolts', NaN, 'created', NaT);
            fid = fopen(file, 'r');
            if fid < 0; error('OpenEphysReader:Open', 'Cannot open %s', file); end
            txt = fread(fid, [1 1024], '*char');
            fclose(fid);
            kv = regexp(txt, 'header\.(\w+)\s*=\s*([^;]*);', 'tokens');
            for k = 1:numel(kv)
                key = kv{k}{1};
                val = strtrim(strrep(kv{k}{2}, '''', ''));
                switch key
                    case 'channel',      h.channel = string(val);
                    case 'sampleRate',   h.sampleRate = str2double(val);
                    case 'bitVolts',     h.bitVolts = str2double(val);
                    case 'date_created', h.created = OpenEphysReader.parseCreated(val);
                end
            end
        end

        function t = parseCreated(s)
            %parseCreated  "17-Sep-2026 10:30:5" (GUI 0.6+) or "17-Sep-2026 103005" (0.4/0.5).
            t = NaT;
            tok = regexp(char(s), '(\d{1,2})-([A-Za-z]{3})-(\d{4})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})', 'tokens', 'once');
            if isempty(tok)
                tok = regexp(char(s), '(\d{1,2})-([A-Za-z]{3})-(\d{4})\s+(\d{2})(\d{2})(\d{2})', 'tokens', 'once');
            end
            if isempty(tok); return; end
            mon = find(strcmpi(tok{2}, {'Jan' 'Feb' 'Mar' 'Apr' 'May' 'Jun' 'Jul' 'Aug' 'Sep' 'Oct' 'Nov' 'Dec'}), 1);
            if isempty(mon); return; end
            v = str2double(tok([3 1 4 5 6]));
            t = datetime(v(1), mon, v(2), v(3), v(4), v(5));
        end

        function [fid, nRec] = openContinuous(file)
            %openContinuous  Open a .continuous file (little-endian headers) and count its whole records.
            fid = fopen(file, 'r', 'ieee-le');
            if fid < 0; error('OpenEphysReader:Open', 'Cannot open %s', file); end
            d = dir(file);
            nRec = max(0, floor((d.bytes - 1024) / 2070));
        end

        function [sample, recNum, n] = recordHeader(fid, k)
            %recordHeader  First sample number, recording number and sample count of record K (0-based).
            fseek(fid, 1024 + k * 2070, 'bof');
            sample = double(fread(fid, 1, 'int64=>int64'));
            n = double(fread(fid, 1, 'uint16=>uint16'));
            recNum = double(fread(fid, 1, 'uint16=>uint16'));
        end

        function H = npyHeader(file)
            %npyHeader  Data offset, element type and length of a 1-D .npy file.
            fid = fopen(file, 'r', 'ieee-le');
            if fid < 0; error('OpenEphysReader:Open', 'Cannot open %s', file); end
            closer = onCleanup(@() fclose(fid));
            fread(fid, 6, 'uint8');
            ver = fread(fid, 1, 'uint8'); fread(fid, 1, 'uint8');
            if ver >= 2; len = fread(fid, 1, 'uint32'); else; len = fread(fid, 1, 'uint16'); end
            hdr = fread(fid, [1 len], '*char');
            descr = regexp(hdr, '''descr''\s*:\s*''([^'']+)''', 'tokens', 'once');
            shp = regexp(hdr, '''shape''\s*:\s*\(([^)]*)\)', 'tokens', 'once');
            shape = sscanf(strrep(shp{1}, ',', ' '), '%g');
            bytes = str2double(descr{1}(3:end));
            switch descr{1}(2)
                case 'i', prec = sprintf('int%d', 8 * bytes);
                case 'u', prec = sprintf('uint%d', 8 * bytes);
                case 'f', prec = 'double'; if bytes == 4; prec = 'single'; end
                otherwise, error('OpenEphysReader:Npy', 'Unsupported dtype %s in %s', descr{1}, file);
            end
            n = 0; if ~isempty(shape); n = prod(shape); end
            H = struct('offset', ftell(fid), 'bytes', bytes, 'prec', prec, 'n', n);
        end

        function v = npyAt(fid, H, i)
            %npyAt  Element I (1-based) of an open 1-D .npy file, as double.
            fseek(fid, H.offset + (i - 1) * H.bytes, 'bof');
            v = double(fread(fid, 1, [H.prec '=>' H.prec]));
        end

        function runs = findRuns(at, n, step)
            %findRuns  [first last value] runs of indices 1..N where at(i) - STEP*i is constant.
            %   AT(i) is non-decreasing in AT(i) - STEP*i (sample numbers never
            %   repeat or go back), so each run end is found by binary search:
            %   O(runs * log n) calls.
            runs = zeros(0, 3);
            i = 1;
            while i <= n
                v0 = at(i);
                h0 = v0 - step * i;
                lo = i; hi = n;
                if at(n) - step * n == h0
                    lo = n;
                else
                    while lo < hi
                        mid = floor((lo + hi + 1) / 2);
                        if at(mid) - step * mid == h0; lo = mid; else; hi = mid - 1; end
                    end
                end
                runs(end+1, :) = [i lo v0]; %#ok<AGROW>
                i = lo + 1;
            end
        end

        function t = fromEpochMs(ms)
            %fromEpochMs  Milliseconds since 1970 (UTC) -> local datetime without a time zone.
            t = datetime(ms / 1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
            t.TimeZone = 'local';
            t.TimeZone = '';
            t.Format = 'yyyy-MM-dd HH:mm:ss.SSS';
        end

        function t = parseIsoLocal(s)
            %parseIsoLocal  "2026-09-17T10:30:00-04:00" -> local datetime without a time zone.
            t = NaT;
            s = strtrim(string(s));
            try
                if ~isempty(regexp(s, '([+-]\d{2}:\d{2}|Z)$', 'once'))
                    t = datetime(s, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ssXXX', 'TimeZone', 'UTC');
                    t.TimeZone = 'local';
                    t.TimeZone = '';
                else
                    t = datetime(s, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
                end
            catch
            end
        end

        function rel = relativeTo(base, files)
            %relativeTo  FILES relative to BASE (with ".." for a part folder's session files).
            base = char(strip(replace(string(base), "\", "/"), 'right', '/'));
            rel = strings(1, numel(files));
            bparts = strsplit(base, '/');
            for k = 1:numel(files)
                f = char(replace(string(files(k)), "\", "/"));
                fparts = strsplit(f, '/');
                m = 0;
                while m < min(numel(bparts), numel(fparts)) && strcmpi(bparts{m + 1}, fparts{m + 1})
                    m = m + 1;
                end
                up = repmat({'..'}, 1, numel(bparts) - m);
                rel(k) = string(strjoin([up, fparts(m + 1:end)], filesep));
            end
        end
    end
end


function b = highBits(w)
%highBits  Line numbers (1-based) set in a TTL word (NaN -> none).
b = zeros(0, 1);
if isempty(w) || ~isfinite(w) || w <= 0; return; end
b = find(bitget(uint64(w), 1:64)).';
end


function b = fullWordBits(w)
%fullWordBits  Line numbers set in any TTL word.
b = zeros(0, 1);
if isempty(w); return; end
any64 = uint64(0);
for k = 1:numel(w); any64 = bitor(any64, uint64(w(k))); end
if any64 > 0; b = find(bitget(any64, 1:64)).'; end
end
