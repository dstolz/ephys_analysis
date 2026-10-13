function onMoveSessionPlot(obj, step)
%onMoveSessionPlot  Move the selected session plot up (STEP -1) or down (+1) the list: runs draw them in this order.
%   It stays selected; its preview stays as it is.
k = obj.SelectedSessionPlot;
n = numel(obj.Config.SessionPlots);
j = k + step;
if k < 1 || k > n || j < 1 || j > n; return; end
cfg = obj.gatherConfig();
P = cfg.SessionPlots;
P([k j]) = P([j k]);
cfg.SessionPlots = P;
obj.SelectedSessionPlot = j;
obj.applyConfig(cfg);
end
