function fig = gatherFigureEditor(obj)
%gatherFigureEditor  The selected figure as the editor shows it (normalized).
%   The figure's rows, the selected panel's (SelectedPanel) and that
%   panel's selected layer's (SelectedLayer); the other panels and layers,
%   and every field without a control, keep their values. The panel's type
%   is not read here (onPanelTypeChanged changes it), nor its place (the
%   Arrangement's buttons). With a section's "Use default" box ticked the
%   figure's ref / window / selection is "default"; unticked (or edited:
%   onFigureAlignEdited), the figure takes the values its controls show.
%   The panel's ref and window are its own where it has them
%   (E.panelSame.UserData: onPanelAlignEdited), else "default". The
%   panel's spans, its row's height and its column's width are written
%   only when their spinners differ from what applyFigureEditor showed, so
%   a value they cannot show is kept as stored; a row height or column
%   width of 1 keeps equal rows ([] sizes) equal.
E = obj.FigureEditor;
fig = obj.Config.Figures(obj.SelectedFigure);
fig.id = strtrim(string(E.id.Value));
fig.title = string(E.title.Value);
fig.enabled = logical(E.enabled.Value);

% observations
o = fig.observe;
o.kind = string(E.observe.Value);
o.source = string(E.obsSource.Value);
u = o.units;
u.classes = ticked(E.obsClasses);
u.ids = parseList(E.obsIds.Value);
u.maxUnits = parseScalar(E.obsMaxUnits.Value, Inf);
u.quality.enabled = logical(E.obsQuality.Value);
u.response.enabled = logical(E.obsResponse.Value);
u.response.test = string(E.obsRespTest.Value);
u.response.direction = string(E.obsRespDirection.Value);
u.response.baseline = [E.obsRespBaseFrom.Value E.obsRespBaseTo.Value];
u.response.window = [E.obsRespFrom.Value E.obsRespTo.Value];
u.response.param = strtrim(string(E.obsRespParam.Value));
u.response.correction = string(E.obsRespCorrection.Value);
u.response.alpha = E.obsRespAlpha.Value;
u.response.auroc = aurocFrom(E, "obsRa", u.response.auroc);
u.shanks = parseList(E.obsShanks.Value);
u.channels = parseList(E.obsUnitChannels.Value);
o.units = u;
o.signal = string(E.obsSignal.Value);
o.channels = parseList(E.obsChannels.Value);
o.datasets = string(E.obsDatasets.Value);
fig.observe = o;

% arrangement and appearance
fig.grid.spacing = string(E.spacing.Value);
s = fig.style;
s.FontSize = E.fontSize.Value;
s.LineWidth = E.lineWidth.Value;
s.SiteSize = E.siteSize.Value;
s.Colormap = strtrim(string(E.colormap.Value));
if s.Colormap == ""; s.Colormap = "lines"; end
s.HeatColormap = string(E.heatColormap.Value);
if s.HeatColormap == "auto"; s.HeatColormap = ""; end
s.SortDepth = E.sortDepth.Value;
s.SortShank = E.sortShank.Value;
s.LabelDepth = E.labelDepth.Value;
s.LabelShank = E.labelShank.Value;
s.ShowSEM = E.showSEM.Value;
s.ShowStop = E.showStop.Value;
s.Legend = E.legend.Value;
s.Grid = E.grid.Value;
s.LegendLocation = string(E.legendLoc.Value);
s.LegendOrientation = string(E.legendOrient.Value);
s.LegendBox = logical(E.legendBox.Value);
s.ErrorType = string(E.errType.Value);
s.ErrorResamples = E.errResamples.Value;
s.ErrorFaceColor = strtrim(string(E.errFace.Value));
if lower(s.ErrorFaceColor) == "auto"; s.ErrorFaceColor = ""; end
s.ErrorFaceAlpha = E.errAlpha.Value;
if isempty(s.ErrorFaceAlpha); s.ErrorFaceAlpha = NaN; end
s.ErrorEdgeColor = strtrim(string(E.errEdge.Value));
if s.ErrorEdgeColor == ""; s.ErrorEdgeColor = "none"; end
s.ErrorEdgeStyle = string(E.errEdgeStyle.Value);
s.ErrorEdgeWidth = E.errEdgeWidth.Value;
fig.style = s;

% the figure's alignment
D = obj.Config.Defaults;
ref = D.EventRef; win = D.Window; sel = D.Selection;
if isstruct(fig.ref); ref = fig.ref; end
if isstruct(fig.window); win = fig.window; end
if isstruct(fig.selection); sel = fig.selection; end
[ref, win, sel] = obj.gatherAlignControls(obj.FigureAlignControls, ref, win, sel);
if E.defaultRef.Value; fig.ref = "default"; else; fig.ref = ref; end
if E.defaultWindow.Value; fig.window = "default"; else; fig.window = win; end
if E.defaultSelection.Value; fig.selection = "default"; else; fig.selection = sel; end

