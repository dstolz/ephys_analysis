function [S, r] = formRow(S, keys, label, height)
%formRow  Add a row to a form section: its label and the keys that show it.
%   [S, R] = formRow(S, KEYS, LABEL) adds a row to the body of the section S
%   (formSection) with LABEL in column 1 ("" = no label: the row's control
%   can span both columns). KEYS name what the row holds (the editor's
%   fields), for formShow. HEIGHT is the row's height (default 22 px).
%   Place the row's controls in row R of S.Body; formLayout finds them
%   there. R is the body's grid row, not the row's number: the body's rows
%   take turns, a form row and then the gap under it (S.Gap px), so the
%   K-th row is in grid row 2K - 1 (formLayout gives a hidden row and its
%   gap no height instead of moving the rows below it).
%
%   See also formSection, formShow, formLayout.
arguments
    S (1,1) struct
    keys (1,:) string
    label (1,1) string
    height (1,1) double = 22
end
k = numel(S.Heights) + 1;
r = 2 * k - 1;
S.Keys{k} = keys;
S.Heights(k) = height;
S.Shown(k) = true;
S.Items{k} = gobjects(1, 0);
S.Body.RowHeight = num2cell(reshape([S.Heights; repmat(S.Gap, 1, k)], 1, []));
if label ~= ""
    l = uilabel(S.Body, "Text", label);
    l.Layout.Row = r;
    l.Layout.Column = 1;
end
end
