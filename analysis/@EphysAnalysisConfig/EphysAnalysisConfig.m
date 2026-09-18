classdef EphysAnalysisConfig
    % EphysAnalysisConfig  A set of quick-look figures, described in one value.
    %   An analysis config says which datasets to read, how to align them
    %   (an event reference, an epoch window and a trial selection shared by
    %   every plot unless a plot overrides them), which plots to draw and
    %   how to export them and report on them. It has no GUI dependency:
    %   EphysAnalysisApp edits one, EphysAnalysisRunner runs one, and
    %   EphysAnalysisScript writes scripts from one. It round-trips through
    %   JSON exactly (Inf / NaN / empty values included).
    %
    %   Sections (see defaults(section))
    %     Source    Mode "project" (a pipeline project: Root, OutputRoot,
    %               NamePattern, Selection "all"|"list", Datasets keys) or
    %               "folders" (Folders: the output folders themselves)
    %     Defaults  EventRef, Window (EpochWindow) and Selection
    %               (TrialSelection) used by every plot whose ref / window /
    %               selection is "default"
    %     Plots     struct array, one entry per plot (defaults("Plot")): id,
    %               kind (see Kinds / plotKinds), enabled, source, units,
    %               channels, ref, window, selection, bins, baseline, layout,
    %               withRaster, maskAfterStop, param, seriesParam, value,
    %               order, style
    %     Export    figure files: Formats (png / eps / svg / pdf), Folder and
    %               FilenamePattern with tokens, Dpi, FigureSizeCm
    %     Report    one HTML and / or multi-page PDF report per run (or per
    %               dataset)
    %
    %   Usage
    %     cfg = EphysAnalysisConfig();
    %     cfg.Source.Root = "D:\EPHYS";
    %     cfg.Defaults.EventRef.line = "Stim";
    %     cfg.Defaults.Selection.groupBy = "Depth";
    %     cfg = cfg.addPlot("psth");
    %     cfg = cfg.addPlot(struct('kind', "evoked", 'source', "LFP"));
    %     cfg.save("am_quicklook.json");
    %     r = EphysAnalysisRunner(EphysAnalysisConfig.load("am_quicklook.json"));
    %     r.run();
    %
    %   Values are coerced to the type and shape of the default whenever a
    %   section is assigned, so what JSON gives back (a one-element list as a
    %   scalar, "Inf" as text, a heterogeneous Plots array as a cell) comes
    %   out right. Unknown fields are dropped (LoadWarnings lists them after
    %   load). Plot ids must be unique (EphysAnalysisConfig:DuplicatePlotId);
    %   a plot without an id gets "<kind>_<n>".
    %
    %   See also EphysAnalysisRunner, EphysAnalysisScript, EphysAnalysisApp,
    %   EphysAnalysisConfig.defaults, EphysAnalysisConfig.validate.

    properties
        Name        (1,1) string = "Untitled"
        Description (1,1) string = ""
        Source      struct = EphysAnalysisConfig.defaults("Source")
        Defaults    struct = EphysAnalysisConfig.defaults("Defaults")
        Plots       struct = EphysAnalysisConfig.emptyPlots()
        Export      struct = EphysAnalysisConfig.defaults("Export")
        Report      struct = EphysAnalysisConfig.defaults("Report")
    end

    properties (Transient)
        File         (1,1) string = ""            % where it was loaded from / saved to
        LoadWarnings (1,:) string = string.empty(1,0)
    end

    properties (Constant)
        Schema   = "ephys-analysis-config"
        Version  = 1
        Sections = ["Source" "Defaults" "Export" "Report"]
        Kinds    = ["psth" "raster" "evoked" "rate" "tuning" "heatmap" "probemap"]
        SpikeSources  = ["units" "detected"]
        SignalSources = ["LFP" "MUA" "SPIKE" "AUX"]
        % String fields that are lists even when their default has one element.
        ListFields = ["response" "pairingFlags" "groupBy" "classes" "groups" "Formats" "Datasets" "Folders"]
    end

    methods
        % --- methods defined in separate files ---
        issues = validate(obj, opts)

        function obj = EphysAnalysisConfig(s)
            %EphysAnalysisConfig  Defaults, or from a struct (see fromStruct).
            if nargin > 0 && ~isempty(s)
                obj = EphysAnalysisConfig.fromStruct(s);
            end
        end

        %% --- normalizing setters -------------------------------------------
        function obj = set.Source(obj, s);   obj.Source   = EphysAnalysisConfig.normalizeSection("Source", s);   end
        function obj = set.Defaults(obj, s); obj.Defaults = EphysAnalysisConfig.normalizeSection("Defaults", s); end
        function obj = set.Export(obj, s);   obj.Export   = EphysAnalysisConfig.normalizeSection("Export", s);   end
        function obj = set.Report(obj, s);   obj.Report   = EphysAnalysisConfig.normalizeSection("Report", s);   end
        function obj = set.Plots(obj, p);    obj.Plots    = EphysAnalysisConfig.normalizePlots(p);               end

        %% --- struct / JSON --------------------------------------------------
        function s = toStruct(obj)
            %toStruct  Plain struct (schema, version, name, description, sections, Plots).
            s = struct('schema', EphysAnalysisConfig.Schema, 'version', EphysAnalysisConfig.Version, ...
                'name', obj.Name, 'description', obj.Description, ...
                'Source', obj.Source, 'Defaults', obj.Defaults, 'Plots', obj.Plots, ...
                'Export', obj.Export, 'Report', obj.Report);
        end

        function obj = save(obj, file)
            %save  Write the config as pretty JSON (atomic; Inf/NaN as strings).
            arguments
                obj (1,1) EphysAnalysisConfig
                file (1,1) string
            end
            writeJsonFile(file, obj.toStruct(), NonFinite="string");
            obj.File = file;
        end

        function tf = isequalConfig(obj, other)
            %isequalConfig  True when two configs hold the same values (NaN == NaN).
            tf = isequaln(obj.toStruct(), other.toStruct());
        end

        %% --- plots ------------------------------------------------------------
        function [obj, id] = addPlot(obj, p, opts)
            %addPlot  Append a plot: a kind ("psth") or a (partial) plot struct.
            %   [CFG, ID] = cfg.addPlot("rate", Id="rate_platform") returns the
            %   new config and the plot's id (assigned when not given).
            arguments
                obj (1,1) EphysAnalysisConfig
                p = "psth"
                opts.Id (1,1) string = ""
            end
            if isstring(p) || ischar(p)
                p = struct('kind', string(p));
            end
            if opts.Id ~= ""; p.id = opts.Id; end
            p = EphysAnalysisConfig.normalizePlot(p);
            if p.id == ""
                p.id = EphysAnalysisConfig.freeId(p.kind, [obj.Plots.id]);
            end
            obj.Plots = [obj.Plots, p];
            id = p.id;
        end

        function obj = removePlot(obj, id)
            %removePlot  Drop the plot with this id (error when there is none).
            k = obj.plotIndex(id);
            if k == 0
                error('EphysAnalysisConfig:NoPlot', 'No plot "%s".', id);
            end
            obj.Plots(k) = [];
        end

        function k = plotIndex(obj, id)
            %plotIndex  Index of the plot with this id in Plots (0 = none).
            k = find([obj.Plots.id] == string(id), 1);
            if isempty(k); k = 0; end
        end

        function ids = enabledPlots(obj)
            %enabledPlots  Ids of the enabled plots, in order.
            if isempty(obj.Plots)
                ids = string.empty(1, 0);
            else
                ids = [obj.Plots([obj.Plots.enabled]).id];
                if isempty(ids); ids = string.empty(1, 0); end
            end
        end

        function spec = plotFor(obj, id)
            %plotFor  A plot with every "default" resolved: what the runner draws.
            %   SPEC = cfg.plotFor(ID) (ID a plot id or an index) is the plot
            %   entry with ref / window / selection taken from Defaults when they
            %   are "default", units.source set to the plot's source (spike
            %   kinds), and layout set to the kind's default when "".
            if isnumeric(id)
                k = id;
            else
                k = obj.plotIndex(id);
            end
            if k < 1 || k > numel(obj.Plots)
                error('EphysAnalysisConfig:NoPlot', 'No plot "%s".', string(id));
            end
            spec = obj.Plots(k);
            if isequal(spec.ref, "default");       spec.ref = obj.Defaults.EventRef;   end
            if isequal(spec.window, "default");    spec.window = obj.Defaults.Window;  end
            if isequal(spec.selection, "default"); spec.selection = obj.Defaults.Selection; end
            u = spec.units;
            u.source = spec.source;
            spec.units = orderfields(u, EphysAnalysisConfig.defaults("UnitSelection"));
            if spec.layout == ""
                K = EphysAnalysisConfig.plotKinds();
                row = K.Kind == spec.kind;
                if any(row); spec.layout = K.DefaultLayout(row); end
            end
        end
    end

    methods (Static)
        % --- methods defined in separate files ---
        s = defaults(section)
        [s, unknown] = normalizeSection(section, in)
        [p, unknown] = normalizePlot(in, path)
        T = plotKinds()

        function obj = fromStruct(s)
            %fromStruct  Build a config from a struct (e.g. decoded JSON).
            %   Missing sections take their defaults; unknown fields are dropped
            %   and listed in LoadWarnings.
            arguments
                s (1,1) struct
            end
            obj = EphysAnalysisConfig();
            warn = string.empty(1, 0);
            if isfield(s, 'name');        obj.Name = string(s.name);               end
            if isfield(s, 'description'); obj.Description = string(s.description); end
            for sec = EphysAnalysisConfig.Sections
                if isfield(s, sec)
                    [v, unknown] = EphysAnalysisConfig.normalizeSection(sec, s.(sec));
                    obj.(sec) = v;
                    if ~isempty(unknown)
                        warn(end+1) = sec + ": dropped unknown field(s) " + strjoin(unknown, ", "); %#ok<AGROW>
                    end
                end
            end
            if isfield(s, 'Plots')
                [obj.Plots, unknown] = EphysAnalysisConfig.normalizePlots(s.Plots);
                if ~isempty(unknown)
                    warn(end+1) = "Plots: dropped unknown field(s) " + strjoin(unknown, ", ");
                end
            end
            known = ["schema" "version" "name" "description" "Plots" EphysAnalysisConfig.Sections];
            extra = setdiff(string(fieldnames(s)).', known);
            if ~isempty(extra)
                warn(end+1) = "dropped unknown top-level field(s) " + strjoin(extra, ", ");
            end
            obj.LoadWarnings = warn;
        end

        function obj = load(file)
            %load  Read a config JSON; errors on a wrong schema or version.
            arguments
                file (1,1) string
            end
            s = readJsonFile(file);
            if ~isstruct(s) || ~isfield(s, 'schema') || string(s.schema) ~= EphysAnalysisConfig.Schema
                error('EphysAnalysisConfig:BadSchema', ...
                    '%s is not an %s file.', file, EphysAnalysisConfig.Schema);
            end
            if ~isfield(s, 'version') || double(s.version) ~= EphysAnalysisConfig.Version
                error('EphysAnalysisConfig:BadSchema', ...
                    '%s has config version %s; this code reads version %d only.', ...
                    file, string(jsonencode(s.version)), EphysAnalysisConfig.Version);
            end
            obj = EphysAnalysisConfig.fromStruct(s);
            obj.File = file;
            if ~isempty(obj.LoadWarnings)
                warning('EphysAnalysisConfig:LoadWarnings', '%s: %s', file, strjoin(obj.LoadWarnings, '; '));
            end
        end

        function p = emptyPlots()
            %emptyPlots  A 1x0 struct array with the plot fields.
            p = repmat(EphysAnalysisConfig.defaults("Plot"), 1, 0);
        end

        function [P, unknown] = normalizePlots(v)
            %normalizePlots  Plots from a struct array, a cell array (jsondecode) or [].
            %   Every entry is normalized (normalizePlot); entries without an id
            %   get "<kind>_<n>"; duplicate ids raise
            %   EphysAnalysisConfig:DuplicatePlotId.
            P = EphysAnalysisConfig.emptyPlots();
            unknown = string.empty(1, 0);
            if isempty(v); return; end
            if isstruct(v)
                v = num2cell(v);
            elseif ~iscell(v)
                error('EphysAnalysisConfig:BadValue', 'Plots must be a struct array or a cell array of structs.');
            end
            for k = 1:numel(v)
                [p, u] = EphysAnalysisConfig.normalizePlot(v{k}, "Plots(" + k + ")");
                unknown = [unknown, u]; %#ok<AGROW>
                P(1, end+1) = p; %#ok<AGROW>
            end
            ids = [P.id];
            [~, first] = unique(ids(ids ~= ""), 'stable');
            given = ids(ids ~= "");
            dup = given(setdiff(1:numel(given), first));
            if ~isempty(dup)
                error('EphysAnalysisConfig:DuplicatePlotId', 'Plot id "%s" is used more than once.', dup(1));
            end
            for k = find(ids == "")
                P(k).id = EphysAnalysisConfig.freeId(P(k).kind, [P.id]);
            end
        end
    end

    methods (Static, Hidden)
        [out, unknown] = coerceStruct(def, in, path)

        function id = freeId(kind, used)
            %freeId  "<kind>_<n>" with the smallest n not in USED.
            n = 1;
            while any(used == kind + "_" + n)
                n = n + 1;
            end
            id = kind + "_" + n;
        end
    end
end
