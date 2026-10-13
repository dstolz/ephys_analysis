function onSessionAutoPreviewToggled(obj)
%onSessionAutoPreviewToggled  The Sessions tab's Auto on: draw now. Kept as a preference (SessionAutoPreview).
if obj.SessionAutoCheckBox.Value
    obj.SessionPreviewSeconds = 0;
    obj.autoSessionPreview();
end
obj.savePreferences();
end
