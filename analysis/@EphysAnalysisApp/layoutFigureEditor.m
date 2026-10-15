function layoutFigureEditor(obj)
%layoutFigureEditor  Pack the figure editor's shown sections to the top and size them.
%   Each section packs its shown rows and takes its height (formLayout):
%   the header alone when collapsed, none when hidden. The sections shown
%   take the editor's first rows, the hidden ones zero-height rows below
%   them, and a last row the space left (the editor scrolls when they need
%   more). syncFigureEditor decides what shows; onFigureSectionToggled what
%   is collapsed.
S = obj.FigureSections;
n = numel(S);
h = zeros(1, n);
for i = 1:n
    [S(i), h(i)] = formLayout(S(i));
end
on = h > 0;
order = [find(on) find(~on)];
for i = 1:n
    S(order(i)).Grid.Layout.Row = i;
end
obj.FigureEditorGrid.RowHeight = [num2cell([h(on) zeros(1, nnz(~on))]) {'1x'}];
obj.FigureSections = S;
i = find([S.Name] == "arrangement", 1);
if ~isempty(i) && ~(h(i) > 0 && S(i).Expanded) && isfield(obj.FigureEditor, 'schematicPanel')
    obj.FigureEditor.schematicPanel.UserData = false;   % its axes is made afresh when it shows (drawFigureSchematic)
end
end
