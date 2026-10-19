function applyFigureEditor(obj)
%applyFigureEditor  Show the selected figure, its selected panel and that panel's selected layer in the editor.
%   The figure's own rows (id, title, observations, spacing, alignment,
%   appearance, looks), then the panel's (SelectedPanel: type, title, spans,
%   its row's height and column's width, its own event and window or the
%   figure's, its type's options, its layers) and the layer's
%   (SelectedLayer), and the panel's text note and overlays (the first
%   picked). The line and parameter lists come from the active
%   dataset. syncFigureEditor then shows the rows they use;
%   drawFigureSchematic draws the arrangement.
E = obj.FigureEditor;
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.SelectedPanel = 0;
    obj.SelectedLayer = 0;
    obj.FigureEditorPanel.Title = "Figure";
    E.id.Value = '';
    obj.syncFigureEditor();
    return
end
wasApplying = obj.Applying;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, wasApplying));
fig = obj.Config.Figures(k);
np = numel(fig.panels);
obj.SelectedPanel = min(max(obj.SelectedPanel, 1), np);
[lines, params] = sourceItems(obj);
obj.FigureEditorPanel.Title = "Figure: " + fig.id;
E.id.Value = char(fig.id);
E.title.Value = char(fig.title);
E.enabled.Value = fig.enabled;

% observations
o = fig.observe;
E.observe.Value = char(pickFrom(o.kind, EphysAnalysisConfig.ObserveKinds, "auto"));
E.obsSource.Value = char(pickFrom(o.source, EphysAnalysisConfig.SpikeSources, "units"));
u = o.units;
for c = string(fieldnames(E.obsClasses)).'
    E.obsClasses.(c).Value = ismember(c, u.classes);
end
E.obsIds.Value = listText(u.ids);
E.obsMaxUnits.Value = char(string(u.maxUnits));
E.obsQuality.Value = logical(u.quality.enabled);
rs = u.response;
E.obsResponse.Value = logical(rs.enabled);
E.obsRespTest.Value = char(pickFrom(rs.test, string(E.obsRespTest.ItemsData), "evoked"));
offerItems(E.obsRespDirection, ["any" "excited" "suppressed"], rs.direction);
E.obsRespBaseFrom.Value = rs.baseline(1);
E.obsRespBaseTo.Value = rs.baseline(2);
E.obsRespFrom.Value = rs.window(1);
E.obsRespTo.Value = rs.window(2);
offerItems(E.obsRespParam, ["" params], rs.param);
E.obsRespCorrection.Value = char(pickFrom(rs.correction, string(E.obsRespCorrection.ItemsData), "bh"));
E.obsRespAlpha.Value = min(1, max(eps, rs.alpha));
aurocTo(E, "obsRa", rs.auroc);
E.obsShanks.Value = listText(u.shanks);
E.obsUnitChannels.Value = listText(u.channels);
offerItems(E.obsSignal, EphysAnalysisConfig.SignalSources, o.signal);
E.obsChannels.Value = listText(o.channels);
E.obsPerGroup.Value = logical(o.perGroup);

% across sessions (the Sessions section)
ss = fig.sessions;
E.sesEnabled.Value = logical(ss.enabled);
E.sesDatasets.Value = char(pickFrom(ss.datasets, ["ticked" "list"], "ticked"));
E.sesKeys.Value = char(strjoin(ss.datasetKeys, ", "));
E.sesFacet.Value = char(pickFrom(ss.facet, EphysAnalysisConfig.SessionFacets, "none"));
E.sesSeries.Value = char(pickFrom(ss.series, EphysAnalysisConfig.SessionSeries, "session"));
E.sesColorOrder.Value = char(pickFrom(ss.colorOrder, EphysAnalysisConfig.SessionColorOrders, "palette"));
E.sesShowMembers.Value = logical(ss.showMembers);
E.sesError.Value = char(pickFrom(ss.error, EphysAnalysisConfig.SessionErrors, "sem"));
E.sesMatch.Value = char(pickFrom(ss.match, EphysAnalysisConfig.FigureSessionMatches, "site"));
E.sesMappingFile.Value = char(ss.mappingFile);
E.sesMinSessions.Value = max(1, ss.minSessions);
E.sesTrialGroups.Value = char(pickFrom(ss.trialGroups, EphysAnalysisConfig.SessionTrialGroups, "pool"));

