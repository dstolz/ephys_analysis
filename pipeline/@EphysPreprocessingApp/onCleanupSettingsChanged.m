function onCleanupSettingsChanged(obj, why)
%onCleanupSettingsChanged  Drop the Clean up preview when what it was made for has changed.
%   A preview is only ever acted on as shown, so a change of the kinds to
%   remove (or of the dataset selection, see refreshCleanupScope) discards
%   it and Remove files... waits for a new Preview.
arguments
    obj
    why (1,1) string = "The kinds to remove changed"
end
if isempty(obj.CleanupPlan); return; end
obj.CleanupPlan = [];
obj.CleanupPlanKeys = string.empty(1, 0);
obj.refreshCleanupTable();
obj.CleanupSummaryLabel.Text = why + ": press Preview again.";
end
