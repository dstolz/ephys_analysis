function refreshEpochDiagram(obj)
%refreshEpochDiagram  Redraw the epoch diagram (onShowEpochs) for what it shows, if it is open.
%   "plot": the plot in the editor (Config.plotFor), cut as computePlot
%   calls epochTable. A behavior plot keeps every epoch. The other kinds
%   drop the incomplete ones and those that touch an artifact period, and
%   test their baseline window too when they have a baseline. "defaults":
%   the Alignment tab's event, window and selection, as its epoch count.
%   A plot that aligns to nothing (probe map, unit waveforms) says so.
%   "figure": the figure in the Figures tab's editor (Config.figureFor),
%   its own alignment or the defaults, cut as computeFigure cuts the
%   figure's epochs: the incomplete ones and those that touch an artifact
%   period dropped, the baseline windows of its panels on its alignment
%   tested too (their hull). A figure without an aligned panel says so.
d = obj.EpochDiagramWindow;
if isempty(d) || ~isvalid(d) || ~d.isOpen(); return; end
if isempty(obj.Runner) || obj.ActiveIdx < 1
    d.clear("Scan and pick a dataset to see how its epochs are cut.");
    return
end
try
    src = obj.Runner.source(obj.ActiveIdx);
catch ME
    d.clear("Cannot read " + obj.Runner.Names(obj.ActiveIdx) + ": " + string(ME.message));
    return
end
if obj.EpochDiagramFor == "defaults"
    D = obj.Config.Defaults;
    d.update(src, D.EventRef, D.Window, D.Selection, Title="Defaults (Alignment tab) on " + src.name);
    return
end
if obj.EpochDiagramFor == "figure"
    figureEpochs(obj, d, src);
    return
end
k = obj.SelectedPlot;
if k < 1 || k > numel(obj.Config.Plots)
    d.clear("Add or pick a plot to see how its epochs are cut.");
    return
end
spec = obj.Config.plotFor(k);
K = EphysAnalysisConfig.plotKinds();
row = K(K.Kind == spec.kind, :);
if ~row.Aligned
    d.clear(spec.id + " (" + row.Label + ") aligns to no event, so it has no epochs.");
    return
end
p = obj.Config.Plots(k);
own = [isstruct(p.ref) isstruct(p.window) isstruct(p.selection)];
parts = ["event" "window" "selection"];
if ~any(own)
    how = "the defaults";
elseif all(own)
    how = "its own event, window and selection";
else
    how = "its own " + strjoin(parts(own), " and ") + ", the default " + strjoin(parts(~own), " and ");
end
b = [];
incomplete = "drop";
artifacts = "drop";
if spec.kind == "behavior"
    incomplete = "keep";
    artifacts = "keep";
elseif spec.baseline.Mode ~= "none"
    b = spec.baseline.Window;
end
d.update(src, spec.ref, spec.window, spec.selection, Baseline=b, Incomplete=incomplete, Artifacts=artifacts, ...
    Title=spec.id + " on " + src.name + " (" + how + ")");
end


function figureEpochs(obj, d, src)
%figureEpochs  The figure in the Figures tab's editor: its resolved event, window and selection, cut as computeFigure cuts them.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    d.clear("Add or pick a figure to see how its epochs are cut.");
    return
end
spec = obj.Config.figureFor(k);
PT = EphysAnalysisConfig.panelTypes();
aligned = false(1, numel(spec.panels));
behavior = false(1, numel(spec.panels));
b = [];
for j = 1:numel(spec.panels)
    p = spec.panels(j);
    row = PT.Type == p.type;
    aligned(j) = any(row) && PT.Aligned(row);
    behavior(j) = p.type == "behavior";
    if ~p.sharesTime || behavior(j) || ~isfield(p.options, 'baseline') || p.options.baseline.Mode == "none"; continue; end
    w = p.options.baseline.Window;
    if isempty(b); b = w; else; b = [min(b(1), w(1)) max(b(2), w(2))]; end
end
if ~any(aligned)
    d.clear(spec.id + " has no panel aligned to events, so it has no epochs.");
    return
end
fig = obj.Config.Figures(k);
own = [isstruct(fig.ref) isstruct(fig.window) isstruct(fig.selection)];
parts = ["event" "window" "selection"];
if ~any(own)
    how = "the defaults";
elseif all(own)
    how = "its own event, window and selection";
else
    how = "its own " + strjoin(parts(own), " and ") + ", the default " + strjoin(parts(~own), " and ");
end
keep = "drop";
if all(behavior(aligned)); keep = "keep"; b = []; end
d.update(src, spec.ref, spec.window, spec.selection, Baseline=b, Incomplete=keep, Artifacts=keep, ...
    Title=spec.id + " on " + src.name + " (" + how + ")");
end