% arrangement, appearance, looks
E.spacing.Value = char(pickFrom(fig.grid.spacing, string(E.spacing.ItemsData), "tight"));
s = fig.style;
E.fontSize.Value = min(E.fontSize.Limits(2), max(E.fontSize.Limits(1), s.FontSize));
E.lineWidth.Value = min(E.lineWidth.Limits(2), max(E.lineWidth.Limits(1), s.LineWidth));
E.siteSize.Value = min(E.siteSize.Limits(2), max(E.siteSize.Limits(1), s.SiteSize));
offerItems(E.colormap, string(E.colormap.Items), pick(s.Colormap, "lines"));
offerItems(E.heatColormap, string(E.heatColormap.Items), pick(s.HeatColormap, "auto"));
E.sortDepth.Value = s.SortDepth;
E.sortShank.Value = s.SortShank;
E.labelDepth.Value = s.LabelDepth;
E.labelShank.Value = s.LabelShank;
E.showSEM.Value = s.ShowSEM;
E.showStop.Value = s.ShowStop;
E.legend.Value = s.Legend;
E.grid.Value = s.Grid;
E.legendLoc.Value = char(pickFrom(s.LegendLocation, string(E.legendLoc.ItemsData), "auto"));
E.legendOrient.Value = char(pickFrom(s.LegendOrientation, string(E.legendOrient.ItemsData), "auto"));
E.legendBox.Value = s.LegendBox;
E.errType.Value = char(pickFrom(s.ErrorType, string(E.errType.ItemsData), "sem"));
E.errResamples.Value = min(E.errResamples.Limits(2), max(E.errResamples.Limits(1), round(s.ErrorResamples)));
offerItems(E.errFace, string(E.errFace.Items), pick(s.ErrorFaceColor, "auto"));
if isnan(s.ErrorFaceAlpha)
    E.errAlpha.Value = [];
else
    E.errAlpha.Value = min(1, max(0, s.ErrorFaceAlpha));
end
offerItems(E.errEdge, string(E.errEdge.Items), pick(s.ErrorEdgeColor, "none"));
E.errEdgeStyle.Value = char(pickFrom(s.ErrorEdgeStyle, string(E.errEdgeStyle.ItemsData), "-"));
E.errEdgeWidth.Value = min(E.errEdgeWidth.Limits(2), max(E.errEdgeWidth.Limits(1), s.ErrorEdgeWidth));

% the common options every linked panel takes
c = fig.common;
E.cmBinMs.Value = max(E.cmBinMs.Limits(1), 1000 * c.bins.BinSec);
E.cmSmoothMs.Value = max(0, 1000 * c.bins.SmoothSec);
offerItems(E.cmMeasure, ["rate" "count" "probability"], c.measure);
offerItems(E.cmBaselineMode, ["none" "subtract" "zscore" "percent" "ratio" "auroc"], c.baseline.Mode);
E.cmBaseFrom.Value = c.baseline.Window(1);
E.cmBaseTo.Value = c.baseline.Window(2);
aurocPlotTo(E, "cmAu", c.auroc);
E.cmMaskAfterStop.Value = logical(c.maskAfterStop);
wv = c.waveform;
E.cmWaveMode.Value = char(pickFrom(wv.mode, string(E.cmWaveMode.ItemsData), "off"));
E.cmWaveSpikes.Value = min(E.cmWaveSpikes.Limits(2), max(E.cmWaveSpikes.Limits(1), round(wv.maxSpikes)));
E.cmWaveLocation.Value = char(pickFrom(wv.location, string(E.cmWaveLocation.ItemsData), "northeast"));
E.cmWaveBox.Value = wv.box;
E.cmWaveScale.Value = min(E.cmWaveScale.Limits(2), max(E.cmWaveScale.Limits(1), wv.scale));
E.cmWavePP.Value = wv.showPP;
E.cmWaveCount.Value = wv.showCount;
n = numel(fig.aesthetics);
E.looksText.Text = sprintf("%d remembered look(s); right-click the preview to edit.", n);
E.looksForget.Enable = matlab.lang.OnOffSwitchState(n > 0);

