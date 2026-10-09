function p = gatherPlotEditor(obj)
%gatherPlotEditor  The selected plot as the editor shows it (normalized).
%   Fields the editor has no control for keep their values. With a section's
%   "Use default" box ticked the plot's ref / window / selection is
%   "default"; unticked (or edited: onPlotAlignEdited), the plot takes the
%   values in that section's controls (set on the plot's own values, else
%   the Defaults they showed: gatherAlignControls).
E = obj.PlotEditor;
p = obj.Config.Plots(obj.SelectedPlot);
p.enabled = E.enabled.Value;
p.id = strtrim(string(E.id.Value));
p.title = string(E.title.Value);
p.source = string(E.source.Value);
p.layout = string(E.layout.Value);
cls = string(fieldnames(E.classes)).';
cls = cls(arrayfun(@(c) E.classes.(c).Value, cls));
if isempty(cls); cls = string.empty(1, 0); end
p.units.classes = cls;
p.units.ids = parseList(E.ids.Value);
p.units.maxUnits = parseScalar(E.maxUnits.Value, Inf);
p.units.quality.enabled = logical(E.quality.Value);
p.units.response.enabled = logical(E.response.Value);
p.units.response.test = string(E.respTest.Value);
p.units.response.direction = string(E.respDirection.Value);
p.units.response.baseline = [E.respBaseFrom.Value E.respBaseTo.Value];
p.units.response.window = [E.respFrom.Value E.respTo.Value];
p.units.response.param = strtrim(string(E.respParam.Value));
p.units.response.correction = string(E.respCorrection.Value);
p.units.response.alpha = E.respAlpha.Value;
ch = parseList(E.channels.Value);
if ismember(p.source, EphysAnalysisConfig.SignalSources)
    p.channels = ch;
else
    p.units.channels = ch;
