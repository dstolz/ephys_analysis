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
    %               withRaster, rasterSort, rasterSortEvent, rasterSortOrder,
    %               rasterByGroup, rasterEvents, histStyle, fill, fillAlpha,
    %               normalize, stack, stackSpacing, stackRaster, stackRasterEqual,
    %               stackRasterTrials, maskAfterStop, param,
    %               seriesParam, yParam, jitter, xScale, value, order,
    %               metric, correlation, measure, auroc, waveform, aux,
    %               note, overlays, aesthetics, style
    %     Figures   struct array, one entry per figure (defaults("Figure")):
    %               one observation's panels (a unit, a channel or the
    %               dataset: observe) on a grid with spans (grid), each
    %               panel of a type (panelTypes) drawing one or more layers,
    %               each layer bound to a source (FigureSources) that either
    %               follows the observation or names fixed items: id,
    %               enabled, title, observe, grid, common, panels, ref,
    %               window, selection, style, aesthetics. common holds the
    %               options every linked panel takes (commonFields: bins,
    %               measure, baseline, maskAfterStop, waveform), as a panel
    %               whose ref / window are "default" takes the figure's
    %               alignment; adoptPanelOptions, adoptPanelAlignment and
    %               relinkPanels spread one panel's settings or re-link
    %               every panel. A panel (defaults("Panel")): id, type,
    %               title, row, col, rowSpan, colSpan, ref, window, common
    %               (true: the figure's common options for the fields its
    %               type has, commonFieldsOf), layers, options (the type's
    %               DefaultOptions; panelOptions gives them as drawn); a layer
    %               (defaults("Layer")): name, enabled, source, binding,
    %               units, channels, aggregate, event, eventsAs, color,
    %               lineStyle. Figure ids are a
    %               namespace of their own (DuplicateFigureId), panel ids
    %               one per figure (DuplicatePanelId); figureFor(id) is the
    %               spec the compute draws. Figures are previewed only in
    %               this release: the run does not draw them
    %     SessionPlots  struct array, one entry per session plot
    %               (defaults("SessionPlot")): a base plot (plot, by id)
    %               drawn over several datasets and merged
    %               (combineSessions): id, enabled, title, plot, layout,
    %               datasets ("ticked" | "list"), datasetKeys, facet, series,
    %               colorOrder, showMembers, error, match, mappingFile,
    %               minSessions, trialGroups, data, aesthetics. Its ids are
    %               a namespace of their own (DuplicateSessionPlotId);
    %               sessionPlotFor(id) is the spec the runner computes
    %     Export    figure files: Formats (png / eps / svg / pdf), Folder and
    %               FilenamePattern with tokens, Dpi, FigureSizeCm;
    %               SessionsFolder (the session plots' figures) and Data
    %               (the session plots' .mat data files: Enabled, Folder,
    %               FilenamePattern, MatVersion)
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
    %     cfg = cfg.addFigure("rasterPsth");   % figure_1: a unit's raster over its PSTH
    %     cfg.save("am_quicklook.json");
    %     r = EphysAnalysisRunner(EphysAnalysisConfig.load("am_quicklook.json"));
    %     r.run();
    %
    %   Values are coerced to the type and shape of the default whenever a
    %   section is assigned, so what JSON gives back (a one-element list as a
    %   scalar, "Inf" as text, a heterogeneous Plots array as a cell) comes
    %   out right. Unknown fields are dropped (LoadWarnings lists them after
    %   load). Plot ids must be unique (EphysAnalysisConfig:DuplicatePlotId);
    %   a plot without an id gets "<kind>_<n>", a figure "figure_<n>" and a
    %   figure's panel "<type>_<n>".
    %
    %   See also EphysAnalysisRunner, EphysAnalysisScript, EphysAnalysisApp,
    %   EphysAnalysisConfig.defaults, EphysAnalysisConfig.validate.

    properties
        Name        (1,1) string = "Untitled"
        Description (1,1) string = ""
        Source      struct = EphysAnalysisConfig.defaults("Source")
        Defaults    struct = EphysAnalysisConfig.defaults("Defaults")
        Plots       = EphysAnalysisConfig.emptyPlots()   % struct array; set.Plots also takes a cell (jsondecode)
        Figures     = EphysAnalysisConfig.emptyFigures() % struct array; set.Figures also takes a cell
        SessionPlots = EphysAnalysisConfig.emptySessionPlots()   % struct array; set.SessionPlots also takes a cell
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
        Kinds    = ["psth" "raster" "evoked" "rate" "tuning" "heatmap" "probemap" "corrmap" "behavior" "waveforms"]
        SpikeSources  = ["units" "detected"]
        SignalSources = ["LFP" "MUA" "SPIKE" "AUX"]
        % What a figure layer reads (Layer.source): spike times, a digital / derived line's events, or a signal;
        % sourceCategories groups them, panelTypes says which categories each panel type draws.
        FigureSources = ["units" "detected" "events" "LFP" "MUA" "SPIKE" "AUX"]
        % What a figure is drawn for (Figure.observe.kind): auto (resolved by observeKind), a unit, a channel, the dataset.
        ObserveKinds  = ["auto" "unit" "channel" "dataset"]
        % Where in a unit's tile its waveform box sits (a plot's waveform.location).
        WaveformLocations = ["northeast" "north" "northwest" "west" "southwest" "south" "southeast" "east"]
        % What a psth / raster plot's mean aux signal (aux) draws, and where: a panel below or above the unit's
        % raster / PSTH, or over it on its right y axis.
        AuxModes      = ["off" "channels" "magnitude"]
        % The error a plot draws as bands or bars (Style.ErrorType): mean +/- SEM, mean +/- SD, bootstrap 95% CI of the mean.
        ErrorTypes    = ["sem" "std" "ci95"]
        AuxPlacements = ["below" "above" "over"]
        % How the mean aux signal is drawn (aux.display): lines, one per trace; stacked, a row of its own per trace;
        % or a heat map, a row per trace in color.
        AuxDisplays   = ["lines" "stacked" "heatmap"]
        % What it shows at each sample over the epochs (aux.statistic), and of what (aux.transform): the signal as
        % recorded, or rectified (its absolute value, taken in each epoch before the statistic).
        AuxStatistics = ["mean" "median"]
        AuxTransforms = ["none" "rectify"]
        % Its error band (aux.errorType): off, mean +/- SEM, mean +/- SD, bootstrap 95% CI, or the interquartile range.
        AuxErrorTypes = ["off" "sem" "std" "ci95" "iqr"]
        % What its traces are colored by (aux.colorBy): auto (by trial group when several, else by channel), the
        % trial selection group, or the channel.
        AuxColorBy    = ["auto" "group" "channel"]
        % Where a plot's note sits (a plot's note.placement): outside the plot, over it, or at a point.
        NotePlacements = ["below" "above" "right" "left" "northwest" "north" "northeast" "west" "center" "east" ...
            "southwest" "south" "southeast" "custom"]
        % What a plot's overlays (defaults("Overlay")) choose from: the axes they go on, the layer, a line's style.
        OverlayPanels     = ["all" "data" "raster"]
        OverlayLayers     = ["over" "under"]
        OverlayLineStyles = ["-" "--" ":" "-."]
        % Session plots: the base plot kinds they merge (combineSessions), what gets a color (series), how units are
        % matched across sessions (match), the band across sessions (error), what the data export holds (data),
        % the base plot's trial groups (trialGroups), the figures per subject (facet) and the colors' order.
        SessionKinds  = ["psth" "raster" "evoked" "rate" "tuning" "behavior" "heatmap" "waveforms"]
        SessionSeries = ["session" "subject" "all"]
        SessionMatches = ["pool" "site" "mapping"]
        SessionErrors = ["sem" "sd" "ci95" "none"]
        SessionData   = ["results" "epochs" "signals"]
        SessionTrialGroups = ["pool" "each" "combine"]
        SessionFacets = ["none" "subject"]
        SessionColorOrders = ["palette" "sequential"]
        % String fields that are lists even when their default has one element.
        ListFields = ["response" "pairingFlags" "groupBy" "classes" "groups" "Formats" "Datasets" "Folders" "datasetKeys" "data"]
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
        function obj = set.Plots(obj, p);    obj.Plots    = EphysAnalysisConfig.normalizePlots(p);               end
        function obj = set.Figures(obj, f);  obj.Figures  = EphysAnalysisConfig.normalizeFigures(f);             end
        function obj = set.SessionPlots(obj, p); obj.SessionPlots = EphysAnalysisConfig.normalizeSessionPlots(p); end

        %% --- struct / JSON --------------------------------------------------
        function s = toStruct(obj)
            %toStruct  Plain struct (schema, version, name, description, sections, Plots, Figures, SessionPlots).
            s = struct('schema', EphysAnalysisConfig.Schema, 'version', EphysAnalysisConfig.Version, ...
                'name', obj.Name, 'description', obj.Description, ...
                'Source', obj.Source, 'Defaults', obj.Defaults, 'Plots', obj.Plots, 'Figures', obj.Figures, ...
                'SessionPlots', obj.SessionPlots, 'Export', obj.Export, 'Report', obj.Report);
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

        %% --- plots ------------------------------------------------------------
        function [obj, id] = addPlot(obj, p, opts)
            %addPlot  Append a plot: a kind ("psth") or a (partial) plot struct.
            %   [CFG, ID] = cfg.addPlot("rate", Id="rate_platform") returns the
            %   new config and the plot's id (assigned when not given). A plot
            %   given without a source reads its kind's first (units; LFP for
            %   an evoked potential, trials for a behavior plot). A waveforms
            %   plot given without a waveform shows each unit's mean and
            %   subsample (waveform.mode "both"); the default, "off", draws nothing.
            arguments
                obj (1,1) EphysAnalysisConfig
                p = "psth"
                opts.Id (1,1) string = ""
            end
            if isstring(p) || ischar(p)
                p = struct('kind', string(p));
            end
            if isstruct(p) && isscalar(p) && isfield(p, 'kind') && ~isfield(p, 'source')
                K = EphysAnalysisConfig.plotKinds();
                row = K.Kind == string(p.kind);
                if any(row); p.source = K.Sources{row}(1); end
            end
            if isstruct(p) && isscalar(p) && isfield(p, 'kind') && string(p.kind) == "waveforms" && ~isfield(p, 'waveform')
                p.waveform = struct('mode', "both");
            end
            if opts.Id ~= ""; p.id = opts.Id; end
            p = EphysAnalysisConfig.normalizePlot(p);
            if p.id == ""
                p.id = EphysAnalysisConfig.freeId(p.kind, obj.plotIds());
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
            k = find(obj.plotIds() == string(id), 1);
            if isempty(k); k = 0; end
        end

        function ids = plotIds(obj)
            %plotIds  Ids of every plot, in order (a string row).
            ids = string.empty(1, 0);
            if ~isempty(obj.Plots); ids = reshape([obj.Plots.id], 1, []); end
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

        %% --- figures ------------------------------------------------------------
        function [obj, id] = addFigure(obj, template, opts)
            %addFigure  Append a figure: a template's name ("rasterPsth") or a (partial) figure struct.
            %   [CFG, ID] = cfg.addFigure("rasterPsth", Id="unit_card")
            %   returns the new config and the figure's id ("figure_<n>"
            %   when not given). The templates (figureTemplates):
            %   "rasterPsth" (the default: a 2 x 1 grid, a raster flush over
            %   a PSTH, each with a units layer following the observed
            %   unit), one per panel type ("psth", "raster", "continuous",
            %   "heatmap", "waveforms", "probemap", "corrmap":
            %   one panel holding defaultLayer(type)) and "blank" (an
            %   empty 1 x 1 grid). Errors: EphysAnalysisConfig:BadValue
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
            if f.id == ""
                f.id = EphysAnalysisConfig.freeId("figure", obj.figureIds());
            end
            obj.Figures = [obj.Figures, f];
            id = f.id;
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
            %enabledFigures  Ids of the enabled figures, in order.
            ids = string.empty(1, 0);
            if ~isempty(obj.Figures)
                on = obj.Figures([obj.Figures.enabled]);
                if ~isempty(on); ids = reshape([on.id], 1, []); end
            end
        end

        function [obj, id, notes] = convertPlotToFigure(obj, plotId)
            %convertPlotToFigure  Append a figure that draws what plot PLOTID draws (plotToFigure).
            %   [CFG, ID, NOTES] = cfg.convertPlotToFigure(PLOTID) returns the
            %   new config, the figure's id ("<plotId>_fig", "_fig2", ...:
            %   free among plots and figures) and NOTES, what the figure could not
            %   carry. The plot stays. Errors: EphysAnalysisConfig:NoPlot,
            %   EphysAnalysisConfig:NotConvertible (rate, tuning, behavior).
            arguments
                obj (1,1) EphysAnalysisConfig
                plotId (1,1) string
            end
            [f, notes] = EphysAnalysisConfig.plotToFigure(obj, plotId);
            obj.Figures = [obj.Figures, f];
            id = f.id;
        end

        %% --- session plots ------------------------------------------------------
        function [obj, id] = addSessionPlot(obj, sp, opts)
            %addSessionPlot  Append a session plot: a base plot's id or a (partial) session plot struct.
            %   [CFG, ID] = cfg.addSessionPlot("psth_stim", Id="psth_days")
            %   returns the new config and the session plot's id
            %   ("<plot>_sessions_<n>" when not given).
            arguments
                obj (1,1) EphysAnalysisConfig
                sp = struct()
                opts.Id (1,1) string = ""
            end
            if isstring(sp) || ischar(sp)
                sp = struct('plot', string(sp));
            end
            if opts.Id ~= ""; sp.id = opts.Id; end
            sp = EphysAnalysisConfig.normalizeSection("SessionPlot", sp);
            if sp.id == ""
                sp.id = EphysAnalysisConfig.freeId(sessionIdBase(sp), obj.sessionPlotIds());
            end
            obj.SessionPlots = [obj.SessionPlots, sp];
            id = sp.id;
        end

        function obj = removeSessionPlot(obj, id)
            %removeSessionPlot  Drop the session plot with this id (error when there is none).
            k = obj.sessionPlotIndex(id);
            if k == 0
                error('EphysAnalysisConfig:NoSessionPlot', 'No session plot "%s".', id);
            end
            obj.SessionPlots(k) = [];
        end

        function k = sessionPlotIndex(obj, id)
            %sessionPlotIndex  Index of the session plot with this id in SessionPlots (0 = none).
            k = find(obj.sessionPlotIds() == string(id), 1);
            if isempty(k); k = 0; end
        end

        function ids = sessionPlotIds(obj)
            %sessionPlotIds  Ids of every session plot, in order (a string row).
            ids = string.empty(1, 0);
            if ~isempty(obj.SessionPlots); ids = reshape([obj.SessionPlots.id], 1, []); end
        end

        function ids = enabledSessionPlots(obj)
            %enabledSessionPlots  Ids of the enabled session plots, in order.
            ids = string.empty(1, 0);
            if ~isempty(obj.SessionPlots)
                on = obj.SessionPlots([obj.SessionPlots.enabled]);
                if ~isempty(on); ids = reshape([on.id], 1, []); end
            end
        end

        function spec = sessionPlotFor(obj, id)
            %sessionPlotFor  The effective spec of a session plot: its base plot with the session plot's overrides.
            %   SPEC = cfg.sessionPlotFor(ID) (a session plot id, an index, or
            %   a session plot struct, which need not be in the config) is
            %   plotFor(sp.plot) with enabled = true, id = sp.id, title and
            %   layout overridden when not "", and with trialGroups "pool"
            %   the trial groups cleared (selection.groupBy = []; a tuning or
            %   behavior plot's seriesParam = "" too: the sessions are the
            %   series); with trialGroups "combine" a psth's histStyle is
            %   "line" (the sessions x trial groups are told apart by line
            %   style). SPEC.sessionAesthetics holds sp.aesthetics, the
            %   session plot's own rules, which renderPlot applies after the
            %   base plot's (SPEC.aesthetics), so a session figure's
            %   remembered looks never change the per-dataset figures.
            %   Errors: EphysAnalysisConfig:NoSessionPlot,
            %   EphysAnalysisConfig:NoPlot (the base plot does not exist).
            if isstruct(id)
                sp = EphysAnalysisConfig.normalizeSection("SessionPlot", id);
            else
                if isnumeric(id)
                    k = id;
                else
                    k = obj.sessionPlotIndex(id);
                end
                if k < 1 || k > numel(obj.SessionPlots)
                    error('EphysAnalysisConfig:NoSessionPlot', 'No session plot "%s".', string(id));
                end
                sp = obj.SessionPlots(k);
            end
            if obj.plotIndex(sp.plot) == 0
                error('EphysAnalysisConfig:NoPlot', 'Session plot "%s": no base plot "%s".', sp.id, sp.plot);
            end
            spec = obj.plotFor(sp.plot);
            spec.enabled = true;
            spec.id = sp.id;
            if sp.title ~= ""; spec.title = sp.title; end
            if sp.layout ~= ""; spec.layout = sp.layout; end
            if sp.trialGroups == "pool"
                spec.selection.groupBy = string.empty(1, 0);
                if ismember(spec.kind, ["tuning" "behavior"]); spec.seriesParam = ""; end
            end
            if sp.trialGroups == "combine" && spec.kind == "psth"
                spec.histStyle = "line";   % sessions x trial groups are told apart by line style
            end
            spec.sessionAesthetics = sp.aesthetics;
        end
    end

    methods (Static)
        % --- methods defined in separate files ---
        s = defaults(section)
        [s, unknown] = normalizeSection(section, in)
        [p, unknown] = normalizePlot(in, path)
        T = plotKinds()
        T = sourceCategories()
        T = panelTypes()
        T = figureTemplates()
        [fig, unknown] = normalizeFigure(in, path)
        [p, unknown] = normalizePanel(in, path)
        [L, unknown] = normalizeLayer(in, path)
        [cells, overlap] = figureCells(fig)
        fig = placePanel(fig, panel, where, anchorId)
        fig = removePanel(fig, id)
        [fig, moved] = movePanel(fig, id, direction)
        fig = adoptPanelOptions(fig, panelId)
        fig = adoptPanelAlignment(fig, panelId)
        fig = relinkPanels(fig)
        [fig, notes] = plotToFigure(cfg, plotId)

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
            if isfield(s, 'Figures')
                [obj.Figures, unknown] = EphysAnalysisConfig.normalizeFigures(s.Figures);
                if ~isempty(unknown)
                    warn(end+1) = "Figures: dropped unknown field(s) " + strjoin(unknown, ", ");
                end
            end
            if isfield(s, 'SessionPlots')
                [obj.SessionPlots, unknown] = EphysAnalysisConfig.normalizeSessionPlots(s.SessionPlots);
                if ~isempty(unknown)
                    warn(end+1) = "SessionPlots: dropped unknown field(s) " + strjoin(unknown, ", ");
                end
            end
            known = ["schema" "version" "name" "description" "Plots" "Figures" "SessionPlots" EphysAnalysisConfig.Sections];
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

        function p = emptySessionPlots()
            %emptySessionPlots  A 1x0 struct array with the session plot fields.
            p = repmat(EphysAnalysisConfig.defaults("SessionPlot"), 1, 0);
        end

        function [P, unknown] = normalizeSessionPlots(v)
            %normalizeSessionPlots  SessionPlots from a struct array, a cell array (jsondecode) or [].
            %   Every entry is normalized (normalizeSection "SessionPlot");
            %   entries without an id get "<plot>_sessions_<n>"; duplicate ids
            %   raise EphysAnalysisConfig:DuplicateSessionPlotId.
            P = EphysAnalysisConfig.emptySessionPlots();
            unknown = string.empty(1, 0);
            if isempty(v); return; end
            if isstruct(v)
                v = num2cell(v);
            elseif ~iscell(v)
                error('EphysAnalysisConfig:BadValue', 'SessionPlots must be a struct array or a cell array of structs.');
            end
            for k = 1:numel(v)
                [p, u] = EphysAnalysisConfig.normalizeSection("SessionPlot", v{k});
                unknown = [unknown, replace(u, textBoundary("start") + "SessionPlot.", "SessionPlots(" + k + ").")]; %#ok<AGROW>
                P(1, end+1) = p; %#ok<AGROW>
            end
            ids = [P.id];
            [~, first] = unique(ids(ids ~= ""), 'stable');
            given = ids(ids ~= "");
            dup = given(setdiff(1:numel(given), first));
            if ~isempty(dup)
                error('EphysAnalysisConfig:DuplicateSessionPlotId', 'Session plot id "%s" is used more than once.', dup(1));
            end
            for k = find(ids == "")
                P(k).id = EphysAnalysisConfig.freeId(sessionIdBase(P(k)), [P.id]);
            end
        end

        function F = emptyFigures()
            %emptyFigures  A 1x0 struct array with the figure fields.
            F = repmat(EphysAnalysisConfig.defaults("Figure"), 1, 0);
        end

        function [F, unknown] = normalizeFigures(v)
            %normalizeFigures  Figures from a struct array, a cell array (jsondecode) or [].
            %   Every entry is normalized (normalizeFigure); entries without
            %   an id get "figure_<n>"; duplicate ids raise
            %   EphysAnalysisConfig:DuplicateFigureId.
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
            given = ids(ids ~= "");
            [~, first] = unique(given, 'stable');
            dup = given(setdiff(1:numel(given), first));
            if ~isempty(dup)
                error('EphysAnalysisConfig:DuplicateFigureId', 'Figure id "%s" is used more than once.', dup(1));
            end
            for k = find(ids == "")
                F(k).id = EphysAnalysisConfig.freeId("figure", [F.id]);
            end
        end

        function cat = categoryOf(source, type)
            %categoryOf  The category in which a panel type draws a layer source ("" = it does not).
            %   CAT = EphysAnalysisConfig.categoryOf(SOURCE, TYPE) is the
            %   category of SOURCE (sourceCategories) that panel type TYPE
            %   accepts (panelTypes().Categories): "point", "continuous",
            %   "unit" or "". units / detected are "point" in a
            %   raster, PSTH or heat map and "unit" in a waveforms panel,
            %   probe map or correlation map. An events layer is "point" in
            %   every panel that shares the time axis (raster, psth,
            %   continuous, heatmap: marks or latency lines), whatever its
            %   categories, and "" elsewhere.
            cat = "";
            T = EphysAnalysisConfig.panelTypes();
            row = T.Type == string(type);
            if ~any(row); return; end
            if string(source) == "events"
                if T.SharesTime(row); cat = "point"; end
                return
            end
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
            %   KIND = EphysAnalysisConfig.observeKind(FIG) is
            %   FIG.observe.kind unless it is "auto"; "auto" is "unit" when
            %   any enabled layer following the observation reads spikes
            %   (units / detected), else "channel" when one reads a signal
            %   (LFP / MUA / SPIKE / AUX), else "dataset".
            kind = fig.observe.kind;
            if kind ~= "auto"; return; end
            srcs = strings(1, 0);
            for k = 1:numel(fig.panels)
                L = fig.panels(k).layers;
                if isempty(L); continue; end
                on = [L.enabled] & [L.binding] == "observation";
                srcs = [srcs, L(on).source]; %#ok<AGROW>
            end
            if any(ismember(srcs, EphysAnalysisConfig.SpikeSources))
                kind = "unit";
            elseif any(ismember(srcs, EphysAnalysisConfig.SignalSources))
                kind = "channel";
            else
                kind = "dataset";
            end
        end

        function L = defaultLayer(type)
            %defaultLayer  A new layer for a panel type: its first source, bound as the type's DefaultBinding.
            %   L = EphysAnalysisConfig.defaultLayer(TYPE) is defaults("Layer")
            %   with the first source of the type's first category (units
            %   for raster / psth / heatmap / waveforms / probemap /
            %   corrmap, LFP for continuous) and the
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
            L.binding = T.DefaultBinding(row);
        end

        function f = commonFields()
            %commonFields  The fields of a figure's common options (defaults("FigureCommon")), in order.
            f = ["bins" "measure" "baseline" "maskAfterStop" "waveform"];
        end

        function f = commonFieldsOf(type)
            %commonFieldsOf  The common fields a panel type has among its options (a string row; none for an unknown type).
            %   raster: maskAfterStop, waveform; psth: bins, measure,
            %   baseline, maskAfterStop, waveform; continuous: baseline;
            %   heatmap: bins, measure, baseline, maskAfterStop; waveforms:
            %   waveform; corrmap: bins, baseline; probemap: none.
            f = string.empty(1, 0);
            T = EphysAnalysisConfig.panelTypes();
            row = T.Type == string(type);
            if ~any(row); return; end
            names = EphysAnalysisConfig.commonFields();
            f = names(isfield(T.DefaultOptions{row}, cellstr(names)));
        end

        function op = panelOptions(fig, panel)
            %panelOptions  A panel's options as drawn: the figure's common values where the panel is linked.
            %   OP = EphysAnalysisConfig.panelOptions(FIG, PANEL) is
            %   PANEL.options with, when PANEL.common is true, each field of
            %   commonFieldsOf(PANEL.type) taken from FIG.common. A
            %   waveforms panel never draws mode "off": a common waveform
            %   mode "off" (the insets' default) is "both" there.
            op = panel.options;
            if ~panel.common; return; end
            for f = EphysAnalysisConfig.commonFieldsOf(panel.type)
                op.(f) = fig.common.(f);
            end
            if panel.type == "waveforms" && op.waveform.mode == "off"
                op.waveform.mode = "both";
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
    end
end


function b = sessionIdBase(sp)
%sessionIdBase  What a session plot's free id starts with: "<plot>_sessions" ("sessions" without a base plot).
b = "sessions";
if sp.plot ~= ""; b = sp.plot + "_sessions"; end
end
