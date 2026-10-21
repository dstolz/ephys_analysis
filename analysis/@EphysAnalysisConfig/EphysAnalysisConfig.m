classdef EphysAnalysisConfig
    % EphysAnalysisConfig  A set of quick-look figures, described in one value.
    %   An analysis config says which datasets to read, how to align them
    %   (an event reference, an epoch window and a trial selection shared by
    %   every figure unless a figure or panel overrides them), which figures
    %   to draw and how to export them and report on them. It has no GUI
    %   dependency: EphysAnalysisApp edits one, EphysAnalysisRunner runs
    %   one, and EphysAnalysisScript writes scripts from one. It round-trips
    %   through JSON exactly (Inf / NaN / empty values included).
    %
    %   Sections (see defaults(section))
    %     Source    Mode "project" (a pipeline project: Root, OutputRoot,
    %               NamePattern, Selection "all"|"list", Datasets keys) or
    %               "folders" (Folders: the output folders themselves)
    %     Defaults  EventRef, Window (EpochWindow) and Selection
    %               (TrialSelection) used by every figure whose ref / window /
    %               selection is "default"
    %     Figures   struct array, one entry per figure (defaults("Figure")):
    %               one observation's panels (a unit, a channel or the
    %               dataset: observe) on a grid with spans (grid), each
    %               panel of a type (panelTypes) drawing one or more layers,
    %               each layer bound to a source (FigureSources) that either
    %               follows the observation or names fixed items: id,
    %               autoId, enabled, title, observe, grid, panels, ref,
    %               window, selection, sessions, style, aesthetics.
    %               sessions (defaults("FigureSessions")) with enabled true
    %               makes it a session figure: drawn once across the ticked
    %               (or listed) datasets, each layer merged across them
    %               (figureSessionCompute, EphysAnalysisRunner.runSessionFigure),
    %               never per dataset. Each panel holds all of its own
    %               options; adoptPanelOptions copies one panel's to the
    %               others (sharedFieldsOf: the options several types
    %               have), with its axis sides, adoptPanelAlignment and relinkPanels spread one
    %               panel's alignment or re-link every panel's.
    %               observe.perGroup draws each observation once
    %               per trial group of the figure's selection;
    %               observe.starred keeps only the starred observations
    %               (DatasetFavorites). A panel
    %               (defaults("Panel")): id, type, title, box (the axes'
    %               box: "auto" = the design's, "on", "off"), xLabel and
    %               yLabel ("" = automatic), xSide ("bottom" | "top") and
    %               ySide ("left" | "right"), row, col,
    %               rowSpan, colSpan, ref, window, selection (its own:
    %               its own groups, colors and legend), layers, options
    %               (the type's DefaultOptions), note
    %               (a Note) and overlays (Overlays drawn on
    %               its own axes: their panel is always "all"); a layer
    %               (defaults("Layer")): name, enabled, source, binding,
    %               units, channels, aggregate, event, eventsAs, color,
    %               lineStyle. Figure ids are a
    %               namespace of their own (DuplicateFigureId), panel ids
    %               one per figure (DuplicatePanelId); figureFor(id) is the
    %               spec the compute draws. The run draws each enabled
    %               figure once per observation on each dataset
    %               (EphysAnalysisRunner.runDataset), a file each named by
    %               figureOutputName ({Plot} its id, {Unit} the observation,
    %               {Group} its trial group per group)
    %     Export    figure files: Formats (png / eps / svg / pdf), Folder and
    %               FilenamePattern with tokens, Dpi, FigureSizeCm;
    %               SessionsFolder (the session figures' files) and Data
    %               (the session figures' .mat data files: Enabled, Folder,
    %               FilenamePattern, MatVersion)
    %     Report    one HTML and / or multi-page PDF report per run (or per
    %               dataset)
    %
    %   Usage
    %     cfg = EphysAnalysisConfig();
    %     cfg.Source.Root = "D:\EPHYS";
    %     cfg.Defaults.EventRef.line = "Stim";
    %     cfg.Defaults.Selection.groupBy = "Depth";
    %     cfg = cfg.addFigure("rasterPsth");   % "Raster+PSTH units": a unit's raster over its PSTH
    %     cfg = cfg.addFigure("continuous");   % "Continuous LFP": a channel's LFP
    %     cfg.save("am_quicklook.json");
    %     r = EphysAnalysisRunner(EphysAnalysisConfig.load("am_quicklook.json"));
    %     r.run();
    %
    %   Values are coerced to the type and shape of the default whenever a
    %   section is assigned, so what JSON gives back (a one-element list as a
    %   scalar, "Inf" as text, a heterogeneous Figures array as a cell) comes
    %   out right. Unknown fields are dropped (LoadWarnings lists them after
    %   load). Figure ids must be unique (EphysAnalysisConfig:DuplicateFigureId).
    %   A figure's id is automatic while its autoId is true (a new figure's,
    %   until an id of the user's own is given): it follows the figure's
    %   panels and data (autoFigureId: "Raster+PSTH units"), made unique by
    %   " (2)", " (3)", ... (nextFreeId), whenever Figures is assigned (every
    %   edit, load). A figure with autoId false and no id gets "figure_<n>";
    %   a figure's panel without an id gets "<type>_<n>".
    %
    %   Version 2 (this one) has no plots: config version 1's Plots and
    %   SessionPlots sections are migrated once, when a version-1 file is
    %   loaded (load, fromStruct): every plot becomes a figure of the same id
    %   and every session plot a session figure (Figure.sessions), each note
    %   of what could not be carried a LoadWarnings line ("plot psth_1
    %   migrated to figure psth_1: ..."); save writes version 2. The
    %   migration lives in private/legacy*.m (legacyMigrate,
    %   legacyPlotToFigure, legacyNormalizePlot, legacyPlotDefaults,
    %   legacyPlotKinds) and is used for nothing else.
    %
    %   See also EphysAnalysisRunner, EphysAnalysisScript, EphysAnalysisApp,
    %   EphysAnalysisConfig.defaults, EphysAnalysisConfig.validate.

    properties
        Name        (1,1) string = "Untitled"
        Description (1,1) string = ""
        Source      struct = EphysAnalysisConfig.defaults("Source")
        Defaults    struct = EphysAnalysisConfig.defaults("Defaults")
        Figures     = EphysAnalysisConfig.emptyFigures() % struct array; set.Figures also takes a cell (jsondecode)
        Export     struct = EphysAnalysisConfig.defaults("Export")
        Report      struct = EphysAnalysisConfig.defaults("Report")
    end

    properties (Transient)
        File         (1,1) string = ""            % where it was loaded from / saved to
        LoadWarnings (1,:) string = string.empty(1,0)
    end

    properties (Constant)
        Schema   = "ephys-analysis-config"
        Version  = 2   % version 1 files (Plots, SessionPlots) are migrated on load (private/legacyMigrate)
        Sections = ["Source" "Defaults" "Export" "Report"]
        SpikeSources  = ["units" "detected"]
        SignalSources = ["LFP" "MUA" "SPIKE" "AUX"]
        % What a figure layer reads (Layer.source): spike times, a digital / derived line's events, or a signal;
        % sourceCategories groups them, panelTypes says which categories each panel type draws.
        FigureSources = ["units" "detected" "events" "LFP" "MUA" "SPIKE" "AUX"]
        % What a figure is drawn for (Figure.observe.data): each sorted unit, each channel's detections, each channel of
        % a signal's extract, or the dataset once (observeKind: "unit", "channel" or "dataset").
        ObserveData   = ["units" "detected" "LFP" "MUA" "SPIKE" "AUX" "dataset"]
        % Where in a unit's tile its waveform box sits (a panel's waveform.location).
        WaveformLocations = ["northeast" "north" "northwest" "west" "southwest" "south" "southeast" "east"]
        % The error a figure draws as bands or bars (Style.ErrorType): mean +/- SEM, mean +/- SD, bootstrap 95% CI of the mean.
        ErrorTypes    = ["sem" "std" "ci95"]
        % What a continuous panel shows at each sample over the epochs (options.statistic), and of what
        % (options.transform): the signal as recorded, rectified (its absolute value, taken in each epoch before
        % the statistic), or the vector magnitude of each layer's channels (sqrt of their sum of squares at every
        % sample of each epoch, after the baseline: one trace, e.g. of a 3-axis accelerometer's channels).
        AuxStatistics = ["mean" "median"]
        AuxTransforms = ["none" "rectify" "magnitude"]
        % Its error band (options.errorType): off, mean +/- SEM, mean +/- SD, bootstrap 95% CI, or the interquartile range.
        AuxErrorTypes = ["off" "sem" "std" "ci95" "iqr"]
        % Where a panel's note sits (note.placement): outside the panel, over it, or at a point.
        NotePlacements = ["below" "above" "right" "left" "northwest" "north" "northeast" "west" "center" "east" ...
            "southwest" "south" "southeast" "custom"]
        % The gap between a figure's panels (grid.spacing): a named gap of GridSpacingPx px (in that order), or custom
        % (grid.rowGap / colGap, or the lists rowGaps / colGaps, in grid.gapUnits); and where a panel smaller than its
        % cell sits in it (panel.align, panel.valign).
        GridSpacings  = ["loose" "compact" "tight" "none" "custom"]
        GridSpacingPx = [24 12 6 0]
        GridGapUnits  = ["px" "%"]
        PanelAligns   = ["left" "center" "right"]
        PanelVAligns  = ["top" "middle" "bottom"]
        % The sides a panel's x and y axes take, their ticks and label (panel.xSide, panel.ySide).
        PanelXSides   = ["bottom" "top"]
        PanelYSides   = ["left" "right"]
        % What a panel's overlays (defaults("Overlay")) choose from: the layer, a line's style.
        OverlayLayers     = ["over" "under"]
        OverlayLineStyles = ["-" "--" ":" "-."]
        % Session figures (Figure.sessions): what gets a color (series), the band across sessions (error), the
        % figure's trial groups (trialGroups), the figures per subject (facet) and the colors' order.
        SessionSeries = ["session" "subject" "all"]
        SessionErrors = ["sem" "sd" "ci95" "none"]
        SessionTrialGroups = ["pool" "each" "combine"]
        SessionFacets = ["none" "subject"]
        SessionColorOrders = ["palette" "sequential"]
        % How the observed unit is matched across sessions (a figure observes one matched unit), and the panel types
        % combineSessions does not merge (a session figure holds none).
        FigureSessionMatches = ["site" "mapping"]
        FigureSessionUnmerged = ["probemap" "corrmap" "spectrum" "spectrogram" "coherence"]
        % String fields that are lists even when their default has one element.
        ListFields = ["response" "pairingFlags" "groupBy" "classes" "groups" "Formats" "Datasets" "Folders" "datasetKeys"]
    end

    methods
        % --- methods defined in separate files ---
        issues = validate(obj, opts)
        spec = figureFor(obj, id)

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
        function obj = set.Figures(obj, f);  obj.Figures  = EphysAnalysisConfig.normalizeFigures(f);             end

        %% --- struct / JSON --------------------------------------------------
        function s = toStruct(obj)
            %toStruct  Plain struct (schema, version, name, description, sections, Figures).
            s = struct('schema', EphysAnalysisConfig.Schema, 'version', EphysAnalysisConfig.Version, ...
                'name', obj.Name, 'description', obj.Description, ...
                'Source', obj.Source, 'Defaults', obj.Defaults, 'Figures', obj.Figures, ...
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

        function txt = toJson(obj, opts)
            %toJson  The JSON text save() writes (Inf / NaN as "Inf" / "NaN").
            arguments
                obj (1,1) EphysAnalysisConfig
                opts.Pretty (1,1) logical = true
            end
            f = string(tempname) + ".json";
            writeJsonFile(f, obj.toStruct(), NonFinite="string", Pretty=opts.Pretty);
            txt = string(fileread(f));
            delete(f);
        end

        function tf = isequalConfig(obj, other)
            %isequalConfig  True when two configs hold the same values (NaN == NaN).
            tf = isequaln(obj.toStruct(), other.toStruct());
        end

        %% --- figures ------------------------------------------------------------
        function [obj, id] = addFigure(obj, template, opts)
            %addFigure  Append a figure: a template's name ("rasterPsth") or a (partial) figure struct.
            %   [CFG, ID] = cfg.addFigure("rasterPsth", Id="unit_card")
            %   returns the new config and the figure's id. An id given
            %   (Id=, or the struct's id) is the figure's own (autoId
            %   false); without one the id is automatic (autoId true):
            %   autoFigureId's, "Raster+PSTH units", or "<that> (n)" when
            %   another figure has it, and it follows the figure's panels
            %   and data from then on. The templates (figureTemplates):
            %   "rasterPsth" (the default: a 2 x 1 grid, a raster flush over
            %   a PSTH, each with a units layer following the observed
            %   unit), one per panel type ("psth", "raster", "continuous",
            %   "heatmap", "waveforms", "probemap", "corrmap":
            %   one panel holding defaultLayer(type)) and "blank" (an
            %   empty 1 x 1 grid). A figure that names no observe.data
            %   (every template) observes what its following layers read
            %   (followedData: units for the unit templates, LFP for
            %   continuous and spectrogram, the dataset for a heat map, a
            %   probe map, a correlation map or a blank figure). Errors: EphysAnalysisConfig:BadValue
            %   (an unknown template), EphysAnalysisConfig:DuplicateFigureId.
            arguments
                obj (1,1) EphysAnalysisConfig
                template = "rasterPsth"
                opts.Id (1,1) string = ""
            end
            if isstring(template) || ischar(template)
                T = EphysAnalysisConfig.figureTemplates();
                row = T.Template == string(template);
                if ~any(row)
                    error('EphysAnalysisConfig:BadValue', 'Unknown figure template "%s" (templates: %s).', ...
                        template, strjoin(T.Template, ", "));
                end
                template = T.Figure{row};
            end
            if opts.Id ~= ""; template.id = opts.Id; end
            f = EphysAnalysisConfig.normalizeFigure(template);
            if ~(isfield(template, 'observe') && isstruct(template.observe) && isfield(template.observe, 'data'))
                f.observe.data = EphysAnalysisConfig.followedData(f);
            end
            f.autoId = f.id == "";   % an id given is the figure's own
            obj.Figures = [obj.Figures, f];   % an automatic id is given here (normalizeFigures)
            id = obj.Figures(end).id;
        end

        function [obj, id] = duplicateFigure(obj, from)
            %duplicateFigure  Copy figure FROM (an id or an index) right after it, as "<base> (n)".
            %   [CFG, ID] = cfg.duplicateFigure("Raster+PSTH units") inserts
            %   a copy of the figure, every setting kept, after it and
            %   returns its id: "<base> (n)" with the smallest n >= 2 that
            %   no figure has (nextFreeId), where <base> is the figure's
            %   automatic id (autoFigureId) when its id is automatic, else
            %   its own id without a " (n)" it ends in ("unit_card (2)"
            %   copies as "unit_card (3)" while "unit_card (2)" is taken).
            %   The copy's autoId is the figure's: an automatic copy
            %   follows its own panels from then on. Error:
            %   EphysAnalysisConfig:NoFigure.
            k = from;
            if ~isnumeric(from); k = obj.figureIndex(from); end
            if ~(isscalar(k) && k >= 1 && k <= numel(obj.Figures))
                error('EphysAnalysisConfig:NoFigure', 'No figure "%s".', string(from));
            end
            f = obj.Figures(k);
            if f.autoId
                base = EphysAnalysisConfig.autoFigureId(f);
            else
                base = regexprep(f.id, ' \(\d+\)$', '');
            end
            f.id = EphysAnalysisConfig.nextFreeId(base, obj.figureIds(), Suffix=true);
            obj.Figures = [obj.Figures(1:k), f, obj.Figures(k+1:end)];
            id = obj.Figures(k + 1).id;
        end

        function obj = removeFigure(obj, id)
            %removeFigure  Drop the figure with this id (error when there is none).
            k = obj.figureIndex(id);
            if k == 0
                error('EphysAnalysisConfig:NoFigure', 'No figure "%s".', id);
            end
            obj.Figures(k) = [];
        end

        function k = figureIndex(obj, id)
            %figureIndex  Index of the figure with this id in Figures (0 = none).
            k = find(obj.figureIds() == string(id), 1);
            if isempty(k); k = 0; end
        end

        function ids = figureIds(obj)
            %figureIds  Ids of every figure, in order (a string row).
            ids = string.empty(1, 0);
            if ~isempty(obj.Figures); ids = reshape([obj.Figures.id], 1, []); end
        end

        function ids = enabledFigures(obj)
            %enabledFigures  Ids of the enabled figures drawn per dataset, in order (session figures apart).
            ids = string.empty(1, 0);
            if ~isempty(obj.Figures)
                s = [obj.Figures.sessions];
                on = obj.Figures([obj.Figures.enabled] & ~[s.enabled]);
                if ~isempty(on); ids = reshape([on.id], 1, []); end
            end
        end

        function ids = sessionFigureIds(obj)
            %sessionFigureIds  Ids of the session figures (sessions.enabled), enabled or not, in order.
            ids = string.empty(1, 0);
            if ~isempty(obj.Figures)
                s = [obj.Figures.sessions];
                on = obj.Figures([s.enabled]);
                if ~isempty(on); ids = reshape([on.id], 1, []); end
            end
        end

        function ids = enabledSessionFigures(obj)
            %enabledSessionFigures  Ids of the enabled session figures, in order: drawn across the datasets after them.
            ids = string.empty(1, 0);
            if ~isempty(obj.Figures)
                s = [obj.Figures.sessions];
                on = obj.Figures([obj.Figures.enabled] & [s.enabled]);
                if ~isempty(on); ids = reshape([on.id], 1, []); end
            end
        end

        function tf = isSessionFigure(obj, id)
            %isSessionFigure  True when figure ID (an id or an index) is drawn across datasets (sessions.enabled).
            k = id;
            if ~isnumeric(id); k = obj.figureIndex(id); end
            tf = k >= 1 && k <= numel(obj.Figures) && obj.Figures(k).sessions.enabled;
        end
    end

    methods (Static)
        % --- methods defined in separate files ---
        s = defaults(section)
        [s, unknown] = normalizeSection(section, in)
        T = sourceCategories()
        T = panelTypes()
        T = figureTemplates()
        [fig, unknown] = normalizeFigure(in, path)
        [p, unknown] = normalizePanel(in, path)
        [L, unknown] = normalizeLayer(in, path)
        id = autoFigureId(fig)
        [cells, overlap] = figureCells(fig)
        fig = placePanel(fig, panel, where, anchorId)
        fig = removePanel(fig, id)
        [fig, moved] = movePanel(fig, id, direction)
        [fig, changed] = adoptPanelOptions(fig, panelId)
        fig = adoptPanelAlignment(fig, panelId)
        fig = relinkPanels(fig)

        function obj = fromStruct(s)
            %fromStruct  Build a config from a struct (e.g. decoded JSON).
            %   Missing sections take their defaults; unknown fields are dropped
            %   and listed in LoadWarnings (a version-2 struct holding Plots or
            %   SessionPlots too: unknown top-level fields). A struct of
            %   version 1 (its version field 1) is migrated first
            %   (private/legacyMigrate): its plots become figures and its
            %   session plots session figures, of the same ids, every note of
            %   the conversion a LoadWarnings line ("plot <id> migrated to
            %   figure <id>: ...").
            arguments
                s (1,1) struct
            end
            obj = EphysAnalysisConfig();
            warn = string.empty(1, 0);
            if isfield(s, 'version') && isnumeric(s.version) && isscalar(s.version) && s.version == 1
                [s, warn] = legacyMigrate(s);
            end
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
            if isfield(s, 'Figures')
                [obj.Figures, unknown] = EphysAnalysisConfig.normalizeFigures(s.Figures);
                if ~isempty(unknown)
                    warn(end+1) = "Figures: dropped unknown field(s) " + strjoin(unknown, ", ");
                end
            end
            known = ["schema" "version" "name" "description" "Figures" EphysAnalysisConfig.Sections];
            extra = setdiff(string(fieldnames(s)).', known);
            if ~isempty(extra)
                warn(end+1) = "dropped unknown top-level field(s) " + strjoin(extra, ", ");
            end
            obj.LoadWarnings = warn;
        end

        function obj = load(file)
            %load  Read a config JSON; errors on a wrong schema or version.
            %   Reads version 2, and version 1 once by migrating it (its plots
            %   and session plots become figures: fromStruct); any other
            %   version, or another schema, raises EphysAnalysisConfig:BadSchema.
            %   save always writes version 2.
            arguments
                file (1,1) string
            end
            s = readJsonFile(file);
            if ~isstruct(s) || ~isfield(s, 'schema') || string(s.schema) ~= EphysAnalysisConfig.Schema
                error('EphysAnalysisConfig:BadSchema', ...
                    '%s is not an %s file.', file, EphysAnalysisConfig.Schema);
            end
            if ~isfield(s, 'version') || ~isnumeric(s.version) || ~isscalar(s.version) ...
                    || ~ismember(double(s.version), [1 EphysAnalysisConfig.Version])
                v = "none";
                if isfield(s, 'version'); v = string(jsonencode(s.version)); end
                error('EphysAnalysisConfig:BadSchema', ...
                    '%s has config version %s; this code reads version %d (and migrates version 1).', ...
                    file, v, EphysAnalysisConfig.Version);
            end
            obj = EphysAnalysisConfig.fromStruct(s);
            obj.File = file;
            if ~isempty(obj.LoadWarnings)
                warning('EphysAnalysisConfig:LoadWarnings', '%s: %s', file, strjoin(obj.LoadWarnings, '; '));
            end
        end

        function F = emptyFigures()
            %emptyFigures  A 1x0 struct array with the figure fields.
            F = repmat(EphysAnalysisConfig.defaults("Figure"), 1, 0);
        end

        function [F, unknown] = normalizeFigures(v)
            %normalizeFigures  Figures from a struct array, a cell array (jsondecode) or [].
            %   Every entry is normalized (normalizeFigure); an entry with
            %   autoId false and no id gets "figure_<n>"; two such entries
            %   with one id raise EphysAnalysisConfig:DuplicateFigureId.
            %   Every entry with autoId true gets its automatic id
            %   (autoFigureId), unique among the figures by the next free
            %   " (n)" (nextFreeId; ids compared as {Plot} writes them,
            %   case-blind): an entry keeps the id it has while that is the
            %   automatic id or "<it> (n)" and no figure before it (or with
            %   an id of its own) has it, so only the figures whose content
            %   changed are renamed; the others take the next free id.
            F = EphysAnalysisConfig.emptyFigures();
            unknown = string.empty(1, 0);
            if isempty(v); return; end
            if isstruct(v)
                v = num2cell(v);
            elseif ~iscell(v)
                error('EphysAnalysisConfig:BadValue', 'Figures must be a struct array or a cell array of structs.');
            end
            for k = 1:numel(v)
                if ~isstruct(v{k})
                    error('EphysAnalysisConfig:BadValue', 'Figures(%d) must be a struct.', k);
                end
                [f, u] = EphysAnalysisConfig.normalizeFigure(v{k}, "Figures(" + k + ")");
                unknown = [unknown, u]; %#ok<AGROW>
                F(1, end+1) = f; %#ok<AGROW>
            end
            ids = [F.id];
            auto = [F.autoId];
            given = ids(ids ~= "" & ~auto);
            [~, first] = unique(given, 'stable');
            dup = given(setdiff(1:numel(given), first));
            if ~isempty(dup)
                error('EphysAnalysisConfig:DuplicateFigureId', 'Figure id "%s" is used more than once.', dup(1));
            end
            for k = find(ids == "" & ~auto)
                F(k).id = EphysAnalysisConfig.freeId("figure", [F.id]);
            end
            if ~any(auto); return; end
            key = @(s) lower(regexprep(s, '[^\w\-\.]', '_'));   % the id as {Plot} writes it, case-blind
            used = key([strings(1, 0) F(~auto).id]);
            base = strings(1, numel(F));
            keep = false(1, numel(F));
            for k = find(auto)   % the ids that still fit their content stay, first come first
                base(k) = EphysAnalysisConfig.autoFigureId(F(k));
                cur = F(k).id;
                fits = cur == base(k) || (startsWith(cur, base(k) + " (") ...
                    && ~isempty(regexp(extractAfter(cur, strlength(base(k))), '^ \([2-9]\d*\)$|^ \(1\d+\)$', 'once')));
                if fits && ~ismember(key(cur), used)
                    keep(k) = true;
                    used(end+1) = key(cur); %#ok<AGROW>
                end
            end
            for k = find(auto & ~keep)
                F(k).id = EphysAnalysisConfig.nextFreeId(base(k), used);
                used(end+1) = key(F(k).id); %#ok<AGROW>
            end
        end

        function cat = categoryOf(source, type)
            %categoryOf  The category in which a panel type draws a layer source ("" = it does not).
            %   CAT = EphysAnalysisConfig.categoryOf(SOURCE, TYPE) is the
            %   category of SOURCE (sourceCategories) that panel type TYPE
            %   accepts (panelTypes().Categories): "point", "continuous",
            %   "unit" or "". units / detected are "point" in a
            %   raster, PSTH, heat map, rate, tuning, spectrum, spectrogram or
            %   coherence panel and "unit" in a waveforms panel,
            %   probe map or correlation map. An events layer is "point" in
            %   every panel that shares the time axis (raster, psth,
            %   continuous, heatmap, spectrogram: marks or latency lines), whatever its
            %   categories, and "" elsewhere. An event-trace panel draws
            %   events layers only: any other source is "" there.
            cat = "";
            T = EphysAnalysisConfig.panelTypes();
            row = T.Type == string(type);
            if ~any(row); return; end
            if string(source) == "events"
                if T.SharesTime(row); cat = "point"; end
                return
            end
            if string(type) == "eventTrace"; return; end
            S = EphysAnalysisConfig.sourceCategories();
            for c = T.Categories{row}
                if ismember(string(source), S.Sources{S.Category == c})
                    cat = c;
                    return
                end
            end
        end

        function kind = observeKind(fig)
            %observeKind  What a figure is drawn for: "unit", "channel" or "dataset".
            %   KIND = EphysAnalysisConfig.observeKind(FIG) follows
            %   FIG.observe.data: "unit" for units or detected (a sorted
            %   unit, or a channel's detections), "channel" for a signal
            %   (LFP / MUA / SPIKE / AUX), "dataset" for the dataset (and
            %   for a value that is none of ObserveData: validate says so).
            d = fig.observe.data;
            if ismember(d, EphysAnalysisConfig.SpikeSources)
                kind = "unit";
            elseif ismember(d, EphysAnalysisConfig.SignalSources)
                kind = "channel";
            else
                kind = "dataset";
            end
        end

        function d = followedData(fig)
            %followedData  The data a figure's following layers read: what addFigure observes when not told.
            %   D = EphysAnalysisConfig.followedData(FIG) is "units" when an
            %   enabled layer following the observation reads sorted units,
            %   else "detected" when one reads detections, else the signal
            %   of the first one that reads a signal (LFP / MUA / SPIKE /
            %   AUX), else "dataset" (no layer follows).
            srcs = strings(1, 0);
            for k = 1:numel(fig.panels)
                L = fig.panels(k).layers;
                if isempty(L); continue; end
                on = [L.enabled] & [L.binding] == "observation";
                srcs = [srcs, L(on).source]; %#ok<AGROW>
            end
            sig = srcs(ismember(srcs, EphysAnalysisConfig.SignalSources));
            if any(srcs == "units")
                d = "units";
            elseif any(srcs == "detected")
                d = "detected";
            elseif ~isempty(sig)
                d = sig(1);
            else
                d = "dataset";
            end
        end

        function L = defaultLayer(type)
            %defaultLayer  A new layer for a panel type: its first source, bound as the type's DefaultBinding.
            %   L = EphysAnalysisConfig.defaultLayer(TYPE) is defaults("Layer")
            %   with the first source of the type's first category (units
            %   for raster / psth / heatmap / waveforms / probemap /
            %   corrmap, LFP for continuous; an events layer, fixed, for
            %   eventTrace) and the
            %   type's DefaultBinding, so a new panel draws at once.
            %   Error: EphysAnalysisConfig:BadValue (an unknown type).
            T = EphysAnalysisConfig.panelTypes();
            row = T.Type == string(type);
            if ~any(row)
                error('EphysAnalysisConfig:BadValue', 'Unknown panel type "%s" (types: %s).', type, strjoin(T.Type, ", "));
            end
            cats = T.Categories{row};
            S = EphysAnalysisConfig.sourceCategories();
            srcs = S.Sources{S.Category == cats(1)};
            L = EphysAnalysisConfig.defaults("Layer");
            L.source = srcs(1);
            if string(type) == "eventTrace"; L.source = "events"; end   % its only source
            L.binding = T.DefaultBinding(row);
        end

        function f = sharedFieldsOf(type)
            %sharedFieldsOf  The options a panel type shares with other types (a string row; none for an unknown type).
            %   Among bins, measure, baseline, auroc, maskAfterStop,
            %   waveform, stack and stackSpacing, in that order, those the
            %   type's options have, the rows adoptPanelOptions (Apply to
            %   all panels) copies across types: raster: maskAfterStop,
            %   waveform; psth: bins, measure, baseline, auroc,
            %   maskAfterStop, waveform, stack, stackSpacing; continuous:
            %   baseline, stack, stackSpacing; heatmap: bins, measure,
            %   baseline, auroc, maskAfterStop, stack, stackSpacing;
            %   corrmap: bins, baseline; rate: measure, baseline; tuning:
            %   measure, baseline, waveform, stack, stackSpacing;
            %   waveforms and probemap: none (a waveforms panel's waveform
            %   is its own settings, not an inset). The spectral types
            %   (spectrum, spectrogram, coherence): stack and stackSpacing
            %   only (their Chronux settings are their own; a
            %   spectrogram's baseline is chronuxNormalize's). The stack
            %   options mean the same on every type (stackModes).
            f = string.empty(1, 0);
            T = EphysAnalysisConfig.panelTypes();
            row = T.Type == string(type);
            if ~any(row); return; end
            names = ["bins" "measure" "baseline" "auroc" "maskAfterStop" "waveform" "stack" "stackSpacing"];
            if string(type) == "waveforms"; names(names == "waveform") = []; end
            if ismember(string(type), ["spectrum" "spectrogram" "coherence"]); names = ["stack" "stackSpacing"]; end
            f = names(isfield(T.DefaultOptions{row}, cellstr(names)));
        end

        function modes = stackModes(type)
            %stackModes  The options.stack values a panel type takes (a string row; empty for a type that does not stack).
            %   MODES = EphysAnalysisConfig.stackModes(TYPE): "off" (the
            %   trial groups overlaid, or the one group options.group names)
            %   and "groups" (a row per trial group, the first on top: its
            %   stackSpacing the row step x the row height) on a PSTH, heat
            %   map, tuning curve (a row per series), spectrum, spectrogram
            %   and coherence panel; a continuous panel also "items" (a row
            %   per channel or layer mean, the groups overlaid in each).
            %   None on a raster (it lists its groups in blocks already), a
            %   firing rate panel (its groups go along x), a waveforms, probe
            %   map or unit correlation panel (no trial groups over a shared
            %   axis) or an event-trace panel (a row per line already). One
            %   list for validate, the figure editor (syncFigureEditor,
            %   figureRowReason) and adoptPanelOptions.
            arguments
                type (1,1) string
            end
            switch type
                case {"psth" "heatmap" "tuning" "spectrum" "spectrogram" "coherence"}
                    modes = ["off" "groups"];
                case "continuous"
                    modes = ["off" "groups" "items"];
                otherwise
                    modes = string.empty(1, 0);
            end
        end

        function modes = baselineModes(type, source)
            %baselineModes  The options.baseline Modes a panel type takes (a string row; "none" for a type without a baseline).
            %   MODES = EphysAnalysisConfig.baselineModes(TYPE, SOURCE): a
            %   PSTH or a heat map of spikes none, subtract, zscore,
            %   percent or auroc; a heat map whose first enabled layer
            %   reads a signal (SOURCE in SignalSources), a continuous
            %   panel or a unit correlation map none or subtract; a rate or
            %   tuning panel firingRate's none, subtract, ratio or zscore;
            %   a spectrogram chronuxNormalize's none, db, percent, zscore
            %   or ratio (adoptPanelOptions copies that one as is). SOURCE
            %   (default "") only matters to a heat map.
            %   One list for validate, the figure editor (figureEditorChoices)
            %   and adoptPanelOptions.
            arguments
                type (1,1) string
                source (1,1) string = ""
            end
            switch type
                case "psth"
                    modes = ["none" "subtract" "zscore" "percent" "auroc"];
                case "heatmap"
                    modes = ["none" "subtract" "zscore" "percent" "auroc"];
                    if ismember(source, EphysAnalysisConfig.SignalSources); modes = ["none" "subtract"]; end
                case {"continuous" "corrmap"}
                    modes = ["none" "subtract"];
                case {"rate" "tuning"}
                    modes = ["none" "subtract" "ratio" "zscore"];
                case "spectrogram"
                    modes = ["none" "db" "percent" "zscore" "ratio"];
                otherwise
                    modes = "none";
            end
        end

        function a = aggregates(type, source)
            %aggregates  How a panel type draws a fixed layer's several items (a string row of Layer.aggregate values).
            %   A = EphysAnalysisConfig.aggregates(TYPE, SOURCE): a raster,
            %   PSTH, continuous, rate or tuning panel "each" (an item each)
            %   or "mean" (their mean, a band across them); a spectrum,
            %   spectrogram or coherence panel, SOURCE a signal (SignalSources),
            %   "each" or "magnitude" (the channels as one: their vector
            %   magnitude, each channel's static part out first, as
            %   figureChronuxLayer reads it, e.g. a 3-axis accelerometer's
            %   AUX channels); any other "each". One list for validate and
            %   the figure editor (figureEditorChoices).
            arguments
                type (1,1) string
                source (1,1) string = ""
            end
            if ismember(type, ["raster" "psth" "continuous" "rate" "tuning"])
                a = ["each" "mean"];
            elseif ismember(type, ["spectrum" "spectrogram" "coherence"]) && ismember(source, EphysAnalysisConfig.SignalSources)
                a = ["each" "magnitude"];
            else
                a = "each";
            end
        end
    end

    methods (Static, Hidden)
        [out, unknown] = coerceStruct(def, in, path)

        function id = freeId(kind, used)
            %freeId  "<kind>_<n>" with the smallest n not in USED.
            n = 1;
            used = string(used);
            while any(used == kind + "_" + n)
                n = n + 1;
            end
            id = kind + "_" + n;
        end

        function id = nextFreeId(base, used, opts)
            %nextFreeId  BASE, or "BASE (n)" with the smallest free n >= 2: a figure id that names other files than USED.
            %   ID = EphysAnalysisConfig.nextFreeId(BASE, USED) compares
            %   the ids as {Plot} writes them (every character outside
            %   A-Z a-z 0-9 _ - . as "_"), case-blind, as validate does.
            %   Suffix=true always adds " (n)" (duplicateFigure).
            arguments
                base (1,1) string
                used string = string.empty(1, 0)
                opts.Suffix (1,1) logical = false
            end
            key = @(s) lower(regexprep(s, '[^\w\-\.]', '_'));
            used = key(reshape(used, 1, []));
            id = base;
            if ~opts.Suffix && ~ismember(key(id), used); return; end
            n = 2;
            while ismember(key(base + " (" + n + ")"), used)
                n = n + 1;
            end
            id = base + " (" + n + ")";
        end
    end
end
