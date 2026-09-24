function applyPlotEditor(obj)
%applyPlotEditor  Show the selected plot in the editor (items follow its kind).
%   syncPlotEditor then shows the rows the plot uses.
E = obj.PlotEditor;
k = obj.SelectedPlot;
if k < 1 || k > numel(obj.Config.Plots)
    E.kind.Text = "";
    E.note.Text = "Add a plot (the kind box under the list).";
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
if ismember(p.source, EphysAnalysisConfig.SignalSources)
    E.channels.Value = listText(p.channels);
else
    E.channels.Value = listText(p.units.channels);
end
E.shanks.Value = listText(p.units.shanks);
E.binMs.Value = 1000 * p.bins.BinSec;
E.smoothMs.Value = 1000 * p.bins.SmoothSec;
offerItems(E.baselineMode, ch.BaselineModes, p.baseline.Mode);
E.baseFrom.Value = p.baseline.Window(1);
E.baseTo.Value = p.baseline.Window(2);
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
if ~isempty(obj.Runner) && obj.ActiveIdx >= 1
    try src = obj.Runner.source(obj.ActiveIdx); params = src.paramNames; catch; end
end
offerItems(E.param, ["" params], p.param);
offerItems(E.seriesParam, ["" params], p.seriesParam);
E.value.Value = char(p.value);
offerItems(E.order, ch.Orders, p.order);
offerItems(E.metric, ["mean" "peak"], p.metric);
E.correlation.Value = char(p.correlation);
s = p.style;
E.maxTiles.Value = s.MaxTiles;
E.fontSize.Value = s.FontSize;
E.showSEM.Value = s.ShowSEM;
E.showStop.Value = s.ShowStop;
E.legend.Value = s.Legend;
E.grid.Value = s.Grid;
E.ylim.Value = listText(s.YLim);
E.lineWidth.Value = min(E.lineWidth.Limits(2), max(E.lineWidth.Limits(1), s.LineWidth));
offerItems(E.colormap, string(E.colormap.Items), pick(s.Colormap, "lines"));
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
obj.syncPlotEditor();
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
