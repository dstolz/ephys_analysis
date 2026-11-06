function tf = formRowShown(S, k)
%formRowShown  Row K of the form section S shows for the figure (S.Shown), ignoring a collapsed group; a sub-heading shows when a row under it does.
%   TF = formRowShown(S, K) is S.Shown(K) for an ordinary row; for a
%   sub-heading (formSubheading, whose own S.Shown stays false) it is
%   whether any row under it is shown, and false for an end marker. A group
%   folded away (S.Collapsed) does not change it: the search and "Go to"
%   ask whether the figure uses the row, and open the group if it does.
%
%   See also formGroup, formLayout.
if S.Sub(k)
    [~, members] = formGroup(S, k);
    tf = any(S.Shown(members)) && S.SubTitle(k) ~= "";
else
    tf = S.Shown(k);
end
end
