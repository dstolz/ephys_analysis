function onFigureCheck(obj, how)
%onFigureCheck  A button above the figure tree: tick or untick every figure (setFiguresEnabled).
%   HOW: "all" (enable them all), "none" (disable them all) or "invert".
n = numel(obj.Config.Figures);
if n == 0; return; end
switch how
    case "all"
        obj.setFiguresEnabled(1:n, "on");
    case "none"
        obj.setFiguresEnabled(1:n, "off");
    case "invert"
        obj.setFiguresEnabled(1:n, "toggle");
    otherwise
        error('EphysAnalysisApp:BadCheck', 'Unknown check action "%s".', how);
end
end
