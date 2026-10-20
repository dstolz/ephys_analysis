function showFigureId(obj)
%showFigureId  Show the selected figure's id in the editor's Id row and the editor's title: its auto box, its color.
%   An automatic id (autoId: it follows the figure's panels and data,
%   EphysAnalysisConfig.autoFigureId) is shown in gray with auto ticked;
%   an id of the user's own in black with auto unticked. applyFigureEditor
%   and onConfigChanged call it, so the Id row follows an automatic
%   rename at once.
%
%   See also EphysAnalysisConfig.autoFigureId.
E = obj.FigureEditor;
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    E.id.Value = '';
    E.idAuto.Value = false;
    return
end
f = obj.Config.Figures(k);
obj.FigureEditorPanel.Title = "Figure: " + f.id;
E.id.Value = char(f.id);
E.idAuto.Value = f.autoId;
E.id.FontColor = [0 0 0];
if f.autoId; E.id.FontColor = [0.35 0.35 0.35]; end
end