% the selected panel
j = obj.SelectedPanel;
if j >= 1 && j <= numel(fig.panels)
    p = fig.panels(j);
    p.title = string(E.panelTitle.Value);
    % the place and sizes only when edited: the controls cannot show every stored value (Validate reports a bad one)
    if E.rowSpan.Value ~= shownSpan(p.rowSpan, E.rowSpan.Limits); p.rowSpan = E.rowSpan.Value; end
    if E.colSpan.Value ~= shownSpan(p.colSpan, E.colSpan.Limits); p.colSpan = E.colSpan.Value; end
    if E.rowHeight.Value ~= shownSize(fig.grid.rowHeights, p.row)
        fig.grid.rowHeights = setSize(fig.grid.rowHeights, p.row, fig.grid.rows, E.rowHeight.Value);
    end
    if E.colWidth.Value ~= shownSize(fig.grid.colWidths, p.col)
        fig.grid.colWidths = setSize(fig.grid.colWidths, p.col, fig.grid.cols, E.colWidth.Value);
    end
    own = E.panelSame.UserData;
    if ~(islogical(own) && numel(own) == 2); own = [false false]; end
    if any(own)
        fref = ref; fwin = win;   % the figure's (resolved): where the panel's own start from
        if isstruct(p.ref); fref = p.ref; end
        if isstruct(p.window); fwin = p.window; end
        [pref, pwin] = obj.gatherAlignControls(obj.PanelAlignControls, fref, fwin, sel);
    end
    if own(1); p.ref = pref; else; p.ref = "default"; end
    if own(2); p.window = pwin; else; p.window = "default"; end
    p.options = gatherOptions(E, p);
    i = obj.SelectedLayer;
    if i >= 1 && i <= numel(p.layers)
        p.layers(i) = gatherLayer(E, p.layers(i), p.type);
    end
    fig.panels(j) = p;
end
fig = EphysAnalysisConfig.normalizeFigure(fig);
end


function op = gatherOptions(E, p)
%gatherOptions  The panel's options as the Options rows (and Group shown) show them; fields of other types are not there.
op = p.options;
if isfield(op, 'group'); op.group = E.group.Value; end
if isfield(op, 'bins')
    op.bins.BinSec = E.binMs.Value / 1000;
    op.bins.SmoothSec = E.smoothMs.Value / 1000;
end
if isfield(op, 'measure'); op.measure = string(E.measure.Value); end
if isfield(op, 'baseline')
    op.baseline.Mode = string(E.baselineMode.Value);
    op.baseline.Window = [E.baseFrom.Value E.baseTo.Value];
end
if isfield(op, 'rasterSort')
    op.rasterSort = strtrim(string(E.rasterSort.Value));
    if op.rasterSort == "event"   % else the panel keeps the event it has
        ln = strtrim(string(E.sortLine.Value));
        if ln == ""
            op.rasterSortEvent = [];
        else
            se = op.rasterSortEvent;
            if isempty(se); se = EphysAnalysisConfig.defaults("EventRef"); end
            se.line = ln;
            se.edge = string(E.sortEdge.Value);
            se.sequence = E.sortSeqText.UserData.sequence;
            se.alignStep = E.sortSeqText.UserData.alignStep;
            op.rasterSortEvent = se;
        end
    end
    op.rasterSortOrder = string(E.rasterSortOrder.Value);
    op.rasterByGroup = logical(E.rasterByGroup.Value);
end
if isfield(op, 'maskAfterStop'); op.maskAfterStop = logical(E.maskAfterStop.Value); end
if isfield(op, 'histStyle')
    op.histStyle = string(E.histStyle.Value);
    op.fill = logical(E.fill.Value);
    op.fillAlpha = E.fillAlpha.Value;
    if isempty(op.fillAlpha); op.fillAlpha = NaN; end
    op.normalize = string(E.normalize.Value);
end
switch p.type
    case "continuous"
        op.display = string(E.contDisplay.Value);
        op.statistic = string(E.statistic.Value);
        op.transform = string(E.transform.Value);
        op.errorType = string(E.errorType.Value);
        op.stackSpacing = E.stackSpacing.Value;
        if isempty(op.stackSpacing); op.stackSpacing = NaN; end
    case "behavior"
        op.param = strtrim(string(E.param.Value));
        op.display = string(E.behDisplay.Value);
        op.xScale = string(E.xScale.Value);
        op.jitter = logical(E.jitter.Value);
end
if isfield(op, 'order'); op.order = string(E.order.Value); end
if isfield(op, 'value'); op.value = string(E.value.Value); end
if isfield(op, 'metric')
    op.metric = string(E.metric.Value);
    op.correlation = string(E.correlation.Value);
    op.fisherZ = logical(E.fisherZ.Value);
