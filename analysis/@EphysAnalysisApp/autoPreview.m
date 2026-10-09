function autoPreview(obj)
%autoPreview  Redraw the preview when the Plots tab shows, Auto is on and the last one was quick.
%   Called after an edit to the plot or the defaults; when it does not
%   redraw, a drawn preview is marked out of date (setPreviewState "stale").
if isempty(obj.Tabs) || obj.Tabs.SelectedTab ~= obj.TabPlots ...
        || ~obj.AutoPreviewCheckBox.Value || obj.PreviewSeconds >= obj.AutoPreviewSeconds
    if obj.PreviewState == "drawn"; obj.setPreviewState("stale"); end
    return
end
obj.refreshPreview();
end
