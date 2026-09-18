function autoPreview(obj)
%autoPreview  Redraw the preview when the Plots tab shows, Auto is on and the last one was quick.
if isempty(obj.Tabs) || obj.Tabs.SelectedTab ~= obj.TabPlots; return; end
if ~obj.AutoPreviewCheckBox.Value || obj.PreviewSeconds >= obj.AutoPreviewSeconds; return; end
obj.refreshPreview();
end
