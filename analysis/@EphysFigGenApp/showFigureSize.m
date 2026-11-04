function showFigureSize(obj, z)
%showFigureSize  Show a figure's page size in the editor's Size rows.
%   showFigureSize(OBJ) shows the selected figure's size (size.source
%   "export": "Export tab size", with the Export tab's page, taller when
%   the figure's rows need it, in the figure's units; "own": the drop-down
%   shows its suggestion's label or "7 x 4.5 in" and the fields its width
%   and height). showFigureSize(OBJ, Z) shows the size struct Z (a figure's
%   size field) instead, for the figure's rows, before it is stored
%   (onFigureSizeEdited). Nothing is edited: the controls are set without
%   their callbacks.
%
%   See also onFigureSizeEdited, applyFigureEditor, figureExportSize.
arguments
    obj (1,1) EphysAnalysisApp
    z = []
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
E = obj.FigureEditor;
fig = obj.Config.Figures(k);
if isempty(z); z = fig.size; end
fig.size = z;
u = string(z.units);
w = z.width;
h = z.height;
if z.source == "own"
    label = figureSizeText(w, h, u);
else
    label = figureSizePresets().Label(1);
    v = figureSizeConvert(figureExportSize(obj.Config.Export, [], fig), "cm", u, obj.Config.Export.Dpi);
    if u == "px"
        v = round(v);
    else
        v = round(v * 1000) / 1000;
    end
    w = v(1);
    h = v(2);
end
E.sizePreset.Value = char(label);
E.sizeWidth.Value = max(w, eps);
E.sizeHeight.Value = max(h, eps);
E.sizeUnits.Value = char(u);
E.sizeLock.Value = logical(z.lock);
end