% the figure's alignment: its own, or the Defaults it uses
E.defaultRef.Value = isequal(fig.ref, "default");
E.defaultWindow.Value = isequal(fig.window, "default");
E.defaultSelection.Value = isequal(fig.selection, "default");
[ref, win, sel] = figureAlignment(obj, fig);
obj.fillAlignItems(obj.FigureAlignControls);
obj.applyAlignControls(obj.FigureAlignControls, ref, win, sel);

% the panel, its alignment, options and layers
obj.fillAlignItems(obj.PanelAlignControls);
j = obj.SelectedPanel;
if j >= 1
    p = fig.panels(j);
    applyPanel(obj, E, fig, p, ref, win, sel, lines, params);
else
    obj.SelectedLayer = 0;
    set(E.layerList, "Items", {}, "ItemsData", []);
    overlayList(E, repmat(EphysAnalysisConfig.defaults("Overlay"), 1, 0), 0);
end
obj.syncFigureEditor();
end


function applyPanel(obj, E, fig, p, ref, win, sel, lines, params)
%applyPanel  The selected panel P's rows: type, title, place and size, alignment, options, layers.
PT = EphysAnalysisConfig.panelTypes();
row = PT.Type == p.type;
label = p.type;
if any(row)
    E.panelType.Value = char(p.type);
    label = PT.Label(row);
end
E.panelTitle.Value = char(p.title);
E.panelBox.Value = char(pickFrom(p.box, string(E.panelBox.ItemsData), "auto"));
E.selPanel.Text = sprintf("%s  (%s; row %d, column %d)", p.id, label, p.row, p.col);
E.rowSpan.Value = min(E.rowSpan.Limits(2), max(1, round(p.rowSpan)));
E.colSpan.Value = min(E.colSpan.Limits(2), max(1, round(p.colSpan)));
E.rowHeight.Value = sizeOf(fig.grid.rowHeights, p.row);   % as stored: gatherFigureEditor writes it back only when edited
E.colWidth.Value = sizeOf(fig.grid.colWidths, p.col);
own = [isstruct(p.ref) isstruct(p.window)];
E.panelSame.Value = ~any(own);
E.panelSame.UserData = own;   % which part the panel has of its own (onPanelAlignEdited, gatherFigureEditor)
pref = ref;
pwin = win;
psel = sel;
if own(1); pref = p.ref; end
if own(2); pwin = p.window; end
E.panelSameSel.Value = ~isstruct(p.selection);   % its own trial selection, else the figure's (locked)
if isstruct(p.selection); psel = p.selection; end
obj.applyAlignControls(obj.PanelAlignControls, pref, pwin, psel);

% options: the rows of the panel type's fields, as drawn (a linked panel's common fields: the figure's)
E.panelCommon.Value = p.common;
op = EphysAnalysisConfig.panelOptions(fig, p);
first = "";
on = [p.layers.enabled];
if any(on); first = p.layers(find(on, 1)).source; end
ch = figureEditorChoices(p.type, first);
if isfield(op, 'group'); E.group.Value = min(E.group.Limits(2), max(1, round(op.group))); end
if isfield(op, 'bins')
    E.binMs.Value = max(E.binMs.Limits(1), 1000 * op.bins.BinSec);
    E.smoothMs.Value = max(0, 1000 * op.bins.SmoothSec);
end
if isfield(op, 'measure'); offerItems(E.measure, ["rate" "count" "probability"], op.measure); end
if isfield(op, 'baseline')
    offerItems(E.baselineMode, ch.BaselineModes, op.baseline.Mode);
    E.baseFrom.Value = op.baseline.Window(1);
    E.baseTo.Value = op.baseline.Window(2);
