function applyPlotEditor(obj)
%applyPlotEditor  Show the selected plot in the editor (items follow its kind).
E = obj.PlotEditor;
k = obj.SelectedPlot;
if k < 1 || k > numel(obj.Config.Plots)
    E.kind.Text = "";
    E.note.Text = "Add a plot (the kind box under the list).";
    obj.syncPlotEditorEnable();
    return
end
wasApplying = obj.Applying;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, wasApplying));
p = obj.Config.Plots(k);
K = EphysAnalysisConfig.plotKinds();
row = K(K.Kind == p.kind, :);
E.enabled.Value = p.enabled;
E.kind.Text = row.Label;
E.id.Value = char(p.id);
E.title.Value = char(p.title);
setItems(E.source, row.Sources{1}, p.source);
setItems(E.layout, row.Layouts{1}, pick(p.layout, row.DefaultLayout));
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
setItems(E.baselineMode, baselineModes(p), p.baseline.Mode);
E.baseFrom.Value = p.baseline.Window(1);
E.baseTo.Value = p.baseline.Window(2);
E.withRaster.Value = p.withRaster;
setItems(E.histStyle, ["bar" "line"], p.histStyle);
E.maskAfterStop.Value = p.maskAfterStop;
params = string.empty(1, 0);
if ~isempty(obj.Runner) && obj.ActiveIdx >= 1
    try src = obj.Runner.source(obj.ActiveIdx); params = src.paramNames; catch; end
end
setItems(E.param, ["" params], p.param);
setItems(E.seriesParam, ["" params], p.seriesParam);
E.value.Value = char(p.value);
E.order.Value = char(p.order);
s = p.style;
E.maxTiles.Value = s.MaxTiles;
E.fontSize.Value = s.FontSize;
E.showSEM.Value = s.ShowSEM;
E.showStop.Value = s.ShowStop;
E.legend.Value = s.Legend;
E.grid.Value = s.Grid;
E.ylim.Value = listText(s.YLim);
setItems(E.heatColormap, string(E.heatColormap.Items), s.HeatColormap);
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
obj.syncPlotEditorEnable();
end


function v = pick(v, default)
if v == ""; v = default; end
end


function m = baselineModes(p)
switch p.kind
    case {"psth" "raster" "heatmap"}
        m = ["none" "subtract" "zscore" "percent"];
        if ismember(p.source, EphysAnalysisConfig.SignalSources); m = ["none" "subtract"]; end
    case {"rate" "tuning"}
        m = ["none" "subtract" "ratio" "zscore"];
    case "evoked"
        m = ["none" "subtract"];
    otherwise
        m = "none";
end
end


function t = listText(v)
if isempty(v)
    t = '';
else
    t = char(strjoin(string(v), " "));
end
end


function setItems(dd, items, v)
items = reshape(string(items), 1, []);
v = string(v);
if ~ismember(v, items); items = [items v]; end
dd.Items = items;
dd.Value = char(v);
end


function setApplying(obj, tf)
if isvalid(obj); obj.Applying = tf; end
end
