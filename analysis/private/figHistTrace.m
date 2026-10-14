function hMain = figHistTrace(ax, t, e, m, base, color, look, lw, group, ls)
%figHistTrace  One PSTH from BASE up: bars or a line, filled or not (a figure's PSTH panel).
%   HMAIN = figHistTrace(AX, T, E, M, BASE, COLOR, LOOK, LW, GROUP, LS)
%   draws the PSTH M [nBins] at the bin centers T and edges E. LOOK: hist
%   ("bar" | "line"), fill (true / false) and alpha (the fill's opacity).
%   The fill patches are tagged "rateFill", the line or outline "rate",
%   both with GROUP (tagPart). LS: the line's (or outline's) LineStyle
%   (default "-"). Filled: one patch per run of finite bins (FaceAlpha
%   look.alpha), bars as a staircase, a line with the area down to BASE
%   under it. Unfilled bars are the staircase outline, dropping to BASE at
%   each run's ends. Returns the object a legend shows (the bars' first
%   patch or outline; the line).
%
%   A copy of renderPSTH's local histTrace, so that no existing renderer
%   changes in phase 1 of the modular figures; phase 2 consolidates the two
%   into one shared helper.
%
%   See also drawPsthPanel, renderPSTH.
if nargin < 10; ls = "-"; end
t = t(:); e = e(:); m = m(:);
ok = isfinite(m);
d = diff([false; ok; false]);
starts = find(d == 1);
stops = find(d == -1) - 1;
hMain = gobjects(0);
ox = zeros(0, 1); oy = zeros(0, 1);
for k = 1:numel(starts)
    r = (starts(k):stops(k)).';
    if look.hist == "bar"
        x = [e(r(1)); reshape([e(r) e(r + 1)].', [], 1); e(r(end) + 1)];
        y = [0; reshape([m(r) m(r)].', [], 1); 0] + base;
    else
        x = [t(r(1)); t(r); t(r(end))];
        y = [0; m(r); 0] + base;
    end
    if look.fill
        p = tagPart(patch(ax, x, y, color, 'FaceAlpha', look.alpha, 'EdgeColor', 'none'), "rateFill", group);
        if isempty(hMain) && look.hist == "bar"; hMain = p; else; p.HandleVisibility = 'off'; end
    end
    ox = [ox; x; NaN]; oy = [oy; y; NaN]; %#ok<AGROW>
end
if look.hist == "line"
    hMain = tagPart(plot(ax, t, m + base, 'Color', color, 'LineWidth', lw, 'LineStyle', ls), "rate", group);
elseif ~look.fill && ~isempty(ox)
    hMain = tagPart(line(ax, ox, oy, 'Color', color, 'LineWidth', lw, 'LineStyle', ls), "rate", group);
end
if isempty(hMain)
    hMain = tagPart(line(ax, NaN, NaN, 'Color', color, 'LineWidth', lw, 'LineStyle', ls), "rate", group);
end
end
