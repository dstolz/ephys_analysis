classdef EphysDataset < handle
    % EphysDataset  One recording folder -> processing, sorting and exports.
    %   An EphysDataset represents a single recording. All raw-data access goes
    %   through an EphysReader chosen for the folder (see Reader): IntanReader
    %   for the Intan RHX layouts, BinaryReader for the universal recording.json
    %   + flat binary format, OpenEphysReader for Open Ephys GUI sessions
    %   (Binary, Open Ephys and NWB formats), TDTReader for TDT Synapse
    %   blocks, or any registered reader, so
    %   nothing above this class depends on the acquisition system.
    %   It discovers the files, gathers header metadata cheaply (without reading
    %   amplifier data), reads/filters/screens the data, streams a Kilosort4 .bin
    %   file to disk, and spawns Kilosort4 - identically across formats, because
    %   all data access goes through the format-agnostic streamPlan/readChunkUV
    %   primitives.
    %
    %   Digital lines: readers key their events by each line's native name
    %   (DIGITAL-IN-04, TTL4); readData and digitalEvents rename them by
    %   TrialConfig.LabelField ("custom" | "native") and TrialConfig.LineNames
    %   ("native=name" entries, e.g. "TTL4=InTrial"), see relabelEvents.
    %
    %   Existing helpers are reused, never forked:
    %     read_Intan_RHD2000_file_modified  traditional reader (via readChunkUV)
    %     matrix2kilosort                   in-memory .bin writer (matrixToBin)
    %
    %   Construction
    %   ------------
    %     ds = EphysDataset(folder)                       % auto-refresh metadata
    %     ds = EphysDataset(folder, AutoMetadata=false)   % cheap; defer parsing
    %     ds = EphysDataset(folder, ProbeFile=..., PythonExe=..., OutputDir=...)
    %
    %   Typical workflow
    %   ----------------
    %     ds = EphysDataset("D:\rec\subj1_day1");
    %     T  = ds.PerFile;                 % per-file header summary
    %     ds.ProbeFile = "probe.json";
    %     ds.PythonExe = "C:\miniconda3\python.exe";
    %     res = ds.runKilosort();          % toBin, then Kilosort4
    %
    %   Derived signals (the intan2matlab conversion, any layout)
    %   ---------------------------------------------------------
    %     [Y, ev, info] = ds.deriveSignals(dataTypeOut=["LFP" "MUA"]);
    %     out = ds.toMat(File="D:\out\subj1.mat", ...
    %                    SignalOptions=struct('dataTypeOut', "LFP"));
    %
    %   Event-organized (epoched) data
    %   ------------------------------
    %     E = ds.eventEpochs(EventSource="behavior", Window=[-0.2 0.5]);
    %     out = ds.exportEpochs();         % the same, saved as <Name>_epochs.mat
    %
    %   Processed files, loaded on demand
    %   ---------------------------------
    %     out = ds.outputs();              % DatasetOutputs: finds every output
    %     FT  = out.FieldTrip;             % loads <Name>_fieldtrip.mat
    %
    %   See also EPHYSPROJECT, DATASETOUTPUTS, READ_INTAN_RHD2000_FILE_MODIFIED,
    %   MATRIX2KILOSORT, EXTRACT_TRIALS, INTAN2MATLAB.

    properties
        Folder   (1,1) string = ""      % recording folder
        Files    (1,:) string = string.empty(1,0)  % recording files (relative to Folder), from the reader
        Name     (1,1) string = ""      % dataset name (defaults to folder name)
    end

    properties (SetAccess = protected)
        % On-disk layout of the recording, from its reader (see
        % EphysDataset.detectFormat): Intan "traditional" | "one-file-per-signal"
        % | "one-file-per-channel", "binary" (recording.json), Open Ephys
        % "openephys-binary" | "openephys-legacy" | "openephys-nwb", or
        % "unknown" when no reader recognises the folder. Recorded in the
        % manifest.
        RecordingFormat (1,1) string = "unknown"
    end

    properties (SetAccess = protected)
        % Header metadata (filled by refreshMetadata; no amplifier data read)
        Fs           (1,1) double = NaN          % amplifier sample rate (Hz)
        NumChannels  (1,1) double = NaN          % amplifier channel count
        ChannelNames (1,:) string = string.empty(1,0)  % custom channel names
        NativeNames  (1,:) string = string.empty(1,0)  % native (hardware) channel names
        ChannelNumbers (1,:) double = double.empty(1,0) % 0-based hardware numbers (units.channelNumber); probe chanMap values are .bin rows, not these
        DigInNames   (1,:) string = string.empty(1,0)  % digital-line custom names
        DigInNativeNames (1,:) string = string.empty(1,0) % digital-line native names (DIGITAL-IN-04, TTL4)
        Duration     (1,1) double = NaN          % total recording duration (s)
        AcqDate      datetime = NaT              % recording start
        NumFiles     (1,1) double = 0            % number of recording files / parts
        PerFile      struct = struct([])         % per-file (per-part) summary (struct array)
    end

    properties
        % Configuration (also pushed down from EphysProject)
        ProbeFile (1,1) string = ""              % existing KS4 probe .json (validated, never generated)

        % Amplifier channels to exclude from Kilosort4 sorting, as 1-based
        % indices into this recording's channels (matching the .bin row order
        % written by toBin, i.e. probe chanMap value + 1). May differ per
        % recording (bad/disconnected sites vary across sessions). Excluded
        % channels are still written to the .bin (n_chan_bin is unchanged); they
        % are simply dropped from the probe's chanMap/xc/yc/kcoords at run time
        % so Kilosort4 ignores them. The recording files and probe .json are never
        % modified. See runKilosort, parseChannelList, formatChannelList.
        ExcludeChannels (1,:) double = double.empty(1,0)

        % Channels left out of the common reference (ArtifactConfig.Reference
        % "car" / "cmr"), 1-based like ExcludeChannels, which are left out
        % too. The reference is still subtracted from them. Filled by
        % suggestReferenceExclude (the noise-floor rule of Ludwig et al.
        % 2009) or set by hand; saved in the manifest. See
        % ReferenceExcludeSource, referenceChannels.
        ReferenceExclude (1,:) double = double.empty(1,0)

        % Where ReferenceExclude came from: "" = never set (the first
        % referenced read suggests it, see prepareReference), "suggested" or
        % "manual".
        ReferenceExcludeSource (1,1) string {mustBeMember(ReferenceExcludeSource, ["" "suggested" "manual"])} = ""

        PythonExe (1,1) string = ""              % python/conda exe path for KS4 spawn
        CondaEnv  (1,1) string = ""              % conda env name (uses `conda run -n` when set)
        Scale     (1,1) double = 1/0.195         % int16 scale (restores native ADC resolution)
        Dtype     (1,1) string {mustBeMember(Dtype, ...
            ["int16","uint16","int32","single","float32"])} = "int16"
        OutputDir (1,1) string = ""              % output dir for .bin / KS4 results (default = Folder)

        % Reader options: the pipeline config's Acquisition section (e.g.
        % OpenEphys.Recordings / RecordNode / Stream). Passed to the reader
        % chosen for Folder; changing it drops the reader, so the next access
        % rebuilds it (call refreshMetadata for fresh metadata).
        ReaderOptions struct = struct()

        % Sorted-output association. "" = auto-discover the Kilosort4/phy
        % results under outputFolder() (see kilosortResultsDir); a non-empty
        % folder pins the association explicitly (e.g. results sorted elsewhere
        % or a phy-curated copy), and nothing replaces it while the folder is
        % not there (sortingMissing). Persisted in the manifest as
        % sorting.source "manual". See sortingResultsDir, readSortedUnits.
        SortingDir (1,1) string = ""

        % Unit identity. NamePattern (parseNameTokens) splits Name into the
        % SubjectID, Date and Time that label this recording's sorted units
        % ("su042_1255_260908T1039"); DatasetKey is the folder relative to the
        % project root ("" = the absolute folder). Both are pushed from
        % EphysProject / the pipeline config. See unitIdentity, nameIdentity.
        NamePattern (1,1) string = EphysDataset.DefaultNamePattern
        DatasetKey  (1,1) string = ""

        % Epsych2 behavioral session file (.mat with Data + Info) associated
        % with this recording. "" = none. Persisted in the manifest under
        % behavior.file. A scan (EphysProject.refresh) fills it from the one
        % Epsych2 file in the recording folder when none is associated (see
        % associateFolderBehavior). See readBehavior, readEpsychSession.
        % Without one, a TDT block's epocs can give the trials (see
        % behaviorSource).
        BehaviorFile (1,1) string = ""

        % How Epsych2 trials are paired with a digital line (pairTrials) and
        % how the digital lines are named: TrialLine, InvertedLines, SignalFs
        % (derived-signal rates for sample columns), LabelField and
        % LineNames. Pushed from the config's Behavior and Signals sections.
        % See defaultTrialConfig.
        TrialConfig struct = EphysDataset.defaultTrialConfig()

        % The reviewed trial pairing, persisted in the manifest under
        % behavior.pairing; struct([]) until one is recorded. Fields: status
        % ("unreviewed" | "approved"), auto_approved (true when approved by
        % autoApproveTrialPairing rather than by a review), cut_trials and
        % cut_intervals ([start end] counts dropped before pairing in order),
        % fingerprint (behavior session + trial line intervals it applies
        % to), trial_line, summary, updated. See pairTrials, setTrialPairing.
        TrialPairing struct = struct([])
        Manifest                                  % optional Manifest for provenance

        % Manually defined artifact periods to blank before writing the .bin.
        % [k x 2] of [tStart tEnd] in seconds, recording-relative (file 1 = t0),
        % set on the Visualize tab. toBin zeros these samples on every channel;
        % the recording files are never modified. See addArtifact /
        % manualArtifactMask.
        ManualArtifacts (:,2) double = zeros(0,2)

        % Automatic artifact-detection configuration applied by toBin (when
        % Enabled) to zero large per-channel amplitude deviations before the
        % .bin is written; never touches the recording files. Set from the Artifacts
        % tab. RmsWindowMs/MergeGapMs/PadMs are in milliseconds (converted to
        % samples with Fs). See detectArtifacts, analyzeArtifacts, toBin and
        % defaultArtifactConfig.
        ArtifactConfig struct = EphysDataset.defaultArtifactConfig()
    end

    properties (SetAccess = protected)
        % The acquisition reader for Folder (an EphysReader subclass such as
        % IntanReader or BinaryReader), chosen by EphysReader.forFolder in
        % discoverFiles. [] when no registered reader recognises the folder.
        Reader = []
    end

    properties (Dependent)
        BinFile     % full path to the .bin (outputFolder/Name.bin, or Name_ks4.bin, see get.BinFile)
        NumSamples  % total amplifier samples across files (sum of PerFile)
    end

    properties (Constant)
        % Dataset manifest schema written by manifestStruct. /2 adds
        % manual_artifacts, sorting and behavior to /1; applyManifest reads
        % both (v2 is a strict superset, so no migration is needed).
        ManifestSchema = "intan-dataset-manifest/2"
        ManifestSchemasAccepted = ["intan-dataset-manifest/1", "intan-dataset-manifest/2"]

        % Default Project.NamePattern: "<subject>_<yyMMdd>_<HHmmss>" (Intan RHX
        % names files from the recording start). Open Ephys session folders use
        % OpenEphysReader.DefaultNamePattern.
        DefaultNamePattern = "{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}"

        % Per-unit notes next to a sort, in phy's custom-label format.
        UnitNotesFile = "cluster_notes.tsv"

        % Sorting refuses to zero more than this share of a recording as
        % artifacts: Kilosort4 then finds no spikes and fails deep inside its
        % template SVD. See silencedFraction.
        MaxSilencedFraction = 0.5

        % A common reference over fewer channels warns (prepareReference):
        % one large unit can then dominate the average (Ludwig et al. 2009).
        MinReferenceChannels = 5

        % Empty file a background Kilosort4 run leaves next to its
        % ks4_status.json once its process exits (see sortRunState).
        SortExitMarker = "ks4_exit.txt"
    end

    methods
        % --- methods defined in separate files in this @-folder ---
        X      = filterContinuous(obj, X, opts)
        [mask, intervals, stats] = detectArtifacts(obj, X, opts)
        [ts, wf, info] = detectSpikes(obj, X, opts)
        [units, info] = readSortedUnits(obj, opts)
        out    = spikesToMat(obj, opts)
        out    = exportChronux(obj, opts)
        out    = exportFieldTrip(obj, opts)
        E      = eventEpochs(obj, opts)
        out    = exportEpochs(obj, opts)
        [trials, info, meta] = readBehavior(obj)
        [src, store] = behaviorSource(obj)
        b      = behaviorStruct(obj, opts)
        out    = behaviorToMat(obj, opts)
        tf     = associateFolderBehavior(obj)
        E      = digitalEvents(obj, opts)
        P      = pairTrials(obj, opts)
        file   = setTrialPairing(obj, P, status, opts)
        [P, tf] = autoApproveTrialPairing(obj, P)
        summary = analyzeArtifacts(obj, opts)
        nl     = noiseLevels(obj, opts)
        X      = applyReference(obj, X)
        r      = referenceTrace(obj, X)
        [bad, info] = suggestReferenceExclude(obj, opts)
        tf     = prepareReference(obj)
        ch     = referenceChannels(obj)
        X      = blankArtifacts(obj, X, mask, opts)
        mask   = manualArtifactMask(obj, nSamp, sampleOffset, Fs, iv)
        addArtifact(obj, t0, t1)
        info   = toBin(obj, opts)
        info   = matrixToBin(obj, X, opts)
        result = runKilosort(obj, opts)
        result = launchSorting(obj, result, opts)
        iv     = artifactIntervals(obj, opts)
        L      = channelLayout(obj, opts)
        [Y, ev, info] = deriveSignals(obj, opts)   % "events" is reserved in classdef
        out    = toMat(obj, opts)

        function obj = EphysDataset(folder, opts)
            %EphysDataset  Construct from a recording folder (any registered reader).
            arguments
                folder (1,1) string = ""
                opts.AutoMetadata (1,1) logical = true
                opts.Name (1,1) string = ""
                opts.ProbeFile (1,1) string = ""
                opts.PythonExe (1,1) string = ""
                opts.CondaEnv  (1,1) string = ""
                opts.Scale     (1,1) double = 1/0.195
                opts.Dtype     (1,1) string = "int16"
                opts.OutputDir (1,1) string = ""
                opts.Manifest  = []
                opts.ReaderOptions struct = struct()
            end

            if folder == ""
                return  % allow empty default object (arrays, preallocation)
            end
            if ~isfolder(folder)
                error('EphysDataset:NoFolder', 'Folder does not exist: %s', folder);
            end

            obj.Folder    = string(folder);
            obj.Name      = opts.Name;
            obj.ProbeFile = opts.ProbeFile;
            obj.PythonExe = opts.PythonExe;
            obj.CondaEnv  = opts.CondaEnv;
            obj.Scale     = opts.Scale;
            obj.Dtype     = opts.Dtype;
            obj.OutputDir = opts.OutputDir;
            obj.ReaderOptions = opts.ReaderOptions;
            if ~isempty(opts.Manifest)
                obj.Manifest = opts.Manifest;
            end

            if obj.Name == ""
                [~, leaf] = fileparts(char(obj.Folder));
                obj.Name = string(leaf);
            end

            obj.discoverFiles();

            if opts.AutoMetadata
                obj.refreshMetadata();
            end
        end

        function set.ReaderOptions(obj, v)
            if ~isequaln(obj.ReaderOptions, v)
                obj.ReaderOptions = v;
                obj.Reader = []; %#ok<MCSUP> rebuilt with the new options on next use
            end
        end

        function discoverFiles(obj)
            %discoverFiles  Pick the reader for Folder and inventory its files.
            %   The registered EphysReader classes (IntanReader, BinaryReader,
            %   OpenEphysReader, ...) are asked in turn; the first that claims
            %   the folder, built with ReaderOptions, becomes obj.Reader and
            %   supplies RecordingFormat / Files / NumFiles.
            obj.Reader = EphysReader.forFolder(obj.Folder, Options=obj.ReaderOptions);
            if isempty(obj.Reader)
                obj.RecordingFormat = "unknown";
                obj.Files = string.empty(1,0);
                obj.NumFiles = 0;
                return
            end
            obj.RecordingFormat = obj.Reader.RecordingFormat;
            obj.Files    = obj.Reader.Files;
            obj.NumFiles = obj.Reader.NumFiles;
            if ~isnat(obj.Reader.AcqDate); obj.AcqDate = obj.Reader.AcqDate; end
        end

        function refreshMetadata(obj)
            %refreshMetadata  Fill header metadata for the recording (no data read).
            %   Re-scans the folder, then asks the reader for Fs, channel names,
            %   duration and the per-file summary (PerFile). Header-only: no
            %   amplifier data is read.
            obj.discoverFiles();
            if isempty(obj.Reader) || obj.NumFiles == 0
                warning('EphysDataset:refreshMetadata:NoFiles', ...
                    'No recording files found in %s', obj.Folder);
                return
            end
            r = obj.Reader;
            r.refreshMetadata();
            obj.Fs           = r.Fs;
            obj.NumChannels  = r.NumChannels;
            obj.ChannelNames = r.ChannelNames;
            obj.NativeNames  = r.NativeNames;
            obj.ChannelNumbers = r.ChannelNumbers;
            obj.DigInNames   = r.DigInNames;
            obj.DigInNativeNames = r.DigInNativeNames;
            obj.Duration     = r.Duration;
            obj.PerFile      = r.PerFile;
            obj.Files        = r.Files;
            obj.NumFiles     = r.NumFiles;
            if ~isnat(r.AcqDate); obj.AcqDate = r.AcqDate; end

            if ~isempty(obj.Manifest) && isa(obj.Manifest, 'Manifest')
                obj.Manifest.add("metadata", "Parsed recording headers", ...
                    struct('folder', obj.Folder, 'reader', string(r.Kind), ...
                    'format', obj.RecordingFormat, 'numFiles', obj.NumFiles, ...
                    'fs', obj.Fs, 'numChannels', obj.NumChannels, ...
                    'duration', obj.Duration));
            end
        end

        function plan = streamPlan(obj, opts)
            %streamPlan  Reader-agnostic list of streaming chunks (see EphysReader).
            %   Each element (kind, name, file, sampleOffset, nSamples) is read
            %   with readChunkUV, so every streaming caller (toBin, artifacts,
            %   detectSpikes, the Visualize tab) shares one loop.
            arguments
                obj (1,1) EphysDataset
                opts.Files (1,:) string = string.empty(1,0)
                opts.MaxChunkSamples (1,1) double = NaN
            end
            if isnan(obj.Fs) || isempty(obj.PerFile)
                obj.refreshMetadata();
            end
            if isempty(obj.Reader)
                plan = repmat(struct('kind', "", 'name', "", 'file', "", ...
                    'sampleOffset', 0, 'nSamples', 0), 1, 0);
                return
            end
            plan = obj.Reader.streamPlan(Files=opts.Files, MaxChunkSamples=opts.MaxChunkSamples);
        end

        function X = readChunkUV(obj, chunk, opts)
            %readChunkUV  One streamPlan chunk as [nSamp x nChan] double microvolts.
            %   The common reference of ArtifactConfig.Reference (CAR / CMR,
            %   see applyReference) is subtracted, so every streaming
            %   consumer - the .bin, artifact detection, noise levels, spike
            %   detection and the app's views - sees the referenced signal.
            %   readChunkUV(CHUNK, Reference=false) returns it as recorded.
            arguments
                obj (1,1) EphysDataset
                chunk (1,1) struct
                opts.Reference (1,1) logical = true
            end
            obj.requireReader('readChunkUV');
            X = obj.Reader.readChunkUV(chunk);
            if opts.Reference
                X = obj.applyReference(X);
            end
        end

        function X = readWindowUV(obj, sampleOffset, nSamp, opts)
            %readWindowUV  Bounded random-access read (readers that support it).
            %   Referenced as readChunkUV is; Reference=false skips it.
            arguments
                obj (1,1) EphysDataset
                sampleOffset (1,1) double
                nSamp (1,1) double
                opts.Reference (1,1) logical = true
            end
            obj.requireReader('readWindowUV');
            X = obj.Reader.readWindowUV(sampleOffset, nSamp);
            if opts.Reference
                X = obj.applyReference(X);
            end
        end

        function tf = supportsRandomAccess(obj)
            %supportsRandomAccess  True when readWindowUV works for this recording.
            tf = ~isempty(obj.Reader) && obj.Reader.supportsRandomAccess();
        end

        function data = readData(obj, opts)
            %readData  The whole recording as the universal data struct.
            %   DATA = ds.readData(Name=Value) reads through the reader with
            %   Files, KeepChannels, IncludeADC, IncludeAux, Concatenate,
            %   ProgressFcn and Precision ("double"|"single"), then names the
            %   digital lines: LabelField ("custom" | "native", default
            %   TrialConfig.LabelField) picks each line's default name and
            %   LineNames ("native=name" entries, default TrialConfig.LineNames)
            %   overrides it (relabelEvents). The struct (amplifier in
            %   microvolts [nSamples x nChan], Fs, t, channel names, events keyed
            %   by the final line names, digInNames = those names, ...) is the
            %   same for every reader; see EphysReader for the field list.
            arguments
                obj (1,1) EphysDataset
                opts.Files (1,:) string = string.empty(1,0)
                opts.KeepChannels (1,:) double {mustBeInteger, mustBePositive} = []
                opts.IncludeADC (1,1) logical = false
                opts.IncludeAux (1,1) logical = false
                opts.Concatenate (1,1) logical = true
                opts.ProgressFcn = []
                opts.Precision (1,1) string {mustBeMember(opts.Precision, ["double", "single"])} = "double"
                opts.LabelField (1,1) string = ""
                opts.LineNames = []
            end
            if obj.NumFiles == 0 || isempty(obj.Reader)
                obj.discoverFiles();
            end
            if isempty(obj.Reader) || obj.NumFiles == 0
                error('EphysDataset:readData:NoFiles', 'No recording files in %s', obj.Folder);
            end
            [labelField, lineNames] = obj.lineNaming(opts.LabelField, opts.LineNames);
            data = obj.Reader.readData(Files=opts.Files, KeepChannels=opts.KeepChannels, ...
                IncludeADC=opts.IncludeADC, IncludeAux=opts.IncludeAux, ...
                Concatenate=opts.Concatenate, ProgressFcn=opts.ProgressFcn, Precision=opts.Precision);
            E = EphysDataset.relabelEvents(struct('events', data.events, ...
                'digInNames', string(data.digInNames), 'digInNativeNames', string(data.digInNativeNames)), ...
                labelField, lineNames);
            data.events = E.events;
            data.digInNames = E.digInNames;
            data.digInNativeNames = E.digInNativeNames;
            data.source = struct('Folder', obj.Folder, 'Name', obj.Name);
        end

        function [labelField, lineNames] = lineNaming(obj, labelField, lineNames)
            %lineNaming  LabelField / LineNames, falling back to TrialConfig ("" / []).
            if labelField == ""
                labelField = string(obj.TrialConfig.LabelField);
            end
            if isnumeric(lineNames)
                lineNames = string.empty(1, 0);
                if isfield(obj.TrialConfig, 'LineNames')
                    lineNames = reshape(string(obj.TrialConfig.LineNames), 1, []);
                end
            end
            lineNames = reshape(string(lineNames), 1, []);
        end

        %% Dependent getters
        function f = get.BinFile(obj)
            % <outputFolder>/<Name>.bin, or <Name>_ks4.bin when <Name>.bin or
            % its <Name>.json sidecar is one of the recording's own files (a
            % binary-format recording keeps its samples in <folder leaf>.bin),
            % so toBin never writes over the recording.
            stem = obj.Name;
            if obj.isRecordingFile(fullfile(obj.outputFolder(), stem + [".bin" ".json"]))
                stem = stem + "_ks4";
            end
            f = fullfile(obj.outputFolder(), stem + ".bin");
        end

        function n = get.NumSamples(obj)
            if isempty(obj.PerFile) || ~isfield(obj.PerFile, 'numAmplifierSamples')
                n = NaN;
                return
            end
            n = sum([obj.PerFile.numAmplifierSamples]);
        end

        function requireReader(obj, what)
            if isempty(obj.Reader)
                obj.discoverFiles();
            end
            if isempty(obj.Reader)
                error('EphysDataset:NoReader', ...
                    '%s: no registered reader recognises %s.', what, obj.Folder);
            end
        end

        function p = outputFolder(obj)
            %outputFolder  Resolve OutputDir, defaulting to the dataset Folder.
            if obj.OutputDir == ""
                p = obj.Folder;
            else
                p = obj.OutputDir;
            end
        end

        function tf = isRecordingFile(obj, files)
            %isRecordingFile  True when any of FILES (full paths) is one of the recording's own files.
            %   The reader's Files, below Folder. See BinFile.
            tf = false;
            if isempty(obj.Files) || obj.Folder == ""; return; end
            own = EphysDataset.pathKey(fullfile(obj.Folder, obj.Files));
            tf = any(ismember(EphysDataset.pathKey(files), own));
        end

        function tf = isOwnSource(obj, folder)
            %isOwnSource  Whether FOLDER, the source folder an output recorded, is this recording's.
            %   TF = ds.isOwnSource(FOLDER) for the sourceFolder in an output's
            %   provenance (conversion / export) or the source_folder of a .bin
            %   sidecar: true when it is Folder, or ends with the dataset's
            %   DatasetKey (its folder below the project root), so outputs still
            %   count after the project moved to another drive or root. Without
            %   a key (no project, or the root itself) the folder's name is
            %   compared. False for another recording's folder: for the dataset
            %   mouse2/rec, the outputs of mouse1/rec, whose files have the same
            %   names. See DatasetOutputs.
            f = EphysDataset.pathKey(folder);
            if f == EphysDataset.pathKey(obj.Folder)
                tf = true;
                return
            end
            key = EphysDataset.pathKey(obj.DatasetKey);
            if key == "" || key == "." || startsWith(key, "/") || ~isempty(regexp(key, '^[a-zA-Z]:', 'once'))
                key = string(regexp(char(EphysDataset.pathKey(obj.Folder)), '[^/]+$', 'match', 'once'));
            end
            tf = strlength(key) > 0 && (f == key || endsWith(f, "/" + key));
        end

        function dt = tracker(obj)
            %tracker  A DatasetTracker inventory of this dataset's artifacts.
            %   Scans outputFolder() (where toBin / runKilosort write, and which
            %   defaults to Folder) so callers get a uniform view of this
            %   dataset's *.bin, probe maps and kilosort4 runs without
            %   re-implementing the scans. Returns a point-in-time snapshot; call
            %   again (or dt.refresh) after writing new outputs.
            %
            %   See also DATASETTRACKER, EphysDataset.toBin, EphysDataset.runKilosort.
            out = obj.outputFolder();
            if out == "" || ~isfolder(out)
                % Output folder not created yet (e.g. a configured OutputRoot
                % whose per-dataset subfolder is written only by toBin /
                % runKilosort). No outputs exist, so return an empty inventory
                % rather than letting the DatasetTracker constructor error.
                dt = DatasetTracker();
                dt.Name = obj.Name;
                return
            end
            dt = DatasetTracker(out, Name=obj.Name, ReaderOptions=obj.ReaderOptions);
        end

        function o = outputs(obj, varargin)
            %outputs  A DatasetOutputs over this dataset's processed files.
            %   OUT = ds.outputs(Name=Value) finds the extract, spikes, behavior
            %   and toolbox export files, the sorted units and the manifest
            %   under outputFolder() and Folder, and loads each one when its
            %   property is read (FT = OUT.FieldTrip). Options are those of
            %   DatasetOutputs (SearchDirs, Recursive, CacheData, AutoRefresh).
            %
            %   See also DATASETOUTPUTS, EphysPipeline.outputsFor.
            o = DatasetOutputs(obj, varargin{:});
        end

        %% --- Kilosort4 output location (cheap, no scan) ------------------
        function p = kilosortDir(obj)
            %kilosortDir  Default Kilosort4 run folder (outputFolder/kilosort4).
            %   This is the folder runKilosort writes the run files and the
            %   phy/npy output into.
            p = fullfile(char(obj.outputFolder()), 'kilosort4');
        end

        function p = kilosortResultsDir(obj)
            %kilosortResultsDir  Folder that actually holds the KS4 phy output.
            %   Kilosort4's files (params.py, spike_*.npy, templates.npy,
            %   cluster_*.tsv) sit directly in kilosortDir(), so this is
            %   kilosortDir(); phy, the Review tab and hasPhyOutput go through
            %   it.
            p = obj.kilosortDir();
        end

        function p = sortingResultsDir(obj)
            %sortingResultsDir  Folder holding the sorted units for this dataset.
            %   Returns SortingDir when it is set (an explicit association, e.g.
            %   a phy-curated copy or results sorted on another machine), else
            %   the auto-discovered kilosortResultsDir(). Every consumer of
            %   sorted output (Review tab, phy launch, readSortedUnits,
            %   ChronuxDataset.spikes) goes through this accessor. A SortingDir
            %   that is not there is still returned (see sortingMissing).
            if obj.SortingDir ~= ""
                p = char(obj.SortingDir);
            else
                p = obj.kilosortResultsDir();
            end
        end

        function tf = sortingMissing(obj)
            %sortingMissing  True when the hand-picked SortingDir holds no sorted output now.
            %   The association is kept (e.g. a phy-curated copy on a disk
            %   that is not connected): the steps that read sorted units
            %   report the missing folder instead of using another sort.
            tf = obj.SortingDir ~= "" && ~isfile(fullfile(obj.SortingDir, 'params.py'));
        end

        function id = unitIdentity(obj)
            %unitIdentity  Subject, recording start and key labelling this dataset's units.
            %   ID = ds.unitIdentity() is EphysDataset.nameIdentity(Name, NamePattern)
            %   (subject, recordingStart, labelSuffix) plus datasetKey (DatasetKey, else
            %   the absolute folder with forward slashes). Throws
            %   EphysDataset:unitIdentity:Pattern | :NoMatch | :Subject | :DateTime when
            %   the name cannot label units, so no unit is ever written without the
            %   recording it came from.
            id = EphysDataset.nameIdentity(obj.Name, obj.NamePattern);
            if ~id.ok
                switch id.reason
                    case "pattern";  what = "Pattern";
                    case "subject";  what = "Subject";
                    case "datetime"; what = "DateTime";
                    otherwise;       what = "NoMatch";
                end
                error("EphysDataset:unitIdentity:" + what, ...
                    'Dataset "%s": %s Rename the recording folder or change Project.NamePattern.', ...
                    obj.Name, id.message);
            end
            id.datasetKey = obj.DatasetKey;
            if id.datasetKey == ""
                id.datasetKey = EphysProject.normalizeKey(obj.Folder);
            end
            id = rmfield(id, ["ok" "reason" "message"]);
        end

        function tf = hasPhyOutput(obj)
            %hasPhyOutput  True when the sorting results dir holds a params.py
            %   (what phy needs to open). Cheap; see sortingResultsDir. For a
            %   full inventory use tracker().
            tf = isfile(fullfile(obj.sortingResultsDir(), 'params.py'));
        end

        function tf = hasKilosortResults(obj)
            %hasKilosortResults  True when the sorting results dir holds spike
            %   output (spike_clusters.npy). Cheap; see sortingResultsDir.
            tf = isfile(fullfile(obj.sortingResultsDir(), 'spike_clusters.npy'));
        end

        %% --- Dataset manifest (JSON state file in the dataset folder) ----
        function f = manifestFile(obj)
            %manifestFile  Path to this dataset's JSON manifest (in the folder).
            f = fullfile(obj.Folder, obj.Name + "_manifest.json");
        end

        function m = manifestStruct(obj)
            %manifestStruct  Snapshot of this dataset (metadata, probe, channel
            %   exclusions, .bin and Kilosort4 output state) ready for jsonencode.
            %   The kilosort block describes the run in kilosortDir()
            %   (DatasetTracker.kilosortRunAt, as the GUI tables do). The
            %   associations (probe, sorting, behavior) are written as recorded,
            %   with "exists" saying whether their file or folder is there now.
            m = struct();
            m.schema           = EphysDataset.ManifestSchema;
            m.name             = obj.Name;
            m.folder           = obj.Folder;
            m.recording_format = obj.RecordingFormat;
            m.reader           = "";
            if ~isempty(obj.Reader); m.reader = string(obj.Reader.Kind); end
            m.updated          = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

            acq = "";
            if ~isnat(obj.AcqDate)
                acq = string(datetime(obj.AcqDate, 'Format', 'yyyy-MM-dd HH:mm:ss'));
            end
            m.metadata = struct( ...
                'fs', obj.Fs, 'num_channels', obj.NumChannels, ...
                'duration_s', obj.Duration, 'num_files', obj.NumFiles, ...
                'acq_date', acq, 'files', obj.Files);

            probe = struct('file', obj.ProbeFile, 'exists', false, 'num_channels', NaN, ...
                'num_shanks', NaN, 'depth_um', NaN, 'notes', "");
            if obj.ProbeFile ~= "" && isfile(obj.ProbeFile)
                pm = DatasetTracker.probeMeta(DatasetTracker.readJson(obj.ProbeFile));
                probe.exists       = true;
                probe.num_channels = pm.nChan;
                probe.num_shanks   = pm.nShank;
                probe.depth_um     = pm.depth;
                probe.notes        = pm.notes;
            end
            m.probe = probe;

            m.exclude_channels = EphysDataset.formatChannelList(obj.ExcludeChannels);

            % Channels left out of the common reference, and whether they
            % were suggested or set by hand ("" = never set).
            m.reference_exclude = struct( ...
                'channels', EphysDataset.formatChannelList(obj.ReferenceExclude), ...
                'source', obj.ReferenceExcludeSource);

            % Manual artifact periods ([k x 2] seconds, recording-relative) so
            % periods marked on the Visualize tab survive a rescan / restart.
            ma = obj.ManualArtifacts;
            if isempty(ma); ma = zeros(0, 2); end
            m.manual_artifacts = ma;

            m.bin = struct('file', obj.BinFile, 'exists', isfile(obj.BinFile));

            ks = struct('has_results', false, 'results_dir', "", ...
                'num_units', NaN, 'state', "");
            run = DatasetTracker.kilosortRunAt(obj.kilosortDir());
            if ~isempty(run)
                ks.has_results = run.HasResults;
                ks.results_dir = run.Dir;
                ks.num_units   = run.NumUnits;
                ks.state       = run.State;
            end
            m.kilosort = ks;

            % Sorted-output association (see sortingResultsDir / SortingDir).
            m.sorting = obj.sortingStruct();

            % Epsych2 behavioral session association (see BehaviorFile).
            m.behavior = obj.behaviorManifest();
        end

        function tf = writeManifest(obj)
            %writeManifest  Write/refresh this dataset's JSON manifest on disk.
            %   Called by the app whenever metadata, the assigned probe/exclusions,
            %   or Kilosort4 output change. TF is true when it was written.
            %   A manifest file this code cannot read (not JSON, or an unknown
            %   schema such as a newer version's) is never replaced: it warns
            %   (EphysDataset:writeManifest:Kept) and leaves the file for you to
            %   fix or delete. Other failures warn too but never interrupt the
            %   caller (the manifest is a convenience, not the source of truth).
            tf = false;
            if obj.Folder == "" || ~isfolder(obj.Folder); return; end
            f = obj.manifestFile();
            [~, why] = EphysDataset.readManifest(f);
            if why ~= "" && why ~= "missing"
                warning('EphysDataset:writeManifest:Kept', ...
                    'Not writing the manifest of %s: %s cannot be read (%s). It is left as it is; fix or delete it.', ...
                    obj.Name, f, why);
                return
            end
            try
                writeJsonFile(f, obj.manifestStruct());
                tf = true;
            catch ME
                warning('EphysDataset:writeManifest:Failed', ...
                    'Could not write manifest for %s: %s', obj.Name, ME.message);
            end
        end

        function [tf, why] = applyManifest(obj)
            %applyManifest  Restore the editable per-dataset state from the
            %   on-disk manifest (if present) so a re-scan recovers prior work:
            %   probe file, channel exclusions, manual artifact periods, an
            %   explicit ("manual") sorting folder and the behavior file. The
            %   probe, sorting folder and behavior file are restored as
            %   recorded even while they are not there (an unplugged disk, a
            %   share that is down): the steps then report them missing rather
            %   than use something else, and the next writeManifest keeps them.
            %   TF is true when a manifest was found and read. WHY is "" then,
            %   and when there is none; otherwise it says why the manifest was
            %   ignored ("not valid JSON", "unknown schema ..."), with a warning
            %   (EphysDataset:applyManifest:Unreadable / :Schema). Header
            %   metadata is always re-parsed. Schema /1 (probe + exclusions
            %   only) and /2 are accepted.
            tf = false;
            f = obj.manifestFile();
            [m, why] = EphysDataset.readManifest(f);
            if why == "missing"
                why = "";
                return
            elseif startsWith(why, "unknown schema")
                warning('EphysDataset:applyManifest:Schema', 'Ignoring manifest %s: %s.', f, why);
                return
            elseif why ~= ""
                warning('EphysDataset:applyManifest:Unreadable', 'Ignoring manifest %s: %s.', f, why);
                return
            end
            if isfield(m, 'probe') && isstruct(m.probe) && isfield(m.probe, 'file')
                pf = string(m.probe.file);
                if isscalar(pf) && pf ~= ""; obj.ProbeFile = pf; end
            end
            if isfield(m, 'exclude_channels')
                obj.ExcludeChannels = EphysDataset.parseChannelList(string(m.exclude_channels));
            end
            if isfield(m, 'reference_exclude') && isstruct(m.reference_exclude) ...
                    && all(isfield(m.reference_exclude, {'channels', 'source'})) ...
                    && ismember(string(m.reference_exclude.source), ["" "suggested" "manual"])
                obj.ReferenceExclude = EphysDataset.parseChannelList(string(m.reference_exclude.channels));
                obj.ReferenceExcludeSource = string(m.reference_exclude.source);
            end
            if isfield(m, 'manual_artifacts')
                ma = m.manual_artifacts;
                if isempty(ma)
                    ma = zeros(0, 2);
                elseif isnumeric(ma) && isvector(ma) && numel(ma) == 2
                    ma = double(ma(:)).';           % jsondecode collapsed 1x2
                elseif isnumeric(ma)
                    ma = double(ma);
                else
                    ma = zeros(0, 2);
                end
                if size(ma, 2) == 2
                    obj.ManualArtifacts = ma;
                end
            end
            if isfield(m, 'sorting') && isstruct(m.sorting) ...
                    && isfield(m.sorting, 'source') && isfield(m.sorting, 'results_dir')
                if string(m.sorting.source) == "manual"
                    sd = string(m.sorting.results_dir);
                    if isscalar(sd) && sd ~= ""; obj.SortingDir = sd; end
                end
            end
            if isfield(m, 'behavior') && isstruct(m.behavior) && isfield(m.behavior, 'file')
                bf = string(m.behavior.file);
                if isscalar(bf) && bf ~= ""; obj.BehaviorFile = bf; end
            end
            if isfield(m, 'behavior') && isstruct(m.behavior) && isfield(m.behavior, 'pairing')
                obj.TrialPairing = EphysDataset.normalizeTrialPairing(m.behavior.pairing);
            end
            tf = true;
        end

        function s = behaviorManifest(obj)
            %behaviorManifest  Manifest block for the associated Epsych2 session.
            %   file (as recorded, even while it is not there), exists,
            %   subject, start_time, n_trials (only Info is read; any read
            %   failure leaves the summary fields empty) and pairing (the
            %   recorded TrialPairing, [] when none).
            s = struct('file', obj.BehaviorFile, 'exists', false, 'subject', "", 'start_time', "", ...
                'n_trials', NaN, 'pairing', []);
            if ~isempty(obj.TrialPairing); s.pairing = obj.TrialPairing; end
            if obj.BehaviorFile == "" || ~isfile(obj.BehaviorFile); return; end
            s.exists = true;
            try
                meta = epsychSessionMeta(obj.BehaviorFile);
                s.subject  = meta.subject;
                s.n_trials = meta.nTrials;
                if ~isnat(meta.startTime)
                    s.start_time = string(datetime(meta.startTime, 'Format', 'yyyy-MM-dd HH:mm:ss'));
                end
            catch
            end
        end

        function s = sortingStruct(obj)
            %sortingStruct  Manifest block describing the sorted-output association.
            %   results_dir  SortingDir when set (as recorded, even while it is
            %                not there), else the kilosort4 folder once it holds
            %                params.py ("" before)
            %   source       "manual" when SortingDir is set, else "auto"
            %   exists       true when results_dir holds params.py
            %   curated      true when phy saved the unit labels there
            %                (EphysDataset.phyCurated)
            %   num_units    rows of the label table (NaN when none)
            %   updated      modification time of spike_clusters.npy ("" if none)
            s = struct('results_dir', "", 'source', "auto", 'exists', false, 'curated', false, ...
                'num_units', NaN, 'updated', "");
            if obj.SortingDir ~= ""
                s.source = "manual";
                s.results_dir = obj.SortingDir;
            end
            p = obj.sortingResultsDir();
            if ~isfile(fullfile(p, 'params.py')); return; end
            s.results_dir = string(p);
            s.exists = true;
            s.curated = EphysDataset.phyCurated(p);
            grp = fullfile(p, 'cluster_group.tsv');
            if ~s.curated && isfile(fullfile(p, 'cluster_KSLabel.tsv'))
                grp = fullfile(p, 'cluster_KSLabel.tsv');
            end
            if isfile(grp)
                try
                    lines = splitlines(strtrim(string(fileread(grp))));
                    s.num_units = max(numel(lines) - 1, 0);   % minus header
                catch
                end
            end
            spk = dir(fullfile(p, 'spike_clusters.npy'));
            if ~isempty(spk)
                s.updated = string(datetime(spk.datenum, 'ConvertFrom', 'datenum', ...
                    'Format', 'yyyy-MM-dd HH:mm:ss'));
            end
        end
    end

    methods (Static)
        % --- static methods defined in separate files in this @-folder ---
        [stopped, message] = stopSortRun(statusFile)

        function fmt = detectFormat(folder, opts)
            %detectFormat  RecordingFormat of the reader that claims FOLDER.
            %   "traditional" | "one-file-per-signal" | "one-file-per-channel"
            %   (IntanReader), "binary" (BinaryReader), "openephys-binary" |
            %   "openephys-legacy" | "openephys-nwb" (OpenEphysReader), "tdt"
            %   (TDTReader), or "unknown" when no registered reader recognises
            %   the folder.
            %   ReaderOptions= passes the reader options.
            arguments
                folder (1,1) string
                opts.ReaderOptions struct = struct()
            end
            r = EphysReader.forFolder(folder, Options=opts.ReaderOptions);
            if isempty(r)
                fmt = "unknown";
            else
                fmt = r.RecordingFormat;
            end
        end

        function cfg = defaultArtifactConfig()
            %defaultArtifactConfig  Default automatic artifact-detection settings.
            %   Used to initialize ArtifactConfig. RmsWindowMs/MergeGapMs/PadMs
            %   are in milliseconds (converted to samples with Fs at run time);
            %   RmsWindowMs NaN means "auto" (~1 ms).
            %   Filter/FilterType/FilterCutoff/FilterOrder make the detector run
            %   on a filtered view of each chunk (e.g. high-pass 300 Hz) instead
            %   of broadband; they apply everywhere the config is consulted
            %   (artifactIntervals, analyzeArtifacts, the Visualize overlay).
            %   Fill/NoiseBandHz/NoiseSeed say how the flagged periods are
            %   erased rather than which ones they are: by default with
            %   Gaussian noise matched to the recording's own noise level
            %   (noiseLevels), because Kilosort4 reads a block of zeros across
            %   every channel as a signal discontinuity - its whitening,
            %   threshold and drift estimates all assume continuous noise.
            %   Reference/ReferenceBadLow/ReferenceBadHigh set the common
            %   reference subtracted from every read before anything else
            %   (applyReference): "none", "car" (mean) or "cmr" (median) of
            %   the channels whose noise floor lies within [Low High] times
            %   the mean across channels (suggestReferenceExclude).
            cfg = struct( ...
                'Reference',    "none", ...  % "none" | "car" (mean) | "cmr" (median)
                'ReferenceBadLow',  0.3, ... % x median noise: quieter channels are left out of the reference
                'ReferenceBadHigh', 2, ...   % x median noise: noisier channels are left out of the reference
                'Enabled',      false, ...   % toBin blanks only when true
                'Method',       "rms", ...   % running-RMS amplitude deviation
                'Threshold',    9, ...       % robust SDs above per-channel baseline
                'RmsWindowMs',  NaN, ...     % ms; NaN = auto (~1 ms)
                'MergeGapMs',   0, ...       % ms; stitch gaps <= this
                'MinChannels',  2, ...       % channels exceeding simultaneously
                'PadMs',        0, ...       % ms to expand each flagged run
                'Filter',       false, ...   % detect on a filtered view
                'FilterType',   "highpass", ...
                'FilterCutoff', 300, ...     % Hz (scalar, or [lo hi] for bandpass)
                'FilterOrder',  4, ...
                'Fill',         "noise", ... % "noise" (Gaussian) | "zero"
                'NoiseBandHz',  300, ...     % Hz; band the noise level is measured in (0 = broadband)
                'NoiseSeed',    0);          % RNG seed for the fill (NaN = a new draw each run)
        end

        function cfg = defaultTrialConfig()
            %defaultTrialConfig  Default trial-pairing and line-naming settings.
            %   TrialLine       digital line held high during each trial
            %   InvertedLines   lines with inverted polarity: on while low,
            %                   onset = falling edge (default none)
            %   SignalFs        struct of derived-signal rates (e.g. LFP: 1000)
            %                   for per-signal sample columns
            %   LabelField      "custom" | "native": each line's default name
            %   LineNames       "native=name" entries renaming lines (e.g.
            %                   "TTL4=InTrial"); see relabelEvents
            %   TrialLine and InvertedLines use the final names.
            cfg = struct('TrialLine', "InTrial", 'InvertedLines', string.empty(1,0), ...
                'SignalFs', struct(), 'LabelField', "custom", 'LineNames', string.empty(1,0));
        end

        function p = normalizeTrialPairing(p)
            %normalizeTrialPairing  A TrialPairing record from a manifest block.
            %   Returns struct([]) for anything that is not a usable record
            %   (status, fingerprint and the two [start end] cut counts).
            if isempty(p) || ~isstruct(p) || ~isscalar(p) ...
                    || ~all(isfield(p, {'status', 'fingerprint', 'cut_trials', 'cut_intervals'}))
                p = struct([]);
                return
            end
            cuts = {p.cut_trials, p.cut_intervals};       % each [1x2] non-negative integers
            for k = 1:2
                v = cuts{k};
                if ~isnumeric(v) || numel(v) ~= 2
                    p = struct([]);
                    return
                end
                v = double(reshape(v, 1, 2));
                if ~all(isfinite(v) & v >= 0 & v == round(v))
                    p = struct([]);
                    return
                end
                cuts{k} = v;
            end
            q = struct('status', string(p.status), 'auto_approved', false, ...
                'cut_trials', cuts{1}, 'cut_intervals', cuts{2}, ...
                'fingerprint', string(p.fingerprint), 'trial_line', "", 'summary', "", 'updated', "");
            if isfield(p, 'auto_approved') && isscalar(p.auto_approved)
                q.auto_approved = logical(p.auto_approved) && q.status == "approved";
            end
            for f = ["trial_line" "summary" "updated"]
                if isfield(p, f) && ~isempty(p.(f)); q.(f) = string(p.(f)); end
            end
            p = q;
        end

        function cfg = normalizeArtifactConfig(cfg)
            %normalizeArtifactConfig  Fill missing fields from the defaults.
            %   Tolerates partial/stale ArtifactConfig structs (e.g. a project
            %   saved before a field such as RmsWindowMs was added) by merging
            %   the given struct onto defaultArtifactConfig; unknown extra
            %   fields are dropped.
            def = EphysDataset.defaultArtifactConfig();
            if isempty(cfg) || ~isstruct(cfg)
                cfg = def;
                return
            end
            fn = fieldnames(def);
            for k = 1:numel(fn)
                if isfield(cfg, fn{k})
                    def.(fn{k}) = cfg.(fn{k});
                end
            end
            cfg = def;
        end

        function [m, why] = readManifest(file)
            %readManifest  A dataset manifest decoded, or why it cannot be used.
            %   [M, WHY] = EphysDataset.readManifest(FILE): WHY is "" when FILE
            %   holds a manifest of an accepted schema (ManifestSchemasAccepted)
            %   and M is its struct; else M is [] and WHY is "missing" (no
            %   FILE), "not valid JSON" or "unknown schema ""<schema>""".
            m = [];
            if ~isfile(file)
                why = "missing";
                return
            end
            s = readJsonFile(file, ErrorOnFail=false);
            if isempty(s) || ~isstruct(s) || ~isscalar(s)
                why = "not valid JSON";
                return
            end
            schema = "";
            if isfield(s, 'schema') && (ischar(s.schema) || isstring(s.schema)) && isscalar(string(s.schema))
                schema = string(s.schema);
            end
            if ~ismember(schema, EphysDataset.ManifestSchemasAccepted)
                why = "unknown schema """ + schema + """";
                return
            end
            m = s;
            why = "";
        end

        function tf = phyCurated(resultsDir)
            %phyCurated  True when phy saved the unit labels in RESULTSDIR.
            %   phy writes cluster_group.tsv with the header
            %   "cluster_id<TAB>group". Kilosort4 (4.1.7) also writes a
            %   cluster_group.tsv on every run - a copy of cluster_KSLabel.tsv
            %   that keeps the "KSLabel" header - so only the header tells a
            %   curated sort. Only the first line is read.
            tf = false;
            fid = fopen(fullfile(char(resultsDir), 'cluster_group.tsv'), 'r');
            if fid < 0; return; end
            head = fgetl(fid);
            fclose(fid);
            if ~ischar(head); return; end
            cols = strtrim(split(string(head), char(9)));
            tf = numel(cols) >= 2 && strcmpi(cols(2), "group");
        end

        function k = pathKey(p)
            %pathKey  Paths as comparable keys: "/" separators, no trailing
            %   separator, lower case on Windows (whose paths ignore case).
            k = EphysProject.normalizeKey(p);
            if ispc; k = lower(k); end
        end

        function iv = mergeIntervals(iv)
            %mergeIntervals  Sorted union of [k x 2] half-open second intervals.
            %   Overlapping or touching periods ([a b) and [b c)) become one;
            %   empty ones are dropped. Returns zeros(0, 2) for none. The rule
            %   of artifactIntervals, for callers that merge cached automatic
            %   detections with the manual periods.
            if isempty(iv)
                iv = zeros(0, 2);
                return
            end
            iv = iv(iv(:, 2) > iv(:, 1), :);
            if isempty(iv)
                iv = zeros(0, 2);
                return
            end
            iv = sortrows(iv, 1);
            out = iv(1, :);
            for k = 2:size(iv, 1)
                if iv(k, 1) <= out(end, 2)
                    out(end, 2) = max(out(end, 2), iv(k, 2));
                else
                    out(end+1, :) = iv(k, :); %#ok<AGROW>
                end
            end
            iv = out;
        end

        function rows = artifactSamples(iv, Fs, nSamp)
            %artifactSamples  The samples [k x 2] artifact periods replace.
            %   ROWS = EphysDataset.artifactSamples(IV, FS, NSAMP) returns the
            %   [first last] 1-based rows of a recording at FS (NSAMP rows)
            %   inside the [k x 2] second periods IV, merged where they touch.
            %   A period [a b) covers 0-based samples round(a*FS) ..
            %   round(b*FS) - 1, the samples a detectArtifacts interval came
            %   from, so every route that erases or rejects them (the .bin,
            %   the derived signals, spike rejection) takes the same samples.
            %   A reversed period (b < a) is empty, as in mergeIntervals.
            %   See also manualArtifactMask, intervalRows.
            rows = zeros(0, 2);
            if isempty(iv) || nSamp < 1; return; end
            iv = iv(iv(:, 2) > iv(:, 1), :);
            r = [max(1, round(iv(:, 1) * Fs) + 1), min(nSamp, round(iv(:, 2) * Fs))];
            rows = mergeRows(r(r(:, 2) >= r(:, 1), :));
        end

        function rows = intervalRows(iv, Fs, nRows)
            %intervalRows  The rows of a signal at any rate that periods touch.
            %   ROWS = EphysDataset.intervalRows(IV, FS, NROWS) returns the
            %   [first last] 1-based rows of a signal at FS (row r at
            %   (r-1)/FS, NROWS rows) whose sample period [(r-1)/FS, r/FS)
            %   overlaps a [k x 2] second period of IV, merged where they
            %   touch. At the recording rate that is artifactSamples' rows for
            %   periods on the sample grid; at a derived rate every row the
            %   period falls in is kept, so a period shorter than one row is
            %   never lost.
            rows = zeros(0, 2);
            if isempty(iv) || nRows < 1; return; end
            tol = 1e-6;                  % rows, for times one rounding off a row
            r = [max(1, floor(iv(:, 1) * Fs + tol) + 1), min(nRows, ceil(iv(:, 2) * Fs - tol))];
            rows = mergeRows(r(r(:, 2) >= r(:, 1), :));
        end

        function tf = overlapsIntervals(tStart, tStop, iv)
            %overlapsIntervals  Which [tStart tStop] windows touch a period.
            %   TF = EphysDataset.overlapsIntervals(TSTART, TSTOP, IV) is true
            %   for each window (closed, seconds) that overlaps one of the
            %   half-open [k x 2] second periods IV: a <= tStop and b > tStart.
            %   Windows and periods on the same clock (the continuous one,
            %   row r at (r-1)/Fs, for artifact periods). The edges are
            %   compared 1 ns apart, far below a sample, so a window edge
            %   that should equal a period edge but is one rounding off it
            %   (0.3 - 0.1 vs 0.2) counts as equal.
            tf = false(size(tStart));
            iv = EphysDataset.mergeIntervals(iv);
            if isempty(iv) || isempty(tStart); return; end
            tol = 1e-9;
            % The only period that can overlap is the last one starting at or
            % before tStop (the merged periods are disjoint and sorted).
            j = discretize(tStop + tol, [iv(:, 1); Inf]);
            has = ~isnan(j);
            tf(has) = reshape(iv(j(has), 2), [], 1) > reshape(tStart(has), [], 1) + tol;
        end

        [units, info] = readPhyUnits(resultsDir, opts)
        [W, info] = readPhyWaveforms(resultsDir, samples, opts)
        id = nameIdentity(name, pattern)
        E = relabelEvents(E, labelField, lineNames)
        [natives, names] = parseLineNames(lineNames)
        [ids, notes, file] = readUnitNotes(resultsDir)
        file = writeUnitNotes(resultsDir, unitIds, notes)

        function files = signalFiles(file, types)
            %signalFiles  Per-signal-type file names derived from one base file.
            %   FILES = EphysDataset.signalFiles("D:\out\rec_extract.mat", ["LFP" "MUA"])
            %   returns ["D:\out\rec_extract_LFP.mat" "D:\out\rec_extract_MUA.mat"],
            %   the names toMat(SeparateFiles=true) writes.
            arguments
                file (1,1) string
                types (1,:) string
            end
            [p, base, ext] = fileparts(file);
            if ext == ""; ext = ".mat"; end
            files = strings(1, numel(types));
            for k = 1:numel(types)
                files(k) = string(fullfile(p, base + "_" + types(k) + ext));
            end
        end

        function files = recordedSignalFiles(files)
            %recordedSignalFiles  Signal files minus an _AUX file that was not written.
            %   toMat writes <base>_AUX.mat only when the recording has aux
            %   (accelerometer) inputs, so a missing one is not a missing
            %   extract. FILES = EphysDataset.recordedSignalFiles(FILES) drops
            %   it; every other file is kept whether it exists or not.
            arguments
                files (1,:) string
            end
            files = files(isfile(files) | ~endsWith(files, "_AUX.mat", 'IgnoreCase', true));
        end

        function saveAtomically(outFile, S, matVersion)
            %saveAtomically  save() the fields of S to a temp file, verify, rename.
            %   EphysDataset.saveAtomically(file, S, "-v7.3") writes
            %   "~<name>.partial.mat" next to FILE and renames it into place only
            %   after save() finished without warnings and every field of S is
            %   confirmed present, so a failed or cancelled run never leaves a
            %   complete-looking file behind. (save() reports a variable it could
            %   not store, e.g. over 2 GB with -v7, as a warning and omits it;
            %   that is treated as a failure here.) Shared by toMat, spikesToMat
            %   and the exporters (export<Format>).
            arguments
                outFile (1,1) string
                S (1,1) struct
                matVersion (1,1) string {mustBeMember(matVersion, ["-v7.3", "-v7"])} = "-v7.3"
            end
            [outDir, base] = fileparts(outFile);
            if strlength(outDir) > 0 && ~isfolder(outDir)
                [ok, msg] = mkdir(outDir);
                if ~ok
                    error('EphysDataset:saveAtomically:MkdirFailed', ...
                        'Could not create %s: %s', outDir, msg);
                end
            end
            tmp = fullfile(outDir, "~" + base + ".partial.mat");
            if isfile(tmp); delete(tmp); end
            lastwarn('');
            try
                save(tmp, '-struct', 'S', char(matVersion));
                [wmsg, wid] = lastwarn;
                if ~isempty(wmsg)
                    error('EphysDataset:saveAtomically:SaveWarning', ...
                        'save() raised a warning, so the output was discarded (%s): %s', wid, wmsg);
                end
                w = whos('-file', tmp);
                missing = setdiff(fieldnames(S), {w.name});
                if ~isempty(missing)
                    error('EphysDataset:saveAtomically:SaveIncomplete', ...
                        'Saved file is missing variable(s): %s', strjoin(missing, ', '));
                end
                [ok, msg] = movefile(tmp, outFile, 'f');
                if ~ok
                    error('EphysDataset:saveAtomically:MoveFailed', ...
                        'Could not rename %s to %s: %s', tmp, outFile, msg);
                end
            catch ME
                if isfile(tmp); delete(tmp); end
                rethrow(ME);
            end
        end

        function p = resolvePhyDir(folder)
            %resolvePhyDir  Folder that actually holds params.py under FOLDER.
            %   Accepts the results folder itself, a kilosort4 run folder or a
            %   dataset output folder (Kilosort4 writes the phy output into
            %   kilosort4/ directly). Returns FOLDER unchanged when neither
            %   holds a params.py.
            folder = char(folder);
            if isfile(fullfile(folder, 'params.py'))
                p = folder;
                return
            end
            if isfile(fullfile(folder, 'kilosort4', 'params.py'))
                p = fullfile(folder, 'kilosort4');
            else
                p = folder;
            end
        end

        function [useFilter, fType, fCut, fOrd] = resolveFilterOptions(cfg, filt, fType, fCut, fOrd)
            %resolveFilterOptions  Per-call filter options falling back to a config.
            %   Empty / "" / NaN inputs take the ArtifactConfig values, so a
            %   config with Filter=true is honored unless the caller overrides.
            cfg = EphysDataset.normalizeArtifactConfig(cfg);
            if isempty(filt);   useFilter = logical(cfg.Filter); else; useFilter = logical(filt); end
            if fType == "";    fType = string(cfg.FilterType);   end
            if isempty(fCut);   fCut  = cfg.FilterCutoff;          end
            if isnan(fOrd);     fOrd  = cfg.FilterOrder;           end
            if useFilter && (isempty(fCut) || any(~isfinite(fCut)) || any(fCut <= 0))
                error('EphysDataset:resolveFilterOptions:Cutoff', ...
                    'FilterCutoff must be positive and finite when Filter is enabled.');
            end
            if useFilter && (~isfinite(fOrd) || fOrd < 1 || fOrd ~= round(fOrd))
                error('EphysDataset:resolveFilterOptions:Order', ...
                    'FilterOrder must be a positive integer when Filter is enabled.');
            end
        end

        function [share, covered] = silencedFraction(iv, duration)
            %silencedFraction  Share of a recording covered by artifact intervals.
            %   [SHARE, COVERED] = EphysDataset.silencedFraction(IV, DURATION)
            %   clips the [k x 2] second intervals IV to [0 DURATION] and
            %   returns the covered seconds of their union and that as a share
            %   of DURATION (NaN when DURATION is unknown).
            covered = 0;
            if ~isempty(iv)
                iv = sortrows([max(iv(:, 1), 0), min(iv(:, 2), duration)], 1);
                reach = 0;
                for k = 1:size(iv, 1)
                    a = max(iv(k, 1), reach);
                    if iv(k, 2) > a
                        covered = covered + iv(k, 2) - a;
                        reach = iv(k, 2);
                    end
                end
            end
            share = NaN;
            if duration > 0; share = covered / duration; end
        end

        function [state, message] = sortRunState(statusFile)
            %sortRunState  How a background Kilosort4 run stands.
            %   [STATE, MESSAGE] = EphysDataset.sortRunState(STATUSFILE) reads
            %   the ks4_status.json that runKilosort
            %   drivers write when they finish: STATE is its "done" or
            %   "error" ("cancelled" for a run ended by stopSortRun), and
            %   "running" while there is none yet (or it is caught
            %   mid-write). A run whose process has exited (the
            %   SortExitMarker beside the status file) without writing a
            %   status is an "error". MESSAGE is the driver's error
            %   message, or why the run counts as failed ("" otherwise).
            statusFile = char(statusFile);
            % The marker is written after the process exits, so once it is
            % there the status file (if any) is complete.
            exited = isfile(fullfile(fileparts(statusFile), char(EphysDataset.SortExitMarker)));
            state = "running";
            message = "";
            if isfile(statusFile)
                try
                    s = jsondecode(fileread(statusFile));
                    state = "done";
                    if isfield(s, 'state'); state = string(s.state); end
                    if isfield(s, 'message'); message = string(s.message); end
                    return
                catch
                    if ~exited; return; end   % mid-write: read it again next time
                    message = "unreadable " + string(statusFile);
                end
            elseif exited
                message = "the process exited without writing ks4_status.json (see ks4_run.log)";
            else
                return
            end
            state = "error";
        end

        function tf = isTorchDevice(s)
            %isTorchDevice  Whether S names a torch device a Kilosort4 run can use.
            %   TF = EphysDataset.isTorchDevice(S): "cpu", "mps", "cuda" or
            %   "cuda:N" (the GPU with index N), elementwise for a string
            %   array. See launchSorting's Device option.
            tf = ~cellfun(@isempty, regexp(cellstr(string(s)), '^(cpu|mps|cuda(:\d+)?)$', 'once'));
            tf = reshape(tf, size(string(s)));
        end

        function ch = parseChannelList(s)
            %parseChannelList  Parse "1,3,5-8" / "1 3 5:8" / "[1:4 9]" / [] into channel indices.
            %   Accepts a numeric vector, or text of numbers and ranges
            %   separated by commas, semicolons or spaces, optionally in
            %   brackets: N, N-M or N:M (inclusive), N:S:M or N-S-M (step S).
            %   The text is parsed, never evaluated (it comes from manifests
            %   and edit fields). Returns a sorted, unique row vector of
            %   positive integers; empty when nothing is given or any part is
            %   not of that form.
            ch = double.empty(1, 0);
            if isnumeric(s)
                v = double(s(:).');
            else
                t = regexprep(char(strjoin(string(s), " ")), '[\[\],;]', ' ');
                t = strtrim(regexprep(t, '\s*([-:])\s*', '$1'));   % "5 - 8" -> "5-8"
                if isempty(t); return; end
                v = [];
                for tok = regexp(t, '\s+', 'split')
                    p = strsplit(tok{1}, {'-', ':'});
                    if numel(p) > 3 || any(cellfun(@isempty, regexp(p, '^\d+(\.\d*)?$', 'once')))
                        return   % not a number or range: nothing is parsed
                    end
                    p = str2double(p);
                    switch numel(p)
                        case 1; v = [v, p]; %#ok<AGROW>
                        case 2; v = [v, p(1):p(2)]; %#ok<AGROW>
                        case 3; v = [v, p(1):p(2):p(3)]; %#ok<AGROW>
                    end
                end
            end
            if isempty(v); return; end
            v = round(v);
            ch = unique(v(v >= 1));
        end

        function s = formatChannelList(ch)
            %formatChannelList  Compact a channel vector to "1,3,5-8" form.
            ch = EphysDataset.parseChannelList(ch);
            if isempty(ch); s = ""; return; end
            d = [true, diff(ch) ~= 1];          % run starts
            starts = ch(d);
            ends   = ch([d(2:end), true]);      % run ends
            parts = strings(1, numel(starts));
            for k = 1:numel(starts)
                if starts(k) == ends(k)
                    parts(k) = string(starts(k));
                else
                    parts(k) = starts(k) + "-" + ends(k);
                end
            end
            s = strjoin(parts, ",");
        end
    end

end


function rows = mergeRows(rows)
%mergeRows  Sorted union of [k x 2] inclusive [first last] row ranges; ranges
%   that overlap or touch ([3 5] and [6 9]) become one.
if isempty(rows)
    rows = zeros(0, 2);
    return
end
rows = sortrows(rows, 1);
out = rows(1, :);
for k = 2:size(rows, 1)
    if rows(k, 1) <= out(end, 2) + 1
        out(end, 2) = max(out(end, 2), rows(k, 2));
    else
        out(end+1, :) = rows(k, :); %#ok<AGROW>
    end
end
rows = out;
end
