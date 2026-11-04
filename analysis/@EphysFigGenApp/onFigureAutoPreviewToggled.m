function onFigureAutoPreviewToggled(obj)
%onFigureAutoPreviewToggled  The Figures tab's Auto box: on, the figure is drawn now; kept as a preference (FigureAutoPreview).
if obj.FigureAutoCheckBox.Value
    obj.FigurePreviewSeconds = 0;
    obj.autoFigurePreview();
    obj.setStatus("Auto-preview on: every edit redraws the observation picked.");
else
    obj.setStatus("Auto-preview off: press Preview after editing.");
end
obj.savePreferences();
end
