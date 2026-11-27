function b = figureBefore(before, after, k)
%figureBefore  The figure of BEFORE that AFTER(k) is, so an edit's changes compare a figure with itself.
%   B = figureBefore(BEFORE, AFTER, K) is BEFORE(K) when that figure
%   (the same id) is AFTER(K), or one renamed in place (its new id is in no
%   figure of BEFORE). When the step moved figures (Move up and down
%   swap two, so BEFORE(K) is the neighbor), it is the figure of BEFORE
%   with AFTER(K)'s id: moved, not edited. Apply last change
%   (onApplyToFigures, refreshEditMenu) compares this with AFTER(K).
%
%   See also onMoveFigure, onApplyToFigures, EphysAnalysisConfig.figureEditChanges.
b = before(k);
id = after(k).id;
if before(k).id == id; return; end
m = find([before.id] == id, 1);
if ~isempty(m); b = before(m); end
end
