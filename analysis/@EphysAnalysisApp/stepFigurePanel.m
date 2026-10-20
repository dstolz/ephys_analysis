function stepFigurePanel(obj, how)
%stepFigurePanel  Select another panel of the selected figure: the next or previous one, or the one above, below, left or right.
%   HOW is "next" or "previous" (the figure's panel order, round at the
%   ends: Ctrl+] and Ctrl+[) or "up", "down", "left" or "right" (the grid:
%   Ctrl+Alt+arrows). A spatial step goes to the nearest panel wholly on
%   that side whose rows (for left and right) or columns (for up and down)
%   overlap the selected panel's, the one overlapping most when several
%   are as near, then the one nearest in line with it; with none there the
%   selection stays and the status bar says so. The panel is selected as a
%   click on it in the schematic selects it (onPanelSelected): the editor
%   shows it and the preview outlines it (markFigurePanel), with nothing
%   computed or drawn again.
arguments
    obj (1,1) EphysAnalysisApp
    how (1,1) string {mustBeMember(how, ["next" "previous" "up" "down" "left" "right"])}
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("No figure is selected: add one, or pick one in the list.");
    return
end
P = obj.Config.Figures(k).panels;
np = numel(P);
if np == 0
    obj.setStatus("The figure has no panel yet.");
    return
end
j = min(max(obj.SelectedPanel, 1), np);
if ismember(how, ["next" "previous"])
    q = mod(j - 1 + 1 - 2 * (how == "previous"), np) + 1;
    obj.onPanelSelected(q);
    obj.setStatus(sprintf("Selected %s (panel %d of %d).", P(q).id, q, np));
    return
end
r = [P.row];
c = [P.col];
r2 = r + [P.rowSpan] - 1;
c2 = c + [P.colSpan] - 1;
switch how
    case "up",    side = r2 < r(j);  gap = r(j) - r2;  over = overlap(c, c2, c(j), c2(j));  line = abs((c + c2) - (c(j) + c2(j)));
    case "down",  side = r > r2(j);  gap = r - r2(j);  over = overlap(c, c2, c(j), c2(j));  line = abs((c + c2) - (c(j) + c2(j)));
    case "left",  side = c2 < c(j);  gap = c(j) - c2;  over = overlap(r, r2, r(j), r2(j));  line = abs((r + r2) - (r(j) + r2(j)));
    otherwise,    side = c > c2(j);  gap = c - c2(j);  over = overlap(r, r2, r(j), r2(j));  line = abs((r + r2) - (r(j) + r2(j)));
end
cand = find(side & over > 0);
if isempty(cand)
    obj.setStatus("No panel " + ternary(ismember(how, ["up" "down"]), ternary(how == "up", "above", "below"), ...
        "to the " + how + " of") + " " + P(j).id + ".");
    return
end
[~, best] = sortrows([gap(cand).' -over(cand).' line(cand).' cand.']);
q = cand(best(1));
obj.onPanelSelected(q);
end


function n = overlap(a1, a2, b1, b2)
%overlap  How many rows (columns) each span [A1, A2] shares with [B1, B2].
n = max(0, min(a2, b2) - max(a1, b1) + 1);
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
