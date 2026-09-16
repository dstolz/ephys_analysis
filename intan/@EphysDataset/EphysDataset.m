classdef EphysDataset < handle
    % EphysDataset  One recording folder -> processing, sorting and exports.
    %   An EphysDataset represents a single recording. All raw-data access goes
    %   through an EphysReader chosen for the folder (see Reader): IntanReader
    %   for the Intan layouts below, BinaryReader for the universal
    %   recording.json + flat binary format, or any registered reader, so
    %   nothing above this class depends on the acquisition system.
    %     "traditional"          one or more *.rhd files with embedded data
    %     "one-file-per-signal"  info.rhd + amplifier.dat (+ other signal .dat)
    %     "one-file-per-channel" info.rhd + amp-<native>.dat (one file per channel)
    %   It discovers the files, gathers header metadata cheaply (without reading
    %   amplifier data), reads/filters/screens the data, streams a Kilosort4 .bin
    %   file to disk, and spawns Kilosort4 - identically across formats, because
    %   all data access goes through the format-agnostic streamPlan/readChunkUV
    %   primitives (whole *.rhd files for traditional; bounded sample windows over
    %   the flat .dat files for the split formats).
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
    %     info = ds.toBin();               % stream raw broadband int16 .bin
    %     ds.ProbeFile = "probe.json";
    %     ds.PythonExe = "C:\miniconda3\python.exe";
    %     res = ds.runKilosort();          % write run_ks4.py + settings.json, spawn
    %
    %   Derived signals (the intan2matlab conversion, any layout)
    %   ---------------------------------------------------------
    %     [Y, ev, info] = ds.deriveSignals(dataTypeOut=["LFP" "MUA"]);
    %     out = ds.toMat(File="D:\out\subj1.mat", ...
    %                    SignalOptions=struct('dataTypeOut', "LFP"));
    %
    %   See also EPHYSPROJECT, READ_INTAN_RHD2000_FILE_MODIFIED,
    %   MATRIX2KILOSORT, EXTRACT_TRIALS, INTAN2MATLAB.

    properties
        Folder   (1,1) string = ""      % directory containing the *.rhd files
        Files    (1,:) string = string.empty(1,0)  % *.rhd files, chronological (datenum)
        Name     (1,1) string = ""      % dataset name (defaults to folder name)
    end

    properties (SetAccess = protected)
        % Intan acquisition file layout for this folder, detected from its
        % contents (see EphysDataset.detectFormat):
        %   "traditional"         one or more *.rhd files with embedded data
        %   "one-file-per-signal" info.rhd + amplifier.dat (+ other signal .dat)
        %   "one-file-per-channel" info.rhd + amp-*.dat (one file per channel)
        %   "unknown"             no recognized Intan files
        % Recorded in the manifest so the GUI shows the layout even for formats
        % whose amplifier data is not yet read in-process.
        RecordingFormat (1,1) string = "traditional"
    end

    properties (SetAccess = protected)
        % Header metadata (filled by refreshMetadata; no amplifier data read)
        Fs           (1,1) double = NaN          % amplifier sample rate (Hz)
        NumChannels  (1,1) double = NaN          % amplifier channel count (first file)
        ChannelNames (1,:) string = string.empty(1,0)  % custom_channel_name
        NativeNames  (1,:) string = string.empty(1,0)  % native_channel_name
        DigInNames   (1,:) string = string.empty(1,0)  % board dig-in custom names
        Duration     (1,1) double = NaN          % total recording duration (s)
        AcqDate      datetime = NaT              % earliest file datenum
        NumFiles     (1,1) double = 0            % number of *.rhd files
        PerFile      struct = struct([])         % per-file header summary (struct array)
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
        % so Kilosort4 ignores them. The *.rhd files and probe .json are never
        % modified. See runKilosort, parseChannelList, formatChannelList.
        ExcludeChannels (1,:) double = double.empty(1,0)

        PythonExe (1,1) string = ""              % python/conda exe path for KS4 spawn
        CondaEnv  (1,1) string = ""              % conda env name (uses `conda run -n` when set)
        Scale     (1,1) double = 1/0.195         % int16 scale (restores native ADC resolution)
        Dtype     (1,1) string {mustBeMember(Dtype, ...
            ["int16","uint16","int32","single","float32"])} = "int16"
        OutputDir (1,1) string = ""              % output dir for .bin / KS4 results (default = Folder)

        % Sorted-output association. "" = auto-discover the Kilosort4/phy
        % results under outputFolder() (see kilosortResultsDir); a non-empty
        % folder pins the association explicitly (e.g. results sorted elsewhere
        % or a phy-curated copy). Persisted in the manifest as sorting.source
        % "manual". See sortingResultsDir, readSortedUnits.
        SortingDir (1,1) string = ""

        % Epsych2 behavioral session file (.mat with Data + Info) associated
        % with this recording. "" = none. Persisted in the manifest under
        % behavior.file. See readBehavior, readEpsychSession.
        BehaviorFile (1,1) string = ""

        % How Epsych2 trials are paired with a digital line (pairTrials):
        % TrialLine, InvertedLines, ToleranceS, SignalFs (derived-signal
        % rates for sample columns) and LabelField. Pushed from the config's
        % Behavior section. See defaultTrialConfig.
        TrialConfig struct = EphysDataset.defaultTrialConfig()

        % The reviewed trial pairing, persisted in the manifest under
        % behavior.pairing; struct([]) until one is recorded. Fields: status
        % ("unreviewed" | "approved"), assignment (interval index per trial,
        % NaN = unpaired), fingerprint (behavior session + trial line
        % intervals it applies to), method, trial_line, summary, updated.
        % See pairTrials, setTrialPairing.
        TrialPairing struct = struct([])
        Manifest                                  % optional Manifest for provenance

        % Manually defined artifact periods to blank before writing the .bin.
        % [k x 2] of [tStart tEnd] in seconds, recording-relative (file 1 = t0),
        % set on the Visualize tab. toBin zeros these samples on every channel;
        % the original *.rhd files are never modified. See addArtifact /
        % manualArtifactMask.
        ManualArtifacts (:,2) double = zeros(0,2)

        % Automatic artifact-detection configuration applied by toBin (when
        % Enabled) to zero large per-channel amplitude deviations before the
        % .bin is written; never touches the *.rhd files. Set from the Artifacts
        % tab. RmsWindowMs/MergeGapMs/PadMs are in milliseconds (converted to
        % samples with Fs). See detectArtifacts, analyzeArtifacts, toBin and
        % defaultArtifactConfig.
        ArtifactConfig struct = EphysDataset.defaultArtifactConfig()

        % SpikeInterface preprocessing configuration used by runSpikeInterface
        % when the recording is converted for Kilosort4 through SpikeInterface
        % (read_intan -> attach probe -> preprocessing -> run_sorter). Controls
        % the optional bandpass filter, common reference, and automatic
        % bad-channel detection/removal. Artifact silencing is driven separately
        % by ManualArtifacts + ArtifactConfig (see artifactIntervals). Set from
        % the Kilosort tab. See defaultSIConfig / normalizeSIConfig.
        SIConfig struct = EphysDataset.defaultSIConfig()
    end

    properties (SetAccess = protected)
        % The acquisition reader for Folder (an EphysReader subclass such as
        % IntanReader or BinaryReader), chosen by EphysReader.forFolder in
        % discoverFiles. [] when no registered reader recognises the folder.
        Reader = []
    end

    properties (Dependent)
        BinFile     % full path to the .bin (OutputDir/Name.bin)
        NumSamples  % total amplifier samples across files (sum of PerFile)
    end

    properties (Constant)
        % Dataset manifest schema written by manifestStruct. /2 adds
        % manual_artifacts, sorting and behavior to /1; applyManifest reads
        % both (v2 is a strict superset, so no migration is needed).
        ManifestSchema = "intan-dataset-manifest/2"
        ManifestSchemasAccepted = ["intan-dataset-manifest/1", "intan-dataset-manifest/2"]
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
        [trials, info, meta] = readBehavior(obj)
        b      = behaviorStruct(obj, opts)
        out    = behaviorToMat(obj, opts)
        E      = digitalEvents(obj, opts)
        P      = pairTrials(obj, opts)
        setTrialPairing(obj, P, status)
        summary = analyzeArtifacts(obj, opts)
        X      = blankArtifacts(obj, X, mask, opts)
        mask   = manualArtifactMask(obj, nSamp, sampleOffset, Fs)
        addArtifact(obj, t0, t1)
        info   = toBin(obj, opts)
        info   = matrixToBin(obj, X, opts)
        result = runKilosort(obj, opts)
        result = runSpikeInterface(obj, opts)
        iv     = artifactIntervals(obj, opts)
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

        function discoverFiles(obj)
            %discoverFiles  Pick the reader for Folder and inventory its files.
            %   The registered EphysReader classes (IntanReader, BinaryReader,
            %   ...) are asked in turn; the first that claims the folder becomes
            %   obj.Reader and supplies RecordingFormat / Files / NumFiles.
            obj.Reader = EphysReader.forFolder(obj.Folder);
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
            obj.DigInNames   = r.DigInNames;
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

        function X = readChunkUV(obj, chunk)
            %readChunkUV  One streamPlan chunk as [nSamp x nChan] double microvolts.
            obj.requireReader('readChunkUV');
            X = obj.Reader.readChunkUV(chunk);
        end

        function X = readWindowUV(obj, sampleOffset, nSamp)
            %readWindowUV  Bounded random-access read (readers that support it).
            obj.requireReader('readWindowUV');
            X = obj.Reader.readWindowUV(sampleOffset, nSamp);
        end

        function tf = supportsRandomAccess(obj)
            %supportsRandomAccess  True when readWindowUV works for this recording.
            tf = ~isempty(obj.Reader) && obj.Reader.supportsRandomAccess();
        end

        function data = readData(obj, varargin)
            %readData  The whole recording as the universal data struct.
            %   DATA = ds.readData(Name=Value) forwards to the reader: Files,
            %   KeepChannels, IncludeADC, IncludeAux, Concatenate, ProgressFcn,
            %   Precision ("double"|"single"), EventLabelField. The struct
            %   (amplifier in microvolts [nSamples x nChan], Fs, t, channel
            %   names, dig-in events, ...) is the same for every reader; see
            %   EphysReader for the field list.
            if obj.NumFiles == 0
                obj.discoverFiles();
            end
            if isempty(obj.Reader) || obj.NumFiles == 0
                error('EphysDataset:readData:NoFiles', 'No recording files in %s', obj.Folder);
            end
            data = obj.Reader.readData(varargin{:});
            data.source = struct('Folder', obj.Folder, 'Name', obj.Name);
        end

        %% Dependent getters
        function f = get.BinFile(obj)
            f = fullfile(obj.outputFolder(), obj.Name + ".bin");
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
            dt = DatasetTracker(out, Name=obj.Name);
        end

        %% --- Kilosort4 output location (cheap, no scan) ------------------
        function p = kilosortDir(obj)
            %kilosortDir  Default Kilosort4 run folder (outputFolder/kilosort4).
            %   This is the folder runKilosort / runSpikeInterface write their
            %   bookkeeping into. The phy/npy output may live one or two levels
            %   deeper for the SpikeInterface engine; use kilosortResultsDir to
            %   locate the actual results.
            p = fullfile(char(obj.outputFolder()), 'kilosort4');
        end

        function p = kilosortResultsDir(obj)
            %kilosortResultsDir  Folder that actually holds the KS4 phy output.
            %   Kilosort4's native files (params.py, spike_*.npy, templates.npy,
            %   cluster_*.tsv) sit directly in kilosortDir() for the legacy
            %   run_ks4.py engine, but SpikeInterface's run_sorter nests them
            %   under <kilosortDir>/si/sorter_output. Return the first candidate
            %   that contains a params.py (deepest/most-specific first), so phy,
            %   the Review tab, and hasPhyOutput find the results for either
            %   engine. Falls back to kilosortDir() when nothing is found yet.
            base = obj.kilosortDir();
            cands = { fullfile(base, 'si', 'sorter_output'), ...
                      fullfile(base, 'sorter_output'), ...
                      base };
            for k = 1:numel(cands)
                if isfile(fullfile(cands{k}, 'params.py'))
                    p = cands{k};
                    return
                end
            end
            p = base;
        end

        function p = sortingResultsDir(obj)
            %sortingResultsDir  Folder holding the sorted units for this dataset.
            %   Returns SortingDir when it is set (an explicit association, e.g.
            %   a phy-curated copy or results sorted on another machine), else
            %   the auto-discovered kilosortResultsDir(). Every consumer of
            %   sorted output (Review tab, phy launch, readSortedUnits,
            %   ChronuxDataset.spikes) goes through this accessor.
            if obj.SortingDir ~= ""
                p = char(obj.SortingDir);
            else
                p = obj.kilosortResultsDir();
            end
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
            %   The filesystem inventory (.bin / probe / kilosort4 runs) is taken
            %   from the DatasetTracker so the manifest and the GUI tables agree.
            dt = obj.tracker();

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

            probe = struct('file', "", 'num_channels', NaN, 'num_shanks', NaN, ...
                'depth_um', NaN, 'notes', "");
            if obj.ProbeFile ~= "" && isfile(obj.ProbeFile)
                pm = DatasetTracker.probeMeta(DatasetTracker.readJson(obj.ProbeFile));
                probe.file         = obj.ProbeFile;
                probe.num_channels = pm.nChan;
                probe.num_shanks   = pm.nShank;
                probe.depth_um     = pm.depth;
                probe.notes        = pm.notes;
            end
            m.probe = probe;

            m.exclude_channels = EphysDataset.formatChannelList(obj.ExcludeChannels);

            % Manual artifact periods ([k x 2] seconds, recording-relative) so
            % periods marked on the Visualize tab survive a rescan / restart.
            ma = obj.ManualArtifacts;
            if isempty(ma); ma = zeros(0, 2); end
            m.manual_artifacts = ma;

            m.bin = struct('file', obj.BinFile, 'exists', isfile(obj.BinFile));

            ks = struct('has_results', false, 'results_dir', "", ...
                'num_units', NaN, 'state', "");
            run = dt.latestKilosortRun();
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

            % SpikeInterface preprocessing provenance (engine + config snapshot).
            m.engine        = "spikeinterface";
            m.preprocessing = EphysDataset.normalizeSIConfig(obj.SIConfig);
        end

        function writeManifest(obj)
            %writeManifest  Write/refresh this dataset's JSON manifest on disk.
            %   Called by the app whenever metadata, the assigned probe/exclusions,
            %   or Kilosort4 output change. Failures warn but never interrupt the
            %   caller (the manifest is a convenience, not the source of truth).
            if obj.Folder == "" || ~isfolder(obj.Folder); return; end
            try
                writeJsonFile(obj.manifestFile(), obj.manifestStruct());
            catch ME
                warning('EphysDataset:writeManifest:Failed', ...
                    'Could not write manifest for %s: %s', obj.Name, ME.message);
            end
        end

        function tf = applyManifest(obj)
            %applyManifest  Restore the editable per-dataset state from the
            %   on-disk manifest (if present) so a re-scan recovers prior work:
            %   probe file, channel exclusions, manual artifact periods, an
            %   explicit ("manual") sorting folder and the behavior file.
            %   Returns true when a manifest was found and read. Header metadata
            %   is always re-parsed. Schema /1 (probe + exclusions only) and /2
            %   are accepted; any other schema is ignored with a warning.
            tf = false;
            f = obj.manifestFile();
            if ~isfile(f); return; end
            m = readJsonFile(f, ErrorOnFail=false);
            if isempty(m) || ~isstruct(m); return; end
            schema = "";
            if isfield(m, 'schema'); schema = string(m.schema); end
            if ~ismember(schema, EphysDataset.ManifestSchemasAccepted)
                warning('EphysDataset:applyManifest:Schema', ...
                    'Ignoring manifest %s with unknown schema "%s".', f, schema);
                return
            end
            if isfield(m, 'probe') && isstruct(m.probe) && isfield(m.probe, 'file')
                pf = string(m.probe.file);
                if pf ~= "" && isfile(pf); obj.ProbeFile = pf; end
            end
            if isfield(m, 'exclude_channels')
                obj.ExcludeChannels = EphysDataset.parseChannelList(string(m.exclude_channels));
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
                    if sd ~= "" && isfile(fullfile(sd, 'params.py'))
                        obj.SortingDir = sd;
                    end
                end
            end
            if isfield(m, 'behavior') && isstruct(m.behavior) && isfield(m.behavior, 'file')
                bf = string(m.behavior.file);
                if bf ~= "" && isfile(bf); obj.BehaviorFile = bf; end
            end
            if isfield(m, 'behavior') && isstruct(m.behavior) && isfield(m.behavior, 'pairing')
                obj.TrialPairing = EphysDataset.normalizeTrialPairing(m.behavior.pairing);
            end
            tf = true;
        end

        function s = behaviorManifest(obj)
            %behaviorManifest  Manifest block for the associated Epsych2 session.
            %   file, subject, start_time, n_trials (only Info is read; any
            %   read failure leaves the summary fields empty) and pairing (the
            %   recorded TrialPairing, [] when none).
            s = struct('file', obj.BehaviorFile, 'subject', "", 'start_time', "", 'n_trials', NaN, ...
                'pairing', []);
            if ~isempty(obj.TrialPairing); s.pairing = obj.TrialPairing; end
            if obj.BehaviorFile == "" || ~isfile(obj.BehaviorFile); return; end
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
            %   results_dir  folder holding params.py ("" when none exists yet)
            %   source       "manual" when SortingDir is set, else "auto"
            %   curated      true when a phy cluster_group.tsv is present
            %   num_units    rows of the label table (NaN when none)
            %   updated      modification time of spike_clusters.npy ("" if none)
            s = struct('results_dir', "", 'source', "auto", 'curated', false, ...
                'num_units', NaN, 'updated', "");
            if obj.SortingDir ~= ""; s.source = "manual"; end
            p = obj.sortingResultsDir();
            if ~isfile(fullfile(p, 'params.py')); return; end
            s.results_dir = string(p);
            grp = fullfile(p, 'cluster_group.tsv');
            s.curated = isfile(grp);
            if ~s.curated; grp = fullfile(p, 'cluster_KSLabel.tsv'); end
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
        function fmt = detectFormat(folder)
            %detectFormat  RecordingFormat of the reader that claims FOLDER.
            %   "traditional" | "one-file-per-signal" | "one-file-per-channel"
            %   (IntanReader), "binary" (BinaryReader), or "unknown" when no
            %   registered reader recognises the folder.
            arguments
                folder (1,1) string
            end
            r = EphysReader.forFolder(folder);
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
            cfg = struct( ...
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
                'FilterOrder',  4);
        end

        function cfg = defaultTrialConfig()
            %defaultTrialConfig  Default trial-pairing settings (see pairTrials).
            %   TrialLine       digital line held high during each trial
            %   InvertedLines   lines with inverted polarity: on while low,
            %                   onset = falling edge (default none)
            %   ToleranceS      timestamp agreement tolerance (s)
            %   SignalFs        struct of derived-signal rates (e.g. LFP: 1000)
            %                   for per-signal sample columns
            %   LabelField      dig-in name used as the line name
            cfg = struct('TrialLine', "InTrial", 'InvertedLines', string.empty(1,0), ...
                'ToleranceS', 0.5, 'SignalFs', struct(), 'LabelField', "custom_channel_name");
        end

        function p = normalizeTrialPairing(p)
            %normalizeTrialPairing  A TrialPairing record from a manifest block.
            %   Returns struct([]) for anything that is not a usable record.
            if isempty(p) || ~isstruct(p) || ~isscalar(p) ...
                    || ~all(isfield(p, {'status', 'assignment', 'fingerprint'}))
                p = struct([]);
                return
            end
            a = p.assignment;
            if iscell(a)                       % jsondecode keeps nulls as [] in a cell
                v = NaN(numel(a), 1);
                for k = 1:numel(a)
                    if isnumeric(a{k}) && isscalar(a{k}); v(k) = a{k}; end
                end
                a = v;
            end
            q = struct('status', string(p.status), 'assignment', {double(a(:))}, ...
                'fingerprint', string(p.fingerprint), 'method', "", 'trial_line', "", ...
                'summary', "", 'updated', "");
            for f = ["method" "trial_line" "summary" "updated"]
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

        [units, info] = readPhyUnits(resultsDir, opts)

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
            %   and the Chronux / FieldTrip exporters.
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
            %   dataset output folder: the SpikeInterface engine nests the phy
            %   output under kilosort4/si/sorter_output, the legacy engine
            %   writes it into kilosort4/ directly. Returns FOLDER unchanged
            %   when no candidate holds a params.py.
            folder = char(folder);
            if isfile(fullfile(folder, 'params.py'))
                p = folder;
                return
            end
            cands = { fullfile(folder, 'kilosort4', 'si', 'sorter_output'), ...
                      fullfile(folder, 'si', 'sorter_output'), ...
                      fullfile(folder, 'sorter_output'), ...
                      fullfile(folder, 'kilosort4') };
            for k = 1:numel(cands)
                if isfile(fullfile(cands{k}, 'params.py'))
                    p = cands{k};
                    return
                end
            end
            p = folder;
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

        function cfg = defaultSIConfig()
            %defaultSIConfig  Default SpikeInterface preprocessing settings.
            %   Used to initialize SIConfig and consumed by runSpikeInterface.
            %   Kilosort4 still high-pass filters and whitens internally, so the
            %   SI bandpass is OFF by default (enabling it risks double-filtering)
            %   and common reference is OFF; automatic bad-channel detection is ON
            %   and augments the manual ExcludeChannels list (union). Fields:
            %     Filter           logical  apply spikeinterface bandpass_filter
            %     FilterFreqMin/Max  Hz      band edges when Filter is true
            %     CommonReference  logical  apply common_reference (CMR/CAR)
            %     ReferenceOperator "median"|"average"  common_reference operator
            %     DetectBadChannels logical detect_bad_channels before sorting
            %     BadChannelMethod  string  spikeinterface detector method
            %                       ("coherence+psd","std","mad","neighborhood_r2")
            %     BadChannelAction  "remove"|"interpolate"  what to do with bad ch
            cfg = struct( ...
                'Filter',            false, ...
                'FilterFreqMin',     300, ...
                'FilterFreqMax',     6000, ...
                'CommonReference',   false, ...
                'ReferenceOperator', "median", ...
                'DetectBadChannels', true, ...
                'BadChannelMethod',  "coherence+psd", ...
                'BadChannelAction',  "remove");
        end

        function cfg = normalizeSIConfig(cfg)
            %normalizeSIConfig  Fill missing fields from the SI defaults.
            %   Tolerates partial/stale SIConfig structs (e.g. a project saved
            %   before a field was added) by merging onto defaultSIConfig; unknown
            %   extra fields are dropped.
            def = EphysDataset.defaultSIConfig();
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

        function ch = parseChannelList(s)
            %parseChannelList  Parse "1,3,5-8" / "1 3 5:8" / [] into channel indices.
            %   Accepts a char/string spec (commas, spaces, colon or hyphen
            %   ranges) or a numeric vector. Returns a sorted, unique row vector
            %   of positive integers (empty when nothing valid is given).
            if isnumeric(s)
                ch = s(:).';
            else
                t = char(string(s));
                t = strrep(strrep(t, ',', ' '), '-', ':');  % hyphen ranges -> colon
                ch = str2num(t); %#ok<ST2NM>  % supports colon ranges like 5:8
            end
            if isempty(ch); ch = double.empty(1,0); return; end
            ch = round(ch(:).');
            ch = unique(ch(ch >= 1));
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
