function applyPlotEditor(obj)
%applyPlotEditor  Show the selected plot in the editor (items follow its kind).
%   syncPlotEditor then shows the rows the plot uses. With several plots
%   selected the editor shows the first's values (showPlotSelection says
%   so), and what it shows now is kept (ShownPlot) for gatherConfig to tell
%   what an edit changed.
E = obj.PlotEditor;
k = obj.SelectedPlot;
if k < 1 || k > numel(obj.Config.Plots)
    E.kind.Text = "";
    E.note.Text = "Add a plot (the kind box under the list).";
    obj.ShownPlot = struct();
    obj.showPlotSelection();
    obj.syncPlotEditor();
    return
end
wasApplying = obj.Applying;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, wasApplying));
p = obj.Config.Plots(k);
K = EphysAnalysisConfig.plotKinds();
row = K(K.Kind == p.kind, :);
ch = plotEditorChoices(p.kind, p.source);
E.enabled.Value = p.enabled;
E.kind.Text = row.Label;
E.id.Value = char(p.id);
E.title.Value = char(p.title);
offerItems(E.source, ch.Sources, p.source);
offerItems(E.layout, ch.Layouts, pick(p.layout, row.DefaultLayout));
for c = string(fieldnames(E.classes)).'
    E.classes.(c).Value = ismember(c, p.units.classes);
end
E.ids.Value = listText(p.units.ids);
E.maxUnits.Value = char(string(p.units.maxUnits));
E.quality.Value = logical(p.units.quality.enabled);
rs = p.units.response;
E.response.Value = logical(rs.enabled);
E.respTest.Value = char(pickFrom(rs.test, string(E.respTest.ItemsData), "evoked"));
offerItems(E.respDirection, ["any" "excited" "suppressed"], rs.direction);
E.respBaseFrom.Value = rs.baseline(1);
E.respBaseTo.Value = rs.baseline(2);
E.respFrom.Value = rs.window(1);
E.respTo.Value = rs.window(2);
E.respCorrection.Value = char(pickFrom(rs.correction, string(E.respCorrection.ItemsData), "bh"));
E.respAlpha.Value = min(1, max(eps, rs.alpha));
if ismember(p.source, EphysAnalysisConfig.SignalSources)
    E.channels.Value = listText(p.channels);
else
    E.channels.Value = listText(p.units.channels);
end
E.shanks.Value = listText(p.units.shanks);
E.binMs.Value = 1000 * p.bins.BinSec;
E.smoothMs.Value = 1000 * p.bins.SmoothSec;
E.measure.Value = char(p.measure);
offerItems(E.baselineMode, ch.BaselineModes, p.baseline.Mode);
E.baseFrom.Value = p.baseline.Window(1);
E.baseTo.Value = p.baseline.Window(2);
aurocTo(E, "a", p.auroc);
aurocTo(E, "ra", rs.auroc);
E.withRaster.Value = p.withRaster;
offerItems(E.histStyle, ["bar" "line"], p.histStyle);
E.normalize.Value = char(pickFrom(p.normalize, string(E.normalize.ItemsData), "none"));
E.fill.Value = p.fill;
if isnan(p.fillAlpha)
    E.fillAlpha.Value = [];
else
    E.fillAlpha.Value = min(1, max(0, p.fillAlpha));
