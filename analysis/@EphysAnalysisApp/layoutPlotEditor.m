function layoutPlotEditor(obj)
%layoutPlotEditor  Pack the plot editor's shown sections to the top and size them.
%   Each section packs its shown rows and takes its height (formLayout):
%   the header alone when collapsed, none when hidden. The sections shown
%   take the editor's first rows, the hidden ones zero-height rows below
%   them, and a last row the space left (the editor scrolls when they need
%   more). syncPlotEditor decides what shows; onPlotSectionToggled what is
%   collapsed.
S = obj.PlotSections;
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
obj.PlotEditorGrid.RowHeight = [num2cell([h(on) zeros(1, nnz(~on))]) {'1x'}];
obj.PlotSections = S;
end
