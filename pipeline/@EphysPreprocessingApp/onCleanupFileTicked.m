function onCleanupFileTicked(obj, evt)
%onCleanupFileTicked  Include or exclude one file of the Clean up preview (Include column).
%   Only Remove rows can be ticked: a Keep row's tick is put back. The table
%   is not rebuilt, so the user's sort stays; only the totals are updated.
%   evt.Indices is the edited cell in Data, whatever the sort shows.
if isempty(obj.CleanupPlan) || evt.Indices(2) ~= 1; return; end
r = evt.Indices(1);
k = obj.CleanupRowMap(r);
if obj.CleanupPlan.Action(k) ~= "remove"
    obj.CleanupTable.Data{r, 1} = false;
    obj.setStatus("Clean up: " + obj.CleanupPlan.File(k) + " is kept (" + obj.CleanupPlan.Reason(k) + ")", "");
    return
end
obj.CleanupPlan.Include(k) = logical(evt.NewData);
color = [0.92 0.92 0.92];
if obj.CleanupPlan.Include(k); color = [0.98 0.85 0.83]; end
addStyle(obj.CleanupTable, uistyle("BackgroundColor", color), "row", r);
obj.refreshCleanupTable("summary");
end
