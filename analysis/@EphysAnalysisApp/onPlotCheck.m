function onPlotCheck(obj, how)
%onPlotCheck  A button above the plot tree: tick or untick plots (setPlotsEnabled).
%   HOW: "all", "none" or "invert" act on every plot; "check", "uncheck" and
%   "only" act on the plots the drop-down names (plotsOfFilter): "only" ticks
%   them and unticks the rest.
n = numel(obj.Config.Plots);
if n == 0; return; end
switch how
    case "all"
        obj.setPlotsEnabled(1:n, "on");
    case "none"
        obj.setPlotsEnabled(1:n, "off");
    case "invert"
        obj.setPlotsEnabled(1:n, "toggle");
    case "check"
        obj.setPlotsEnabled(obj.plotsOfFilter(), "on");
    case "uncheck"
        obj.setPlotsEnabled(obj.plotsOfFilter(), "off");
    case "only"
        obj.setPlotsEnabled(obj.plotsOfFilter(), "only");
    otherwise
        error('EphysAnalysisApp:BadCheck', 'Unknown check action "%s".', how);
end
end