end
if isfield(op, 'auroc'); aurocPlotTo(E, "au", op.auroc); end
if isfield(op, 'param')   % a tuning curve's parameters
    offerItems(E.param, ["" params], op.param);
    offerItems(E.seriesParam, ["" params], op.seriesParam);
end
if p.type == "rate"; E.rateDisplay.Value = char(pickFrom(op.display, string(E.rateDisplay.ItemsData), "bar")); end
if isfield(op, 'layout'); E.waveLayout.Value = char(pickFrom(op.layout, string(E.waveLayout.ItemsData), "grid")); end
if isfield(op, 'rasterSort')
    offerItems(E.rasterSort, ["" "stop" "event" params], op.rasterSort);
    offerItems(E.rasterSortOrder, ["ascending" "descending"], op.rasterSortOrder);
    se = op.rasterSortEvent;   % none: a blank line to pick
    if isempty(se); se = EphysAnalysisConfig.defaults("EventRef"); se.line = ""; end
    offerItems(E.sortLine, ["" lines], se.line);
    offerItems(E.sortEdge, ["onset" "offset"], se.edge);
    closeSequenceDialog(obj, E.sortSeqText);
    setSequenceHolder(E.sortSeqText, struct('sequence', se.sequence, 'alignStep', se.alignStep));
    E.rasterByGroup.Value = op.rasterByGroup;
end
if isfield(op, 'yTicks'); E.yTicks.Value = logical(op.yTicks); end
if isfield(op, 'maskAfterStop'); E.maskAfterStop.Value = op.maskAfterStop; end
if isfield(op, 'histStyle')
    offerItems(E.histStyle, ["bar" "line"], op.histStyle);
    E.fill.Value = op.fill;
    if isnan(op.fillAlpha); E.fillAlpha.Value = []; else; E.fillAlpha.Value = min(1, max(0, op.fillAlpha)); end
    E.normalize.Value = char(pickFrom(op.normalize, string(E.normalize.ItemsData), "none"));
end
if isfield(op, 'stack')
    E.stack.Value = logical(op.stack);
    if isfinite(op.stackSpacing) && op.stackSpacing > 0; E.psthSpacing.Value = op.stackSpacing; else; E.psthSpacing.Value = 1.1; end
end
if p.type == "continuous"
    E.contDisplay.Value = char(pickFrom(op.display, string(E.contDisplay.ItemsData), "lines"));
    E.statistic.Value = char(pickFrom(op.statistic, string(E.statistic.ItemsData), "mean"));
    E.transform.Value = char(pickFrom(op.transform, string(E.transform.ItemsData), "none"));
    E.errorType.Value = char(pickFrom(op.errorType, string(E.errorType.ItemsData), "sem"));
    if isfinite(op.stackSpacing) && op.stackSpacing > 0; E.stackSpacing.Value = op.stackSpacing; else; E.stackSpacing.Value = []; end
    E.contTrials.Value = char(pickFrom(op.trials, string(E.contTrials.ItemsData), "off"));
    E.maxTrials.Value = max(1, op.maxTrials);
end
if isfield(op, 'rows'); E.heatRows.Value = char(pickFrom(op.rows, string(E.heatRows.ItemsData), "items")); end
if isfield(op, 'order'); offerItems(E.order, ["probe" "peak" "modulation"], op.order); end
if isfield(op, 'value'); offerItems(E.value, ["rate" "nSpikes" "nUnits"], op.value); end
if isfield(op, 'metric')
    offerItems(E.metric, ["mean" "peak"], op.metric);
    E.correlation.Value = char(pickFrom(op.correlation, string(E.correlation.ItemsData), "pearson"));
    E.fisherZ.Value = logical(op.fisherZ);
