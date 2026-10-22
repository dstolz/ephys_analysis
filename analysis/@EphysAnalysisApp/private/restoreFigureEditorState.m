function S = restoreFigureEditorState(obj, id, opts)
%restoreFigureEditorState  The editor as figure ID left it: its sections open or collapsed, its panel and layer.
%   S = restoreFigureEditorState(OBJ, ID) takes the state saveFigureEditorState
%   kept for figure ID: each section and supersection open or collapsed
%   as it was (FigureSections / FigureSupers.Expanded) and, unless
%   Selection=false (Undo and Redo pick the panel the edit was made in),
%   SelectedPanel and SelectedLayer (applyFigureEditor keeps them within
%   the figure's panels). Called before the editor shows the figure
%   (applyFigureEditor lays the sections out); S, the state ([] when the
%   figure has none: the editor stays as it is), goes to
%   scrollFigureEditor after, for the scroll.
%
%   See also saveFigureEditorState, scrollFigureEditor.
arguments
    obj (1,1) EphysAnalysisApp
    id (1,1) string
    opts.Selection (1,1) logical = true
end
S = [];
M = obj.FigureEditorStates;
if ~isa(M, 'containers.Map') || ~isKey(M, char(id)); return; end
S = M(char(id));
names = [obj.FigureSections.Name];
for i = 1:numel(S.Sections.Name)
    j = find(names == S.Sections.Name(i), 1);
    if ~isempty(j); obj.FigureSections(j).Expanded = S.Sections.Expanded(i); end
end
names = [obj.FigureSupers.Name];
for i = 1:numel(S.Supers.Name)
    j = find(names == S.Supers.Name(i), 1);
    if ~isempty(j); obj.FigureSupers(j).Expanded = S.Supers.Expanded(i); end
end
if opts.Selection
    obj.SelectedPanel = S.Panel;
    obj.SelectedLayer = S.Layer;
end
end
