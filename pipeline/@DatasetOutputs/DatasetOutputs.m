classdef DatasetOutputs < handle & matlab.mixin.CustomDisplay
    % DatasetOutputs  One dataset's processed files, found once and loaded on demand.
    %   A DatasetOutputs keeps track of every file the pipeline writes for one
    %   dataset -- derived signals, spikes, analysis-toolbox and epoch
    %   exports, sorted units, the Epsych2 behavior session, the manifest and
    %   the artifact cache -- wherever they live, and loads each one only when its
    %   property is read:
    %
    %     out = ds.outputs();                  % from an EphysDataset
    %     out = DatasetOutputs("D:\out\subj1_day1");   % or from a folder alone
    %     FT  = out.FieldTrip;                 % loads <Name>_fieldtrip.mat
    %     lfp = out.LFP;                       % only the file holding LFP
    %     u   = out.Units;                     % Kilosort4 / phy sorted units
    %
    %   Nothing is read from the recording itself, so analysis scripts work on
    %   a machine that only has the processed files.
    %
    %   Discovery
    %   ---------
    %   refresh() lists the *.mat files under the search roots whose names
    %   start with Name (followed by "_", "-", "." or a space) and classifies
    %   each one by the variables it holds, not by its suffix, so configured
    %   Signals/Spikes suffixes and output folders are found too:
    %     extract    Y + info                     (toMat; the Signals step)
    %     spikes     detected + conversion (spikesToMat)
    %     chronux    export + sp                   (exportChronux)
    %     fieldtrip  export + event / spike / data_* (exportFieldTrip)
    %     epochs     export + epochs               (exportEpochs)
    %   and each *.npz named like the dataset by its meta member:
    %     kcsd       meta.tool EphysDataset.exportKCSD  (exportKCSD)
    %   and each *.nwb named like the dataset by the JSON in its
    %   /general/notes:
    %     nwb        notes.tool EphysDataset.exportNWB  (exportNWB)
    %     behavior   behavior + conversion         (behaviorToMat)
    %   A file whose provenance (conversion / export struct, a .npz's meta) names another
    %   dataset is skipped and listed in Foreign: another dataset name, or -
    %   built from a dataset - another recording folder (sourceFolder, see
    %   EphysDataset.isOwnSource), so of two recordings with the same name
    %   (mouse1/rec, mouse2/rec) neither picks up the other's files.
    %   <Name>_manifest.json and <Name>_artifacts.json are found by name.
    %   When several files of one kind exist, the newest wins; every
    %   candidate is listed in Candidates.
    %
    %   Search roots: the dataset's outputFolder() and Folder (or FOLDER when
    %   constructed from a folder), plus SearchDirs, recursively unless
    %   Recursive=false. Sorted units come from the dataset's
    %   sortingResultsDir(), else the manifest's sorting.results_dir, else the
    %   standard kilosort4 layouts under the roots; a hand-picked folder (the
    %   dataset's SortingDir, or "manual" in the manifest) is kept even while
    %   it is not there, so no other sort is used instead. BehaviorFile is the
    %   <Name>_behavior.mat file; until one has been written it falls back to
    %   the associated Epsych2 session (the dataset's BehaviorFile, else the
    %   manifest's behavior.file), which loads into the same struct.
    %
    %   Manual paths
    %   ------------
    %   The path properties (ExtractFiles, SpikesFile, ChronuxFile,
    %   FieldTripFile, EpochsFile, KCSDFile, NWBFile, SortingDir, BehaviorFile,
    %   ManifestFile, ArtifactsFile)
    %   always return the path in effect. Assigning one pins it; assigning ""
    %   returns it to discovery. pathSource(kind) says which applies.
    %
    %     out.FieldTripFile = "E:\shared\subj1_day1_ft.mat";
    %     out.SortingDir    = "E:\curated\subj1_day1";
    %
    %   Loading
    %   -------
    %     Extract      all signal files merged into one toMat-shaped struct
    %                  (Y, info, events, behavior, conversion); newer files win
    %     LFP, MUA, SPIKE, AUX   the toMat-shaped struct of the file holding
    %                  that signal, with Y / info trimmed to it
    %     Spikes, Chronux, FieldTrip, Epochs   the file's variables as a struct
    %                  (Epochs: epochs + export, see EphysDataset.exportEpochs)
    %     KCSD         the .npz arrays (readNPZ), meta decoded from its JSON
    %                  (see EphysDataset.exportKCSD)
    %     NWB          file and notes (the decoded JSON the exporter records:
    %                  dataset, sources, provenance); read the data itself
    %                  with pynwb or MatNWB (see EphysDataset.exportNWB)
    %     Units        readSortedUnits (with a dataset) / readPhyUnits defaults
    %     Behavior     trials, info, meta, file, subject, startTime, nTrials
    %                  (the EphysDataset.behaviorStruct shape), from
    %                  <Name>_behavior.mat or the Epsych2 session itself
    %     Manifest, Artifacts   the decoded JSON
    %   Reading a property whose file is missing raises DatasetOutputs:Missing;
    %   has(kind) checks first. load(kind, vars...) loads selected variables
    %   only, readUnits(Name=Value) forwards unit-reading options, and
    %   readWaveforms(unitId) cuts a sorted unit's spikes from the sorted data.
    %   Set CacheData=true to keep loaded data in memory (clearCache frees it).
    %
    %   See also EphysDataset.outputs, EphysPipeline.outputsFor, DatasetTracker,
    %   EphysDataset.toMat, EphysDataset.spikesToMat, EphysDataset.behaviorToMat,
    %   EphysDataset.exportChronux, EphysDataset.exportFieldTrip,
    %   EphysDataset.exportEpochs, EphysDataset.exportKCSD, EphysDataset.exportNWB.

    properties
        Name       (1,1) string = ""      % dataset name; files must start with it
        Folder     (1,1) string = ""      % search root when not built from a dataset
        SearchDirs (1,:) string = string.empty(1,0)  % extra folders to search
        Recursive  (1,1) logical = true   % search sub-folders of every root
        CacheData  (1,1) logical = false  % keep loaded data in memory
    end

    properties (SetAccess = protected)
        Dataset = []                      % the EphysDataset, when built from one
        Candidates table = DatasetOutputs.emptyCandidates()  % every file found
        Foreign (:,1) string = strings(0, 1)  % files named like this dataset's whose provenance names another
        LastRefreshed datetime = NaT
    end

    properties (Dependent)
        % Paths in effect. Assign to pin; assign "" to use discovery again.
        ExtractFiles    % derived-signal .mat file(s), newest first
        SpikesFile      % spikesToMat output
        ChronuxFile     % exportChronux output
        FieldTripFile   % exportFieldTrip output
        EpochsFile      % exportEpochs output (event-organized data)
        KCSDFile        % exportKCSD output (.npz for kCSD-python)
        NWBFile         % exportNWB output (<Name>.nwb)
        SortingDir      % Kilosort4 / phy results folder
        BehaviorFile    % <Name>_behavior.mat, else the Epsych2 session .mat
        ManifestFile    % <Name>_manifest.json
        ArtifactsFile   % <Name>_artifacts.json
    end

    properties (Dependent, SetAccess = private)
        % Data, loaded from the files above each time it is read.
        Extract
        LFP
        MUA
        SPIKE
        AUX
        Spikes
        Units
        Chronux
        FieldTrip
        Epochs
        KCSD
        NWB
        Behavior
        Manifest
        Artifacts
        Roots           % folders searched by refresh()
    end

    properties (Constant)
        Kinds = ["extract" "spikes" "chronux" "fieldtrip" "epochs" "kcsd" "nwb" "sorting" "behavior" "manifest" "artifacts"]
        SignalTypes = ["LFP" "MUA" "SPIKE" "AUX"]
    end

    properties (Constant, Access = private)
        PathProps = ["ExtractFiles" "SpikesFile" "ChronuxFile" "FieldTripFile" ...
                     "EpochsFile" "KCSDFile" "NWBFile" "SortingDir" "BehaviorFile" "ManifestFile" "ArtifactsFile"]
    end

    properties (Access = private)
        Pinned = struct('extract', string.empty(1,0), 'spikes', string.empty(1,0), ...
            'chronux', string.empty(1,0), 'fieldtrip', string.empty(1,0), ...
            'epochs', string.empty(1,0), 'kcsd', string.empty(1,0), 'nwb', string.empty(1,0), ...
            'sorting', string.empty(1,0), 'behavior', string.empty(1,0), ...
            'manifest', string.empty(1,0), 'artifacts', string.empty(1,0))
        Cache = []
        InfoSignals = []   % combined extract file -> the signal types its info holds (signalFile)
    end

    methods
        function obj = DatasetOutputs(source, opts)
            %DatasetOutputs  Track the processed files of a dataset or a folder.
            %   out = DatasetOutputs(ds)        an EphysDataset
            %   out = DatasetOutputs(folder)    a folder holding the outputs
            %   out = DatasetOutputs()          empty; set Name/Folder, then refresh
            %   Options: Name (default ds.Name, or the folder's name: the
            %   dataset <name> of a version folder <name>_v<n> holding its
            %   outputs, see EphysProject.outputFolderName), SearchDirs,
            %   Recursive, CacheData, AutoRefresh (default true).
            arguments
                source = []
                opts.Name (1,1) string = ""
                opts.SearchDirs (1,:) string = string.empty(1,0)
                opts.Recursive (1,1) logical = true
                opts.CacheData (1,1) logical = false
                opts.AutoRefresh (1,1) logical = true
            end
            obj.Cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.InfoSignals = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.SearchDirs = opts.SearchDirs;
            obj.Recursive  = opts.Recursive;
            obj.CacheData  = opts.CacheData;
            obj.Name       = opts.Name;
            if isempty(source) || ((isstring(source) || ischar(source)) && strlength(string(source)) == 0)
                return
            end
            if isa(source, 'EphysDataset')
                obj.Dataset = source;
                if obj.Name == ""; obj.Name = source.Name; end
            elseif isstring(source) || ischar(source)
                folder = string(source);
                if ~isfolder(folder)
                    error('DatasetOutputs:NoFolder', 'Folder does not exist: %s', folder);
                end
                obj.Folder = folder;
                if obj.Name == ""
                    obj.Name = EphysProject.outputFolderName(folder);   % the leaf; <name> of a version folder <name>_v<n>
                end
            else
                error('DatasetOutputs:Source', 'Source must be an EphysDataset or a folder.');
            end
            if opts.AutoRefresh
                obj.refresh();
            end
        end

        function refresh(obj)
            %refresh  Re-scan the search roots and clear any cached data.
            if obj.Name == ""
                error('DatasetOutputs:NoName', 'Set Name before refreshing.');
            end
            obj.clearCache();
            remove(obj.InfoSignals, keys(obj.InfoSignals));
            T = DatasetOutputs.emptyCandidates();
            foreign = strings(0, 1);
            prefix = "^" + string(regexptranslate('escape', char(obj.Name))) + "([_\-. ].*)?";
            for root = obj.Roots
                tree = listTree(root, obj.Recursive);   % one walk for every pattern
                mats = listFiles(tree, "*.mat");
                for k = 1:numel(mats)
                    m = mats(k);
                    if isempty(regexpi(m.name, prefix + "\.mat$", 'once')); continue; end
                    [kind, prov] = classifyMat(m.path);
                    if kind == ""; continue; end
                    if ~obj.belongs(m.path, prov)
                        foreign(end+1, 1) = m.path; %#ok<AGROW>
                        continue
                    end
                    sig = "";
                    if kind == "extract"
                        tok = regexp(m.name, '_(LFP|MUA|SPIKE|AUX)\.mat$', 'tokens', 'once');
                        if ~isempty(tok); sig = string(tok{1}); end
                    end
                    T = [T; candidateRow(kind, m, sig)]; %#ok<AGROW>
                end
                npz = listFiles(tree, "*.npz");
                for k = 1:numel(npz)
                    m = npz(k);
                    if isempty(regexpi(m.name, prefix + "\.npz$", 'once')); continue; end
                    meta = npzMeta(m.path);
                    if ~isstruct(meta) || ~isfield(meta, 'tool') || string(meta.tool) ~= "EphysDataset.exportKCSD"; continue; end
                    if ~obj.ownsProvenance(meta)
                        foreign(end+1, 1) = m.path; %#ok<AGROW>
                        continue
                    end
                    T = [T; candidateRow("kcsd", m, "")]; %#ok<AGROW>
                end
                nwbs = listFiles(tree, "*.nwb");
                for k = 1:numel(nwbs)
                    m = nwbs(k);
                    if isempty(regexpi(m.name, prefix + "\.nwb$", 'once')); continue; end
                    meta = nwbNotes(m.path);
                    if ~isstruct(meta) || ~isfield(meta, 'tool') || string(meta.tool) ~= "EphysDataset.exportNWB"; continue; end
                    if ~obj.ownsProvenance(meta)
                        foreign(end+1, 1) = m.path; %#ok<AGROW>
                        continue
                    end
                    T = [T; candidateRow("nwb", m, "")]; %#ok<AGROW>
                end
                for kind = ["manifest" "artifacts"]
                    js = listFiles(tree, obj.Name + "_" + kind + ".json");
                    for k = 1:numel(js)
                        T = [T; candidateRow(kind, js(k), "")]; %#ok<AGROW>
                    end
                end
            end
            [~, keep] = unique(lower(T.File), 'stable');
            T = T(keep, :);
            obj.Candidates = sortrows(T, 'Modified', 'descend');
            [~, keep] = unique(lower(foreign), 'stable');
            obj.Foreign = foreign(keep);
            obj.LastRefreshed = datetime('now');
        end

        function tf = has(obj, kind)
            %has  True when the file (or folder) for KIND exists.
            %   KIND: "extract" | "spikes" | "chronux" | "fieldtrip" |
            %   "epochs" | "kcsd" | "nwb" | "sorting" | "behavior" | "manifest" | "artifacts" |
            %   "LFP" | "MUA" | "SPIKE" | "AUX".
            kind = string(kind);
            if ismember(upper(kind), DatasetOutputs.SignalTypes)
                tf = ~isempty(obj.signalFile(upper(kind)));
                return
            end
            f = obj.resolve(kind);
            if isempty(f)
                tf = false;
            elseif DatasetOutputs.checkKind(kind) == "sorting"
                tf = isfile(fullfile(EphysDataset.resolvePhyDir(f), 'params.py'));
            else
                tf = all(isfile(f));
            end
        end

        function src = pathSource(obj, kind)
            %pathSource  Where KIND's path comes from.
            %   "manual" (pinned), "discovered" (refresh), "dataset" (the
            %   EphysDataset's association), "manifest", or "" (none).
            [~, src] = obj.resolve(kind);
        end

        function T = inventory(obj)
            %inventory  One row per kind: path in effect, its source and state.
            kinds = DatasetOutputs.Kinds(:);
            n = numel(kinds);
            Property = DatasetOutputs.PathProps(:);
            Path = strings(n, 1); Source = strings(n, 1);
            Exists = false(n, 1); Bytes = nan(n, 1);
            Modified = NaT(n, 1); NumCandidates = zeros(n, 1);
            for k = 1:n
                [f, Source(k)] = obj.resolve(kinds(k));
                Path(k) = strjoin(f, "; ");
                Exists(k) = obj.has(kinds(k));
                NumCandidates(k) = sum(obj.Candidates.Kind == kinds(k));
                if Exists(k) && kinds(k) ~= "sorting"
                    listing = cellfun(@dir, cellstr(f));
                    Bytes(k) = sum([listing.bytes]);
                    Modified(k) = datetime(max([listing.datenum]), 'ConvertFrom', 'datenum');
                end
            end
            Kind = kinds;
            T = table(Kind, Property, Path, Source, Exists, Bytes, Modified, NumCandidates);
        end

        function S = load(obj, kind, vars)
            %load  Load a kind's data, optionally only some variables.
            %   S = out.load("fieldtrip", "data_LFP", "event") reads just those
            %   variables. Without VARS it is the same as reading the property
            %   (out.load("LFP") == out.LFP).
            arguments
                obj (1,1) DatasetOutputs
                kind (1,1) string
            end
            arguments (Repeating)
                vars (1,1) string
            end
            vars = [vars{:}];
            if ismember(upper(kind), DatasetOutputs.SignalTypes)
                kind = upper(kind);
                files = obj.signalFile(kind);
            else
                kind = DatasetOutputs.checkKind(kind);
                files = obj.resolve(kind);
            end
            key = char(strjoin([kind, vars, files], "|"));
            if obj.CacheData && isKey(obj.Cache, key)
                S = obj.Cache(key);
                return
            end
            if isempty(files) || ~obj.has(kind)
                obj.missing(kind);
            end
            switch kind
                case "extract"
                    S = [];
                    for f = files
                        T = loadMat(f, vars);
                        if isempty(S); S = T; else; S = mergeExtract(S, T); end
                    end
                case {"LFP", "MUA", "SPIKE", "AUX"}
                    S = trimToSignal(loadMat(files, vars), kind);
                case {"spikes", "chronux", "fieldtrip", "epochs"}
                    S = loadMat(files, vars);
                case "kcsd"
                    S = readNPZ(files, vars);
                    if isfield(S, 'meta'); S.meta = jsondecode(S.meta); end
                case "nwb"
                    S = struct('file', files, 'notes', nwbNotes(files));
                case "sorting"
                    S = obj.readUnits();
                case "behavior"
                    if ismember("behavior", matVars(files))
                        B = load(files, 'behavior');    % <Name>_behavior.mat
                        S = B.behavior;
                    else                                % the Epsych2 session itself
                        [trials, info, meta] = readEpsychSession(files);
                        S = struct('trials', trials, 'info', info, 'meta', meta, 'file', files, ...
                            'subject', meta.subject, 'startTime', meta.startTime, 'nTrials', meta.nTrials);
                    end
                case {"manifest", "artifacts"}
                    S = readJsonFile(files);
            end
            if obj.CacheData
                obj.Cache(key) = S;
            end
        end

        function [units, info] = readUnits(obj, varargin)
            %readUnits  Sorted units from SortingDir with reader options.
            %   [UNITS, INFO] = out.readUnits(Groups=["good" "mua"], ...) takes
            %   the options of EphysDataset.readSortedUnits (with a dataset) or
            %   EphysDataset.readPhyUnits (without one).
            if ~obj.has("sorting")
                obj.missing("sorting");
            end
            d = obj.resolve("sorting");
            if ~isempty(obj.Dataset)
                [units, info] = obj.Dataset.readSortedUnits('ResultsDir', d, varargin{:});
                return
            end
            [units, info] = EphysDataset.readPhyUnits(d, varargin{:});
        end

        function [W, info] = readWaveforms(obj, unitId, opts)
            %readWaveforms  A sorted unit's spikes on its peak channel, cut from the sorted data.
            %   [W, INFO] = out.readWaveforms(UNITID, MaxSpikes=N) reads at most N
            %   of the spikes of the sorted unit with cluster id UNITID (picked at
            %   random, the same ones each time; default 100) on its peak channel
            %   (units.ksChannel), with EphysDataset.readPhyWaveforms from the data
            %   the sort read: W is [nt x nSpikes] in INFO.units, INFO as
            %   readPhyWaveforms returns it. With CacheData they are kept, so a
            %   redraw does not read them again. readPhyWaveforms' errors pass
            %   through (EphysDataset:readPhyWaveforms:NoDataFile when the sorted
            %   .bin is not there); DatasetOutputs:NoUnit when the sort has no
            %   such unit.
            arguments
                obj (1,1) DatasetOutputs
                unitId (1,1) double
                opts.MaxSpikes (1,1) double {mustBePositive} = 100
            end
            d = obj.resolve("sorting");
            key = char(strjoin(["waveforms" d string(unitId) string(opts.MaxSpikes)], "|"));
            if obj.CacheData && isKey(obj.Cache, key)
                c = obj.Cache(key);
                W = c.W;
                info = c.info;
                return
            end
            U = obj.load("sorting");
            row = find(double(U.unitId) == unitId, 1);
            if isempty(row)
                error('DatasetOutputs:NoUnit', 'The sorting of %s has no unit %g.', obj.Name, unitId);
            end
            [W, info] = EphysDataset.readPhyWaveforms(d, U.samples{row}, Channels=U.ksChannel(row), ...
                MaxSpikes=opts.MaxSpikes);
            W = reshape(W, size(W, 1), []);
            if obj.CacheData
                obj.Cache(key) = struct('W', W, 'info', info);
            end
        end

        function f = probeFile(obj)
            %probeFile  The probe .json this dataset was sorted with ("" when none is there).
            %   The manifest's probe.file, the path on the machine that wrote
            %   it; when no file is there (the outputs were copied to another
            %   machine) a file of the same name in the dataset's folder
            %   (analysisFiles copies it there).
            f = "";
            m = obj.manifestStruct();
            if ~(isfield(m, 'probe') && isstruct(m.probe) && isfield(m.probe, 'file')); return; end
            pf = string(m.probe.file);
            if ~isscalar(pf) || pf == ""; return; end
            if isfile(pf); f = pf; return; end
            [~, nm, ext] = fileparts(pf);
            for root = obj.Roots
                c = fullfile(root, nm + ext);
                if isfile(c); f = string(c); return; end
            end
        end

        function [T, notes] = analysisFiles(obj, opts)
            %analysisFiles  The files EphysAnalysisApp needs to analyse this dataset.
            %   [T, NOTES] = out.analysisFiles(Signals=, Spikes=, Sorting=,
            %   SortedData=, Probe=) lists what the analysis reads, so a
            %   copy of just these files (into <folder>/<dataset key>) runs
            %   it on another machine. T has one row per file or folder:
            %   Kind ("manifest", "behavior", "extract", "spikes", "sorting",
            %   "sorted data", "probe"), Path, Base (the folder the file's
            %   place in the copy is counted from: its path below it is kept;
            %   "" keeps the name only) and Bytes. NOTES says in words what
            %   is missing (no behavior file, no sorted units, ...).
            %
            %     Signals     ["LFP" "MUA" "AUX"]  the extract files holding these
            %                 signals; the smallest extract file is always
            %                 there (the digital events live in it)
            %     Spikes      true      the detected spikes, <Name>_spikes.mat
            %     Sorting     "essential" (default): the sorting folder's files
            %                 the readers use (spike times, clusters,
            %                 templates, channel files, params.py,
            %                 settings.json, the cluster_*.tsv tables),
            %                 without the large feature files; "all": the whole
            %                 folder; "none"
            %     SortedData  false     the sorted binary params.py names (large;
            %                 the unit waveforms are cut from it, else the
            %                 templates are drawn)
            %     Probe       true      the probe .json (probeFile)
            %
            %   The manifest and <Name>_behavior.mat are always there.
            arguments
                obj (1,1) DatasetOutputs
                opts.Signals (1,:) string = ["LFP" "MUA" "AUX"]
                opts.Spikes (1,1) logical = true
                opts.Sorting (1,1) string {mustBeMember(opts.Sorting, ["essential" "all" "none"])} = "essential"
                opts.SortedData (1,1) logical = false
                opts.Probe (1,1) logical = true
            end
            sigs = upper(opts.Signals);
            if ~all(ismember(sigs, DatasetOutputs.SignalTypes))
                error('DatasetOutputs:BadSignal', 'Signals must be among %s.', strjoin(DatasetOutputs.SignalTypes, ", "));
            end
            roots = obj.Roots;
            rows = cell(0, 3);   % kind, path, base
            notes = strings(0, 1);

            if obj.has("manifest")
                rows(end+1, :) = {"manifest", string(obj.ManifestFile), rootOf(obj.ManifestFile, roots)};
            else
                notes(end+1, 1) = "no manifest";
            end

            if obj.has("behavior")
                f = string(obj.BehaviorFile);
                if endsWith(lower(f), "_behavior.mat")
                    rows(end+1, :) = {"behavior", f, rootOf(f, roots)};
                else
                    notes(end+1, 1) = "the behavior is read from " + f + ", which is not <Name>_behavior.mat: " + ...
                        "run the Behavior step so the analysis finds it";
                end
            else
                notes(end+1, 1) = "no behavior file (no trials)";
            end

            files = strings(1, 0);
            for s = sigs
                f = obj.signalFile(s);
                if isempty(f)
                    notes(end+1, 1) = "no " + s + " file"; %#ok<AGROW>
                else
                    files(end+1) = f; %#ok<AGROW>
                end
            end
            if isempty(files)
                ex = obj.ExtractFiles;
                ex = ex(isfile(ex));
                if isempty(ex)
                    notes(end+1, 1) = "no extract file (no events)";
                else
                    b = arrayfun(@(e) fileBytes(e), ex);
                    [~, k] = min(b);
                    files = ex(k);
                end
            end
            for f = unique(files, 'stable')
                rows(end+1, :) = {"extract", f, rootOf(f, roots)}; %#ok<AGROW>
            end

            if opts.Spikes && obj.has("spikes")
                f = string(obj.SpikesFile);
                rows(end+1, :) = {"spikes", f, rootOf(f, roots)};
            end

            if opts.Sorting ~= "none" || opts.SortedData
                if obj.has("sorting")
                    d = string(EphysDataset.resolvePhyDir(obj.SortingDir));
                    r = rootOf(d, roots);
                    if r == ""; r = string(fileparts(d)); end   % kept as <folder name>/..., so the copy finds it
                    switch opts.Sorting
                        case "all"
                            rows(end+1, :) = {"sorting", d, r};
                        case "essential"
                            for f = DatasetOutputs.essentialSortFiles(d)
                                rows(end+1, :) = {"sorting", f, r}; %#ok<AGROW>
                            end
                    end
                    if opts.SortedData
                        f = DatasetOutputs.sortedDataFile(d);
                        if f == ""
                            notes(end+1, 1) = "the sorted data file is not there"; %#ok<AGROW>
                        elseif ~(opts.Sorting == "all" && startsWith(lower(f), lower(d) + filesep))
                            rows(end+1, :) = {"sorted data", f, rootOf(f, roots)};
                        end
                    end
                else
                    notes(end+1, 1) = "no sorted units";
                end
            end

            if opts.Probe
                f = obj.probeFile();
                if f ~= ""
                    rows(end+1, :) = {"probe", f, ""};
                else
                    notes(end+1, 1) = "no probe file";
                end
            end
            T = table(string(rows(:, 1)), string(rows(:, 2)), string(rows(:, 3)), ...
                cellfun(@pathBytes, rows(:, 2)), 'VariableNames', {'Kind', 'Path', 'Base', 'Bytes'});
        end

        function f = signalFile(obj, type)
            %signalFile  The extract file holding signal TYPE ("" when none).
            %   Per-type files (<...>_LFP.mat) and combined files are searched
            %   newest first; a combined file is checked by loading its info,
            %   once (until the file changes or refresh()).
            type = upper(string(type));
            f = string.empty(1,0);
            for c = obj.resolve("extract")
                if ~isfile(c); continue; end
                tok = regexp(c, '_(LFP|MUA|SPIKE|AUX)\.mat$', 'tokens', 'once');
                if ~isempty(tok)
                    if tok{1} == type; f = c; return; end
                    continue
                end
                if any(obj.infoSignals(c) == type)
                    f = c;
                    return
                end
            end
        end

        function clearCache(obj)
            %clearCache  Drop data kept by CacheData.
            if ~isempty(obj.Cache)
                remove(obj.Cache, keys(obj.Cache));
            end
        end

        %% --- path properties -------------------------------------------------
        function f = get.ExtractFiles(obj);  f = obj.resolve("extract");   end
        function f = get.SpikesFile(obj);    f = obj.resolve("spikes");    end
        function f = get.ChronuxFile(obj);   f = obj.resolve("chronux");   end
        function f = get.FieldTripFile(obj); f = obj.resolve("fieldtrip"); end
        function f = get.EpochsFile(obj);    f = obj.resolve("epochs");    end
        function f = get.KCSDFile(obj);      f = obj.resolve("kcsd");      end
        function f = get.NWBFile(obj);       f = obj.resolve("nwb");       end
        function f = get.SortingDir(obj);    f = obj.resolve("sorting");   end
        function f = get.BehaviorFile(obj);  f = obj.resolve("behavior");  end
        function f = get.ManifestFile(obj);  f = obj.resolve("manifest");  end
        function f = get.ArtifactsFile(obj); f = obj.resolve("artifacts"); end

        function set.ExtractFiles(obj, f);  obj.pin("extract", f);   end
        function set.SpikesFile(obj, f);    obj.pin("spikes", f);    end
        function set.ChronuxFile(obj, f);   obj.pin("chronux", f);   end
        function set.FieldTripFile(obj, f); obj.pin("fieldtrip", f); end
        function set.EpochsFile(obj, f);    obj.pin("epochs", f);    end
        function set.KCSDFile(obj, f);      obj.pin("kcsd", f);      end
        function set.NWBFile(obj, f);       obj.pin("nwb", f);       end
        function set.SortingDir(obj, f);    obj.pin("sorting", f);   end
        function set.BehaviorFile(obj, f);  obj.pin("behavior", f);  end
        function set.ManifestFile(obj, f);  obj.pin("manifest", f);  end
        function set.ArtifactsFile(obj, f); obj.pin("artifacts", f); end

        %% --- data properties -------------------------------------------------
        function S = get.Extract(obj);   S = obj.load("extract");   end
        function S = get.LFP(obj);       S = obj.load("LFP");       end
        function S = get.MUA(obj);       S = obj.load("MUA");       end
        function S = get.SPIKE(obj);     S = obj.load("SPIKE");     end
        function S = get.AUX(obj);       S = obj.load("AUX");       end
        function S = get.Spikes(obj);    S = obj.load("spikes");    end
        function S = get.Units(obj);     S = obj.load("sorting");   end
        function S = get.Chronux(obj);   S = obj.load("chronux");   end
        function S = get.FieldTrip(obj); S = obj.load("fieldtrip"); end
        function S = get.Epochs(obj);    S = obj.load("epochs");    end
        function S = get.KCSD(obj);      S = obj.load("kcsd");      end
        function S = get.NWB(obj);       S = obj.load("nwb");       end
        function S = get.Behavior(obj);  S = obj.load("behavior");  end
        function S = get.Manifest(obj);  S = obj.load("manifest");  end
        function S = get.Artifacts(obj); S = obj.load("artifacts"); end

        function r = get.Roots(obj)
            r = string.empty(1,0);
            if ~isempty(obj.Dataset)
                r = [string(obj.Dataset.outputFolder()), obj.Dataset.Folder];
            elseif obj.Folder ~= ""
                r = obj.Folder;
            end
            r = stripSep([r, obj.SearchDirs]);
            r = r(strlength(r) > 0 & isfolder(r));
            [~, keep] = unique(lower(r), 'stable');
            r = r(sort(keep));
        end
    end

    methods (Access = private)
        function [f, src] = resolve(obj, kind)
            %resolve  Path(s) in effect for KIND and where they came from.
            kind = DatasetOutputs.checkKind(kind);
            p = obj.Pinned.(kind);
            if ~isempty(p)
                f = p; src = "manual";
                return
            end
            if isnat(obj.LastRefreshed) && obj.Name ~= ""
                obj.refresh();
            end
            f = string.empty(1,0); src = "";
            ds = obj.Dataset;
            switch kind
                case "sorting"
                    % A hand-picked folder is the association even while it
                    % is not there: no other sort is used instead.
                    if ~isempty(ds) && (ds.SortingDir ~= "" || isfile(fullfile(ds.sortingResultsDir(), 'params.py')))
                        f = string(ds.sortingResultsDir()); src = "dataset";
                        return
                    end
                    m = obj.manifestStruct();
                    if isfield(m, 'sorting') && isstruct(m.sorting) && isfield(m.sorting, 'results_dir')
                        d = string(m.sorting.results_dir);
                        manual = isfield(m.sorting, 'source') && string(m.sorting.source) == "manual";
                        if isscalar(d) && d ~= "" && (manual || isfile(fullfile(d, 'params.py')))
                            f = d; src = "manifest";
                            return
                        end
                    end
                    for root = obj.Roots
                        d = string(EphysDataset.resolvePhyDir(root));
                        if isfile(fullfile(d, 'params.py'))
                            f = d; src = "discovered";
                            return
                        end
                    end
                case "behavior"
                    f = obj.newest(kind);          % <Name>_behavior.mat
                    if ~isempty(f); src = "discovered"; return; end
                    if ~isempty(ds) && ds.BehaviorFile ~= ""
                        f = ds.BehaviorFile; src = "dataset";
                        return
                    end
                    m = obj.manifestStruct();
                    if isfield(m, 'behavior') && isstruct(m.behavior) && isfield(m.behavior, 'file')
                        b = string(m.behavior.file);
                        if b ~= ""; f = b; src = "manifest"; end
                    end
                case "manifest"
                    if ~isempty(ds) && isfile(ds.manifestFile())
                        f = string(ds.manifestFile()); src = "dataset";
                        return
                    end
                    f = obj.newest(kind);
                    if ~isempty(f); src = "discovered"; end
                case "extract"
                    % Newest file per signal type plus the newest combined
                    % file, newest first (so a later run's signals win).
                    C = obj.Candidates(obj.Candidates.Kind == "extract", :);
                    pick = false(height(C), 1);
                    for sig = ["" DatasetOutputs.SignalTypes]
                        i = find(C.Signal == sig, 1);   % already newest first
                        pick(i) = true;
                    end
                    f = C.File(pick).';
                    if ~isempty(f); src = "discovered"; end
                otherwise
                    f = obj.newest(kind);
                    if ~isempty(f); src = "discovered"; end
            end
        end

        function f = newest(obj, kind)
            f = obj.Candidates.File(find(obj.Candidates.Kind == kind, 1)).';
        end

        function pin(obj, kind, f)
            f = stripSep(string(f));
            f = f(strlength(f) > 0);
            if kind ~= "extract" && numel(f) > 1
                error('DatasetOutputs:Pin', '%s takes one path.', ...
                    DatasetOutputs.PathProps(DatasetOutputs.Kinds == kind));
            end
            obj.Pinned.(kind) = reshape(f, 1, []);   % 1x0 = not pinned
            obj.clearCache();
        end

        function types = infoSignals(obj, file)
            %infoSignals  Signal types the info of a combined extract FILE holds.
            %   Loaded once per file, size and modification time.
            s = dir(file);
            k = char(lower(file) + sprintf("|%.15g|%d", max([s.datenum 0]), max([s.bytes 0])));
            if isKey(obj.InfoSignals, k)
                types = obj.InfoSignals(k);
                return
            end
            types = string.empty(1, 0);
            try
                I = load(file, 'info');
                if isfield(I, 'info') && isstruct(I.info)
                    types = intersect(DatasetOutputs.SignalTypes, string(fieldnames(I.info)).', 'stable');
                end
            catch ME
                warning('DatasetOutputs:Unreadable', ...
                    'Cannot read the info of %s (%s); its signals are left out.', file, ME.message);
            end
            obj.InfoSignals(k) = types;
        end

        function m = manifestStruct(obj)
            %manifestStruct  The decoded manifest, or struct() (never errors).
            m = struct();
            f = obj.Pinned.manifest;
            if isempty(f)
                if ~isempty(obj.Dataset)
                    f = string(obj.Dataset.manifestFile());
                else
                    if isnat(obj.LastRefreshed) && obj.Name ~= ""; obj.refresh(); end
                    f = obj.newest("manifest");
                end
            end
            if isempty(f) || ~isfile(f); return; end
            s = readJsonFile(f, ErrorOnFail=false);
            if isstruct(s)
                m = s;
            else
                warning('DatasetOutputs:Unreadable', 'Cannot read the manifest %s; it is treated as empty.', f);
            end
        end

        function tf = belongs(obj, file, prov)
            %belongs  False when FILE's provenance names another dataset.
            %   Another dataset name, or - built from a dataset - another
            %   recording folder (sourceFolder, EphysDataset.isOwnSource).
            tf = true;
            if prov == ""; return; end
            try
                P = load(file, prov);
                tf = obj.ownsProvenance(P.(prov));
            catch ME
                warning('DatasetOutputs:Unreadable', ...
                    'Cannot read the provenance of %s (%s); it is counted as this dataset''s.', file, ME.message);
            end
        end

        function tf = ownsProvenance(obj, p)
            %ownsProvenance  False when provenance struct P names another
            %   dataset, or - built from a dataset - another recording folder.
            tf = true;
            if ~isstruct(p); return; end
            if isfield(p, 'dataset') && strlength(string(p.dataset)) > 0
                tf = strcmpi(string(p.dataset), obj.Name);
            end
            if tf && ~isempty(obj.Dataset) && isfield(p, 'sourceFolder') && strlength(string(p.sourceFolder)) > 0
                tf = obj.Dataset.isOwnSource(string(p.sourceFolder));
            end
        end

        function missing(obj, kind)
            where = obj.Roots;
            if isempty(where); where = "(no folders)"; end
            where = "searched " + strjoin(where, ", ");
            if ismember(kind, DatasetOutputs.Kinds)
                prop = DatasetOutputs.PathProps(DatasetOutputs.Kinds == kind);
                f = obj.resolve(kind);
                if ~isempty(f)   % a path in effect, but nothing there (moved, or on a disk not connected?)
                    where = "not found at " + strjoin(f, ", ");
                end
            else
                prop = "ExtractFiles";
            end
            error('DatasetOutputs:Missing', ...
                'No %s output found for dataset "%s" (%s). Set %s to its location, or refresh() after writing it.', ...
                kind, obj.Name, where, prop);
        end
    end

    methods (Access = protected)
        function groups = getPropertyGroups(obj)
            %getPropertyGroups  Show paths only; data properties load files.
            if ~isscalar(obj)
                groups = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
                return
            end
            groups = [ ...
                matlab.mixin.util.PropertyGroup({'Name', 'Folder', 'Dataset', 'Roots', ...
                    'SearchDirs', 'Recursive', 'CacheData', 'LastRefreshed'}), ...
                matlab.mixin.util.PropertyGroup(cellstr(DatasetOutputs.PathProps), ...
                    'Files in effect (assign to pin, "" to rediscover)')];
        end

        function s = getFooter(obj)
            if ~isscalar(obj); s = ''; return; end
            s = sprintf(['  Load on demand: Extract, LFP, MUA, SPIKE, AUX, Spikes, Units, ' ...
                'Chronux, FieldTrip, Epochs, KCSD, NWB, Behavior, Manifest, Artifacts\n' ...
                '  See inventory(), has(kind), load(kind, vars...), readUnits(...), readWaveforms(unitId)\n']);
        end
    end

    methods (Static)
        function T = emptyCandidates()
            %emptyCandidates  Schema of the Candidates table.
            T = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
                NaT(0,1), zeros(0,1), ...
                'VariableNames', {'Kind', 'File', 'Signal', 'Modified', 'Bytes'});
        end
    end

    methods (Static, Access = private)
        function f = essentialSortFiles(d)
            %essentialSortFiles  The files of sorting folder D the unit readers use (not the large feature files).
            %   readPhyUnits and readPhyWaveforms read these (and the
            %   cluster_*.tsv tables); templates and whitening_mat_inv.npy
            %   give the unit waveforms, settings.json the scale.
            names = ["spike_times.npy" "spike_clusters.npy" "spike_templates.npy" "spike_positions.npy" ...
                "amplitudes.npy" "templates.npy" "whitening_mat_inv.npy" "channel_map.npy" ...
                "channel_positions.npy" "channel_shanks.npy" "params.py" "settings.json"];
            L = dir(d);
            L = L(~[L.isdir]);
            n = string({L.name});
            keep = ismember(lower(n), lower(names)) | (startsWith(n, "cluster_") & endsWith(lower(n), ".tsv"));
            f = reshape(string(fullfile(d, n(keep))), 1, []);
        end

        function f = sortedDataFile(d)
            %sortedDataFile  The binary sorting folder D's params.py names, or "" when it is not there.
            %   The place EphysDataset.readPhyWaveforms looks: dat_path, its
            %   name in D, and in the two folders above.
            f = "";
            pf = fullfile(d, 'params.py');
            if ~isfile(pf); return; end
            tok = regexp(fileread(pf), 'dat_path\s*=\s*\[?\s*[''"]([^''"]+)[''"]', 'tokens', 'once');
            if isempty(tok) || tok{1} == "no_path.bin"; return; end
            p = string(tok{1});
            if isempty(regexp(p, '^([A-Za-z]:|[\\/])', 'once')); p = string(fullfile(d, p)); end
            [~, nm, ext] = fileparts(p);
            up1 = fileparts(d);
            tried = [p, string(fullfile(d, nm + ext)), string(fullfile(up1, nm + ext)), ...
                string(fullfile(fileparts(up1), nm + ext))];
            hit = find(arrayfun(@isfile, tried), 1);
            if ~isempty(hit); f = tried(hit); end
        end

        function kind = checkKind(kind)
            kind = lower(string(kind));
            if ~ismember(kind, DatasetOutputs.Kinds)
                error('DatasetOutputs:Kind', 'Unknown kind "%s" (expected %s).', ...
                    kind, strjoin(DatasetOutputs.Kinds, ", "));
            end
        end
    end
end


function p = stripSep(p)
p = regexprep(string(p), '[\\/]+$', '');
end


function r = rootOf(p, roots)
%rootOf  The first of ROOTS that P is below ("" for none): the folder its place in a copy is counted from.
r = "";
p = lower(string(p));
for k = reshape(string(roots), 1, [])
    if startsWith(p, lower(k) + filesep); r = k; return; end
end
end


function b = fileBytes(f)
d = dir(f);
b = Inf;
if ~isempty(d); b = d(1).bytes; end
end


function b = pathBytes(p)
%pathBytes  Bytes in the file P, or in the files below the folder P.
if isfolder(p)
    L = dir(fullfile(p, '**'));
    b = sum([L(~[L.isdir]).bytes]);
else
    b = fileBytes(p);
    if isinf(b); b = 0; end
end
end


function m = listFiles(tree, pattern)
%listFiles  Files of TREE (listTree) matching PATTERN: name, path, datenum, bytes.
d = matchFiles(tree, pattern);
d = d(~startsWith({d.name}, '~'));
m = struct('name', num2cell(string({d.name})), ...
    'path', num2cell(string(fullfile({d.folder}, {d.name}))), ...
    'datenum', {d.datenum}, 'bytes', {d.bytes});
end


function row = candidateRow(kind, m, sig)
row = table(string(kind), m.path, string(sig), ...
    datetime(m.datenum, 'ConvertFrom', 'datenum'), m.bytes, ...
    'VariableNames', {'Kind', 'File', 'Signal', 'Modified', 'Bytes'});
end


function [kind, prov] = classifyMat(file)
%classifyMat  Output kind of a .mat from its variable names ("" = not ours).
kind = ""; prov = "";
v = matVars(file);
if all(ismember(["export" "epochs"], v))
    kind = "epochs"; prov = "export";
elseif ismember("export", v) && any(ismember(["sp" "spDetected"], v))
    kind = "chronux"; prov = "export";
elseif ismember("export", v) && (any(ismember(["event" "spike" "spikeDetected"], v)) ...
        || any(startsWith(v, "data_")))
    kind = "fieldtrip"; prov = "export";
elseif all(ismember(["detected" "conversion"], v))
    kind = "spikes"; prov = "conversion";
elseif all(ismember(["Y" "info"], v))
    kind = "extract";
    if ismember("conversion", v); prov = "conversion"; end
elseif all(ismember(["behavior" "conversion"], v))
    kind = "behavior"; prov = "conversion";
end
end


function meta = nwbNotes(file)
%nwbNotes  The decoded JSON of an NWB file's /general/notes ([] when it has none or it is not JSON).
meta = [];
try
    info = h5info(file, '/general');
    if ~any(string({info.Datasets.Name}) == "notes"); return; end
    v = string(h5read(file, '/general/notes'));
catch ME
    warning('DatasetOutputs:Unreadable', 'Cannot read %s (%s); it is left out.', file, ME.message);
    return
end
try
    meta = jsondecode(char(v(1)));
catch
    meta = [];   % notes that are not JSON: another tool's file
end
end


function meta = npzMeta(file)
%npzMeta  The decoded JSON meta member of a .npz ([] when it has none or cannot be read).
meta = [];
try
    M = readNPZ(file, "meta");
    meta = jsondecode(M.meta);
catch ME
    if ME.identifier ~= "readNPZ:NoMember"   % an archive without meta is not one of ours
        warning('DatasetOutputs:Unreadable', 'Cannot read %s (%s); it is left out.', file, ME.message);
    end
end
end


function v = matVars(file)
%matVars  Variable names in a .mat file (empty when it cannot be read).
try
    w = whos('-file', file);
    v = string({w.name});
catch ME
    v = string.empty(1,0);
    warning('DatasetOutputs:Unreadable', 'Cannot read %s (%s); it is left out.', file, ME.message);
end
end


function S = loadMat(file, vars)
if isempty(vars)
    S = load(file);
else
    names = cellstr(vars);
    S = load(file, names{:});
end
end


function S = mergeExtract(S, T)
%mergeExtract  Add T's signals that S lacks; S (the newer file) wins.
if ~isfield(T, 'Y'); return; end
if ~isfield(S, 'Y'); S.Y = struct(); end
if ~isfield(S, 'info'); S.info = struct(); end
for sig = DatasetOutputs.SignalTypes
    if isfield(T.Y, sig) && ~isempty(T.Y.(sig)) ...
            && ~(isfield(S.Y, sig) && ~isempty(S.Y.(sig)))
        S.Y.(sig) = T.Y.(sig);
        if isfield(T, 'info') && isfield(T.info, sig)
            S.info.(sig) = T.info.(sig);
        end
    end
end
end


function S = trimToSignal(S, sig)
%trimToSignal  Keep only signal SIG in Y and info (as toMat's per-type files).
if isfield(S, 'Y') && isstruct(S.Y)
    if ~isfield(S.Y, sig) || isempty(S.Y.(sig))
        error('DatasetOutputs:SignalMissing', 'The extract holds no %s signal.', sig);
    end
    S.Y = struct(sig, S.Y.(sig));
end
if isfield(S, 'info') && isstruct(S.info)
    other = intersect(fieldnames(S.info), cellstr(setdiff(DatasetOutputs.SignalTypes, sig)));
    S.info = rmfield(S.info, other);
end
end
