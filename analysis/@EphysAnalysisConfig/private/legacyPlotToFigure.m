function [fig, notes] = legacyPlotToFigure(p, defaults, layout)
%legacyPlotToFigure  The figure that draws what one plot of a version-1 config drew, for its migration only.
%   [FIG, NOTES] = legacyPlotToFigure(P, DEFAULTS) converts the version-1
%   plot P (legacyNormalizePlot's; its "default" ref / window / selection
%   read from DEFAULTS, the config's Defaults section, where the
%   conversion needs them) into a figure (normalizeFigure'd), and NOTES, a
%   string row of what could not be carried, one sentence each. Nothing is
%   dropped silently: every setting the plot's kind uses that the figure
%   cannot hold is a note. LAYOUT (default "": the plot's own, else its
%   kind's default) overrides the plot's layout, as a version-1 session
%   plot's layout did. legacyMigrate calls it for every plot of a
%   version-1 file's Plots (and every session plot's base plot) and turns
%   NOTES into load warnings; nothing else uses it.
%
%   Figure level
%     id          the plot's id
%     enabled, title   the plot's
%     aesthetics  the plot's, through legacyLooks (auxTrace / auxSem /
%                 auxAxes become trace / sem / axes, a note each; a rule
%                 on a role no figure draws is dropped, a note)
%     ref, window, selection       the plot's ("default" stays "default")
%     style       the plot's, with MaxTiles, TileSpacing, XLim, YLim and
%                 CLim back at their defaults (a figure does not use them):
%                 YLim goes to the data panel's options.yLim (psth,
%                 continuous, waveforms, rate, tuning) and CLim to its
%                 options.cLim (heatmap, probemap, corrmap); the others,
%                 when set, are notes
%     the plot's bins, measure, baseline, auroc, maskAfterStop and
%                 waveform (a PSTH's, raster's or tuning curve's inset; a
%                 waveforms plot's own settings, its mode "off" drawn as
%                 "both") go into the options of every panel whose type
%                 has them (but a raster under a PSTH with an inset, which
%                 keeps its own waveform, and the aux signal's panel,
%                 which keeps the aux baseline). A baseline the figure's
%                 panels do not take (a signal's other than subtract)
%                 becomes "none"; the auROC baseline of a PSTH or heat map
%                 of spikes is carried with its auroc settings
%   The plot's text note goes to the panel it borders (below: the bottom
%   panel; above: the top one; elsewhere: the data panel) and each overlay
%   to the panels its panel names (raster: the raster panel; data: the
%   panels but the raster and the aux signal; all: every panel); an
%   overlay naming a panel the figure lacks is a note.
%   The plot's source (units / detected) is the layers' source and, for a
%   figure drawn per unit, observe.source; its unit filter is observe.units
%   when the figure observes units, else the fixed layer's units.
%
%   By kind
%     psth, grid      per unit: a raster panel (withRaster) over a PSTH
%                     panel, each with a layer following the unit; the
%                     raster sort options and rasterEvents (events layers
%                     drawn as marks) on the raster, histStyle / fill /
%                     fillAlpha / normalize / stack / stackSpacing on the
%                     PSTH; the aux signal as a continuous panel below (or
%                     above the raster) with a fixed AUX layer; spacing
%                     "none"
%     psth, overlay   per dataset: one PSTH panel with a fixed units layer
%                     (the plot's filter) and aggregate "mean"
%     raster          per unit: one raster panel, events layers, aux
%     evoked          grid: per channel (observe.signal = the source,
%                     observe.channels = the plot's channels), one
%                     continuous panel following the channel; stack: per
%                     dataset, one continuous panel of a fixed layer of the
%                     channels, display "stacked"; butterfly: as stack
%                     with display "lines"
%     heatmap         per dataset: one heat map of a fixed layer (the units
%                     filter, or the channels), its order (modulation
%                     included), trial group 1
%     probemap        per dataset: one probe map of a fixed layer
%     corrmap         per dataset: one correlation map of a fixed layer,
%                     trial group 1
%     waveforms       grid: per unit, one waveforms panel following the
%                     unit; probe: per dataset, a fixed layer, options.layout
%                     "probe"
%     rate            per unit: one rate panel following the unit, the
%                     layout (bar / box / points) as its display
%     tuning          grid: per unit, one tuning panel following the unit;
%                     overlay: per dataset, a fixed units layer with
%                     aggregate "mean" (the plot's mean over units); param,
%                     seriesParam
%   A behavior plot (no panel type), or a kind version 1 did not have,
%   raises EphysAnalysisConfig:NotConvertible.
%
%   See also legacyMigrate, legacyNormalizePlot, legacyPlotKinds,
%   EphysAnalysisConfig.normalizeFigure, EphysAnalysisConfig.panelTypes.

arguments
    p (1,1) struct
    defaults (1,1) struct
    layout (1,1) string = ""
end

K = legacyPlotKinds();
row = K.Kind == p.kind;
if ~any(row)
    error('EphysAnalysisConfig:NotConvertible', 'Plot "%s" is of kind "%s", which config version 1 did not have.', p.id, p.kind);
end
kindLabel = K.Label(row);
if p.kind == "behavior"
    error('EphysAnalysisConfig:NotConvertible', ...
        'Plot "%s" is a %s plot (%s): figures have no panel type for it, so it cannot be converted.', ...
        p.id, lower(kindLabel), p.kind);
end
% what version 1's plotFor resolved and the conversion reads: the layout, and the trial groups
spec = struct('layout', layout, 'selection', p.selection);
if spec.layout == ""; spec.layout = p.layout; end
if spec.layout == ""; spec.layout = K.DefaultLayout(row); end
if isequal(spec.selection, "default"); spec.selection = defaults.Selection; end
notes = string.empty(1, 0);
spikes = ismember(p.source, EphysAnalysisConfig.SpikeSources);

% --- figure level ---------------------------------------------------------------------------------
fig = struct();
fig.id = p.id;
fig.enabled = p.enabled;
fig.title = p.title;
fig.ref = p.ref;
fig.window = p.window;
fig.selection = p.selection;
[fig.aesthetics, lookNotes] = legacyLooks(p.aesthetics);   % aux roles renamed, retired roles dropped
for ln = lookNotes; addNote(ln); end

sd = EphysAnalysisConfig.defaults("Style");
st = p.style;
yLim = st.YLim;
cLim = st.CLim;
yUsed = isempty(yLim);
cUsed = isempty(cLim);
if ~isequal(st.MaxTiles, sd.MaxTiles)
    addNote(sprintf("Tiles per page (MaxTiles %g) is not used: a figure draws one observation per page.", st.MaxTiles));
end
if ~isequal(st.TileSpacing, sd.TileSpacing)
    addNote(sprintf("TileSpacing ""%s"" is not used: the figure's panels take grid.spacing.", st.TileSpacing));
end
if ~isempty(st.XLim)
    addNote(sprintf("XLim %s is not used: the time panels take the epoch window.", mat2str(st.XLim)));
end
for f = ["MaxTiles" "TileSpacing" "XLim" "YLim" "CLim"]
    st.(f) = sd.(f);
end
fig.style = st;

cm = struct('bins', p.bins, 'measure', p.measure, 'baseline', p.baseline, 'auroc', p.auroc, ...
    'maskAfterStop', p.maskAfterStop, 'waveform', p.waveform);   % the plot's options every panel of the figure takes
if ismember(p.kind, ["evoked" "corrmap"]) || (p.kind == "heatmap" && ~spikes)
    modes = ["none" "subtract"];
elseif ismember(p.kind, ["rate" "tuning"])
    modes = ["none" "subtract" "ratio" "zscore"];     % firingRate's Normalize, as the plot used it
elseif ismember(p.kind, ["psth" "heatmap"])
    modes = ["none" "subtract" "zscore" "percent" "auroc"];
else
    modes = ["none" "subtract" "zscore" "percent"];
end
if ~ismember(p.baseline.Mode, modes)
    cm.baseline.Mode = "none";
    addNote(sprintf("The baseline ""%s"" is not one the figure's %s panel takes (%s): it became none.", p.baseline.Mode, ...
        lower(kindLabel), strjoin(modes, ", ")));
end

% --- the panels, top to bottom ---------------------------------------------------------------------
P = {};          % partial panel structs
heights = [];    % relative row heights
grouped = ~isempty(spec.selection.groupBy);
follow = struct('source', p.source, 'binding', "observation");
switch p.kind
    case "psth"
        if spec.layout == "overlay"
            fig.observe = struct('kind', "dataset");
            if p.withRaster
                addNote("The overlay's raster (withRaster) is not carried: an overlay of several units draws none.");
            end
            if ~isempty(p.rasterEvents)
                addNote(sprintf("%d raster event mark(s) not carried: the overlay draws no raster.", numel(p.rasterEvents)));
            end
            if p.waveform.mode ~= "off"
                cm.waveform.mode = "off";
                addNote("The waveform inset is not carried: an overlay of several units draws none.");
            end
            L = struct('source', p.source, 'binding', "fixed", 'units', p.units, 'aggregate', "mean");
            addPanel(panelOf("psth", psthOptions(), {L}), 1);
        else
            observeUnits();
            if p.withRaster
                r = panelOf("raster", rasterOptions(), [{follow}, markLayers()]);
                if p.waveform.mode ~= "off"   % the inset sits in the PSTH, as the plot drew it
                    r.plotOptions = false;
                    r.options.maskAfterStop = p.maskAfterStop;
                end
                addPanel(r, 1);
            elseif ~isempty(p.rasterEvents)
                addNote(sprintf("%d raster event mark(s) not carried: the plot draws no raster (withRaster is off).", ...
                    numel(p.rasterEvents)));
            end
            addPanel(panelOf("psth", psthOptions(), {follow}), 1);
            fig.grid = struct('spacing', "none");
        end
        if p.stack && p.stackRaster && p.withRaster && spec.layout ~= "overlay"
            addNote("stackRaster (each group's raster in its PSTH row) is not available: the raster is a panel of its own above the stack.");
        end
        addAux();
    case "raster"
        observeUnits();
        addPanel(panelOf("raster", rasterOptions(), [{follow}, markLayers()]), 1);
        fig.grid = struct('spacing', "none");
        addAux();
    case "evoked"
        o = continuousOptions();
        if spec.layout == "grid"
            fig.observe = struct('kind', "channel", 'signal', p.source, 'channels', p.channels);
            addPanel(panelOf("continuous", o, {follow}), 1);
        else
            fig.observe = struct('kind', "dataset");
            o.stackSpacing = p.style.StackSpacing;
            if spec.layout == "stack"
                o.display = "stacked";
            else
                o.display = "lines";
                addNote("The butterfly layout's one panel per group is not available: the channels are drawn as lines in one panel.");
            end
            L = struct('source', p.source, 'binding', "fixed", 'channels', p.channels, 'aggregate', "each");
            addPanel(panelOf("continuous", o, {L}), 1);
        end
    case "heatmap"
        fig.observe = struct('kind', "dataset");
        o = struct('order', p.order, 'group', 1, 'cLim', cLim);
        cUsed = true;
        oneGroupNote("heat map");
        addPanel(panelOf("heatmap", o, {fixedLayer()}), 1);
    case "probemap"
        fig.observe = struct('kind', "dataset");
        cUsed = true;
        addPanel(panelOf("probemap", struct('value', p.value, 'cLim', cLim), {fixedLayer()}), 1);
    case "corrmap"
        fig.observe = struct('kind', "dataset");
        cUsed = true;
        oneGroupNote("correlation map");
        o = struct('metric', p.metric, 'correlation', p.correlation, 'fisherZ', p.fisherZ, 'group', 1, 'cLim', cLim);
        addPanel(panelOf("corrmap", o, {fixedLayer()}), 1);
    case "waveforms"
        yUsed = true;
        o = struct('layout', spec.layout, 'yLim', yLim);
        if spec.layout == "probe"
            fig.observe = struct('kind', "dataset");
            addPanel(panelOf("waveforms", o, {fixedLayer()}), 1);
        else
            observeUnits();
            addPanel(panelOf("waveforms", o, {follow}), 1);
        end
    case "rate"
        observeUnits();
        yUsed = true;
        o = struct('measure', p.measure, 'baseline', cm.baseline, 'display', spec.layout, 'yLim', yLim);
        addPanel(panelOf("rate", o, {follow}), 1);
    case "tuning"
        yUsed = true;
        o = struct('param', p.param, 'seriesParam', p.seriesParam, 'measure', p.measure, 'baseline', cm.baseline, 'yLim', yLim);
        if spec.layout == "overlay"
            fig.observe = struct('kind', "dataset");
            if p.waveform.mode ~= "off"
                cm.waveform.mode = "off";
                addNote("The waveform inset is not carried: an overlay of several units draws none.");
            end
            L = struct('source', p.source, 'binding', "fixed", 'units', p.units, 'aggregate', "mean");
            addPanel(panelOf("tuning", o, {L}), 1);
        else
            observeUnits();
            addPanel(panelOf("tuning", o, {follow}), 1);
        end
end
if ~yUsed
    addNote(sprintf("YLim %s is not used: no panel of this figure takes y limits from the plot.", mat2str(yLim)));
end
if ~cUsed
    addNote(sprintf("CLim %s is not used: no panel of this figure takes color limits.", mat2str(cLim)));
end
% the text note and the overlays: onto the panels they border or are drawn on
nP = numel(P);
isRaster = false(1, nP);
isAux = false(1, nP);
for j = 1:nP
    isRaster(j) = P{j}.type == "raster";
    isAux(j) = ismember(p.kind, ["psth" "raster"]) && P{j}.type == "continuous";   % addAux's panel
end
isData = ~isRaster & ~isAux;
if strtrim(p.note.text) ~= "" && nP > 0
    switch p.note.placement
        case "below", at = nP;   % the bottom panel
        case "above", at = 1;    % the top one
        otherwise
            at = find(isData, 1);   % beside or over the plot: its data panel
            if isempty(at); at = 1; end
    end
    P{at}.note = p.note;
    if nP > 1
        addNote(sprintf("The text note went to panel %d of %d (%s): a figure's notes belong to its panels.", at, nP, P{at}.type));
    end
end
lost = 0;
for i = 1:numel(p.overlays)
    ov = p.overlays(i);
    switch ov.panel
        case "raster", on = isRaster;
        case "data",   on = isData;
        otherwise,     on = true(1, nP);
    end
    if ~any(on); lost = lost + 1; continue; end
    ov.panel = "all";
    for j = find(on)
        if ~isfield(P{j}, 'overlays'); P{j}.overlays = ov; else; P{j}.overlays(end+1) = ov; end
    end
end
if lost > 0
    addNote(sprintf("%d overlay(s) not carried: the figure has no panel of the kind they name.", lost));
end

% --- the grid ---------------------------------------------------------------------------------------
n = numel(P);
for j = 1:n
    P{j}.row = j;
    P{j}.col = 1;
end
g = struct('rows', max(n, 1), 'cols', 1);
if isfield(fig, 'grid') && isfield(fig.grid, 'spacing') && n > 1
    g.spacing = fig.grid.spacing;
end
if n > 1 && numel(unique(heights)) > 1
    g.rowHeights = heights;
elseif n > 1
    g.rowHeights = ones(1, n);
end
fig.grid = g;
T = EphysAnalysisConfig.panelTypes();
for j = 1:n   % the plot's options, in every panel that takes them
    if P{j}.plotOptions
        for f = string(fieldnames(cm)).'
            if isfield(T.DefaultOptions{T.Type == P{j}.type}, f); P{j}.options.(f) = cm.(f); end
        end
        if P{j}.type == "waveforms" && P{j}.options.waveform.mode == "off"; P{j}.options.waveform.mode = "both"; end
    end
    P{j} = rmfield(P{j}, 'plotOptions');
end
fig.panels = P;
fig = EphysAnalysisConfig.normalizeFigure(fig, "Figure");


    % --- nested helpers ----------------------------------------------------------------------------
    function addNote(s)
        notes(1, end+1) = string(s);
    end

    function observeUnits()
        %observeUnits  The figure is drawn per unit of the plot's source, through the plot's filter.
        fig.observe = struct('kind', "unit", 'source', p.source, 'units', p.units);
    end

    function L = fixedLayer()
        %fixedLayer  A fixed layer of the plot's source: its units filter (spikes) or its channels (signals).
        L = struct('source', p.source, 'binding', "fixed");
        if spikes
            L.units = p.units;
        else
            L.channels = p.channels;
        end
    end

    function L = markLayers()
        %markLayers  The plot's raster event marks, each an events layer drawn as marks.
        L = cell(1, numel(p.rasterEvents));
        for m = 1:numel(p.rasterEvents)
            L{m} = struct('source', "events", 'binding', "fixed", 'event', p.rasterEvents(m), 'eventsAs', "marks");
        end
    end

    function o = rasterOptions()
        o = struct('rasterSort', p.rasterSort, 'rasterSortEvent', p.rasterSortEvent, ...
            'rasterSortOrder', p.rasterSortOrder, 'rasterByGroup', p.rasterByGroup);
    end

    function o = psthOptions()
        o = struct('histStyle', p.histStyle, 'fill', p.fill, 'fillAlpha', p.fillAlpha, 'normalize', p.normalize, ...
            'stack', p.stack, 'stackSpacing', p.stackSpacing, 'yLim', yLim);
        yUsed = true;
    end

    function o = continuousOptions()
        o = struct('errorType', p.style.ErrorType, 'yLim', yLim);
        if ~p.style.ShowSEM; o.errorType = "off"; end
        yUsed = true;
    end

    function oneGroupNote(what)
        if grouped
            addNote(sprintf("The %s draws one trial group (group 1); the plot drew one per group: set the panel's Group shown, " + ...
                "or add a panel per group.", what));
        end
    end

    function q = panelOf(type, options, layers)
        q = struct('type', type, 'plotOptions', true, 'options', options, 'layers', {layers});   % plotOptions: takes the plot's bins, baseline, ...
    end

    function addPanel(q, h)
        P{end+1} = q;
        heights(end+1) = h;
    end

    function addAux()
        %addAux  The plot's mean aux signal: a continuous panel of a fixed AUX layer, below the unit's panels or above them.
        a = p.aux;
        if a.mode == "off"; return; end
        L = struct('source', "AUX", 'binding', "fixed", 'channels', a.channels, 'aggregate', "each");
        if a.mode == "magnitude"
            L.aggregate = "mean";
            addNote("The aux magnitude became the mean of the AUX channels.");
        end
        o = struct('baseline', struct('Mode', a.baseline, 'Window', a.baselineWindow), 'display', a.display, ...
            'statistic', a.statistic, 'transform', a.transform, 'errorType', a.errorType, 'yLim', a.yLim);
        if a.display == "heatmap"
            o.display = "lines";
            addNote("The aux heat map display is not available in a continuous panel: its channels are drawn as lines.");
        end
        if a.colorBy ~= "auto"
            addNote(sprintf("The aux colorBy ""%s"" is not carried: the panel colors its traces by trial group.", a.colorBy));
        end
        if ~a.byGroup
            addNote("The aux byGroup off (one trace over every epoch) is not carried: the panel draws one trace per trial group.");
        end
        x = panelOf("continuous", o, {L});
        x.plotOptions = false;   % its own baseline, as the plot's aux had
        h = 1;
        heights(:) = 2;   % the unit's panels twice the aux panel's height, as the plot drew them
        if a.placement == "above"
            P = [{x} P];
            heights = [h heights];
        else
            if a.placement == "over"
                addNote("The aux placement ""over"" (on the right y axis) is not available: the aux signal is a panel below.");
            end
            P{end+1} = x;
            heights(end+1) = h;
        end
        fig.grid = struct('spacing', "none");
    end
end
