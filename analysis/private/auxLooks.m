function X = auxLooks(A, colors, style)
%auxLooks  How the mean aux traces of A (auxMean) are drawn: colors, line styles, legend entries, y label.
%   X = auxLooks(A, COLORS, STYLE): COLORS are the plot's group colors
%   (groupPalette), STYLE the renderer's (renderStyle; its design's ground
%   picks the neutral color). A.mean is [nTime x nTraces x nGroups]: the
%   channels (or their magnitude, one trace) per group (one group, "all
%   epochs", when A.byGroup is false).
%     X.trace(c, g)  color, lineStyle and group (the aesthetics group,
%                    tagPart) of trace c of group g:
%                    - by group with several groups, or one channel: the
%                      group's color; several channels then differ by line
%                      style (solid, dashed, dotted, dash-dot, ...)
%                    - several channels and one group (or every epoch): a
%                      color per channel (orange, green, purple, ...), solid
%                    - one trace over every epoch: a neutral gray (light on
%                      a dark ground)
%                    The group is the channel's label when there are
%                    several channels, else the group's label (one trace:
%                    the trace's label)
%     X.legend       label, color, lineStyle: one entry per channel when
%                    there are several (none otherwise: the group colors
%                    are the plot's own legend's, and the y label names a
%                    single trace)
%     X.label        the y label: "AUX (V)", "AUX - baseline (V)",
%                    "|AUX| (V)" or "|AUX - baseline| (V)"
%
%   See also auxInto, auxStandIns, auxMean, renderPSTH, renderRaster.

[~, nTr, nGa] = size(A.mean);
palette = [0.85 0.33 0.10; 0.47 0.67 0.19; 0.49 0.18 0.56; 0.93 0.69 0.13; 0.30 0.75 0.93; 0.64 0.08 0.18];
styles = ["-" "--" ":" "-."];
neutral = [0.25 0.25 0.25];
if isfield(style, 'Design') && numel(style.Design.background) == 3 && ...
        [0.2126 0.7152 0.0722] * reshape(double(style.Design.background), 3, 1) < 0.5
    neutral = [0.80 0.80 0.80];   % a dark ground
end
groupColored = A.byGroup && (nGa > 1 || nTr == 1);   % else a color per channel, or the neutral one
X.trace = repmat(struct('color', neutral, 'lineStyle', "-", 'group', ""), nTr, nGa);
for g = 1:nGa
    for c = 1:nTr
        T = X.trace(c, g);
        if groupColored
            T.color = groupColor(A, colors, g);
            if nTr > 1; T.lineStyle = styles(mod(c - 1, numel(styles)) + 1); end
        elseif nTr > 1
            T.color = palette(mod(c - 1, size(palette, 1)) + 1, :);
        end
        if nTr > 1
            T.group = A.labels(c);
        elseif nGa > 1
            T.group = A.groups.label(g);
        else
            T.group = A.labels(1);
        end
        X.trace(c, g) = T;
    end
end
X.legend = struct('label', {}, 'color', {}, 'lineStyle', {});
if nTr > 1
    for c = 1:nTr
        col = X.trace(c, 1).color;
        if groupColored; col = neutral; end   % the colors are the groups'; the entry shows the line style
        X.legend(end+1) = struct('label', A.labels(c), 'color', col, 'lineStyle', X.trace(c, 1).lineStyle);
    end
end
what = "AUX";
if isfield(A, 'params') && isfield(A.params, 'Baseline') && numel(A.params.Baseline) == 2
    what = what + " - baseline";
end
if A.mode == "magnitude"; what = "|" + what + "|"; end
X.label = what + " (" + A.units + ")";
end


function c = groupColor(A, colors, g)
%groupColor  Group G's color: the plot's (COLORS, its groups are A's), else A's own.
if g <= size(colors, 1)
    c = colors(g, :);
else
    c = A.groups.color(g, :);
end
end