end
p.units.shanks = parseList(E.shanks.Value);
p.bins.BinSec = E.binMs.Value / 1000;
p.bins.SmoothSec = E.smoothMs.Value / 1000;
p.measure = string(E.measure.Value);
p.baseline.Mode = string(E.baselineMode.Value);
p.baseline.Window = [E.baseFrom.Value E.baseTo.Value];
p.auroc = aurocFrom(E, "a", p.auroc);
p.units.response.auroc = aurocFrom(E, "ra", p.units.response.auroc);
p.withRaster = E.withRaster.Value;
p.rasterSort = strtrim(string(E.rasterSort.Value));
p.rasterSortOrder = string(E.rasterSortOrder.Value);
p.rasterByGroup = logical(E.rasterByGroup.Value);
lines = split(replace(strtrim(string(E.markLines.Value)), ",", " "));
lines = reshape(unique(lines(lines ~= ""), 'stable'), 1, []);
if isempty(lines); lines = string.empty(1, 0); end
p.rasterEvents.lines = lines;
p.rasterEvents.edge = string(E.markEdge.Value);
p.rasterEvents.scope = string(E.markScope.Value);
p.rasterEvents.sequences = E.markSeqText.UserData;
p.rasterEvents.marker = string(E.markMarker.Value);
p.rasterEvents.size = E.markSize.Value;
p.rasterEvents.color = strtrim(string(E.markColor.Value));
if p.rasterEvents.color == "auto"; p.rasterEvents.color = ""; end
p.histStyle = string(E.histStyle.Value);
p.normalize = string(E.normalize.Value);
p.fill = E.fill.Value;
p.fillAlpha = E.fillAlpha.Value;
if isempty(p.fillAlpha); p.fillAlpha = NaN; end
p.stack = E.stack.Value;
p.stackSpacing = E.stackSpacing.Value;
p.maskAfterStop = E.maskAfterStop.Value;
p.param = strtrim(string(E.param.Value));
p.seriesParam = strtrim(string(E.seriesParam.Value));
p.yParam = strtrim(string(E.yParam.Value));
p.xScale = string(E.xScale.Value);
p.jitter = logical(E.jitter.Value);
p.value = string(E.value.Value);
p.order = string(E.order.Value);
p.metric = string(E.metric.Value);
p.correlation = string(E.correlation.Value);
p.waveform.mode = string(E.waveMode.Value);
p.waveform.maxSpikes = E.waveSpikes.Value;
p.waveform.location = string(E.waveLocation.Value);
p.waveform.box = logical(E.waveBox.Value);
p.waveform.showPP = logical(E.wavePP.Value);
p.waveform.showCount = logical(E.waveCount.Value);
p.waveform.scale = E.waveScale.Value;
p.waveform.ampScale = string(E.waveAmp.Value);
p.waveform.showSites = logical(E.waveSites.Value);
p.waveform.showNames = logical(E.waveNames.Value);
p.note.text = strjoin(string(E.annText.Value(:)).', newline);
p.note.placement = string(E.annPlace.Value);
p.note.x = E.annX.Value;
p.note.y = E.annY.Value;
p.note.align = string(E.annAlign.Value);
p.note.valign = string(E.annVAlign.Value);
p.note.rotation = E.annRotation.Value;
p.note.fontName = strtrim(string(E.annFont.Value));
if lower(p.note.fontName) == "auto"; p.note.fontName = ""; end
p.note.fontSize = E.annSize.Value;
if isempty(p.note.fontSize); p.note.fontSize = NaN; end
p.note.bold = logical(E.annBold.Value);
p.note.italic = logical(E.annItalic.Value);
p.note.box = logical(E.annBox.Value);
p.note.color = strtrim(string(E.annColor.Value));
if lower(p.note.color) == "auto"; p.note.color = ""; end
p.note.background = strtrim(string(E.annBackground.Value));
if lower(p.note.background) == "none"; p.note.background = ""; end
p.note.interpreter = string(E.annInterp.Value);
p.style.MaxTiles = E.maxTiles.Value;
p.style.TileSpacing = string(E.tileSpacing.Value);
p.style.FontSize = E.fontSize.Value;
p.style.SortDepth = E.sortDepth.Value;
p.style.SortShank = E.sortShank.Value;
p.style.LabelDepth = E.labelDepth.Value;
p.style.LabelShank = E.labelShank.Value;
p.style.ShowSEM = E.showSEM.Value;
p.style.ShowStop = E.showStop.Value;
p.style.Legend = E.legend.Value;
p.style.LegendLocation = string(E.legendLoc.Value);
p.style.LegendOrientation = string(E.legendOrient.Value);
p.style.LegendBox = logical(E.legendBox.Value);
p.style.Grid = E.grid.Value;
yl = parseList(E.ylim.Value);
if numel(yl) ~= 2; yl = []; end
p.style.YLim = yl;
p.style.LineWidth = E.lineWidth.Value;
p.style.SiteSize = E.siteSize.Value;
p.style.Colormap = strtrim(string(E.colormap.Value));
if p.style.Colormap == ""; p.style.Colormap = "lines"; end
p.style.HeatColormap = string(E.heatColormap.Value);
if p.style.HeatColormap == "auto"; p.style.HeatColormap = ""; end
D = obj.Config.Defaults;
ref = D.EventRef; win = D.Window; sel = D.Selection;
if isstruct(p.ref); ref = p.ref; end
if isstruct(p.window); win = p.window; end
if isstruct(p.selection); sel = p.selection; end
[ref, win, sel] = obj.gatherAlignControls(obj.PlotAlignControls, ref, win, sel);
if E.defaultRef.Value; p.ref = "default"; else; p.ref = ref; end
if E.defaultWindow.Value; p.window = "default"; else; p.window = win; end
if E.defaultSelection.Value; p.selection = "default"; else; p.selection = sel; end
p = EphysAnalysisConfig.normalizePlot(p);
end


function a = aurocFrom(E, pre, a)
%aurocFrom  The auROC settings A as the editor's fields PRE* show them (buildPlotsTab's aurocRows).
a.method = string(E.(pre + "Method").Value);
a.windows = string(E.(pre + "Windows").Value);
a.windowSec = E.(pre + "WinMs").Value / 1000;
a.stepSec = E.(pre + "StepMs").Value / 1000;
a.cutoff = string(E.(pre + "Cutoff").Value);
a.threshold = E.(pre + "Threshold").Value;
a.test = string(E.(pre + "Test").Value);
a.nResamples = E.(pre + "Resamples").Value;
if isfield(E, pre + "BinMs"); a.binSec = E.(pre + "BinMs").Value / 1000; end
if isfield(E, pre + "ModFrom")
    a.modulationWindow = [E.(pre + "ModFrom").Value E.(pre + "ModTo").Value];
    a.correction = string(E.(pre + "Correction").Value);
    a.alpha = E.(pre + "Alpha").Value;
    a.marks = logical(E.(pre + "Marks").Value);
    a.modulatedOnly = logical(E.(pre + "ModOnly").Value);
end
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
