function h = memberLines(ax, x, M, R, colors, style, labels)
%memberLines  Each member session of a merged result (R.members) as a thin pale line, under its series' summary.
%   H = memberLines(AX, X, M, R, COLORS, STYLE, LABELS) draws M [nX x
%   nMembers] (the members' values on one panel, tile or channel, offset as
%   the caller draws its series) against X into AX, member s in the pale
%   color (paleColor 0.55) of its series R.members.series(s) (COLORS: one
%   row per series), 0.6 x Style.LineWidth wide, in its series' line style
%   (groupLineStyles: "combine" tells the trial groups apart), no marker,
%   out of the legend. Tagged "memberLine" with its series' label: LABELS
%   (default R.groups.label; a tuning curve passes R.series). H: the
%   lines. Shared by renderPSTH, renderEvoked, renderTuning and the
%   figures' PSTH, continuous and tuning panels.
%
%   See also combineSessions, groupLineStyles, paleColor.

if nargin < 7 || isempty(labels); labels = string(R.groups.label); end
labels = string(labels);
ls = groupLineStyles(R);
h = gobjects(1, size(M, 2));
for s = 1:size(M, 2)
    g = R.members.series(s);
    h(s) = tagPart(plot(ax, x, M(:, s), 'Color', paleColor(colors(g, :), 0.55, style), 'LineWidth', 0.6 * style.LineWidth, ...
        'LineStyle', ls(g), 'Marker', 'none', 'HandleVisibility', 'off'), "memberLine", labels(g));
end
end
