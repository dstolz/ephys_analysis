function p = gatherPlotEditor(obj)
%gatherPlotEditor  The selected plot as the editor shows it (normalized).
%   Fields the editor has no control for keep their values. With a "Default
%   ..." box ticked the plot's ref / window / selection is "default";
%   untick it to take the values in the controls below.
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
ch = parseList(E.channels.Value);
if ismember(p.source, EphysAnalysisConfig.SignalSources)
    p.channels = ch;
else
    p.units.channels = ch;
end
p.units.shanks = parseList(E.shanks.Value);
p.bins.BinSec = E.binMs.Value / 1000;
p.bins.SmoothSec = E.smoothMs.Value / 1000;
p.baseline.Mode = string(E.baselineMode.Value);
p.baseline.Window = [E.baseFrom.Value E.baseTo.Value];
p.withRaster = E.withRaster.Value;
p.histStyle = string(E.histStyle.Value);
p.maskAfterStop = E.maskAfterStop.Value;
p.param = strtrim(string(E.param.Value));
p.seriesParam = strtrim(string(E.seriesParam.Value));
p.value = string(E.value.Value);
p.order = string(E.order.Value);
p.metric = string(E.metric.Value);
p.correlation = string(E.correlation.Value);
p.style.MaxTiles = E.maxTiles.Value;
p.style.FontSize = E.fontSize.Value;
p.style.ShowSEM = E.showSEM.Value;
p.style.ShowStop = E.showStop.Value;
p.style.Legend = E.legend.Value;
p.style.Grid = E.grid.Value;
yl = parseList(E.ylim.Value);
if numel(yl) ~= 2; yl = []; end
p.style.YLim = yl;
p.style.HeatColormap = string(E.heatColormap.Value);
if p.style.HeatColormap == "auto"; p.style.HeatColormap = ""; end
[ref, win, sel] = obj.gatherAlignControls(obj.PlotAlignControls);
if E.defaultRef.Value; p.ref = "default"; else; p.ref = ref; end
if E.defaultWindow.Value; p.window = "default"; else; p.window = win; end
if E.defaultSelection.Value; p.selection = "default"; else; p.selection = sel; end
p = EphysAnalysisConfig.normalizePlot(p);
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
