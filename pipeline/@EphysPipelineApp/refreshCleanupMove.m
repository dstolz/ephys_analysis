function changed = refreshCleanupMove(obj, look)
%refreshCleanupMove  Check the Move folder for the Clean up preview's files and decide what each would do (cleanupMoveTargets).
%   refreshCleanupMove(obj) (LOOK true) looks at each Remove file's place in
%   the folder of Removed files go, then decides, for the ticked ones, what
%   If a file is already there does: CleanupMove. It holds a row per plan
%   row; [] when the method is not a move, the folder is not a full path or
%   there is no preview. refreshCleanupMove(obj, false) decides again from
%   the last look without reading the disk, after a tick changed (the
%   ticks decide which datasets need a version folder). CHANGED is true
%   when CleanupMove changed, so the table must be filled again; the caller
%   does that (refreshCleanupTable).
arguments
    obj
    look (1,1) logical = true
end
old = obj.CleanupMove;
T = obj.CleanupPlan;
dest = strtrim(string(obj.CleanupDestField.Value));
if isempty(T) || string(obj.CleanupMethodDropDown.Value) ~= "move" ...
        || isempty(regexp(dest, '^([A-Za-z]:([\\/]|$)|\\\\)', 'once'))
    obj.CleanupMove = [];
else
    how = string(obj.CleanupIfExistsDropDown.Value);
    ticked = T;
    ticked.Action(~T.Include) = "keep";
    try
        if look || isempty(old)
            obj.CleanupMove = cleanupMoveTargets(T, dest, IfExists=how);   % every Remove file's place
        end
        obj.CleanupMove = cleanupMoveTargets(ticked, dest, IfExists=how, Checked=obj.CleanupMove);
    catch ME
        obj.CleanupMove = [];
        obj.setStatus("Clean up: could not check " + dest + " for the files already there: " + ME.message, "");
    end
end
changed = ~isequaln(old, obj.CleanupMove);
end
