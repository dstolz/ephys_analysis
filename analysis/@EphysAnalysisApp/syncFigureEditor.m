function syncFigureEditor(obj)
%syncFigureEditor  Show, enable and list the figure editor's rows for the selected figure, panel and layer.
%   What shows (rows a section does not use are hidden, and so is a
%   section left with none: layoutFigureEditor):
%     Observations   the unit filter for a unit observation (classes and
%                    quality for sorted units; the response test's rows, its
%                    auROC rows with the auROC test), the signal and channels
%                    for a channel observation; "auto" says what it resolves
%                    to (EphysAnalysisConfig.observeKind)
%     Arrangement    the selected panel's rows once there is one
%     Panel, Panel alignment, Layers, Options   with a panel selected;
%                    Group shown for the one-group types (heat map, unit
%                    correlation); Panel alignment's rows grayed out (they
%                    show the figure's) while "Same as the figure" is
%                    ticked, and, with a note, for a type not aligned to
%                    events; its Apply to all panels only while the panel
%                    has its own, Re-link all panels while any panel has
%                    its own event, window or options
%     Common options always (the waveform rows enabled when it is not Off,
%                    the baseline window with a baseline); a linked panel's
%                    Options rows of its type's common fields (bins,
%                    measure, baseline, mask, waveform) are locked, showing
%                    the figure's; Options' Apply to all panels when the
%                    panel has its own common values or another panel of
%                    its type
%     Event reference, Epoch window, Trial selection   unless every panel
%                    of the figure is one not aligned to events
%     Layers         the picked layer's rows by its source and binding:
%                    what a following layer draws; a fixed spike layer's
%                    unit rows, a fixed signal layer's channels, the
%                    aggregate on a raster, PSTH or continuous panel; an
%                    events layer's line, edge, sequence and how it is
%                    drawn (a mark's look for marks); the color and line
%                    style but for marks
%     Options        the panel type's own (titled "<Type> options"); a heat
%                    map of a signal has no bins or measure
%     Appearance     all rows; the site size with a probe map, the heat
%                    colors with a heat map, probe map or correlation map
%   What is enabled: the binding only where a layer may follow the
%   observation (figureEditorChoices: Bindable; otherwise it shows Fixed),
%   the train only on a raster, PSTH or heat map, the response test's rows
%   with Responsive only, the baseline window with a baseline, the fill
%   opacity when filled, the sort event with "event", the
%   waveform's rows when it is not Off, the bins of a unit
%   correlation for its peak rate, the mask with a stop event, the stack
%   spacing when stacked, the error and legend rows with their boxes, each
%   Move button when the panel has a same-shaped neighbor that way, and
%   the list buttons. The schematic is redrawn (drawFigureSchematic).
E = obj.FigureEditor;
S = obj.FigureSections;
k = obj.SelectedFigure;
nf = numel(obj.Config.Figures);
has = k >= 1 && k <= nf;
onoff = @(tf) matlab.lang.OnOffSwitchState(tf);
en = @(c, tf) set(c, 'Enable', onoff(tf));
set([obj.RemoveFigureButton obj.DuplicateFigureButton], 'Enable', onoff(has));
obj.CopyFigureButton.Enable = onoff(has && nf > 1);
if ~isempty(obj.FigureGenerateButton)
    obj.FigureGenerateButton.Enable = onoff(has && ~obj.Running);   % off while a run (or a generate) goes
end
obj.UpFigureButton.Enable = onoff(has && k > 1);
obj.DownFigureButton.Enable = onoff(has && k < nf);
names = [S.Name];
if ~has
    for i = 1:numel(S)
        S(i).Shown(:) = false;
        S(i).Visible = names(i) == "general";
    end
    S = formShow(S, "summary", true);
    E.summary.Text = "Add a figure: pick a template under the list and press Add.";
    obj.FigureSections = S;
    obj.layoutFigureEditor();
    obj.drawFigureSchematic();
    return
end
fig = obj.Config.Figures(k);
PT = EphysAnalysisConfig.panelTypes();
np = numel(fig.panels);
j = obj.SelectedPanel;
hasPanel = j >= 1 && j <= np;
kind = EphysAnalysisConfig.observeKind(fig);
spikes = EphysAnalysisConfig.SpikeSources;
signals = EphysAnalysisConfig.SignalSources;
plural = @(n, w) sprintf("%d %s%s", n, w, repmat('s', 1, n ~= 1));
E.summary.Text = plural(fig.grid.rows, "row") + " x " + plural(fig.grid.cols, "column") + ", " + plural(np, "panel") + "; per " + kind;
E.observeResolved.Text = "";
if fig.observe.kind == "auto"; E.observeResolved.Text = "(resolves to: " + kind + ")"; end
aligned = false(1, np);
for q = 1:np
    row = PT.Type == fig.panels(q).type;
    aligned(q) = any(row) && PT.Aligned(row);
end

v = struct();
for f = ["id" "title" "enabled" "summary" "observe" "obsDatasets" "obsCount" "schematic" "addType" "addWhere" "spacing" ...
        "fontSize" "lineWidth" "colormap" "sortDepth" "labelDepth" "showSEM" "legendLoc" "errType" "errFace" "errEdge" "looksText" ...
        "cmNote" "cmBinMs" "cmSmoothMs" "cmMeasure" "cmBaselineMode" "cmBaseFrom" "cmMaskAfterStop" "cmWaveMode" ...
        "cmWaveLocation" "cmWaveScale" "cmWavePP"]
    v.(f) = true;   % the rows every figure shows
end
en([E.cmBaseFrom E.cmBaseTo], string(E.cmBaselineMode.Value) ~= "none");
en([E.cmWaveSpikes E.cmWaveLocation E.cmWaveBox E.cmWaveScale E.cmWavePP E.cmWaveCount], string(E.cmWaveMode.Value) ~= "off");
% observations
unit = kind == "unit";
sorted = unit && fig.observe.source == "units";
respAuroc = unit && string(E.obsRespTest.Value) == "auroc";
v.obsSource = unit; v.obsClasses = sorted; v.obsQuality = sorted;
v.obsResponse = unit; v.obsRespBaseFrom = unit; v.obsRespParam = unit;
v.obsRaMethod = respAuroc; v.obsRaWinMs = respAuroc; v.obsRaCutoff = respAuroc;
v.obsRaTest = respAuroc && string(E.obsRaCutoff.Value) == "test";
v.obsIds = unit; v.obsMaxUnits = unit; v.obsShanks = unit; v.obsUnitChannels = unit;
v.obsSignal = kind == "channel"; v.obsChannels = kind == "channel";
% arrangement and panel
v.selPanel = hasPanel; v.noPanel = ~hasPanel;
v.rowSpan = hasPanel; v.colSpan = hasPanel; v.rowHeight = hasPanel; v.colWidth = hasPanel; v.panelButtons = hasPanel;
v.panelType = hasPanel; v.panelTitle = hasPanel; v.group = false;
% layers and options: off unless the panel uses them
layerKeys = ["layerList" "layerAdd" "layerNote" "layerName" "layerSource" "layerBinding" "layerFollows" "layerClasses" ...
    "layerIds" "layerQuality" "layerMaxUnits" "layerShanks" "layerUnitChannels" "layerChannels" "layerAggregate" "evLine" ...
    "evEdge" "evSeqText" "evDrawAs" "evMarker" "evColor" "layerColor" "layerLineStyle"];
optionKeys = ["binMs" "smoothMs" "measure" "baselineMode" "baseFrom" "rasterSort" "sortLine" "sortSeqText" "rasterByGroup" ...
    "maskAfterStop" "histStyle" "fill" "normalize" "contDisplay" "statistic" "errorType" "stackSpacing" "order" ...
    "value" "metric" "correlation" "fisherZ" "yLim" "cLim" "waveMode" "waveLocation" "waveScale" "wavePP" ...
    "optApplyAll"];
for f = [layerKeys optionKeys]; v.(f) = false; end
optionsTitle = "Options";
paligned = false;
if hasPanel
    p = fig.panels(j);
    t = p.type;
    row = PT.Type == t;
    known = any(row);
    typeLabel = t;
    if known
        typeLabel = PT.Label(row);
        optionsTitle = typeLabel + " options";
        paligned = PT.Aligned(row);
        v.group = PT.OneGroup(row);
    end
    on = [p.layers.enabled];
    first = "";
    if any(on); first = p.layers(find(on, 1)).source; end
    pointHeat = t == "heatmap" && ~ismember(first, signals);
    ch = figureEditorChoices(t, first);

    % layers
    nl = numel(p.layers);
    labels = strings(1, nl);
    for i = 1:nl; labels(i) = layerLabel(p.layers(i)); end
    if ~isequal(string(E.layerList.Items), labels)
        if nl == 0
            set(E.layerList, "Items", {}, "ItemsData", []);
        else
            set(E.layerList, "Items", cellstr(labels), "ItemsData", 1:nl, "Value", min(max(obj.SelectedLayer, 1), nl));
        end
    end
    v.layerList = true; v.layerAdd = true;
    multi = known && PT.MultiLayer(row);
    v.layerNote = ~multi && nl > 1;
    if v.layerNote
        E.layerNote.Text = "A " + lower(typeLabel) + " panel draws one layer: only the first enabled one is drawn.";
    end
    i = obj.SelectedLayer;
    if i >= 1 && i <= nl
        L = p.layers(i);
        lc = figureEditorChoices(t, L.source);
        isSpike = ismember(L.source, spikes);
        isSignal = ismember(L.source, signals);
        fixed = L.binding == "fixed";
        marks = L.source == "events" && L.eventsAs == "marks";
        v.layerName = true; v.layerSource = true; v.layerBinding = true;
        v.layerFollows = ~fixed && (isSpike || isSignal);
        v.layerClasses = fixed && L.source == "units";
        v.layerIds = fixed && isSpike; v.layerQuality = v.layerIds; v.layerMaxUnits = v.layerIds;
        v.layerShanks = v.layerIds; v.layerUnitChannels = v.layerIds;
        v.layerChannels = fixed && isSignal;
        v.layerAggregate = fixed && (isSpike || isSignal) && ismember(t, ["raster" "psth" "continuous"]);
        v.evLine = L.source == "events"; v.evEdge = v.evLine; v.evSeqText = v.evLine; v.evDrawAs = v.evLine;
        v.evMarker = marks; v.evColor = marks;
        v.layerColor = ~marks; v.layerLineStyle = ~marks;
        if ~lc.Bindable; E.layerBinding.Value = "fixed"; end
        en(E.layerBinding, lc.Bindable);
        en(E.layerQuality, L.source == "units");
        en(E.evDrawAs, ismember(t, ["raster" "psth" "heatmap"]));
        what = "unit";
        if isSignal; what = "channel"; end
        set(E.layerAggregate, "Items", ["each " + what "their mean"], "ItemsData", ["each" "mean"]);
        E.layerFollows.Text = followsText(L, kind, fig.observe);
    end
    en([E.removeLayer], i >= 1 && i <= nl);
    en(E.layerUp, i > 1 && i <= nl);
    en(E.layerDown, i >= 1 && i < nl);
    en(E.addLayer, ~isempty(ch.Sources));

    % options
    v.binMs = t == "psth" || pointHeat || t == "corrmap"; v.smoothMs = v.binMs;
    v.measure = t == "psth" || pointHeat;
    v.baselineMode = ismember(t, ["psth" "continuous" "heatmap" "corrmap"]); v.baseFrom = v.baselineMode;
    v.rasterSort = t == "raster"; v.sortLine = v.rasterSort; v.sortSeqText = v.rasterSort; v.rasterByGroup = v.rasterSort;
    v.maskAfterStop = ismember(t, ["raster" "psth"]) || pointHeat;
    v.histStyle = t == "psth"; v.fill = v.histStyle; v.normalize = v.histStyle;
    v.contDisplay = t == "continuous"; v.statistic = v.contDisplay; v.errorType = v.contDisplay; v.stackSpacing = v.contDisplay;
    v.order = t == "heatmap";
    v.value = t == "probemap";
    v.metric = t == "corrmap"; v.correlation = v.metric; v.fisherZ = v.metric;
    v.yLim = ismember(t, ["psth" "continuous" "waveforms"]);
    v.cLim = ismember(t, ["heatmap" "probemap" "corrmap"]);
    v.waveMode = ismember(t, ["raster" "psth" "waveforms"]); v.wavePP = v.waveMode;
    v.waveLocation = ismember(t, ["raster" "psth"]); v.waveScale = v.waveLocation;
    if v.baselineMode; offerItems(E.baselineMode, ch.BaselineModes); end
    en([E.baseFrom E.baseTo], string(E.baselineMode.Value) ~= "none");
    en(E.fillAlpha, E.fill.Value);
    en([E.sortLine E.sortEdge E.sortSeqText E.sortSeqEdit], strtrim(string(E.rasterSort.Value)) == "event");
    en([E.waveSpikes E.waveLocation E.waveBox E.waveScale E.wavePP E.waveCount], string(E.waveMode.Value) ~= "off");
    en([E.binMs E.smoothMs], t ~= "corrmap" || string(E.metric.Value) == "peak");
    stop = obj.FigureAlignControls.StopOn.Value;
    if isstruct(p.window); stop = obj.PanelAlignControls.StopOn.Value; end
    en(E.maskAfterStop, stop);
    en(E.stackSpacing, string(E.contDisplay.Value) == "stacked");
    % a linked panel's common rows show the figure's Common options, locked
    rowsOf = struct('bins', [E.binMs E.smoothMs], 'measure', E.measure, 'baseline', [E.baselineMode E.baseFrom E.baseTo], ...
        'maskAfterStop', E.maskAfterStop, 'waveform', [E.waveMode E.waveSpikes E.waveLocation E.waveBox E.waveScale E.wavePP E.waveCount]);
    cf = EphysAnalysisConfig.commonFieldsOf(t);
    if p.common
        for f = cf; en(rowsOf.(f), false); end
    end
    en(E.panelCommon, ~isempty(cf));
    sameType = nnz([fig.panels.type] == t) > 1;
    v.optApplyAll = known;
    en(E.optApplyAll, (~p.common && ~isempty(cf)) || sameType);

    % the panel's own alignment
    modes = "fixed";
    if t == "corrmap"; modes = ["fixed" "between"]; end
    setWindowModes(obj.PanelAlignControls.Mode, modes);
    C2 = obj.PanelAlignControls;
    unlinked = paligned && ~E.panelSame.Value;   % linked ("Same as the figure"): the rows show the figure's, locked
    ctl = findobj([C2.RefGrid C2.WindowGrid], '-property', 'Enable');
    set(ctl, 'Enable', onoff(unlinked));
    if unlinked; syncAlignEnable(C2); end
    en(E.panelSame, paligned);
    en(E.alignApplyAll, unlinked);
    E.palignNote.Text = "";
    if ~paligned
        E.palignNote.Text = typeLabel + " panels are not aligned to events: they use no event or window.";
    end

    % moving and removing
    for d = ["up" "down" "left" "right"]
        [~, moved] = EphysAnalysisConfig.movePanel(fig, p.id, d);
        en(E.("move" + upper(extractBefore(d, 2)) + extractAfter(d, 1)), moved);
    end
end
en(E.removePanel, hasPanel);
own = false;   % any panel with its own event, window or options: Re-link all panels has something to do
for q = 1:np
    own = own || isstruct(fig.panels(q).ref) || isstruct(fig.panels(q).window) || ~fig.panels(q).common;
end
en(E.alignRelinkAll, own);
pg = E.palignGrid;
hs = pg.UserData;
note = 34 * (hasPanel && ~paligned);
pg.RowHeight = {note, 30, hs(1), hs(2), 0};
S(names == "palign").BodyHeight = note + 30 + hs(1) + hs(2) + 4 * pg.RowSpacing;

% appearance
types = strings(1, 0);
if np > 0; types = [fig.panels.type]; end
v.siteSize = any(types == "probemap");
v.heatColormap = any(ismember(types, ["heatmap" "probemap" "corrmap"]));
errOn = logical(E.showSEM.Value);
en(E.errType, errOn);
en(E.errResamples, errOn && string(E.errType.Value) == "ci95");
en([E.errFace E.errAlpha E.errEdge], errOn);
en([E.errEdgeStyle E.errEdgeWidth], errOn && lower(strtrim(string(E.errEdge.Value))) ~= "none");
en([E.legendLoc E.legendOrient E.legendBox], E.legend.Value);

% observations' enables
respOn = logical(E.obsResponse.Value);
en([E.obsRespTest E.obsRespDirection E.obsRespBaseFrom E.obsRespBaseTo E.obsRespFrom E.obsRespTo E.obsRespParam ...
    E.obsRespCorrection E.obsRespAlpha E.obsRaMethod E.obsRaWindows E.obsRaWinMs E.obsRaBinMs E.obsRaCutoff E.obsRaTest], respOn);
en(E.obsRaStepMs, respOn && string(E.obsRaWindows.Value) == "sliding");
en(E.obsRaThreshold, respOn && string(E.obsRaCutoff.Value) == "fixed");
en(E.obsRaResamples, respOn && string(E.obsRaTest.Value) ~= "ranksum");
n = numel(fig.aesthetics);
E.looksText.Text = sprintf("%d remembered look(s); right-click the preview to edit.", n);
en(E.looksForget, n > 0);

for f = string(fieldnames(v)).'
    S = formShow(S, f, v.(f));
end
for i = 1:numel(S)
    switch names(i)
        case {"panel" "palign" "layers" "options"}
            S(i).Visible = hasPanel;
        case {"ref" "window" "selection"}
            S(i).Visible = np == 0 || any(aligned);
        otherwise
            S(i).Visible = true;
    end
end
S(names == "options").Title = optionsTitle;
S(names == "layers").Title = "Layers";
if hasPanel && ~isempty(fig.panels(j).layers)
    S(names == "layers").Title = "Layers (" + numel(fig.panels(j).layers) + ") of " + fig.panels(j).id;
end
obj.FigureSections = S;
syncAlignEnable(obj.FigureAlignControls);
obj.layoutFigureEditor();
obj.drawFigureSchematic();
end


function t = followsText(L, kind, ob)
%followsText  What a layer that follows the observation draws, in words (the mockup's notes).
spike = ismember(L.source, EphysAnalysisConfig.SpikeSources);
switch kind
    case "unit"
        if spike
            if ob.source == L.source
                t = "Draws the observed unit.";
            elseif L.source == "detected"
                t = "Draws the detections on the observed unit's channel.";
            else
                t = "Draws the sorted units on the observed channel.";
            end
        elseif L.source == "AUX"
            t = "AUX has no recording channel: bind it to fixed channels.";
        else
            t = "Draws the observed unit's own " + L.source + " channel.";
        end
    case "channel"
        if spike
            t = "Draws the observed channel's " + ternary(L.source == "detected", "detections.", "sorted units.");
        elseif L.source == ob.signal
            t = "Draws the observed channel.";
        elseif L.source == "AUX" || ob.signal == "AUX"
            t = "AUX has no recording channel: bind it to fixed channels.";
        else
            t = "Draws the same channel number in the " + L.source + " extract.";
        end
    otherwise
        t = "The figure observes the dataset: a following layer has nothing to follow. Bind it to fixed items.";
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
