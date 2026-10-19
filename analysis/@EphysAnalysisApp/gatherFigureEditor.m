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
%   (E.panelSame.UserData: onPanelAlignEdited), else "default"; its
%   selection is its own while "Trial selection as the figure" is
%   unticked (the selection rows of the Panel alignment section), else
%   "default". The
%   panel's spans, its row's height, its column's width and its own size
%   (% of its cell) are written only when their spinners differ from what
%   applyFigureEditor showed, so a value they cannot show is kept as
%   stored; a row height or column width of 1 keeps equal rows ([] sizes)
%   equal. The figure's gaps beyond the Spacing drop-down (custom's units
%   and values) are the Spacing window's (figureSpacingDialog), kept here
%   as they are. The panel's options are its Options rows', every field
%   of its type.
%   The panel's text note is its Text note rows', its overlays the
%   Overlays list's, the one picked read from its rows (overlayGather).
E = obj.FigureEditor;
fig = obj.Config.Figures(obj.SelectedFigure);
fig.id = strtrim(string(E.id.Value));
fig.title = string(E.title.Value);
fig.enabled = logical(E.enabled.Value);

% observations
o = fig.observe;
o.data = string(E.observe.Value);
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
o.channels = parseList(E.obsChannels.Value);
o.perGroup = logical(E.obsPerGroup.Value);
fig.observe = o;

% across sessions (datasetKeys has no control of its own: Pick... sets it, onPickFigureDatasets)
ss = fig.sessions;
ss.enabled = logical(E.sesEnabled.Value);
ss.datasets = string(E.sesDatasets.Value);
ss.facet = string(E.sesFacet.Value);
ss.series = string(E.sesSeries.Value);
ss.colorOrder = string(E.sesColorOrder.Value);
ss.showMembers = logical(E.sesShowMembers.Value);
ss.error = string(E.sesError.Value);
ss.match = string(E.sesMatch.Value);
ss.mappingFile = strtrim(string(E.sesMappingFile.Value));
ss.minSessions = max(1, round(E.sesMinSessions.Value));
ss.trialGroups = string(E.sesTrialGroups.Value);
fig.sessions = ss;

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
    p.box = string(E.panelBox.Value);
    % the place and sizes only when edited: the controls cannot show every stored value (Validate reports a bad one)
    if E.rowSpan.Value ~= shownSpan(p.rowSpan, E.rowSpan.Limits); p.rowSpan = E.rowSpan.Value; end
    if E.colSpan.Value ~= shownSpan(p.colSpan, E.colSpan.Limits); p.colSpan = E.colSpan.Value; end
    if E.rowHeight.Value ~= shownSize(fig.grid.rowHeights, p.row)
        fig.grid.rowHeights = setSize(fig.grid.rowHeights, p.row, fig.grid.rows, E.rowHeight.Value);
    end
    if E.colWidth.Value ~= shownSize(fig.grid.colWidths, p.col)
        fig.grid.colWidths = setSize(fig.grid.colWidths, p.col, fig.grid.cols, E.colWidth.Value);
    end
    shown = shownShare(p.size);
    for d = 1:2   % the panel's own size in its cell, % in the editor
        sp = E.panelWidth;
        if d == 2; sp = E.panelHeight; end
        if sp.Value ~= shown(d); p.size(d) = sp.Value / 100; end
    end
    p.align = string(E.panelAlign.Value);
    p.valign = string(E.panelVAlign.Value);
    own = E.panelSame.UserData;
    if ~(islogical(own) && numel(own) == 2); own = [false false]; end
    ownSel = ~E.panelSameSel.Value;   % "Trial selection as the figure" unticked: the panel's own
    if any(own) || ownSel
        fref = ref; fwin = win; fsel = sel;   % the figure's (resolved): where the panel's own start from
        if isstruct(p.ref); fref = p.ref; end
        if isstruct(p.window); fwin = p.window; end
        if isstruct(p.selection); fsel = p.selection; end
        [pref, pwin, psel] = obj.gatherAlignControls(obj.PanelAlignControls, fref, fwin, fsel);
    end
    if own(1); p.ref = pref; else; p.ref = "default"; end
    if own(2); p.window = pwin; else; p.window = "default"; end
    if ownSel; p.selection = psel; else; p.selection = "default"; end
    p.options = gatherOptions(E, p);
    i = obj.SelectedLayer;
    if i >= 1 && i <= numel(p.layers)
        rows = "items";
        if isfield(p.options, 'rows'); rows = p.options.rows; end
        p.layers(i) = gatherLayer(E, p.layers(i), p.type, rows);
    end
    p.note = gatherNote(E, p.note);
    p.overlays = overlayGather(E);   % the list's, the one picked read from its rows
    fig.panels(j) = p;
