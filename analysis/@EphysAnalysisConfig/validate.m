function issues = validate(obj, opts)
%validate  Check an analysis config for problems before it runs.
%   ISSUES = cfg.validate() returns a table (Section, Field, Severity,
%   Message); Severity "error" means the run cannot start, "warning" that
%   part of it may not do what is meant. An empty table means clean.
%
%   Checked
%     Source    Mode; Root exists (project) or every folder does (folders);
%               NamePattern parses; a "list" selection names datasets
%     Defaults  the event reference, window and selection are valid (a
%               filter that does not parse is a warning: it is checked
%               against each dataset's trials when it runs)
%     Plots     at least one enabled; ids stay distinct as file names
%               ({Plot} replaces characters outside A-Z a-z 0-9 _ - . by
%               "_", and Windows ignores case); kind is one of Kinds; source fits the
%               kind (units / detected for spike kinds, LFP / MUA / SPIKE /
%               AUX for signal kinds); layout fits the kind; "between"
%               windows only for rate / tuning / corrmap, and with a stop
%               event; tuning names its parameter; groupBy <= 2; BinSec > 0;
%               pre <= post; baseline mode fits the kind and its window is
%               [b0 b1] with b0 < b1; psth histStyle, normalize,
%               fillAlpha (0-1 or NaN) and stackSpacing (> 0); probemap value;
%               heatmap order ("modulation" with an auROC baseline);
%               corrmap metric and correlation; a psth / raster's raster
%               sort direction, its sort event (rasterSort "event": one
%               given, as an event reference) and event marks (edge,
%               scope, marker, size, each mark sequence as an event
%               reference; a color that is not one is a warning); a
%               behavior plot's
%               param and yParam ("stop" needs a stop event), xScale, and
%               violinplot for the violin layout; a baseline Mode "auroc"
%               (psth and heatmap of spikes) and its auroc settings
%               (method, windows, whole-bin window and step, modulation
%               window, cutoff, threshold, test, nResamples, correction,
%               alpha, modulatedOnly with a cutoff, the toolbox); an
%               enabled units.response test (test, param, windows,
%               direction, correction, alpha, test "auroc"'s settings, and
%               the Statistics and Machine Learning Toolbox it needs);
%               a waveform mode other than off: its location, scale (0-3)
%               and maxSpikes, and a warning when the plot draws no unit
%               tiles (a raster, a PSTH or tuning grid of spikes, a
%               waveforms plot); its amplitude scale; a waveforms plot's
%               mode is never off; an aux mode other than off: its
%               placement (a warning for "over" on a stacked PSTH, drawn
%               below), channels (whole numbers >= 1), baseline and a
%               baseline window [b0 b1] that overlaps the epoch window,
%               and a warning when the plot is not a PSTH or raster of
%               spikes; a note's placement, alignment, rotation,
%               font size and interpreter (a color that is not one is a
%               warning); each overlay's shape, axis, finite position (line)
%               or edges (region, which must differ), panel, layer, line
%               style and width, opacities (0-1), and colors (one that is
%               not a color is a warning), a warning for a panel the plot
%               does not draw and for two overlays with one name; style
%               values (the error: ErrorType sem / std / ci95, ci95 with
%               the Statistics and Machine Learning Toolbox where the plot
%               draws it, whole ErrorResamples >= 1, the bands' opacity
%               (0-1 or NaN), edge style and width; a face or edge color
%               that is not one is a warning)
%     Export    formats are png / eps / svg / pdf; Dpi, FigureSizeCm; the
%               folder and file-name patterns use known tokens; a warning
%               when the files of two enabled plots, or of two datasets,
%               would get the same names (no {Plot} -- or {Kind} for plots
%               of different kinds -- no {Name} / {OutputFolder})
%     Report    Format html / pdf / both; EmbedFormat png / svg; Dpi;
%               FileName; the folder pattern
%
%   Options: CheckPaths (default true) also checks that folders exist.
%
%   See also EphysAnalysisConfig, EphysAnalysisRunner.plan, figureFileName.

arguments
    obj (1,1) EphysAnalysisConfig
    opts.CheckPaths (1,1) logical = true
end

Section = strings(0, 1); Field = strings(0, 1); Severity = strings(0, 1); Message = strings(0, 1);
    function add(sec, field, sev, msg)
        Section(end+1, 1) = sec; Field(end+1, 1) = field; Severity(end+1, 1) = sev; Message(end+1, 1) = msg;
    end

% --- Source ------------------------------------------------------------------------
S = obj.Source;
if ~ismember(S.Mode, ["project" "folders"])
    add("Source", "Mode", "error", "Mode must be ""project"" or ""folders"".");
elseif S.Mode == "project"
    if S.Root == ""
        add("Source", "Root", "error", "The project root is empty.");
    elseif opts.CheckPaths && ~isfolder(S.Root)
        add("Source", "Root", "error", "The project root does not exist: " + S.Root);
    end
    if S.OutputRoot ~= "" && opts.CheckPaths && ~isfolder(S.OutputRoot)
        add("Source", "OutputRoot", "warning", "The output root does not exist: " + S.OutputRoot);
    end
    if ~ismember(S.Selection, ["all" "list"])
        add("Source", "Selection", "error", "Selection must be ""all"" or ""list"".");
    elseif S.Selection == "list" && isempty(S.Datasets)
        add("Source", "Datasets", "warning", "Selection is ""list"" but no datasets are listed; nothing will run.");
    end
    try
        parseNameTokens("", S.NamePattern);
    catch ME
        add("Source", "NamePattern", "error", string(ME.message));
    end
    if ~ismember(S.Recordings, ["concatenate" "separate" "single"])
        add("Source", "Recordings", "error", "Recordings must be ""concatenate"", ""separate"" or ""single"".");
    end
else
    if isempty(S.Folders)
        add("Source", "Folders", "error", "Mode is ""folders"" but no folders are listed.");
    elseif opts.CheckPaths
        for f = S.Folders
            if ~isfolder(f); add("Source", "Folders", "error", "Folder not found: " + f); end
        end
    end
end

% --- Defaults ------------------------------------------------------------------------
D = obj.Defaults;
checkRef(D.EventRef, "Defaults", "EventRef");
checkWindow(D.Window, "Defaults", "Window");
checkSelection(D.Selection, "Defaults", "Selection");

% --- Plots -----------------------------------------------------------------------------
K = EphysAnalysisConfig.plotKinds();
if isempty(obj.Plots) || ~any([obj.Plots.enabled])
    add("Plots", "enabled", "error", "No plot is enabled.");
end
ids = obj.plotIds();
key = lower(regexprep(ids, '[^\w\-\.]', '_'));   % the id as {Plot} writes it (figureFileName), case-blind (Windows)
for u = unique(key)
    same = ids(key == u);
    if numel(same) > 1
        add("Plots", same(end) + ".id", "error", "Plot ids " + strjoin("""" + same + """", " and ") + ...
            " name the same files: {Plot} replaces characters outside A-Z a-z 0-9 _ - . by ""_"", and Windows ignores case.");
    end
end
for k = 1:numel(obj.Plots)
    p = obj.Plots(k);
    f0 = p.id;
    if ~ismember(p.kind, EphysAnalysisConfig.Kinds)
        add("Plots", f0 + ".kind", "error", "Unknown kind """ + p.kind + """ (kinds: " + strjoin(EphysAnalysisConfig.Kinds, ", ") + ").");
        continue
    end
    row = K(K.Kind == p.kind, :);
    if ~ismember(p.source, row.Sources{1})
        add("Plots", f0 + ".source", "error", sprintf("A %s plot reads %s, not ""%s"".", p.kind, strjoin(row.Sources{1}, " / "), p.source));
    end
    if p.layout ~= "" && ~ismember(p.layout, row.Layouts{1})
        add("Plots", f0 + ".layout", "error", sprintf("A %s plot has layouts %s, not ""%s"".", p.kind, strjoin(row.Layouts{1}, " / "), p.layout));
    end
    if row.Aligned
        if isstruct(p.ref); checkRef(p.ref, "Plots", f0 + ".ref"); end
        if isstruct(p.window); checkWindow(p.window, "Plots", f0 + ".window"); end
        if isstruct(p.selection); checkSelection(p.selection, "Plots", f0 + ".selection"); end
        w = p.window;
        if isequal(w, "default"); w = D.Window; end
        if ~ismember(w.mode, row.WindowModes{1})
            between = K.Kind(cellfun(@(m) ismember("between", m), K.WindowModes));
            add("Plots", f0 + ".window", "error", sprintf("A %s plot needs a fixed window (""between"" windows are for %s plots).", ...
                p.kind, strjoin(between, " / ")));
        end
    end
    if ~ismember(p.measure, ["rate" "count" "probability"])
        add("Plots", f0 + ".measure", "error", "The measure is rate, count or probability.");
    end
    if p.kind == "tuning" && strtrim(p.param) == ""
        add("Plots", f0 + ".param", "error", "A tuning plot needs param: the trial parameter on its x axis.");
    end
    if p.kind == "behavior"
        if strtrim(p.param) == ""
            add("Plots", f0 + ".param", "error", "A behavior plot needs param: the trial parameter on its x axis.");
        end
        if strtrim(p.yParam) == ""
            add("Plots", f0 + ".yParam", "error", "A behavior plot needs yParam: a trial parameter (e.g. RespLatency), or ""stop"" for the stop event's latency.");
        elseif p.yParam == "stop"
            w = p.window;
            if isequal(w, "default"); w = D.Window; end
            if isempty(w.stop)
                add("Plots", f0 + ".yParam", "error", "yParam ""stop"" plots each epoch's stop-event latency: give the epoch window a stop event.");
            end
        end
        if ~ismember(p.xScale, ["category" "linear"])
            add("Plots", f0 + ".xScale", "error", "A behavior plot's xScale is category or linear.");
        end
        if p.layout == "violin" && ~exist('violinplot', 'file')
            add("Plots", f0 + ".layout", "error", "The violin layout needs violinplot (MATLAB R2024b or later).");
        end
    end
    if ismember(p.kind, ["psth" "raster"])
        if ~ismember(p.rasterSortOrder, ["ascending" "descending"])
            add("Plots", f0 + ".rasterSortOrder", "error", "The raster sort order is ascending or descending.");
        end
        if p.rasterSort == "event"
            if isempty(p.rasterSortEvent)
                add("Plots", f0 + ".rasterSortEvent", "error", "rasterSort ""event"" sorts the raster by an event's " + ...
                    "latency from each epoch's event: give rasterSortEvent, e.g. Platform offset.");
            else
                checkRef(p.rasterSortEvent, "Plots", f0 + ".rasterSortEvent");
            end
        end
        mk = p.rasterEvents;
        if ~ismember(mk.edge, ["onset" "offset" "both"])
            add("Plots", f0 + ".rasterEvents.edge", "error", "The raster marks' edge is onset, offset or both.");
        end
        if ~ismember(mk.scope, ["window" "trial"])
            add("Plots", f0 + ".rasterEvents.scope", "error", "The raster marks' scope is window or trial.");
        end
        markers = PlotAesthetics.catalog().Marker.Choices;
        if ~ismember(mk.marker, markers)
            add("Plots", f0 + ".rasterEvents.marker", "error", "The raster marks' marker is one of " + strjoin(markers, ", ") + ".");
        end
        if ~(mk.size > 0 && isfinite(mk.size))
            add("Plots", f0 + ".rasterEvents.size", "error", "The raster marks' size must be positive (points).");
        end
        if mk.color ~= "" && ~isColor(mk.color)
            add("Plots", f0 + ".rasterEvents.color", "warning", "No color """ + mk.color + """; each mark gets its own color.");
        end
        for q = 1:numel(mk.sequences)
            checkRef(mk.sequences(q), "Plots", f0 + ".rasterEvents.sequences(" + q + ")");
        end
    end
    if ismember(p.kind, ["psth" "raster"]) || (p.kind == "heatmap" && ismember(p.source, EphysAnalysisConfig.SpikeSources)) ...
            || (p.kind == "corrmap" && p.metric == "peak")
        if ~(p.bins.BinSec > 0); add("Plots", f0 + ".bins.BinSec", "error", "BinSec must be positive."); end
        if ~(p.bins.SmoothSec >= 0); add("Plots", f0 + ".bins.SmoothSec", "error", "SmoothSec must be >= 0."); end
    end
    switch p.kind
        case {"psth" "raster" "heatmap"}
            modes = ["none" "subtract" "zscore" "percent"];
            if p.kind ~= "raster"; modes(end+1) = "auroc"; end
            if ismember(p.source, EphysAnalysisConfig.SignalSources); modes = ["none" "subtract"]; end
        case {"rate" "tuning"}
            modes = ["none" "subtract" "ratio" "zscore"];
        case {"evoked" "corrmap"}
            modes = ["none" "subtract"];
        otherwise
            modes = "none";
    end
    bm = p.baseline;
    if ~ismember(bm.Mode, modes)
        add("Plots", f0 + ".baseline.Mode", "error", sprintf("A %s plot's baseline Mode is one of %s, not ""%s"".", p.kind, strjoin(modes, ", "), bm.Mode));
    elseif bm.Mode ~= "none" && ~(numel(bm.Window) == 2 && bm.Window(2) > bm.Window(1))
        add("Plots", f0 + ".baseline.Window", "error", "The baseline window must be [b0 b1] with b0 < b1.");
    end
    if bm.Mode == "auroc" && ismember(bm.Mode, modes)
        checkAuroc(p.auroc, p.bins.BinSec, "Plots", f0 + ".auroc", true);
    end
    if p.kind == "psth"
        if ~ismember(p.histStyle, ["bar" "line"])
            add("Plots", f0 + ".histStyle", "error", "A PSTH is drawn as bar or line.");
        end
        if ~ismember(p.normalize, ["none" "unitPeak" "groupPeak"])
            add("Plots", f0 + ".normalize", "error", "A PSTH's normalize is none, unitPeak or groupPeak.");
        end
        if ~(isnan(p.fillAlpha) || (p.fillAlpha >= 0 && p.fillAlpha <= 1))
            add("Plots", f0 + ".fillAlpha", "error", "fillAlpha is an opacity from 0 to 1 (NaN = automatic).");
        end
        if ~(p.stackSpacing > 0 && isfinite(p.stackSpacing))
            add("Plots", f0 + ".stackSpacing", "error", "stackSpacing must be positive (1 = the tallest PSTH reaches the next row).");
        end
    end
    if p.kind == "probemap" && ~ismember(p.value, ["rate" "nSpikes" "nUnits"])
        add("Plots", f0 + ".value", "error", "A probe map shows rate, nSpikes or nUnits.");
    end
    if p.kind == "heatmap" && ~ismember(p.order, ["probe" "peak" "modulation"])
        add("Plots", f0 + ".order", "error", "A heatmap orders its rows by probe (the style's sort options), peak or modulation.");
    elseif p.kind == "heatmap" && p.order == "modulation" && bm.Mode ~= "auroc"
        add("Plots", f0 + ".order", "error", "A heatmap's rows go in modulation order only with the auROC baseline (baseline Mode ""auroc"").");
    end
    if p.kind == "corrmap"
        if ~ismember(p.metric, ["mean" "peak"])
            add("Plots", f0 + ".metric", "error", "A unit correlation map correlates each epoch's mean or peak rate.");
        end
        if ~ismember(p.correlation, ["pearson" "spearman"])
            add("Plots", f0 + ".correlation", "error", "A unit correlation map's correlation is pearson or spearman.");
        end
    end
    if ~(p.units.maxUnits >= 1)
        add("Plots", f0 + ".units.maxUnits", "error", "maxUnits must be >= 1 (Inf = all).");
    end
    rs = p.units.response;
    if rs.enabled && ismember(p.source, EphysAnalysisConfig.SpikeSources)
        r0 = f0 + ".units.response";
        if ~ismember(rs.test, ["evoked" "tuning" "either" "both" "auroc"])
            add("Plots", r0 + ".test", "error", "The response test is evoked, tuning, either, both or auroc.");
        elseif rs.test == "auroc"
            checkAuroc(rs.auroc, rs.auroc.binSec, "Plots", r0 + ".auroc", false);
        elseif rs.test ~= "evoked" && rs.param == ""
            add("Plots", r0 + ".param", "error", "The tuning test needs the trial parameter (param).");
        end
        for wf = ["baseline" "window"]
            if ~(numel(rs.(wf)) == 2 && all(isfinite(rs.(wf))) && rs.(wf)(2) > rs.(wf)(1))
                add("Plots", r0 + "." + wf, "error", "The response test's " + wf + " must be [from to] with from < to (s from the event).");
            end
        end
        if ~ismember(rs.direction, ["any" "excited" "suppressed"])
            add("Plots", r0 + ".direction", "error", "The response direction is any, excited or suppressed.");
        end
        if ~ismember(rs.correction, ["bh" "holm" "bonferroni" "none"])
            add("Plots", r0 + ".correction", "error", "The correction is bh, holm, bonferroni or none.");
        end
        if ~(rs.alpha > 0 && rs.alpha <= 1)
            add("Plots", r0 + ".alpha", "error", "alpha must be in (0, 1].");
        end
        if ~(license('test', 'Statistics_Toolbox') && exist('signrank', 'file'))
            add("Plots", r0 + ".enabled", "error", "The response test needs the Statistics and Machine Learning Toolbox (signrank, kruskalwallis).");
        end
    end
    wv = p.waveform;
    w0 = f0 + ".waveform";
    if ~ismember(wv.ampScale, ["unit" "common"])
        add("Plots", w0 + ".ampScale", "error", "The waveform amplitude scale is unit or common.");
    end
    if ~ismember(wv.mode, ["off" "mean" "subsample" "both"])
        add("Plots", w0 + ".mode", "error", "The waveform mode is off, mean, subsample or both.");
    elseif p.kind == "waveforms" && wv.mode == "off"
        add("Plots", w0 + ".mode", "error", "A waveforms plot shows the mean, a subsample or both: its waveform mode cannot be off.");
    elseif wv.mode ~= "off"
        if ~ismember(wv.location, EphysAnalysisConfig.WaveformLocations)
            add("Plots", w0 + ".location", "error", "The waveform location is one of " + ...
                strjoin(EphysAnalysisConfig.WaveformLocations, ", ") + ".");
        end
        if ~(wv.scale > 0 && wv.scale <= 3)
            add("Plots", w0 + ".scale", "error", "The waveform scale is above 0 and at most 3 (1 = a third of the tile).");
        end
        if ~(wv.maxSpikes >= 1 && wv.maxSpikes == round(wv.maxSpikes))
            add("Plots", w0 + ".maxSpikes", "error", "maxSpikes is a whole number of spikes, at least 1.");
        end
        if ~(ismember(p.source, EphysAnalysisConfig.SpikeSources) && (ismember(p.kind, ["raster" "waveforms"]) || ...
                (ismember(p.kind, ["psth" "tuning"]) && p.layout ~= "overlay")))
            add("Plots", w0 + ".mode", "warning", "Unit waveforms are drawn in the tiles of a raster, or of a " + ...
                "PSTH or tuning grid, of spikes; this plot draws none.");
        end
    end
    aux = p.aux;
    x0 = f0 + ".aux";
    if ~ismember(aux.mode, EphysAnalysisConfig.AuxModes)
        add("Plots", x0 + ".mode", "error", "The aux mode is one of " + strjoin(EphysAnalysisConfig.AuxModes, ", ") + ".");
    elseif aux.mode ~= "off"
        if ~(ismember(p.kind, ["psth" "raster"]) && ismember(p.source, EphysAnalysisConfig.SpikeSources))
            add("Plots", x0 + ".mode", "warning", "The mean aux signal is drawn with the units of a PSTH or raster " + ...
                "of spikes; this plot draws none.");
        end
        if ~ismember(aux.placement, EphysAnalysisConfig.AuxPlacements)
            add("Plots", x0 + ".placement", "error", "The aux placement is one of " + ...
                strjoin(EphysAnalysisConfig.AuxPlacements, ", ") + ".");
        elseif aux.placement == "over" && p.kind == "psth" && p.stack
            add("Plots", x0 + ".placement", "warning", "A stacked PSTH's right axis labels its rows' peaks: " + ...
                "the aux signal goes below it instead of over it.");
        end
        if ~isempty(aux.channels) && ~all(aux.channels >= 1 & aux.channels == round(aux.channels))
            add("Plots", x0 + ".channels", "error", "The aux channels are columns of the AUX extract: whole numbers, at least 1 ([] = all).");
        end
        if ~ismember(aux.baseline, ["none" "subtract"])
            add("Plots", x0 + ".baseline", "error", "The aux baseline is none or subtract.");
        elseif aux.baseline == "subtract"
            bw = aux.baselineWindow;
            w = p.window;
            if isequal(w, "default"); w = D.Window; end
            if ~(numel(bw) == 2 && all(isfinite(bw)) && bw(2) > bw(1))
                add("Plots", x0 + ".baselineWindow", "error", "The aux baseline window must be [b0 b1] with b0 < b1 (s from the event).");
            elseif isstruct(w) && (bw(2) < w.pre || bw(1) > w.post)
                add("Plots", x0 + ".baselineWindow", "error", sprintf("The aux baseline window [%g %g] s must overlap " + ...
                    "the epoch window [%g %g] s: it is taken from the samples cut for each epoch.", bw(1), bw(2), w.pre, w.post));
            end
        end
    end
    nt = p.note;
    n0 = f0 + ".note";
    if strtrim(nt.text) ~= ""
        if ~ismember(nt.placement, EphysAnalysisConfig.NotePlacements)
            add("Plots", n0 + ".placement", "error", "The note placement is one of " + strjoin(EphysAnalysisConfig.NotePlacements, ", ") + ".");
        elseif nt.placement == "custom" && ~(isfinite(nt.x) && isfinite(nt.y))
            add("Plots", n0 + ".x", "error", "A custom note needs a finite x and y (0-1 across and up the plot).");
        end
        if ~ismember(nt.align, ["left" "center" "right"])
            add("Plots", n0 + ".align", "error", "The note alignment is left, center or right.");
        end
        if ~ismember(nt.valign, ["top" "middle" "bottom"])
            add("Plots", n0 + ".valign", "error", "The note vertical alignment is top, middle or bottom.");
        end
        if ~ismember(nt.interpreter, ["none" "tex"])
            add("Plots", n0 + ".interpreter", "error", "The note interpreter is none or tex.");
        end
        if ~isfinite(nt.rotation)
            add("Plots", n0 + ".rotation", "error", "The note rotation is a number of degrees.");
        end
        if ~(isnan(nt.fontSize) || (isfinite(nt.fontSize) && nt.fontSize > 0))
            add("Plots", n0 + ".fontSize", "error", "The note font size is positive (NaN: the plot's).");
        end
        for cf = ["color" "background"]
            if nt.(cf) ~= "" && ~isColor(nt.(cf))
                add("Plots", n0 + "." + cf, "warning", "No color """ + nt.(cf) + """; the note's " + cf + " is left to the design.");
            end
        end
    end
    names = strings(1, 0);
    for q = 1:numel(p.overlays)
        ov = p.overlays(q);
        o0 = f0 + ".overlays(" + q + ")";
        if ~ismember(ov.shape, ["line" "region"])
            add("Plots", o0 + ".shape", "error", "An overlay is a line or a region.");
        elseif ov.shape == "line" && ~isfinite(ov.value)
            add("Plots", o0 + ".value", "error", "An overlay line needs a finite position (data units).");
        elseif ov.shape == "region"
            if ~(isfinite(ov.from) && isfinite(ov.to))
                add("Plots", o0 + ".from", "error", "An overlay region needs finite edges, from and to (data units).");
            elseif ov.from == ov.to
                add("Plots", o0 + ".to", "error", "An overlay region's edges must differ (from and to are both " + ov.from + ").");
            end
        end
        if ~ismember(ov.axis, ["x" "y"])
            add("Plots", o0 + ".axis", "error", "An overlay's axis is x (vertical line, patch between x values) or y.");
        end
        if ~ismember(ov.panel, EphysAnalysisConfig.OverlayPanels)
            add("Plots", o0 + ".panel", "error", "An overlay's panel is one of " + strjoin(EphysAnalysisConfig.OverlayPanels, ", ") + ".");
        elseif (ov.panel == "raster" && ~(p.kind == "raster" || (p.kind == "psth" && p.withRaster))) ...
                || (ov.panel == "data" && p.kind == "raster")
            add("Plots", o0 + ".panel", "warning", "A " + p.kind + " plot draws no " + ov.panel + " panel here; this overlay is not drawn.");
        end
        if ~ismember(ov.layer, EphysAnalysisConfig.OverlayLayers)
            add("Plots", o0 + ".layer", "error", "An overlay's layer is over or under the data.");
        end
        if ~ismember(ov.lineStyle, EphysAnalysisConfig.OverlayLineStyles)
            add("Plots", o0 + ".lineStyle", "error", "An overlay's line style is one of " + strjoin(EphysAnalysisConfig.OverlayLineStyles, "  ") + ".");
        end
        if ~(isfinite(ov.lineWidth) && ov.lineWidth > 0)
            add("Plots", o0 + ".lineWidth", "error", "An overlay's line width must be positive (points).");
        end
        for af = ["alpha" "faceAlpha"]
            if ~(ov.(af) >= 0 && ov.(af) <= 1)
                add("Plots", o0 + "." + af, "error", "An overlay's " + af + " is an opacity from 0 to 1.");
            end
        end
        for cf = ["color" "faceColor" "edgeColor"]
            if ~(cf == "edgeColor" && lower(strtrim(ov.(cf))) == "none") && ~isColor(ov.(cf))
                add("Plots", o0 + "." + cf, "warning", "No color """ + ov.(cf) + """; the overlay keeps its default " + cf + ".");
            end
        end
        if strtrim(ov.name) ~= "" && ismember(strtrim(ov.name), names)
            add("Plots", o0 + ".name", "warning", "Another overlay of this plot is also named """ + strtrim(ov.name) + ...
                """; a change in the aesthetics editor reaches both.");
        end
        names(end+1) = strtrim(ov.name); %#ok<AGROW>
    end
    st = p.style;
    if ~(st.MaxTiles >= 1); add("Plots", f0 + ".style.MaxTiles", "error", "MaxTiles must be >= 1."); end
    if ~ismember(st.TileSpacing, ["loose" "compact" "tight" "none"])
        add("Plots", f0 + ".style.TileSpacing", "error", "TileSpacing is loose, compact, tight or none.");
    end
    if ~ismember(st.LegendLocation, ["auto" "inside" "north" "south" "east" "west"])
        add("Plots", f0 + ".style.LegendLocation", "error", "LegendLocation is auto, inside, north, south, east or west.");
    end
    if ~ismember(st.LegendOrientation, ["auto" "vertical" "horizontal"])
        add("Plots", f0 + ".style.LegendOrientation", "error", "LegendOrientation is auto, vertical or horizontal.");
    end
    if ~ismember(st.ErrorType, EphysAnalysisConfig.ErrorTypes)
        add("Plots", f0 + ".style.ErrorType", "error", "ErrorType is sem (mean +/- SEM), std (mean +/- SD) or ci95 (bootstrap 95% CI).");
    elseif st.ShowSEM && st.ErrorType == "ci95" && (plotErrorType(p) == "ci95" || plotErrorType(p, "aux") == "ci95") ...
            && ~(license('test', 'Statistics_Toolbox') && exist('bootci', 'file'))
        add("Plots", f0 + ".style.ErrorType", "error", "The bootstrap 95% CI needs the Statistics and Machine Learning Toolbox (bootci).");
    end
    if ~(isfinite(st.ErrorResamples) && st.ErrorResamples >= 1 && st.ErrorResamples == round(st.ErrorResamples))
        add("Plots", f0 + ".style.ErrorResamples", "error", "ErrorResamples is a whole number of bootstrap resamples, at least 1.");
    end
    if ~(isnan(st.ErrorFaceAlpha) || (st.ErrorFaceAlpha >= 0 && st.ErrorFaceAlpha <= 1))
        add("Plots", f0 + ".style.ErrorFaceAlpha", "error", "ErrorFaceAlpha is an opacity from 0 to 1 (NaN = opaque, the trace's color paled).");
    end
    if st.ErrorFaceColor ~= "" && ~isColor(st.ErrorFaceColor)
        add("Plots", f0 + ".style.ErrorFaceColor", "warning", "No color """ + st.ErrorFaceColor + """; the bands take their trace's color.");
    end
    if ~ismember(lower(strtrim(st.ErrorEdgeColor)), ["none" "auto"]) && ~isColor(st.ErrorEdgeColor)
        add("Plots", f0 + ".style.ErrorEdgeColor", "warning", "No color """ + st.ErrorEdgeColor + """; the bands have no edge.");
    end
    if ~ismember(st.ErrorEdgeStyle, EphysAnalysisConfig.OverlayLineStyles)
        add("Plots", f0 + ".style.ErrorEdgeStyle", "error", "ErrorEdgeStyle is one of " + strjoin(EphysAnalysisConfig.OverlayLineStyles, "  ") + ".");
    end
    if ~(isfinite(st.ErrorEdgeWidth) && st.ErrorEdgeWidth > 0)
        add("Plots", f0 + ".style.ErrorEdgeWidth", "error", "ErrorEdgeWidth must be positive (points).");
    end
    if ~(st.FontSize > 0);  add("Plots", f0 + ".style.FontSize", "error", "FontSize must be positive."); end
    if ~(st.LineWidth > 0); add("Plots", f0 + ".style.LineWidth", "error", "LineWidth must be positive."); end
    if ~(st.SiteSize > 0);  add("Plots", f0 + ".style.SiteSize", "error", "SiteSize must be positive."); end
    for cm = ["Colormap" "HeatColormap"]
        if ~(cm == "Colormap" && (st.(cm) == "lines" || isColor(st.(cm)))) && ~(cm == "HeatColormap" && st.(cm) == "") ...
                && ~ismember(exist(char(st.(cm))), [2 5]) %#ok<EXIST>
            what = "colormap function";
            if cm == "Colormap"; what = "colormap function or color"; end
            add("Plots", f0 + ".style." + cm, "warning", "No " + what + " """ + st.(cm) + """; the default is used.");
        end
    end
end

% --- Export -----------------------------------------------------------------------------
X = obj.Export;
if X.Enabled && isempty(X.Formats)
    add("Export", "Formats", "error", "Export is enabled but no format is chosen (png, eps, svg, pdf).");
end
bad = setdiff(X.Formats, ["png" "eps" "svg" "pdf"]);
if ~isempty(bad)
    add("Export", "Formats", "error", "Unknown format(s) " + strjoin(bad, ", ") + " (png, eps, svg, pdf).");
end
if ~(X.Dpi > 0); add("Export", "Dpi", "error", "Dpi must be positive."); end
if ~(numel(X.FigureSizeCm) == 2 && all(X.FigureSizeCm > 0))
    add("Export", "FigureSizeCm", "error", "FigureSizeCm must be [width height] > 0.");
end
checkPattern(X.FilenamePattern, "file", "Export", "FilenamePattern");
checkPattern(X.Folder, "folder", "Export", "Folder");
on = obj.Plots([obj.Plots.enabled]);
if numel(on) > 1 && ~contains(X.FilenamePattern, "{Plot}") ...
        && ~(contains(X.FilenamePattern, "{Kind}") && numel(unique([on.kind])) == numel(on))
    add("Export", "FilenamePattern", "warning", sprintf("The file-name pattern has no {Plot}, so the %d enabled plots' files overwrite each other.", numel(on)));
end
if ~contains(X.Folder, ["{OutputFolder}" "{Name}"]) && ~contains(X.FilenamePattern, "{Name}") ...
        && ~(S.Mode == "folders" && numel(S.Folders) <= 1)
    add("Export", "Folder", "warning", "Neither the export folder nor the file-name pattern names the dataset ({OutputFolder} or {Name}), so the datasets' files overwrite each other.");
end

% --- Report -------------------------------------------------------------------------------
P = obj.Report;
if ~ismember(P.Format, ["html" "pdf" "both"])
    add("Report", "Format", "error", "Format must be html, pdf or both.");
end
if ~ismember(P.EmbedFormat, ["png" "svg"])
    add("Report", "EmbedFormat", "error", "EmbedFormat must be png or svg.");
end
if ~(P.Dpi > 0); add("Report", "Dpi", "error", "Dpi must be positive."); end
if strtrim(P.FileName) == "" || ~isempty(regexp(P.FileName, '[\\/:*?"<>|]', 'once'))
    add("Report", "FileName", "error", "FileName must be a plain file name (no folder, no \ / : * ? "" < > |).");
end
checkPattern(P.Folder, "folder", "Report", "Folder");
if ~P.PerDataset && contains(P.Folder, "{OutputFolder}")
    add("Report", "Folder", "warning", "{OutputFolder} is one dataset's folder; a report over every dataset goes to the first dataset's.");
end

issues = table(Section, Field, Severity, Message);

    function checkRef(r, sec, field)
        try
            eventRef(r);
        catch ME
            add(sec, field, "error", string(ME.message));
        end
    end

    function checkWindow(w, sec, field)
        try
            epochWindow(w);
        catch ME
            add(sec, field, "error", string(ME.message));
        end
    end

    function checkAuroc(a, binSec, sec, field, isPlot)
        %checkAuroc  A plot's auroc settings (ISPLOT) or a response test's.
        if ~ismember(a.method, ["psth" "epochs"]); add(sec, field + ".method", "error", "The auROC method is psth or epochs."); end
        if ~ismember(a.windows, ["tiled" "sliding"]); add(sec, field + ".windows", "error", "The auROC windows are tiled or sliding."); end
        whole = @(x) binSec > 0 && x / binSec >= 1 - 1e-6 && abs(x / binSec - round(x / binSec)) < 1e-6;
        if ~whole(a.windowSec)
            add(sec, field + ".windowSec", "error", sprintf("The auROC window (%g s) must be a whole number of %g s bins.", a.windowSec, binSec));
        end
        if a.windows == "sliding" && ~whole(a.stepSec)
            add(sec, field + ".stepSec", "error", sprintf("The sliding step (%g s) must be a whole number of %g s bins.", a.stepSec, binSec));
        end
        if ~ismember(a.cutoff, ["ci" "fixed" "test" "none"])
            add(sec, field + ".cutoff", "error", "The auROC cutoff is ci, fixed, test or none.");
        elseif ~isPlot && a.cutoff == "none"
            add(sec, field + ".cutoff", "error", "The auROC response test needs a cutoff (ci, fixed or test) to call units modulated.");
        end
        if a.cutoff == "fixed" && ~(a.threshold >= 0 && a.threshold < 0.5)
            add(sec, field + ".threshold", "error", "The threshold is |auROC - 0.5|, from 0 up to (not including) 0.5.");
        end
        if a.cutoff == "test"
            if ~ismember(a.test, ["bootstrap" "ranksum" "shuffle"])
                add(sec, field + ".test", "error", "The auROC test is bootstrap, ranksum or shuffle.");
            elseif a.test ~= "ranksum" && ~(a.nResamples >= 1 && a.nResamples == round(a.nResamples))
                add(sec, field + ".nResamples", "error", "nResamples must be a whole number >= 1.");
            end
        end
        if isPlot
            m = a.modulationWindow;
            if ~(numel(m) == 2 && all(isfinite(m)) && m(2) > m(1))
                add(sec, field + ".modulationWindow", "error", "The modulation window must be [m0 m1] with m0 < m1 (s from the event).");
            end
            if a.cutoff == "test"
                if ~ismember(a.correction, ["bh" "holm" "bonferroni" "none"])
                    add(sec, field + ".correction", "error", "The correction is bh, holm, bonferroni or none.");
                end
                if ~(a.alpha > 0 && a.alpha <= 1); add(sec, field + ".alpha", "error", "alpha must be in (0, 1]."); end
            end
            if a.modulatedOnly && a.cutoff == "none"
                add(sec, field + ".modulatedOnly", "error", "Modulated units only needs a cutoff (ci, fixed or test) to call units modulated.");
            end
        end
        if ~(license('test', 'Statistics_Toolbox') && exist('tiedrank', 'file'))
            add(sec, field, "error", "auROC needs the Statistics and Machine Learning Toolbox (tiedrank, tinv, ranksum).");
        end
    end

    function checkSelection(s, sec, field)
        try
            trialSelection(s);
        catch ME
            if ME.identifier == "trialSelection:BadFilter"
                add(sec, field + ".filter", "warning", string(ME.message));
            else
                add(sec, field, "error", string(ME.message));
            end
        end
    end

    function checkPattern(pattern, kind, sec, field)
        if kind == "file"
            t = struct('Name', "n", 'Plot', "p", 'Kind', "k", 'Group', "g", 'Unit', "u", 'Index', 1);
        else
            t = struct('OutputFolder', "o", 'OutputRoot', "r", 'Root', "r", 'Name', "n");
        end
        try
            figureFileName(pattern, t, Kind=kind);
        catch ME
            add(sec, field, "error", string(ME.message));
        end
        if kind == "file" && strtrim(pattern) == ""
            add(sec, field, "error", "The file-name pattern is empty.");
        end
    end
end


function tf = isColor(name)
%isColor  True for a color name or hex code (groupPalette gives every group that color).
try
    validatecolor(name);
    tf = true;
catch
    tf = false;
end
end