end
if isfield(op, 'yLim'); E.yLim.Value = listText(op.yLim); end
if isfield(op, 'cLim'); E.cLim.Value = listText(op.cLim); end
if isfield(op, 'waveform')
    wv = op.waveform;
    fallback = ch.WaveModes(1);
    if p.type == "waveforms"; fallback = "both"; end
    setChoices(E.waveMode, ch.WaveLabels, ch.WaveModes, pickFrom(wv.mode, ch.WaveModes, fallback));
    E.waveSpikes.Value = min(E.waveSpikes.Limits(2), max(E.waveSpikes.Limits(1), round(wv.maxSpikes)));
    E.waveLocation.Value = char(pickFrom(wv.location, string(E.waveLocation.ItemsData), "northeast"));
    E.waveBox.Value = wv.box;
    E.waveScale.Value = min(E.waveScale.Limits(2), max(E.waveScale.Limits(1), wv.scale));
    E.wavePP.Value = wv.showPP;
    E.waveCount.Value = wv.showCount;
end
if isfield(op, 'taperMode')   % a spectral panel's Chronux rows
    applySpectral(E, op);
end

% its text note and overlays
applyNote(E, p.note);
overlayList(E, p.overlays, 1);
if ~isempty(p.overlays); overlayShow(E, p.overlays(1)); end

% layers: the list, the sources Add offers, the layer picked
nl = numel(p.layers);
obj.SelectedLayer = min(max(obj.SelectedLayer, 1), nl);
if nl == 0
    set(E.layerList, "Items", {}, "ItemsData", []);
else
    labels = strings(1, nl);
    for i = 1:nl; labels(i) = layerLabel(p.layers(i)); end
    set(E.layerList, "Items", cellstr(labels), "ItemsData", 1:nl, "Value", obj.SelectedLayer);
end
add = obj.FigureAddSource;
if ~ismember(add, ch.Sources) && ~isempty(ch.Sources); add = ch.Sources(1); end
if isempty(ch.Sources)
    setChoices(E.addSource, "(none)", "", "");
else
    setChoices(E.addSource, ch.SourceLabels, ch.Sources, add);
end
if obj.SelectedLayer >= 1
    applyLayer(obj, E, p.layers(obj.SelectedLayer), p.type, lines, params);
end
end


function applyNote(E, nt)
%applyNote  The panel's text note NT (defaults("Note")) in the Text note rows.
E.annText.Value = cellstr(splitlines(nt.text));
E.annPlace.Value = char(pickFrom(nt.placement, string(E.annPlace.ItemsData), "below"));
E.annX.Value = min(E.annX.Limits(2), max(E.annX.Limits(1), nt.x));
E.annY.Value = min(E.annY.Limits(2), max(E.annY.Limits(1), nt.y));
E.annAlign.Value = char(pickFrom(nt.align, string(E.annAlign.ItemsData), "left"));
E.annVAlign.Value = char(pickFrom(nt.valign, string(E.annVAlign.ItemsData), "middle"));
E.annRotation.Value = min(E.annRotation.Limits(2), max(E.annRotation.Limits(1), nt.rotation));
offerItems(E.annFont, string(E.annFont.Items), pick(nt.fontName, "auto"));
if isfinite(nt.fontSize)
    E.annSize.Value = min(E.annSize.Limits(2), max(E.annSize.Limits(1), nt.fontSize));
else
    E.annSize.Value = [];
end
E.annBold.Value = nt.bold;
E.annItalic.Value = nt.italic;
E.annBox.Value = nt.box;
offerItems(E.annColor, string(E.annColor.Items), pick(nt.color, "auto"));
offerItems(E.annBackground, string(E.annBackground.Items), pick(nt.background, "none"));
E.annInterp.Value = char(pickFrom(nt.interpreter, string(E.annInterp.ItemsData), "none"));
end


function applySpectral(E, op)
%applySpectral  A spectrum, spectrogram or coherence panel's Chronux rows (the fields its type has).
E.spTaperMode.Value = char(pickFrom(op.taperMode, string(E.spTaperMode.ItemsData), "TWK"));
E.spTW.Value = max(eps, op.TW);
E.spK.Value = max(1, round(op.K));
E.spW.Value = max(eps, op.W);
E.spP.Value = max(0, round(op.p));
E.spPad.Value = min(E.spPad.Limits(2), max(E.spPad.Limits(1), round(op.pad)));
E.spFmin.Value = max(0, op.fpass(1));
E.spFmax.Value = max(eps, op.fpass(2));
E.spDetrend.Value = char(pickFrom(op.detrend, string(E.spDetrend.ItemsData), "constant"));
if isfield(op, 'timeBase')
    E.spTimeBase.Value = char(pickFrom(op.timeBase, string(E.spTimeBase.ItemsData), "aligned"));
    E.spRangeFrom.Value = max(0, op.range(1));
    E.spRangeTo.Value = max(0, op.range(2));
    E.spSegment.Value = max(eps, op.segmentSec);
