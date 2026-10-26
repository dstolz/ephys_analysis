function s = latencySummary(L, kind)
%latencySummary  A raster's first-spike marks or a PSTH's latency box plot in a few words, for the Options row beside its button.
%   S = latencySummary(L, KIND) for L, a panel's options.firstSpike (KIND
%   "firstSpike", defaults("FirstSpike")) or options.latencyBox (KIND
%   "latencyBox", defaults("LatencyBox")): "off", or "on" and the look:
%   the marker as a glyph (filled or open) and its color ("on, ○ groups"),
%   or the box's color and line style ("on, groups --"). How the latency
%   is found is the figure's (its latency block). The status line of an OK
%   in the window (latencyDialog) says it too.
%
%   See also latencyDialog, applyFigureEditor.
arguments
    L (1,1) struct
    kind (1,1) string
end
if ~L.enabled
    s = "off";
    return
end
if kind == "firstSpike"
    s = "on, " + glyph(L.marker, L.filled) + " " + string(L.color);
else
    s = "on, " + string(L.color);
    if L.lineStyle ~= "-"; s = s + " " + L.lineStyle; end
end
end


function g = glyph(marker, filled)
%glyph  A marker as one character, filled or open where the marker has both.
names = ["o" "square" "diamond" "^" "v" ">" "<" "pentagram"];
open = ["○" "□" "◇" "△" "▽" "▷" "◁" "☆"];
full = ["●" "■" "◆" "▲" "▼" "▶" "◀" "★"];
k = find(names == marker, 1);
if ~isempty(k)
    g = open(k);
    if filled; g = full(k); end
    return
end
other = struct('plus', "+", 'star', "*", 'dot', "·", 'cross', "×", 'hline', "_", 'vline', "|");
key = struct('m', ["+" "*" "." "x" "_" "|"], 'f', ["plus" "star" "dot" "cross" "hline" "vline"]);
k = find(key.m == marker, 1);
g = string(marker);
if ~isempty(k); g = other.(key.f(k)); end
end
