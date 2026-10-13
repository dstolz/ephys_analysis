function S = formStack(S, grid)
%formStack  Pack a column of form sections to the top of GRID and size them.
%   S = formStack(S, GRID): each section packs its shown rows and takes
%   its height (formLayout): the header alone when collapsed, none when
%   hidden. The sections shown take GRID's first rows, the hidden ones
%   zero-height rows below them, and a last row the space left (GRID
%   scrolls when they need more).
%
%   See also formSection, formLayout.
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
grid.RowHeight = [num2cell([h(on) zeros(1, nnz(~on))]) {'1x'}];
end