end
fig = EphysAnalysisConfig.normalizeFigure(fig);
end


function op = gatherOptions(E, p)
%gatherOptions  The panel's options as the Options rows (and Group shown) show them; fields of other types are not there.
op = p.options;
own = @(f) isfield(op, f);
if isfield(op, 'group'); op.group = E.group.Value; end
if own('bins')
    op.bins.BinSec = E.binMs.Value / 1000;
    op.bins.SmoothSec = E.smoothMs.Value / 1000;
end
if own('measure'); op.measure = string(E.measure.Value); end
if own('baseline')
    op.baseline.Mode = string(E.baselineMode.Value);
    op.baseline.Window = [E.baseFrom.Value E.baseTo.Value];
end
if own('auroc'); op.auroc = aurocPlotFrom(E, "au", op.auroc); end
if isfield(op, 'param')   % a tuning curve's parameters
    op.param = strtrim(string(E.param.Value));
    op.seriesParam = strtrim(string(E.seriesParam.Value));
end
if p.type == "rate"; op.display = string(E.rateDisplay.Value); end
if isfield(op, 'layout'); op.layout = string(E.waveLayout.Value); end
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
if isfield(op, 'yTicks'); op.yTicks = logical(E.yTicks.Value); end
if own('maskAfterStop'); op.maskAfterStop = logical(E.maskAfterStop.Value); end
if isfield(op, 'histStyle')
    op.histStyle = string(E.histStyle.Value);
    op.fill = logical(E.fill.Value);
    op.fillAlpha = E.fillAlpha.Value;
    if isempty(op.fillAlpha); op.fillAlpha = NaN; end
    op.normalize = string(E.normalize.Value);
end
if isfield(op, 'stack')   % a PSTH's rows (a continuous panel's stackSpacing is its own row)
    op.stack = logical(E.stack.Value);
    op.stackSpacing = E.psthSpacing.Value;
end
if p.type == "continuous"
    op.display = string(E.contDisplay.Value);
    op.statistic = string(E.statistic.Value);
    op.transform = string(E.transform.Value);
    op.errorType = string(E.errorType.Value);
    op.stackSpacing = E.stackSpacing.Value;
    if isempty(op.stackSpacing); op.stackSpacing = NaN; end
    op.trials = string(E.contTrials.Value);
    op.maxTrials = E.maxTrials.Value;
end
if isfield(op, 'rows'); op.rows = string(E.heatRows.Value); end
if isfield(op, 'order'); op.order = string(E.order.Value); end
if isfield(op, 'value'); op.value = string(E.value.Value); end
if isfield(op, 'metric')
    op.metric = string(E.metric.Value);
    op.correlation = string(E.correlation.Value);
    op.fisherZ = logical(E.fisherZ.Value);
end
if isfield(op, 'yLim'); op.yLim = limits(E.yLim.Value); end
if isfield(op, 'cLim'); op.cLim = limits(E.cLim.Value); end
if isfield(op, 'taperMode')   % a spectral panel's Chronux rows
    op.taperMode = string(E.spTaperMode.Value);
    op.TW = E.spTW.Value;
    op.K = E.spK.Value;
    op.W = E.spW.Value;
    op.p = E.spP.Value;
    op.pad = E.spPad.Value;
    op.fpass = [E.spFmin.Value E.spFmax.Value];
    op.detrend = string(E.spDetrend.Value);
end
if isfield(op, 'timeBase')
    op.timeBase = string(E.spTimeBase.Value);
    op.range = [E.spRangeFrom.Value E.spRangeTo.Value];
    op.segmentSec = E.spSegment.Value;
end
if isfield(op, 'err')
    op.err = string(E.spErr.Value);
    op.errP = E.spErrP.Value;
