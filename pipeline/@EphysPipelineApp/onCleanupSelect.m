function onCleanupSelect(obj, how)
%onCleanupSelect  Tick or untick the Remove files shown in the Clean up table.
%   HOW is "all" (tick the Remove rows shown), "none" (untick the rows
%   shown), "only" (tick the Remove rows shown, untick every hidden row) or
%   "invert" (flip the Remove rows shown). Keep rows are never ticked.
arguments
    obj
    how (1,1) string {mustBeMember(how, ["all" "none" "only" "invert"])}
end
T = obj.CleanupPlan;
if isempty(T); return; end
vis = obj.CleanupRowMap;
rm = T.Action == "remove";
shown = false(height(T), 1);
shown(vis) = true;
switch how
    case "all";    T.Include(shown & rm) = true;
    case "none";   T.Include(shown) = false;
    case "only";   T.Include = shown & rm;
    case "invert"; T.Include(shown & rm) = ~T.Include(shown & rm);
end
obj.CleanupPlan = T;
obj.refreshCleanupTable();
end
