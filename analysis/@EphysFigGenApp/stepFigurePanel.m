function stepFigurePanel(obj, how)
%stepFigurePanel  Select another panel of the selected figure: the next or previous one, or the one above, below, left or right.
%   HOW is "next" or "previous" (the figure's panel order, round at the
%   ends: Ctrl+] and Ctrl+[) or "up", "down", "left" or "right" (the
%   page: Ctrl+Alt+arrows). A spatial step goes by the panels' rects
%   (figureNeighbors): to the nearest panel wholly on that side (touching
%   or overlapping it by no more than RectTol) whose extent across that
%   direction shares some of the selected panel's (its width for up and
%   down, its height for left and right), the one sharing most when
%   several are as near, then the one whose middle is most in line with
%   the selected panel's; with none there the selection stays and the
%   status bar says so. The panel is selected alone, as Ctrl+Click on it
%   in the preview selects it (onPanelSelected; the panels Shift+click
%   added let go): the editor
%   shows it and the preview outlines it (markFigurePanel), with nothing
%   computed or drawn again.
arguments
    obj (1,1) EphysFigGenApp
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
    selectAlone(obj, q);
    obj.setStatus(sprintf("Selected %s (panel %d of %d).", P(q).id, q, np));
    return
end
R = NaN(np, 4);   % the rects, a row each (one that is not 4 finite numbers is nobody's neighbor)
for q = 1:np
    v = double(P(q).rect);
    if numel(v) == 4 && all(isfinite(v)); R(q, :) = reshape(v, 1, 4); end
end
tol = EphysAnalysisConfig.RectTol;
N = figureNeighbors(R, tol);
x0 = R(:, 1); x1 = x0 + R(:, 3); y0 = R(:, 2); y1 = y0 + R(:, 4);
cx = (x0 + x1) / 2; cy = (y0 + y1) / 2;
switch how
    case "up",    side = y0 >= y1(j) - tol;  gap = N.gapY(j, :).';  over = N.xShare(j, :).';  line = abs(cx - cx(j));
    case "down",  side = y1 <= y0(j) + tol;  gap = N.gapY(j, :).';  over = N.xShare(j, :).';  line = abs(cx - cx(j));
    case "left",  side = x1 <= x0(j) + tol;  gap = N.gapX(j, :).';  over = N.yShare(j, :).';  line = abs(cy - cy(j));
    otherwise,    side = x0 >= x1(j) - tol;  gap = N.gapX(j, :).';  over = N.yShare(j, :).';  line = abs(cy - cy(j));
end
cand = find(side & gap > -tol & over > 0).';
if isempty(cand)
    obj.setStatus("No panel " + ternary(ismember(how, ["up" "down"]), ternary(how == "up", "above", "below"), ...
        "to the " + how + " of") + " " + P(j).id + ".");
    return
end
[~, best] = sortrows([gap(cand) -over(cand) line(cand) cand.']);
q = cand(best(1));
selectAlone(obj, q);
end


function selectAlone(obj, q)
%selectAlone  Select panel Q alone: the panels Shift+click added let go (onPanelSelected).
many = ~isempty(obj.FigurePanelExtra);
obj.FigurePanelExtra = strings(1, 0);
if q ~= obj.SelectedPanel
    obj.onPanelSelected(q);
elseif many
    obj.syncFigureEditor();   % (the rows are this panel's alone again; one outline)
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
