function [S, r] = formRow(S, keys, label, height)
%formRow  Add a row to a form section: its label and the keys that show it.
%   [S, R] = formRow(S, KEYS, LABEL) adds row R to the body of the section S
%   (formSection) with LABEL in column 1 ("" = no label: the row's control
%   can span both columns). KEYS name what the row holds (the editor's
%   fields), for formShow. HEIGHT is the row's height (default 22 px).
%   Place the row's controls in row R of S.Body; formLayout finds them
%   there.
%
%   See also formSection, formShow, formLayout.
arguments
    S (1,1) struct
    keys (1,:) string
    label (1,1) string
    height (1,1) double = 22
end
r = numel(S.Heights) + 1;
S.Keys{r} = keys;
S.Heights(r) = height;
S.Shown(r) = true;
S.Items{r} = gobjects(1, 0);
S.Body.RowHeight = num2cell(S.Heights);
if label ~= ""
    l = uilabel(S.Body, "Text", label);
    l.Layout.Row = r;
    l.Layout.Column = 1;
end
end