end
if isfield(op, 'yLim'); op.yLim = limits(E.yLim.Value); end
if isfield(op, 'cLim'); op.cLim = limits(E.cLim.Value); end
if isfield(op, 'waveform')
    wv = op.waveform;
    wv.mode = string(E.waveMode.Value);
    wv.maxSpikes = E.waveSpikes.Value;
    wv.showPP = logical(E.wavePP.Value);
    wv.showCount = logical(E.waveCount.Value);
    if p.type ~= "waveforms"   % an inset's place and size
        wv.location = string(E.waveLocation.Value);
        wv.box = logical(E.waveBox.Value);
        wv.scale = E.waveScale.Value;
    end
    op.waveform = wv;
end
end


function L = gatherLayer(E, L, type)
%gatherLayer  Layer L of a panel of TYPE as the Layers rows show it.
L.name = strtrim(string(E.layerName.Value));
L.enabled = logical(E.layerEnabled.Value);
L.source = string(E.layerSource.Value);
L.binding = string(E.layerBinding.Value);
ch = figureEditorChoices(type, L.source);
if ~ch.Bindable; L.binding = "fixed"; end   % events, trials, and the types that draw fixed layers
u = L.units;
u.classes = ticked(E.layerClasses);
u.ids = parseList(E.layerIds.Value);
u.quality.enabled = logical(E.layerQuality.Value);
u.response.enabled = logical(E.layerResponse.Value);
u.maxUnits = parseScalar(E.layerMaxUnits.Value, Inf);
u.shanks = parseList(E.layerShanks.Value);
u.channels = parseList(E.layerUnitChannels.Value);
L.units = u;
L.channels = parseList(E.layerChannels.Value);
L.aggregate = string(E.layerAggregate.Value);
ev = L.event;
ev.line = strtrim(string(E.evLine.Value));
ev.edge = string(E.evEdge.Value);
ev.sequence = E.evSeqText.UserData.sequence;
ev.alignStep = E.evSeqText.UserData.alignStep;
ev.marker = string(E.evMarker.Value);
ev.size = E.evSize.Value;
ev.color = strtrim(string(E.evColor.Value));
if lower(ev.color) == "auto"; ev.color = ""; end
L.event = ev;
L.eventsAs = string(E.evDrawAs.Value);
L.yParam = strtrim(string(E.layerYParam.Value));
L.seriesParam = strtrim(string(E.layerSeries.Value));
L.color = strtrim(string(E.layerColor.Value));
if lower(L.color) == "auto"; L.color = ""; end
L.lineStyle = string(E.layerLineStyle.Value);
if L.lineStyle == "auto"; L.lineStyle = ""; end
end


function v = shownSize(sizes, i)
%shownSize  The relative size applyFigureEditor shows for row (column) I.
v = 1;
if numel(sizes) >= i && isfinite(sizes(i)) && sizes(i) > 0; v = sizes(i); end
end


function v = shownSpan(span, limits)
%shownSpan  The span applyFigureEditor shows.
v = min(limits(2), max(1, round(span)));
end


function s = setSize(s, i, n, v)
%setSize  Relative sizes S with entry I set to V: [] (equal) stays [] while V is 1.
if isempty(s)
    if v == 1; return; end
    s = ones(1, n);
end
if numel(s) < n; s(end+1:n) = 1; end
s(i) = v;
end


function c = ticked(boxes)
%ticked  The classes whose boxes are ticked (a 1 x 0 string when none).
c = string(fieldnames(boxes)).';
c = c(arrayfun(@(x) boxes.(x).Value, c));
if isempty(c); c = string.empty(1, 0); end
end


function a = aurocFrom(E, pre, a)
%aurocFrom  The response test's auROC settings A as the editor's fields PRE* show them.
a.method = string(E.(pre + "Method").Value);
a.windows = string(E.(pre + "Windows").Value);
a.windowSec = E.(pre + "WinMs").Value / 1000;
a.stepSec = E.(pre + "StepMs").Value / 1000;
a.binSec = E.(pre + "BinMs").Value / 1000;
a.cutoff = string(E.(pre + "Cutoff").Value);
a.threshold = E.(pre + "Threshold").Value;
a.test = string(E.(pre + "Test").Value);
a.nResamples = E.(pre + "Resamples").Value;
end


function v = limits(t)
%limits  Two ascending values, else [] (automatic).
v = parseList(t);
if numel(v) ~= 2 || v(2) <= v(1); v = []; end
end


function v = parseList(t)
%parseList  "3 5 8:12" / "3, 5" -> [3 5 8 9 10 11 12]; blank -> [].
t = strtrim(string(t));
v = [];
if t == ""; return; end
parts = split(replace(t, ",", " "));
parts = parts(parts ~= "");
for s = parts.'
    if contains(s, ":")
        ab = str2double(split(s, ":"));
        if numel(ab) == 2 && all(isfinite(ab)); v = [v ab(1):ab(2)]; end %#ok<AGROW>
    else
        x = str2double(s);
        if isfinite(x); v(end+1) = x; end %#ok<AGROW>
    end
end
end


function x = parseScalar(t, default)
t = lower(strtrim(string(t)));
if t == "" || t == "inf"
    x = default;
    if t == "inf"; x = Inf; end
    return
end
x = str2double(t);
if isnan(x); x = default; end
end
