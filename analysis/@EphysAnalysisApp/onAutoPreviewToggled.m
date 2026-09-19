function onAutoPreviewToggled(obj)
%onAutoPreviewToggled  Auto-preview on: draw now.
if obj.AutoPreviewCheckBox.Value
    obj.PreviewSeconds = 0;
    obj.autoPreview();
end
obj.savePreferences();
end