end
E.stack.Value = p.stack;
if p.stackSpacing > 0 && isfinite(p.stackSpacing); E.stackSpacing.Value = p.stackSpacing; end
E.maskAfterStop.Value = p.maskAfterStop;
params = string.empty(1, 0);
lines = "Trial";
if ~isempty(obj.Runner) && obj.ActiveIdx >= 1
    try
        src = obj.Runner.source(obj.ActiveIdx);
        params = src.paramNames;
        lines = [lines string(fieldnames(src.events)).'];
        if src.hasTrials && height(src.trials) > 0; lines = [lines string(fieldnames(src.trials.TrialEvents)).']; end
    catch
    end
end
offerItems(E.param, ["" params], p.param);
offerItems(E.seriesParam, ["" params], p.seriesParam);
offerItems(E.rasterSort, ["" "stop" "event" params], p.rasterSort);
offerItems(E.rasterSortOrder, ["ascending" "descending"], p.rasterSortOrder);
se = p.rasterSortEvent;   % none: a blank line to pick
if isempty(se); se = EphysAnalysisConfig.defaults("EventRef"); se.line = ""; end
offerItems(E.sortLine, ["" unique(lines, 'stable')], se.line);
offerItems(E.sortEdge, ["onset" "offset"], se.edge);
closeSequenceDialog(obj, E.sortSeqText);
setSequenceHolder(E.sortSeqText, struct('sequence', se.sequence, 'alignStep', se.alignStep));
E.rasterByGroup.Value = p.rasterByGroup;
mk = p.rasterEvents;
E.markLines.Value = char(strjoin(mk.lines, " "));
offerItems(E.markEdge, ["onset" "offset" "both"], mk.edge);
offerItems(E.markScope, ["window" "trial"], mk.scope);
closeSequenceDialog(obj, E.markSeqText);
setSequenceHolder(E.markSeqText, mk.sequences);
E.markMarker.Value = char(pickFrom(mk.marker, string(E.markMarker.ItemsData), "diamond"));
E.markSize.Value = min(E.markSize.Limits(2), max(E.markSize.Limits(1), mk.size));
offerItems(E.markColor, string(E.markColor.Items), pick(mk.color, "auto"));
offerItems(E.yParam, ["" "stop" params], p.yParam);
E.xScale.Value = char(pickFrom(p.xScale, string(E.xScale.ItemsData), "category"));
E.jitter.Value = p.jitter;
offerItems(E.respParam, ["" params], rs.param);
E.value.Value = char(p.value);
offerItems(E.order, ch.Orders, p.order);
offerItems(E.metric, ["mean" "peak"], p.metric);
E.correlation.Value = char(p.correlation);
E.fisherZ.Value = logical(p.fisherZ);
wv = p.waveform;
offerWaveModes(E.waveMode, p.kind);
fallback = "off";
if p.kind == "waveforms"; fallback = "both"; end
E.waveMode.Value = char(pickFrom(wv.mode, string(E.waveMode.ItemsData), fallback));
E.waveSpikes.Value = min(E.waveSpikes.Limits(2), max(E.waveSpikes.Limits(1), round(wv.maxSpikes)));
E.waveLocation.Value = char(pickFrom(wv.location, string(E.waveLocation.ItemsData), "northeast"));
E.waveBox.Value = wv.box;
E.wavePP.Value = wv.showPP;
E.waveCount.Value = wv.showCount;
E.waveScale.Value = min(E.waveScale.Limits(2), max(E.waveScale.Limits(1), wv.scale));
E.waveAmp.Value = char(pickFrom(wv.ampScale, string(E.waveAmp.ItemsData), "unit"));
E.waveSites.Value = wv.showSites;
E.waveNames.Value = wv.showNames;
nt = p.note;
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
overlayList(E, p.overlays, 1);
if ~isempty(p.overlays); overlayShow(E, p.overlays(1)); end
s = p.style;
E.maxTiles.Value = s.MaxTiles;
E.tileSpacing.Value = char(s.TileSpacing);
E.fontSize.Value = s.FontSize;
E.sortDepth.Value = s.SortDepth;
E.sortShank.Value = s.SortShank;
E.labelDepth.Value = s.LabelDepth;
E.labelShank.Value = s.LabelShank;
E.showSEM.Value = s.ShowSEM;
E.showStop.Value = s.ShowStop;
E.legend.Value = s.Legend;
E.legendLoc.Value = char(pickFrom(s.LegendLocation, string(E.legendLoc.ItemsData), "auto"));
E.legendOrient.Value = char(pickFrom(s.LegendOrientation, string(E.legendOrient.ItemsData), "auto"));
E.legendBox.Value = s.LegendBox;
E.grid.Value = s.Grid;
E.ylim.Value = listText(s.YLim);
E.clim.Value = listText(s.CLim);
E.lineWidth.Value = min(E.lineWidth.Limits(2), max(E.lineWidth.Limits(1), s.LineWidth));
E.siteSize.Value = min(E.siteSize.Limits(2), max(E.siteSize.Limits(1), s.SiteSize));
offerItems(E.colormap,string(E.colormap.Items), pick(s.Colormap, "lines"));
offerItems(E.heatColormap, string(E.heatColormap.Items), pick(s.HeatColormap, "auto"));
E.defaultRef.Value = isequal(p.ref, "default");
E.defaultWindow.Value = isequal(p.window, "default");
E.defaultSelection.Value = isequal(p.selection, "default");
E.note.Text = row.Description;
D = obj.Config.Defaults;
ref = D.EventRef; win = D.Window; sel = D.Selection;
if ~E.defaultRef.Value; ref = p.ref; end
if ~E.defaultWindow.Value; win = p.window; end
if ~E.defaultSelection.Value; sel = p.selection; end
obj.fillAlignItems(obj.PlotAlignControls);
obj.applyAlignControls(obj.PlotAlignControls, ref, win, sel);
obj.showPlotSelection();
obj.syncPlotEditor();
obj.ShownPlot = obj.gatherPlotEditor();
end


function aurocTo(E, pre, a)
%aurocTo  Show the auROC settings A in the editor's fields PRE* (buildPlotsTab's aurocRows).
E.(pre + "Method").Value = char(pickFrom(a.method, string(E.(pre + "Method").ItemsData), "psth"));
offerItems(E.(pre + "Windows"), ["tiled" "sliding"], a.windows);
E.(pre + "WinMs").Value = max(1e-6, 1000 * a.windowSec);
E.(pre + "StepMs").Value = max(1e-6, 1000 * a.stepSec);
E.(pre + "Cutoff").Value = char(pickFrom(a.cutoff, string(E.(pre + "Cutoff").ItemsData), "ci"));
E.(pre + "Threshold").Value = min(0.499, max(0, a.threshold));
offerItems(E.(pre + "Test"), ["bootstrap" "ranksum" "shuffle"], a.test);
E.(pre + "Resamples").Value = max(1, round(a.nResamples));
if isfield(E, pre + "BinMs"); E.(pre + "BinMs").Value = max(1e-6, 1000 * a.binSec); end
if isfield(E, pre + "ModFrom")
    E.(pre + "ModFrom").Value = a.modulationWindow(1);
    E.(pre + "ModTo").Value = a.modulationWindow(2);
    E.(pre + "Correction").Value = char(pickFrom(a.correction, string(E.(pre + "Correction").ItemsData), "bh"));
    E.(pre + "Alpha").Value = min(1, max(eps, a.alpha));
    E.(pre + "Marks").Value = a.marks;
    E.(pre + "ModOnly").Value = a.modulatedOnly;
end
end


function offerWaveModes(dd, kind)
%offerWaveModes  The waveform modes the plot's kind offers: a waveforms plot cannot show none.
modes = ["off" "mean" "subsample" "both"];
labels = ["Off" "Mean" "Subsample" "Mean + subsample"];
if kind == "waveforms"; modes = modes(2:end); labels = labels(2:end); end
if isequal(string(dd.ItemsData), modes); return; end
dd.ItemsData = [];
dd.Items = labels;
dd.ItemsData = modes;
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
