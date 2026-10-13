function autoSessionPreview(obj)
%autoSessionPreview  Redraw the session preview when the Sessions tab shows, its Auto is on and the last one was quick.
%   Called after an edit to the session plot, its base plot, the defaults
%   or the ticks (onConfigChanged); when it does not redraw, a drawn
%   preview is marked out of date (setSessionPreviewState "stale"). Auto is
%   off by default (preference SessionAutoPreview): a session preview reads
%   every dataset.
if isempty(obj.Tabs) || obj.Tabs.SelectedTab ~= obj.TabSessions ...
        || ~obj.SessionAutoCheckBox.Value || obj.SessionPreviewSeconds >= obj.AutoPreviewSeconds
    if obj.SessionPreviewState == "drawn"; obj.setSessionPreviewState("stale"); end
    return
end
obj.refreshSessionPreview();
end