end
if isfield(op, 'err')
    offerItems(E.spErr, ["none" "theoretical" "jackknife"], op.err);
    E.spErrP.Value = min(1 - eps, max(eps, op.errP));
end
if isfield(op, 'scale'); E.spScale.Value = char(pickFrom(op.scale, string(E.spScale.ItemsData), "db")); end
if isfield(op, 'spikeFs'); E.spSpikeFs.Value = max(eps, op.spikeFs); end
if isfield(op, 'movingwin')
    E.spWin.Value = max(eps, op.movingwin(1));
    E.spStep.Value = max(eps, op.movingwin(2));
end
if isfield(op, 'overTime'); E.spOverTime.Value = logical(op.overTime); end
if isfield(op, 'showPhase'); E.spShowPhase.Value = logical(op.showPhase); end
end


function applyLayer(obj, E, L, type, lines, ~)
%applyLayer  The rows of layer L of a panel of TYPE.
ch = figureEditorChoices(type, L.source);
srcs = ch.Sources;
labels = ch.SourceLabels;
if ~ismember(L.source, srcs); srcs(end+1) = L.source; labels(end+1) = L.source; end   % kept, for Validate to report
setChoices(E.layerSource, labels, srcs, L.source);
E.layerName.Value = char(L.name);
E.layerEnabled.Value = L.enabled;
E.layerBinding.Value = char(pickFrom(L.binding, ["observation" "fixed"], "fixed"));
u = L.units;
for c = string(fieldnames(E.layerClasses)).'
    E.layerClasses.(c).Value = ismember(c, u.classes);
end
E.layerIds.Value = listText(u.ids);
E.layerQuality.Value = logical(u.quality.enabled);
E.layerResponse.Value = logical(u.response.enabled);
E.layerMaxUnits.Value = char(string(u.maxUnits));
E.layerShanks.Value = listText(u.shanks);
E.layerUnitChannels.Value = listText(u.channels);
E.layerChannels.Value = listText(L.channels);
E.layerAggregate.Value = char(pickFrom(L.aggregate, ["each" "mean"], "each"));
ev = L.event;
offerItems(E.evLine, lines, ev.line);
offerItems(E.evEdge, ["onset" "offset"], ev.edge);
closeSequenceDialog(obj, E.evSeqText);
setSequenceHolder(E.evSeqText, struct('sequence', ev.sequence, 'alignStep', ev.alignStep));
E.evDrawAs.Value = char(pickFrom(L.eventsAs, ["marks" "train"], "marks"));
E.evMarker.Value = char(pickFrom(ev.marker, string(E.evMarker.ItemsData), "diamond"));
E.evSize.Value = min(E.evSize.Limits(2), max(E.evSize.Limits(1), ev.size));
offerItems(E.evColor, string(E.evColor.Items), pick(ev.color, "auto"));
offerItems(E.layerColor, string(E.layerColor.Items), pick(L.color, "auto"));
E.layerLineStyle.Value = char(pickFrom(pick(L.lineStyle, "auto"), string(E.layerLineStyle.ItemsData), "auto"));
end


function [ref, win, sel] = figureAlignment(obj, fig)
%figureAlignment  The figure's event reference, window and selection: its own, else the Defaults.
D = obj.Config.Defaults;
ref = D.EventRef; win = D.Window; sel = D.Selection;
if isstruct(fig.ref); ref = fig.ref; end
if isstruct(fig.window); win = fig.window; end
if isstruct(fig.selection); sel = fig.selection; end
end


