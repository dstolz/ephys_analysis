classdef DatasetOutputs < handle & matlab.mixin.CustomDisplay
    % DatasetOutputs  One dataset's processed files, found once and loaded on demand.
    %   A DatasetOutputs keeps track of every file the pipeline writes for one
    %   dataset -- derived signals, spikes, analysis-toolbox exports,
    %   sorted units, the Epsych2 behavior session, the manifest and the
    %   artifact cache -- wherever they live, and loads each one only when its
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
    %     spikes     detected + units + conversion (spikesToMat)
    %     chronux    export + sp                   (exportChronux)
    %     fieldtrip  export + event / spike / data_* (exportFieldTrip)
    %     behavior   behavior + conversion         (behaviorToMat)
    %   A file whose provenance struct (conversion / export) names another
    %   dataset is skipped. <Name>_manifest.json and <Name>_artifacts.json are
    %   found by name. When several files of one kind exist, the newest wins;
    %   every candidate is listed in Candidates.
    %
    %   Search roots: the dataset's outputFolder() and Folder (or FOLDER when
    %   constructed from a folder), plus SearchDirs, recursively unless
    %   Recursive=false. Sorted units come from the dataset's
    %   sortingResultsDir(), else the manifest's sorting.results_dir, else the
    %   standard kilosort4 layouts under the roots. BehaviorFile is the
    %   <Name>_behavior.mat file; until one has been written it falls back to
    %   the associated Epsych2 session (the dataset's BehaviorFile, else the
    %   manifest's behavior.file), which loads into the same struct.
    %
    %   Manual paths
    %   ------------
    %   The path properties (ExtractFiles, SpikesFile, ChronuxFile,
    %   FieldTripFile, SortingDir, BehaviorFile, ManifestFile, ArtifactsFile)
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
    %     Spikes, Chronux, FieldTrip   the file's variables as a struct
    %     Units        readSortedUnits (with a dataset) / readPhyUnits defaults
    %     Behavior     trials, info, meta, file, subject, startTime, nTrials
    %                  (the EphysDataset.behaviorStruct shape), from
    %                  <Name>_behavior.mat or the Epsych2 session itself
    %     Manifest, Artifacts   the decoded JSON
    %   Reading a property whose file is missing raises DatasetOutputs:Missing;
    %   has(kind) checks first. load(kind, vars...) loads selected variables
    %   only, and readUnits(Name=Value) forwards unit-reading options. Set
    %   CacheData=true to keep loaded data in memory (clearCache frees it).
    %
    %   See also EphysDataset.outputs, EphysPipeline.outputsFor, DatasetTracker,
    %   EphysDataset.toMat, EphysDataset.spikesToMat, EphysDataset.behaviorToMat,
    %   EphysDataset.exportChronux, EphysDataset.exportFieldTrip.

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
        LastRefreshed datetime = NaT
    end

    properties (Dependent)
        % Paths in effect. Assign to pin; assign "" to use discovery again.
        ExtractFiles    % derived-signal .mat file(s), newest first
        SpikesFile      % spikesToMat output
        ChronuxFile     % exportChronux output
        FieldTripFile   % exportFieldTrip output
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
        Behavior
        Manifest
        Artifacts
        Roots           % folders searched by refresh()
    end

    properties (Constant)
        Kinds = ["extract" "spikes" "chronux" "fieldtrip" "sorting" "behavior" "manifest" "artifacts"]
        SignalTypes = ["LFP" "MUA" "SPIKE" "AUX"]
    end

    properties (Constant, Access = private)
        PathProps = ["ExtractFiles" "SpikesFile" "ChronuxFile" "FieldTripFile" ...
                     "SortingDir" "BehaviorFile" "ManifestFile" "ArtifactsFile"]
    end

    properties (Access = private)
        Pinned = struct('extract', string.empty(1,0), 'spikes', string.empty(1,0), ...
            'chronux', string.empty(1,0), 'fieldtrip', string.empty(1,0), ...
            'sorting', string.empty(1,0), 'behavior', string.empty(1,0), ...
            'manifest', string.empty(1,0), 'artifacts', string.empty(1,0))
        Cache = []
    end

    methods
        function obj = DatasetOutputs(source, opts)
            %DatasetOutputs  Track the processed files of a dataset or a folder.
            %   out = DatasetOutputs(ds)        an EphysDataset
            %   out = DatasetOutputs(folder)    a folder holding the outputs
            %   out = DatasetOutputs()          empty; set Name/Folder, then refresh
            %   Options: Name (default ds.Name or the folder leaf), SearchDirs,
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
                    [~, leaf] = fileparts(char(stripSep(folder)));
                    obj.Name = string(leaf);
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
            T = DatasetOutputs.emptyCandidates();
            prefix = "^" + string(regexptranslate('escape', char(obj.Name))) + "([_\-. ].*)?";
            for root = obj.Roots
                mats = listFiles(root, "*.mat", obj.Recursive);
                for k = 1:numel(mats)
                    m = mats(k);
                    if isempty(regexpi(m.name, prefix + "\.mat$", 'once')); continue; end
                    [kind, prov] = classifyMat(m.path);
                    if kind == "" || ~obj.belongs(m.path, prov); continue; end
                    sig = "";
                    if kind == "extract"
                        tok = regexp(m.name, '_(LFP|MUA|SPIKE|AUX)\.mat$', 'tokens', 'once');
                        if ~isempty(tok); sig = string(tok{1}); end
                    end
                    T = [T; candidateRow(kind, m, sig)]; %#ok<AGROW>
                end
                for kind = ["manifest" "artifacts"]
                    js = listFiles(root, obj.Name + "_" + kind + ".json", obj.Recursive);
                    for k = 1:numel(js)
                        T = [T; candidateRow(kind, js(k), "")]; %#ok<AGROW>
                    end
                end
            end
            [~, keep] = unique(lower(T.File), 'stable');
            T = T(keep, :);
            obj.Candidates = sortrows(T, 'Modified', 'descend');
            obj.LastRefreshed = datetime('now');
        end

        function tf = has(obj, kind)
            %has  True when the file (or folder) for KIND exists.
            %   KIND: "extract" | "spikes" | "chronux" | "fieldtrip" | "sorting"
            %   | "behavior" | "manifest" | "artifacts" | "LFP" | "MUA" |
            %   "SPIKE" | "AUX".
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
                case {"spikes", "chronux", "fieldtrip"}
                    S = loadMat(files, vars);
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
            %   EphysDataset.readPhyUnits (without one; the manifest's probe
            %   file is used for the SpikeInterface channel mapping).
            if ~obj.has("sorting")
                obj.missing("sorting");
            end
            d = obj.resolve("sorting");
            if ~isempty(obj.Dataset)
                [units, info] = obj.Dataset.readSortedUnits('ResultsDir', d, varargin{:});
                return
            end
            args = {};
            m = obj.manifestStruct();
            if isfield(m, 'probe') && isstruct(m.probe) && isfield(m.probe, 'file') ...
                    && isfile(string(m.probe.file))
                args = {'ProbeFile', string(m.probe.file)};
            end
            [units, info] = EphysDataset.readPhyUnits(d, args{:}, varargin{:});
        end

        function f = signalFile(obj, type)
            %signalFile  The extract file holding signal TYPE ("" when none).
            %   Per-type files (<...>_LFP.mat) and combined files are searched
            %   newest first; a combined file is checked by loading its info.
            type = upper(string(type));
            f = string.empty(1,0);
            for c = obj.resolve("extract")
                if ~isfile(c); continue; end
                tok = regexp(c, '_(LFP|MUA|SPIKE|AUX)\.mat$', 'tokens', 'once');
                if ~isempty(tok)
                    if tok{1} == type; f = c; return; end
                    continue
                end
                try
                    I = load(c, 'info');
                    if isfield(I, 'info') && isfield(I.info, type)
                        f = c;
                        return
                    end
                catch
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
        function f = get.SortingDir(obj);    f = obj.resolve("sorting");   end
        function f = get.BehaviorFile(obj);  f = obj.resolve("behavior");  end
        function f = get.ManifestFile(obj);  f = obj.resolve("manifest");  end
        function f = get.ArtifactsFile(obj); f = obj.resolve("artifacts"); end

        function set.ExtractFiles(obj, f);  obj.pin("extract", f);   end
        function set.SpikesFile(obj, f);    obj.pin("spikes", f);    end
        function set.ChronuxFile(obj, f);   obj.pin("chronux", f);   end
        function set.FieldTripFile(obj, f); obj.pin("fieldtrip", f); end
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
                    if ~isempty(ds) && isfile(fullfile(ds.sortingResultsDir(), 'params.py'))
                        f = string(ds.sortingResultsDir()); src = "dataset";
                        return
                    end
                    m = obj.manifestStruct();
                    if isfield(m, 'sorting') && isstruct(m.sorting) && isfield(m.sorting, 'results_dir')
                        d = string(m.sorting.results_dir);
                        if d ~= "" && isfile(fullfile(d, 'params.py'))
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
            if isstruct(s); m = s; end
        end

        function tf = belongs(obj, file, prov)
            %belongs  False when FILE's provenance names another dataset.
            tf = true;
            if prov == ""; return; end
            try
                P = load(file, prov);
                p = P.(prov);
                if isstruct(p) && isfield(p, 'dataset') && strlength(string(p.dataset)) > 0
                    tf = strcmpi(string(p.dataset), obj.Name);
                end
            catch
            end
        end

        function missing(obj, kind)
            if ismember(kind, DatasetOutputs.Kinds)
                prop = DatasetOutputs.PathProps(DatasetOutputs.Kinds == kind);
            else
                prop = "ExtractFiles";
            end
            roots = obj.Roots;
            if isempty(roots); roots = "(no folders)"; end
            error('DatasetOutputs:Missing', ...
                'No %s output found for dataset "%s" (searched %s). Set %s to its location, or refresh() after writing it.', ...
                kind, obj.Name, strjoin(roots, ", "), prop);
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
                'Chronux, FieldTrip, Behavior, Manifest, Artifacts\n' ...
                '  See inventory(), has(kind), load(kind, vars...), readUnits(...)\n']);
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


function m = listFiles(root, pattern, recursive)
%listFiles  Files matching PATTERN under ROOT: name, path, datenum, bytes.
if recursive
    d = dir(fullfile(root, '**', pattern));
else
    d = dir(fullfile(root, pattern));
end
d = d(~[d.isdir]);
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
if ismember("export", v) && any(ismember(["sp" "spDetected"], v))
    kind = "chronux"; prov = "export";
elseif ismember("export", v) && (any(ismember(["event" "spike" "spikeDetected"], v)) ...
        || any(startsWith(v, "data_")))
    kind = "fieldtrip"; prov = "export";
elseif all(ismember(["detected" "units" "conversion"], v))
    kind = "spikes"; prov = "conversion";
elseif all(ismember(["Y" "info"], v))
    kind = "extract";
    if ismember("conversion", v); prov = "conversion"; end
elseif all(ismember(["behavior" "conversion"], v))
    kind = "behavior"; prov = "conversion";
end
end


function v = matVars(file)
%matVars  Variable names in a .mat file (empty when it cannot be read).
try
    w = whos('-file', file);
    v = string({w.name});
catch
    v = string.empty(1,0);
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
