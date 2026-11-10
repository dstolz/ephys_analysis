function fig = gatherFigureEditor(obj)
%gatherFigureEditor  The selected figure as the editor shows it (normalized).
%   The figure's rows, the selected panel's (SelectedPanel) and that
%   panel's selected layer's (SelectedLayer); the other panels and layers,
%   and every field without a control, keep their values. The panel's type
%   is not read here (onPanelTypeChanged changes it). With a section's "Use default" box ticked the
%   figure's ref / window / selection is "default"; unticked (or edited:
%   onFigureAlignEdited), the figure takes the values its controls show.
%   The panel's ref and window are its own where it has them
%   (E.panelSame.UserData: onPanelAlignEdited), else "default"; its
%   selection is its own while "Trial selection as the figure" is
%   unticked (the selection rows of the Panel alignment section), else
%   "default"; a trial panel's ref and window are always "default" (it has
%   none: its selection alone). The
%   panel's rect (the Layout section's Position and Size, in the units
%   picked) and the figure's padding are written only where a field no
%   longer shows what showPanelPlace showed (on the page, dpi and units
%   it showed them on), so a value the fields round is kept as stored: a
%   field typed is converted to 0-1 of the page (figureRectConvert), the
%   padding to cm, and the rect kept on the page (x and y at least 0,
%   width and height at least 0.01 and inside the page: a position typed
%   moves the panel, a size typed is cut at the page's edge). Boxes mean
%   is the drop-down's. The panel's options are its Analysis, Display and Axes rows', every field
%   of its type, but its waveform: the Waveform section's rows (the time
%   span [] while both its fields are blank, ampLim only with the fixed
%   scale); a trial panel's its trial rows (gatherTrial). A layer's
%   measures (a trials layer's measure and xMeasure) have no row: the
%   Trial measure window sets them (trialMeasureDialog).
%   The panel's text note is its Annotations' Text note rows', its overlays the
%   Overlays list's, the one picked read from its rows (overlayGather).
%   The figure's latency block is the First-spike latency rows' (a value
%   in ms written only when it differs from what applyFigureEditor showed).
%   Its probe block is the Probe layout rows': the shanks and channels as
%   the Observations section's lists, the depth range two ascending
%   values ("lo hi"; anything else, blank, is [] = all), the tile's width
%   and height only when their spinners differ from what
%   applyFigureEditor showed.
%   The figure's Pages row (Observations) sets sessions.enabled (across
%   datasets) and probe.enabled (on the probe): one of the two at most.
%   The figure's size is the Page size rows' (Layout): "Export tab size" in the drop-down
%   is size.source "export" (the own width and height kept as stored),
%   anything else an own size of the Width and Height fields (the drop-down
%   and the fields agree: onFigureSizeEdited keeps them so).
%   While an Arrange press has selected a panel lightly (FigureSelectPending:
%   the panel's rows still show the previous panel) the rows are filled
%   first (finishPendingSelect), so the previous panel's values are not
%   read into the one selected.
finishPendingSelect(obj, "");
E = obj.FigureEditor;
fig = obj.Config.Figures(obj.SelectedFigure);
fig.id = strtrim(string(E.id.Value));
fig.autoId = logical(E.idAuto.Value);   % ticked: the config gives the automatic id (normalizeFigures)
fig.title = string(E.title.Value);
fig.enabled = logical(E.enabled.Value);
fig.size.units = string(E.sizeUnits.Value);   % (an Export tab size keeps the own size's numbers, which it does not use)
fig.size.lock = logical(E.sizeLock.Value);
if lower(strtrim(string(E.sizePreset.Value))) ~= lower(figureSizePresets().Label(1))
    fig.size.source = "own";
    fig.size.width = E.sizeWidth.Value;
    fig.size.height = E.sizeHeight.Value;
else
    fig.size.source = "export";
end

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
o.starred = logical(E.obsStarred.Value);
o.perGroup = logical(E.obsPerGroup.Value);
fig.observe = o;

% across sessions (datasetKeys has no control of its own: Pick... sets it, onPickFigureDatasets)
ss = fig.sessions;
ss.enabled = string(E.pages.Value) == "sessions";   % (Pages)
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

% on the probe (the Probe layout section): a tile's width and height only when edited (the spinners start at 0.1)
pr = fig.probe;
pr.enabled = string(E.pages.Value) == "probe";
pr.layout = string(E.prbLayout.Value);
pr.overlap = string(E.prbOverlap.Value);
pr.lanes = max(1, round(E.prbLanes.Value));
pr.shanks = parseList(E.prbShanks.Value);
pr.channels = parseList(E.prbChannels.Value);
pr.depthRange = limits(E.prbDepth.Value);
pr.maxTiles = max(1, round(E.prbMaxTiles.Value));
pr.maxPerSite = max(1, round(E.prbPerSite.Value));
if E.prbTileWidth.Value ~= shownIn(pr.tileWidth, E.prbTileWidth.Limits); pr.tileWidth = E.prbTileWidth.Value; end
if E.prbTileHeight.Value ~= shownIn(pr.tileHeight, E.prbTileHeight.Limits); pr.tileHeight = E.prbTileHeight.Value; end
pr.tileScale = E.prbScale.Value;
pr.labels = string(E.prbLabels.Value);
pr.sharedY = logical(E.prbSharedY.Value);
pr.scaleTile = logical(E.prbScaleTile.Value);
pr.showSites = logical(E.prbShowSites.Value);
pr.leaders = logical(E.prbLeaders.Value);
fig.probe = pr;

% the first-spike latency and response onset: a value in ms is written only when its field differs from what
% applyFigureEditor showed (ms to s and back need not give the same number)
L = fig.latency;
L.method = string(E.latMethod.Value);
L.minSec = fromMs(E.latFrom.Value, L.minSec);
if isempty(E.latTo.Value); L.maxSec = Inf; else; L.maxSec = fromMs(E.latTo.Value, L.maxSec); end
L.baseline = string(E.latBaseline.Value);
bw = [-0.1 0];
if numel(L.baselineWindow) == 2 && all(isfinite(L.baselineWindow)); bw = L.baselineWindow; end
L.baselineWindow = [fromMs(E.latBaseFrom.Value, bw(1)) fromMs(E.latBaseTo.Value, bw(2))];
L.baselineRate = string(E.latRate.Value);
L.surprise = E.latSurprise.Value;
L.minSpikes = E.latMinSpikes.Value;
L.alpha = E.latAlpha.Value;
L.cusumBinSec = fromMs(E.latCusum.Value, L.cusumBinSec);
L.cusumSustainSec = fromMs(E.latCusumSustain.Value, L.cusumSustainSec);
L.cusumThreshold = E.latCusumSD.Value;
L.cusumDrift = E.latCusumDrift.Value;
fig.latency = L;

% what a rect means and the padding (in the units shown: cm when edited); appearance
fig.layout.boxesMean = string(E.boxesMean.Value);
[page, dpi, units, shownPanel] = shownOn(obj, E);
[~, d] = unitsShown([], "", units);
tol = 0.5 * 10^-d + 1e-9;
if abs(E.padding.Value - unitsShown(double(fig.layout.padding), "cm", units, page, dpi, "x")) > tol
    fig.layout.padding = max(0, figureRectConvert(E.padding.Value, units, "cm", page, dpi, "x"));
end
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
s.ShowStop = E.showStop.Value;
s.ShowArtifactNote = E.showArtifactNote.Value;
s.Legend = E.legend.Value;
s.Grid = E.grid.Value;
s.LegendLocation = string(E.legendLoc.Value);
s.LegendOrientation = string(E.legendOrient.Value);
s.LegendBox = logical(E.legendBox.Value);
fig.style = s;

% the figure's alignment
D = obj.Config.Defaults;
ref = D.EventRef; win = D.Window; sel = D.Selection;
if isstruct(fig.ref); ref = fig.ref; end
if isstruct(fig.window); win = fig.window; end
if isstruct(fig.selection); sel = fig.selection; end
[ref, win, sel] = AlignControls.read(obj.FigureAlignControls, ref, win, sel);
if E.defaultRef.Value; fig.ref = "default"; else; fig.ref = ref; end
if E.defaultWindow.Value; fig.window = "default"; else; fig.window = win; end
if E.defaultSelection.Value; fig.selection = "default"; else; fig.selection = sel; end

% the selected panel
j = obj.SelectedPanel;
if j >= 1 && j <= numel(fig.panels)
    p = fig.panels(j);
    p.title = string(E.panelTitle.Value);
    p.box = string(E.panelBox.Value);
    p.xLabel = strtrim(string(E.panelXLabel.Value));
    p.yLabel = strtrim(string(E.panelYLabel.Value));
    p.xSide = string(E.panelXSide.Value);
    p.ySide = string(E.panelYSide.Value);
    p.xShow = string(E.panelXShow.Value);
    p.yShow = string(E.panelYShow.Value);
    % its rect only where a field was edited: the fields round what they show (Validate reports a bad rect); only
    % when they show this panel's rect (showPanelPlace)
    r = double(p.rect);
    if numel(r) == 4 && all(isfinite(r)) && shownPanel == p.id
        typed = [E.rectX.Value E.rectY.Value E.rectW.Value E.rectH.Value];
        edited = abs(typed - unitsShown(r, "normalized", units, page, dpi, "rect")) > tol & isfinite(typed);
        if any(edited)
            n = figureRectConvert(typed, units, "normalized", page, dpi, "rect");
            r(edited) = n(edited);
            p.rect = onPage(r, edited);
        end
    end
    own = E.panelSame.UserData;
    if ~(islogical(own) && numel(own) == 2); own = [false false]; end
    if ismember(p.type, EphysAnalysisConfig.TrialPanelTypes); own = [false false]; end   % no event or window: its trial selection alone
    ownSel = ~E.panelSameSel.Value;   % "Trial selection as the figure" unticked: the panel's own
    if any(own) || ownSel
        fref = ref; fwin = win; fsel = sel;   % the figure's (resolved): where the panel's own start from
        if isstruct(p.ref); fref = p.ref; end
        if isstruct(p.window); fwin = p.window; end
        if isstruct(p.selection); fsel = p.selection; end
        [pref, pwin, psel] = AlignControls.read(obj.PanelAlignControls, fref, fwin, fsel);
    end
    if own(1); p.ref = pref; else; p.ref = "default"; end
    if own(2); p.window = pwin; else; p.window = "default"; end
    if ownSel; p.selection = psel; else; p.selection = "default"; end
    p.options = gatherOptions(E, p);
    i = obj.SelectedLayer;
    if i >= 1 && i <= numel(p.layers)
        rows = "items";
        if isfield(p.options, 'rows'); rows = p.options.rows; end
        p.layers(i) = gatherLayer(E, p.layers(i), p.type, rows, fig.observe.data);
    end
    p.note = gatherNote(E, p.note);
    p.overlays = overlayGather(E);   % the list's, the one picked read from its rows
    fig.panels(j) = p;
end
fig = EphysAnalysisConfig.normalizeFigure(fig);
end


function s = fromMs(v, s)
%fromMs  A field's value in ms as s, or S (the value stored) when the field shows that already.
if isempty(v) || abs(v - 1000 * s) <= 1e-9 * max(1, abs(v)); return; end
s = v / 1000;
end


function op = gatherOptions(E, p)
%gatherOptions  The panel's options as the Analysis, Display and Axes rows (and Trial group drawn) show them; fields of other types are not there.
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
if p.type == "legend"
    op.orientation = string(E.legOrient.Value);
    op.columns = round(E.legColumns.Value);
    op.align = string(E.legAlign.Value);
    op.valign = string(E.legVAlign.Value);
end
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
if isfield(op, 'trialCount'); op.trialCount = string(E.trialCount.Value); end
if isfield(op, 'onsetLine'); op.onsetLine = string(E.onsetLine.Value); end
if isfield(op, 'yTicks'); op.yTicks = logical(E.yTicks.Value); end
if isfield(op, 'tickColor'); op.tickColor = strtrim(string(E.tickColor.Value)); end
if isfield(op, 'tickWidth'); op.tickWidth = E.tickWidth.Value; end
if isfield(op, 'backColor'); op.backColor = strtrim(string(E.backColor.Value)); end
if own('maskAfterStop'); op.maskAfterStop = logical(E.maskAfterStop.Value); end
if isfield(op, 'smoothLine')
    op.smoothLine.enabled = logical(E.smoothLine.Value);
    op.smoothLine.smoothSec = E.smoothLineMs.Value / 1000;
    op.smoothLine.legend = logical(E.smoothLineLegend.Value);
end
if isfield(op, 'histStyle')
    op.histStyle = string(E.histStyle.Value);
    op.fill = logical(E.fill.Value);
    op.fillAlpha = E.fillAlpha.Value;
    if isempty(op.fillAlpha); op.fillAlpha = NaN; end
    op.normalize = string(E.normalize.Value);
end
if p.type == "psth"; op.display = string(E.psthDisplay.Value); end
if isfield(op, 'colormap')   % "auto": the design's
    op.colormap = strtrim(string(E.panelColormap.Value));
    if op.colormap == "auto"; op.colormap = ""; end
end
if isfield(op, 'stack')   % the stack, one row for every type that stacks
    op.stack = string(E.stack.Value);
    op.stackSpacing = E.stackSpacing.Value;
end
if p.type == "continuous"
    op.statistic = string(E.statistic.Value);
    op.transform = string(E.transform.Value);
    op.trials = string(E.contTrials.Value);
    op.maxTrials = E.maxTrials.Value;
end
if isfield(op, 'errorType'); op.errorType = string(E.errorType.Value); end   % the panel's own error
if isfield(op, 'errorResamples'); op.errorResamples = E.errResamples.Value; end
if isfield(op, 'band')   % its bands' look
    b = op.band;
    b.faceColor = strtrim(string(E.errFace.Value));
    if lower(b.faceColor) == "auto"; b.faceColor = ""; end
    b.faceAlpha = E.errAlpha.Value;
    if isempty(b.faceAlpha); b.faceAlpha = NaN; end
    b.edgeColor = strtrim(string(E.errEdge.Value));
    if b.edgeColor == ""; b.edgeColor = "none"; end
    b.edgeStyle = string(E.errEdgeStyle.Value);
    b.edgeWidth = E.errEdgeWidth.Value;
    op.band = b;
end
if isfield(op, 'rows'); op.rows = string(E.heatRows.Value); end
if isfield(op, 'order'); op.order = string(E.order.Value); end
if isfield(op, 'value'); op.value = string(E.value.Value); end
if isfield(op, 'unitLabels'); op.unitLabels = logical(E.unitLabels.Value); end
if isfield(op, 'waveColor'); op.waveColor = logical(E.waveColor.Value); end
if isfield(op, 'metric')
    op.metric = string(E.metric.Value);
    op.correlation = string(E.correlation.Value);
    op.fisherZ = logical(E.fisherZ.Value);
    op.detrend = logical(E.detrend.Value);
end
if isfield(op, 'yLim'); op.yLim = limits(E.yLim.Value); end
if isfield(op, 'yLimMode'); op.yLimMode = string(E.yLimMode.Value); end
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
if isfield(op, 'freqScale'); op.freqScale = string(E.spFreqScale.Value); end
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
    op.minWidth = E.etMinWidth.Value;
    op.lineStyle = string(E.etLineStyle.Value);
    op.lineWidth = E.etLineWidth.Value;
    op.showBaseline = logical(E.etBaseline.Value);
    op.baselineColor = strtrim(string(E.etBaseColor.Value));
    if lower(op.baselineColor) == "auto"; op.baselineColor = ""; end
    op.baselineStyle = string(E.etBaseStyle.Value);
    op.baselineWidth = E.etBaseWidth.Value;
    op.rowSpacing = E.etRowSpacing.Value;
end
if ismember(p.type, EphysAnalysisConfig.TrialPanelTypes); op = gatherTrial(E, op, p.type); end
if own('waveform')
    wv = op.waveform;
    wv.mode = string(E.waveMode.Value);
    wv.band = string(E.waveBand.Value);
    wv.maxSpikes = E.waveSpikes.Value;
    wv.timeMs = spanOf(E.waveFrom.Value, E.waveTo.Value);
    wv.ampScale = string(E.waveAmp.Value);
    wv.ampLim = [];   % only with the fixed scale: the fields keep their values meanwhile
    if wv.ampScale == "fixed"; wv.ampLim = [E.waveAmpLo.Value E.waveAmpHi.Value]; end
    wv.width = E.waveWidth.Value;
    wv.height = E.waveHeight.Value;
    wv.location = string(E.waveLocation.Value);
    wv.box = logical(E.waveBox.Value);
    wv.showPP = logical(E.wavePP.Value);
    wv.showCount = logical(E.waveCount.Value);
    wv.showSites = logical(E.waveSites.Value);
    wv.showNames = logical(E.waveNames.Value);
    op.waveform = wv;
end
end


function op = gatherTrial(E, op, type)
%gatherTrial  A trial distribution's, histogram's or scatter's options OP (of TYPE) as its Analysis, Display and Axes rows show them (the fields it has).
%   Its error and y limits are the Error and Y limits rows' (gatherOptions);
%   a parameter's bins are a list ("" = [], "5" = 5 bins, "0 100 200" =
%   edges), the x limits two ascending values else [] (automatic).
if isfield(op, 'categories')
    op.categories = string(E.trCategories.Value);
    op.categoryParam = strtrim(string(E.trCategoryParam.Value));
    op.categoryBins = parseList(E.trCategoryBins.Value);
end
op.series = string(E.trSeries.Value);
op.seriesParam = strtrim(string(E.trSeriesParam.Value));
op.seriesBins = parseList(E.trSeriesBins.Value);
op.summary = string(E.trSummary.Value);
op.test = string(E.trTest.Value);
op.testPairs = string(E.trPairs.Value);
op.adjust = string(E.trAdjust.Value);
op.testAlpha = E.trAlpha.Value;
op.testShow = string(E.trTestShow.Value);
switch type
    case "trialDist"
        op.bracketPairs = string(E.trBracketPairs.Value);
        op.display = string(E.trDisplay.Value);
        op.ordinalX = logical(E.trOrdinalX.Value);
        op.markerSize = E.trMarker.Value;
        op.jitter = E.trJitter.Value;
        op.showSummary = logical(E.trShowSummary.Value);
        op.showN = "off";
        if E.trShowN.Value; op.showN = "ticks"; end
        op.yScale = string(E.trYScale.Value);
    case "trialHist"
        op.display = string(E.trHistDisplay.Value);
        op.normalization = string(E.trNormalization.Value);
        op.binMode = string(E.trBins.Value);
        op.binCount = E.trBinCount.Value;
        op.binWidth = E.trBinWidth.Value;
        op.alpha = E.trOpacity.Value;
        op.showSummary = logical(E.trShowSummary.Value);
        op.xScale = string(E.trXScale.Value);
        op.xLim = limits(E.trXLim.Value);
    case "trialScatter"
        op.fit = string(E.trFit.Value);
        op.fitBand = logical(E.trFitBand.Value);
        op.fitWindow = E.trFitWindow.Value;
        op.corr = string(E.trCorr.Value);
        op.marginals = logical(E.trMarginals.Value);
        op.marginalSize = E.trMarginalSize.Value;
        op.markerSize = E.trMarker.Value;
        op.alpha = E.trOpacity.Value;
        op.xScale = string(E.trXScale.Value);
        op.yScale = string(E.trYScale.Value);
        op.xLim = limits(E.trXLim.Value);
end
end


function span = spanOf(from, to)
%spanOf  A waveform's time span from its two fields: [] when both are blank, else [from to] (a blank one: -Inf or Inf).
if isempty(from) && isempty(to)
    span = [];
    return
end
if isempty(from); from = -Inf; end
if isempty(to); to = Inf; end
span = [from to];
end


function nt = gatherNote(E, nt)
%gatherNote  The panel's text note as the Annotations' Text note rows show it.
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


function L = gatherLayer(E, L, type, rows, observed)
%gatherLayer  Layer L of a panel of TYPE (a heat map's options.rows ROWS) in a figure observing OBSERVED, as the Layers rows show it.
L.name = strtrim(string(E.layerName.Value));
L.enabled = logical(E.layerEnabled.Value);
L.source = string(E.layerSource.Value);
L.binding = string(E.layerBinding.Value);
ch = figureEditorChoices(type, L.source, rows, Observed=observed);
if ~ch.Bindable; L.binding = "fixed"; end   % events, AUX under units, and the types that draw fixed layers
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
if ~ismember(L.aggregate, ch.Aggregates) || (L.aggregate == "magnitude" && L.binding ~= "fixed")
    L.aggregate = "each";   % only what the type offers the source; a magnitude makes fixed channels one
end
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


function [page, dpi, units, panel] = shownOn(obj, E)
%shownOn  The page ([w h] cm), dpi and units the Layout section's fields were shown on, and the panel whose rect they show (showPanelPlace).
S = E.rectUnits.UserData;
if isstruct(S) && isscalar(S) && all(isfield(S, {'page', 'dpi', 'units', 'panel'}))
    page = S.page;
    dpi = S.dpi;
    units = S.units;
    panel = string(S.panel);
    return
end
[page, dpi] = figurePage(obj);   % not shown yet: the figure's page now, no panel's rect
units = obj.FigureRectUnits;
panel = "";
end


function r = onPage(r, edited)
%onPage  Rect R ([x y w h], 0-1 of the page) kept on the page: x, y >= 0, w, h >= 0.01, inside [0 1]; EDITED says which parts were typed.
%   A side too long for the page is cut at its edge when its size was
%   typed; else (its position typed) the panel moves back onto the page.
minSize = 0.01;
r(3:4) = min(max(r(3:4), minSize), 1);
r(1:2) = min(max(r(1:2), 0), 1 - minSize);
for a = 1:2   % x with the width, y with the height
    if r(a) + r(a + 2) <= 1; continue; end
    if edited(a + 2) && ~edited(a)
        r(a + 2) = 1 - r(a);   % the size typed: cut at the page's edge
    else
        r(a) = 1 - r(a + 2);   % the position typed: back onto the page
    end
end
end


function v = shownIn(x, limits)
%shownIn  The value applyFigureEditor shows for X in a spinner of LIMITS (clipped to them).
v = min(limits(2), max(limits(1), x));
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
