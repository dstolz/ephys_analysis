function [fig, target, how] = placeTarget(fig, where, anchorId, rect, what)
%placeTarget  Where on a figure's page something new goes: placePanel's and placeBlock's one rule.
%   [FIG, TARGET, HOW] = placeTarget(FIG, WHERE, ANCHORID, RECT, WHAT)
%   is the rect ([x y width height], 0-1 of the page) a new panel (or a
%   block of panels) takes on figure FIG, and FIG with its anchor panel
%   made room in:
%     a figure without panels   the whole page, [0 0 1 1], whatever WHERE
%     "free"    the largest empty rectangle of the page (freeRect); when
%               there is none, "below" the anchor ANCHORID, and with no
%               anchor EphysAnalysisConfig:NoRoom
%     "below" / "above" / "left" / "right"
%               the anchor's rect cut in two flush halves (splitRect): the
%               anchor keeps the half next to the side, TARGET is the half
%               on it
%     "rect"    RECT, clipped to the page ([0 1] each way)
%   HOW is the way taken: "page", "free", "below", "above", "left",
%   "right" or "rect" (a "free" without room that fell back says
%   "below"). WHAT ("the panel", "the panels") words the errors.
%
%   Errors: EphysAnalysisConfig:NoPanel (no anchor given, or no such
%   panel), EphysAnalysisConfig:NoRoom ("free" without free space or an
%   anchor), EphysAnalysisConfig:BadRect ("rect": not 4 finite numbers,
%   or no width or height left inside the page).
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.placeBlock,
%   EphysAnalysisConfig.freeRect, splitRect.

if isempty(fig.panels)
    target = [0 0 1 1];
    how = "page";
    return
end
how = where;
if where == "rect"
    r = double(rect);
    if ~(numel(r) == 4 && all(isfinite(r)))
        error('EphysAnalysisConfig:BadRect', 'Give the rect for %s as [x y width height], 0-1 of the page.', what);
    end
    lo = max(0, min(1, [r(1) r(2)]));
    hi = max(0, min(1, [r(1) + r(3), r(2) + r(4)]));
    if ~all(hi - lo > 0)
        error('EphysAnalysisConfig:BadRect', 'The rect [%s] leaves %s no width or height on the page.', ...
            strjoin(compose("%g", r(:).'), " "), what);
    end
    target = [lo, hi - lo];
    return
end
if where == "free"
    target = EphysAnalysisConfig.freeRect(fig);
    if ~isempty(target); return; end
    if anchorId == ""
        error('EphysAnalysisConfig:NoRoom', 'The page has no free space for %s: give a panel to place it beside, or a rect.', what);
    end
    where = "below";
    how = "below";
end
a = find([fig.panels.id] == anchorId, 1);
if isempty(a)
    if anchorId == ""
        error('EphysAnalysisConfig:NoPanel', 'Place %s %s one of the figure''s panels: give its id.', what, where);
    end
    error('EphysAnalysisConfig:NoPanel', 'The figure has no panel "%s".', anchorId);
end
[near, target] = splitRect(fig.panels(a).rect, where);
fig.panels(a).rect = near;
end
