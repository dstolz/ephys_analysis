function [hs, yTop] = drawSigBrackets(ax, pairs, xOf, yBase, step, style, color, opts)
%drawSigBrackets  Brackets over pairs of levels, each with its stars, stacked so no two on one level overlap.
%   [HS, YTOP] = drawSigBrackets(AX, PAIRS, XOF, YBASE, STEP, STYLE, COLOR, Name=Value)
%   draws one bracket per row of PAIRS (a table: label, the components'
%   group, "a vs b"; stars, test, p, pAdj, n1, n2: trialStats' pairs) from
%   XOF(i, 1) to XOF(i, 2) (x in data units). The brackets are placed by
%   interval scheduling: the shortest span first, each on the lowest level
%   where it overlaps no bracket already there (brackets that only share
%   an end may share a level: each end is drawn a little inside its x),
%   level L at YBASE + L x STEP (Log=true: a log axis,
%   YBASE x STEP^L, STEP a factor over 1). A bracket is a line down at
%   both ends ([xa xa xb xb], role "sigBracket") with its stars over its
%   middle (role "sigText"; "n.s." a point smaller), both in COLOR ([1 x
%   3], or a row per pair), both tagged with the pair's label and carrying
%   appdata SigPair (test, p, pAdj, adjust, n1, n2, label, stars), which
%   their data tips read. HS: the objects drawn. YTOP: the top of the
%   highest level's stars, for the caller's y limits (YBASE when PAIRS is
%   empty).
%
%   Options
%     Log      false (default) | true: the y axis is logarithmic
%     Adjust   the adjustment the pairs' pAdj took (pAdjust's method;
%              default "holm"), named in the tips
%
%   See also drawTrialDistPanel, trialStats, statText.

arguments
    ax
    pairs table
    xOf (:,2) double
    yBase (1,1) double
    step (1,1) double
    style (1,1) struct
    color double
    opts.Log (1,1) logical = false
    opts.Adjust (1,1) string = "holm"
end
hs = gobjects(1, 0);
yTop = yBase;
n = height(pairs);
if n == 0; return; end
xa = min(xOf, [], 2);
xb = max(xOf, [], 2);
span = xb - xa;
pos = span(span > 0);
d = 0;   % each end moved in a little, so brackets sharing an end stay apart
if ~isempty(pos); d = 0.04 * min(pos); end
tol = 1e-9;
lev = zeros(n, 1);
placed = false(n, 1);
[~, order] = sort(span);
for i = reshape(order, 1, [])
    L = 0;
    while true
        there = placed & lev == L;
        if ~any(there & xa < xb(i) - tol & xb > xa(i) + tol); break; end
        L = L + 1;
    end
    lev(i) = L;
    placed(i) = true;
end
if opts.Log
    at = @(L) yBase * step .^ L;
else
    at = @(L) yBase + step * L;
end
if size(color, 1) == 1; color = repmat(color, n, 1); end
fs = max(6, style.FontSize - 1);
lw = max(0.5, 0.75 * style.LineWidth);
for i = 1:n
    y = at(lev(i));
    y0 = at(lev(i) - 0.3);
    c = color(i, :);
    g = string(pairs.label(i));
    st = string(pairs.stars(i));
    if st == ""; st = "n.s."; end
    pair = struct('test', string(pairs.test(i)), 'p', pairs.p(i), 'pAdj', pairs.pAdj(i), 'adjust', opts.Adjust, ...
        'n1', pairs.n1(i), 'n2', pairs.n2(i), 'label', g, 'stars', st);
    ln = tagPart(line(ax, [xa(i) + d, xa(i) + d, xb(i) - d, xb(i) - d], [y0 y y y0], 'Color', c, 'LineWidth', lw, ...
        'HandleVisibility', 'off'), "sigBracket", g);
    tx = tagPart(text(ax, (xa(i) + xb(i)) / 2, y, st, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', fs - (st == "n.s."), 'Color', c, 'Interpreter', 'none', 'Clipping', 'on'), "sigText", g);
    setappdata(ln, 'SigPair', pair);
    setappdata(tx, 'SigPair', pair);
    hs = [hs ln tx]; %#ok<AGROW>
end
yTop = at(max(lev) + 1);
end
