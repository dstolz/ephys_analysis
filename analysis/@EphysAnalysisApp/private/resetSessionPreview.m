function resetSessionPreview(obj, msg)
%resetSessionPreview  Forget the session preview (another session plot, a new scan): an empty panel saying MSG, badge idle.
%   The next auto-preview is not held back by a slow last one.
obj.SessionPreviewResults = [];
obj.SessionPreviewIndex = 1;
obj.SessionPreviewSeconds = 0;
dd = obj.SessionGroupDropDown;
set(dd, "Items", "all", "ItemsData", 1, "Value", 1);
dd.Parent.Visible = "off";
clearSessionPanel(obj, msg);
obj.setSessionPreviewState("idle");
end