function [lines, params] = sourceItems(obj)
%sourceItems  The active dataset's lines ("Trial", its digital and trial lines) and trial parameters.
lines = "Trial";
params = string.empty(1, 0);
if isempty(obj.Runner) || obj.ActiveIdx < 1; return; end
try
    src = obj.Runner.source(obj.ActiveIdx);
    params = src.paramNames;
    lines = [lines string(fieldnames(src.events)).'];
    if src.hasTrials && height(src.trials) > 0; lines = [lines string(fieldnames(src.trials.TrialEvents)).']; end
catch
end
lines = unique(lines, 'stable');
end


function v = sizeOf(sizes, i)
%sizeOf  The relative size of row (column) I: 1 while the sizes are [] (equal), or not a positive number (Validate says so).
v = 1;
if numel(sizes) >= i && isfinite(sizes(i)) && sizes(i) > 0; v = sizes(i); end
end


function aurocTo(E, pre, a)
%aurocTo  Show the response test's auROC settings A in the editor's fields PRE* (buildFiguresTab's aurocRows).
E.(pre + "Method").Value = char(pickFrom(a.method, string(E.(pre + "Method").ItemsData), "psth"));
offerItems(E.(pre + "Windows"), ["tiled" "sliding"], a.windows);
E.(pre + "WinMs").Value = max(1e-6, 1000 * a.windowSec);
E.(pre + "StepMs").Value = max(1e-6, 1000 * a.stepSec);
E.(pre + "BinMs").Value = max(1e-6, 1000 * a.binSec);
E.(pre + "Cutoff").Value = char(pickFrom(a.cutoff, string(E.(pre + "Cutoff").ItemsData), "ci"));
E.(pre + "Threshold").Value = min(0.499, max(0, a.threshold));
offerItems(E.(pre + "Test"), ["bootstrap" "ranksum" "shuffle"], a.test);
E.(pre + "Resamples").Value = max(1, round(a.nResamples));
end


function aurocPlotTo(E, pre, a)
%aurocPlotTo  Show a PSTH's or heat map's auROC settings A (defaults("Auroc")) in the editor's fields PRE* (aurocRows, ISPLOT).
E.(pre + "Method").Value = char(pickFrom(a.method, string(E.(pre + "Method").ItemsData), "psth"));
offerItems(E.(pre + "Windows"), ["tiled" "sliding"], a.windows);
E.(pre + "WinMs").Value = max(1e-6, 1000 * a.windowSec);
E.(pre + "StepMs").Value = max(1e-6, 1000 * a.stepSec);
m = a.modulationWindow;
if numel(m) == 2
    E.(pre + "ModFrom").Value = m(1);
    E.(pre + "ModTo").Value = m(2);
end
E.(pre + "Cutoff").Value = char(pickFrom(a.cutoff, string(E.(pre + "Cutoff").ItemsData), "ci"));
E.(pre + "Threshold").Value = min(0.499, max(0, a.threshold));
offerItems(E.(pre + "Test"), ["bootstrap" "ranksum" "shuffle"], a.test);
E.(pre + "Resamples").Value = max(1, round(a.nResamples));
E.(pre + "Correction").Value = char(pickFrom(a.correction, string(E.(pre + "Correction").ItemsData), "bh"));
E.(pre + "Alpha").Value = min(1, max(eps, a.alpha));
E.(pre + "Marks").Value = logical(a.marks);
E.(pre + "ModOnly").Value = logical(a.modulatedOnly);
end


function setChoices(dd, labels, data, v)
%setChoices  Give drop-down DD these labels and values, and show V.
dd.ItemsData = [];
dd.Items = labels;
dd.ItemsData = data;
dd.Value = v;
end


function v = pick(v, default)
if v == ""; v = default; end
end


function v = pickFrom(v, allowed, default)
if ~ismember(v, allowed); v = default; end
end


function t = listText(v)
if isempty(v)
    t = '';
else
    t = char(strjoin(string(v), " "));
end
end


function setApplying(obj, tf)
if isvalid(obj); obj.Applying = tf; end
end
