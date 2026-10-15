function [fig, notes] = plotToFigure(cfg, plotId)
%plotToFigure  A Figures entry that draws what one plot of the Plots section draws.
%   [FIG, NOTES] = EphysAnalysisConfig.plotToFigure(CFG, PLOTID) converts
%   the plot PLOTID of config CFG (its layout resolved by plotFor) into a
%   figure (normalizeFigure'd; not added: convertPlotToFigure adds it), and
%   NOTES, a string row of what could not be carried, one sentence each.
%   Nothing is dropped silently: every setting the plot's kind uses that
%   the figure cannot hold is a note.
%
%   Figure level
%     id          "<plotId>_fig", or "<plotId>_fig2", "_fig3", ... when a
%                 plot or figure has it (case ignored): a figure may not
%                 share a plot's id, as both name files through {Plot}
%                 (validate)
%     enabled, title, aesthetics   the plot's
%     ref, window, selection       the plot's ("default" stays "default")
%     style       the plot's, with MaxTiles, TileSpacing, XLim, YLim and
%                 CLim back at their defaults (a figure does not use them):
%                 YLim goes to the data panel's options.yLim (psth,
%                 continuous, waveforms, rate, tuning) and CLim to its
%                 options.cLim (heatmap, probemap, corrmap); the others,
%                 when set, are notes
%     common      the plot's bins, measure, baseline, auroc, maskAfterStop
%                 and waveform (a PSTH's, raster's or tuning curve's inset;
%                 a waveforms plot's own settings). A baseline the figure's
%                 panels do not take (a signal's other than subtract)
%                 becomes "none"; the auROC baseline of a PSTH or heat map
%                 of spikes is carried with its auroc settings
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
%   A behavior plot has no panel type: EphysAnalysisConfig:NotConvertible.
%   Errors: EphysAnalysisConfig:NoPlot.
%
%   See also EphysAnalysisConfig.convertPlotToFigure, EphysAnalysisConfig.normalizeFigure,
%   EphysAnalysisConfig.panelTypes, EphysAnalysisConfig.plotFor.

arguments
    cfg (1,1) EphysAnalysisConfig
    plotId (1,1) string
end

k = cfg.plotIndex(plotId);
if k == 0
    error('EphysAnalysisConfig:NoPlot', 'No plot "%s".', plotId);
end
p = cfg.Plots(k);          % as written: "default" sentinels kept
spec = cfg.plotFor(k);     % the layout resolved
K = EphysAnalysisConfig.plotKinds();
kindLabel = K.Label(K.Kind == p.kind);
if p.kind == "behavior"
    error('EphysAnalysisConfig:NotConvertible', ...
        'Plot "%s" is a %s plot (%s): figures have no panel type for it, so it cannot be converted.', ...
        p.id, lower(kindLabel), p.kind);
end
notes = string.empty(1, 0);
spikes = ismember(p.source, EphysAnalysisConfig.SpikeSources);

% --- figure level ---------------------------------------------------------------------------------
fig = struct();
used = lower([cfg.plotIds() cfg.figureIds()]);   % a figure's id must not name a plot's files (validate)
fig.id = p.id + "_fig";
n = 1;
while any(used == lower(fig.id))
    n = n + 1;
    fig.id = p.id + "_fig" + n;
end
fig.enabled = p.enabled;
fig.title = p.title;
fig.ref = p.ref;
fig.window = p.window;
fig.selection = p.selection;
fig.aesthetics = p.aesthetics;

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

cm = EphysAnalysisConfig.defaults("FigureCommon");
cm.bins = p.bins;
cm.measure = p.measure;
cm.maskAfterStop = p.maskAfterStop;
cm.waveform = p.waveform;
cm.baseline = p.baseline;
cm.auroc = p.auroc;
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
                    r.common = false;
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
if p.note.text ~= ""
    addNote("The text note is not carried: figures have no notes yet.");
end
if ~isempty(p.overlays)
    addNote(sprintf("%d overlay(s) not carried: figures have no overlays yet.", numel(p.overlays)));
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
fig.common = cm;
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
        for i = 1:numel(p.rasterEvents)
            L{i} = struct('source', "events", 'binding', "fixed", 'event', p.rasterEvents(i), 'eventsAs', "marks");
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
        q = struct('type', type, 'common', true, 'options', options, 'layers', {layers});
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
        x.common = false;   % its own baseline, as the plot's aux had
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