end
if isfield(op, 'scale'); op.scale = string(E.spScale.Value); end
if isfield(op, 'spikeFs'); op.spikeFs = E.spSpikeFs.Value; end
if isfield(op, 'movingwin'); op.movingwin = [E.spWin.Value E.spStep.Value]; end
if isfield(op, 'overTime'); op.overTime = logical(E.spOverTime.Value); end
if isfield(op, 'showPhase'); op.showPhase = logical(E.spShowPhase.Value); end
if p.type == "eventTrace"
    op.display = string(E.etDisplay.Value);
    op.trials = string(E.etTrials.Value);
    op.groupBands = logical(E.etGroupBands.Value);
    op.colorBy = string(E.etColorBy.Value);
    op.height = E.etHeight.Value;
    op.alpha = E.etAlpha.Value;
    if isempty(op.alpha); op.alpha = NaN; end
    op.edgeColor = strtrim(string(E.etEdge.Value));
    op.edgeWidth = E.etEdgeWidth.Value;
    op.lineStyle = string(E.etLineStyle.Value);
    op.lineWidth = E.etLineWidth.Value;
    op.showBaseline = logical(E.etBaseline.Value);
    op.baselineColor = strtrim(string(E.etBaseColor.Value));
    if lower(op.baselineColor) == "auto"; op.baselineColor = ""; end
    op.baselineStyle = string(E.etBaseStyle.Value);
    op.baselineWidth = E.etBaseWidth.Value;
    op.rowSpacing = E.etRowSpacing.Value;
end
if own('waveform')
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


function nt = gatherNote(E, nt)
%gatherNote  The panel's text note as the Text note rows show it.
nt.text = strjoin(string(E.annText.Value(:)).', newline);
nt.placement = string(E.annPlace.Value);
nt.x = E.annX.Value;
nt.y = E.annY.Value;
nt.align = string(E.annAlign.Value);
nt.valign = string(E.annVAlign.Value);
nt.rotation = E.annRotation.Value;
nt.fontName = strtrim(string(E.annFont.Value));
if lower(nt.fontName) == "auto"; nt.fontName = ""; end
nt.fontSize = E.annSize.Value;
if isempty(nt.fontSize); nt.fontSize = NaN; end
nt.bold = logical(E.annBold.Value);
nt.italic = logical(E.annItalic.Value);
nt.box = logical(E.annBox.Value);
nt.color = strtrim(string(E.annColor.Value));
if lower(nt.color) == "auto"; nt.color = ""; end
nt.background = strtrim(string(E.annBackground.Value));
if lower(nt.background) == "none"; nt.background = ""; end
nt.interpreter = string(E.annInterp.Value);
end


function L = gatherLayer(E, L, type, rows)
%gatherLayer  Layer L of a panel of TYPE (a heat map's options.rows ROWS) as the Layers rows show it.
L.name = strtrim(string(E.layerName.Value));
L.enabled = logical(E.layerEnabled.Value);
L.source = string(E.layerSource.Value);
L.binding = string(E.layerBinding.Value);
ch = figureEditorChoices(type, L.source, rows);
if ~ch.Bindable; L.binding = "fixed"; end   % events, and the types that draw fixed layers
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
ev.spanStyle = string(E.evSpanStyle.Value);
ev.spanWidth = E.evSpanWidth.Value;
ev.spanAlpha = E.evSpanAlpha.Value;
L.event = ev;
L.eventsAs = string(E.evDrawAs.Value);
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


function v = shownShare(s)
%shownShare  The panel size applyFigureEditor shows, % of its cell each way (100 for what is not two numbers).
v = [100 100];
if numel(s) == 2 && all(isfinite(s)); v = min(100, max(1, 100 * reshape(s, 1, 2))); end
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


function a = aurocPlotFrom(E, pre, a)
%aurocPlotFrom  A PSTH's or heat map's auROC settings A as the editor's fields PRE* show them (aurocRows, ISPLOT).
a.method = string(E.(pre + "Method").Value);
a.windows = string(E.(pre + "Windows").Value);
a.windowSec = E.(pre + "WinMs").Value / 1000;
a.stepSec = E.(pre + "StepMs").Value / 1000;
a.modulationWindow = [E.(pre + "ModFrom").Value E.(pre + "ModTo").Value];
a.cutoff = string(E.(pre + "Cutoff").Value);
a.threshold = E.(pre + "Threshold").Value;
a.test = string(E.(pre + "Test").Value);
a.nResamples = E.(pre + "Resamples").Value;
a.correction = string(E.(pre + "Correction").Value);
a.alpha = E.(pre + "Alpha").Value;
a.marks = logical(E.(pre + "Marks").Value);
a.modulatedOnly = logical(E.(pre + "ModOnly").Value);
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
