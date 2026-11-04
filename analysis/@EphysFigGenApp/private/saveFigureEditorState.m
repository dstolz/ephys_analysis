function saveFigureEditorState(obj)
%saveFigureEditorState  Keep the editor as the selected figure has it, to show it so again when the figure comes back.
%   Called before another figure is selected (onFigureSelected, onAddFigure,
%   onDuplicateFigure, onUndoRedo): FigureEditorStates(id) becomes a
%   struct of
%     Sections   the sections' names and whether each is open (Expanded)
%     Supers     the supersections' names and whether each is open
%     Scroll     where the editor is scrolled (its grid's viewport, as
%                scroll(grid, x, y) takes it; [] when it cannot be read)
%     Panel      the selected panel (SelectedPanel)
%     Layer      its selected layer (SelectedLayer)
%   restoreFigureEditorState and scrollFigureEditor give it back. The
%   states live while the app runs (the collapsed sections the app starts
%   with are a preference: FigureSectionsCollapsed); trackFigureIds
%   follows a renamed figure, onRemoveFigure and another config
%   (clearFigureViews) forget them.
%
%   See also restoreFigureEditorState, scrollFigureEditor.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || ~isa(obj.FigureEditorStates, 'containers.Map'); return; end
S = struct();
S.Sections = struct('Name', [obj.FigureSections.Name], 'Expanded', [obj.FigureSections.Expanded]);
S.Supers = struct('Name', [obj.FigureSupers.Name], 'Expanded', [obj.FigureSupers.Expanded]);
S.Scroll = [];
try
    S.Scroll = obj.FigureEditorGrid.ScrollableViewportLocation;   % (undocumented: what scroll(grid, x, y) takes)
catch
end
S.Panel = obj.SelectedPanel;
S.Layer = obj.SelectedLayer;
obj.FigureEditorStates(char(obj.Config.Figures(k).id)) = S;
end
