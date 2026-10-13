function X = auxLooks(A, colors, style, opt)
%auxLooks  How the mean aux traces of A (auxMean) are drawn: colors, line styles, legend entries, y label.
%   X = auxLooks(A, COLORS, STYLE, OPT): COLORS are the plot's group colors
%   (groupPalette), STYLE the renderer's (renderStyle; its design's ground
%   picks the neutral color), OPT a plot's aux settings (defaults("Aux");
%   default: its defaults). A.mean is [nTime x nTraces x nGroups]: the
%   channels (or their magnitude, one trace) per group (one group, "all
%   epochs", when A.byGroup is false).
%     X.trace(c, g)  color, lineStyle and group (the aesthetics group,
%                    tagPart) of trace c of group g. OPT.colorBy says what
%                    the colors are:
%                    - "group": the trial selection group's color (with
%                      several channels they differ by line style: solid,
%                      dashed, dotted, dash-dot, ...); one trace over every
%                      epoch (A.byGroup false) has no group: a neutral gray
%                      (light on a dark ground)
%                    - "channel": a color per channel (orange, green,
%                      purple, ...); with several groups they differ by line
%                      style
%                    - "auto" (default): by group with several groups, or
%                      one channel; else by channel; one trace over every
%                      epoch: the neutral gray
%                    The group is the channel's label when there are
%                    several channels, else the group's label (one trace:
%                    the trace's label)
%     X.legend       label, color, lineStyle: with OPT.display "lines", one
%                    entry per channel when there are several, and, when the
%                    colors are the channels' and there are several groups,
%                    one per group, showing its line style (none otherwise:
%                    the group colors are the plot's own legend's, and the
%                    y label names a single trace)
%     X.rows         label, color, c, g of each row of a stacked or heat map
%                    display, from the top down: a channel's groups
%                    together ("AUX1 · group A")
%     X.neutral      the color of a trace that has no group
%     X.label        the y label: "AUX (V)", "AUX - baseline (V)",
%                    "|AUX| (V)" (the magnitude, or a rectified signal) or
%                    "|AUX - baseline| (V)", with "median " in front for a
%                    median
%
%   See also auxInto, auxStandIns, auxMean, renderPSTH, renderRaster.

if nargin < 4 || isempty(opt); opt = struct(); end
opt = EphysAnalysisConfig.normalizeSection("Aux", opt);
[~, nTr, nGa] = size(A.mean);
palette = [0.85 0.33 0.10; 0.47 0.67 0.19; 0.49 0.18 0.56; 0.93 0.69 0.13; 0.30 0.75 0.93; 0.64 0.08 0.18];
styles = ["-" "--" ":" "-."];
neutral = [0.25 0.25 0.25];
if isfield(style, 'Design') && numel(style.Design.background) == 3 && ...
        [0.2126 0.7152 0.0722] * reshape(double(style.Design.background), 3, 1) < 0.5
    neutral = [0.80 0.80 0.80];   % a dark ground
end
switch opt.colorBy
    case "group",   byGroup = A.byGroup;
    case "channel", byGroup = false;
    otherwise,      byGroup = A.byGroup && (nGa > 1 || nTr == 1);
end
byChannel = ~byGroup && (opt.colorBy == "channel" || nTr > 1);   % else the neutral gray
X.neutral = neutral;
X.trace = repmat(struct('color', neutral, 'lineStyle', "-", 'group', ""), nTr, nGa);
for g = 1:nGa
    for c = 1:nTr
        T = X.trace(c, g);
        if byGroup
            T.color = groupColor(A, colors, g);
            if nTr > 1; T.lineStyle = styles(mod(c - 1, numel(styles)) + 1); end
        elseif byChannel
            T.color = palette(mod(c - 1, size(palette, 1)) + 1, :);
            if nGa > 1; T.lineStyle = styles(mod(g - 1, numel(styles)) + 1); end
        elseif nGa > 1
            T.lineStyle = styles(mod(g - 1, numel(styles)) + 1);
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
if opt.display == "lines"
    if nTr > 1
        for c = 1:nTr
            col = X.trace(c, 1).color;
            if byGroup; col = neutral; end   % the colors are the groups'; the entry shows the line style
            X.legend(end+1) = struct('label', A.labels(c), 'color', col, 'lineStyle', X.trace(c, 1).lineStyle);
        end
    end
    if ~byGroup && nGa > 1   % the plot's legend shows the groups' colors: here they are line styles
        for g = 1:nGa
            X.legend(end+1) = struct('label', A.groups.label(g), 'color', neutral, 'lineStyle', X.trace(1, g).lineStyle);
        end
    end
end
X.rows = struct('label', {}, 'color', {}, 'c', {}, 'g', {});
for c = 1:nTr
    for g = 1:nGa
        if nTr > 1 && nGa > 1
            lab = A.labels(c) + " · " + A.groups.label(g);
        elseif nTr > 1
            lab = A.labels(c);
        elseif nGa > 1
            lab = A.groups.label(g);
        else
            lab = A.labels(1);
        end
        X.rows(end+1) = struct('label', string(lab), 'color', X.trace(c, g).color, 'c', c, 'g', g);
    end
end
what = "AUX";
if isfield(A, 'params') && isfield(A.params, 'Baseline') && numel(A.params.Baseline) == 2
    what = what + " - baseline";
end
if A.mode == "magnitude" || (isfield(A, 'rectified') && A.rectified); what = "|" + what + "|"; end
X.label = what + " (" + A.units + ")";
if isfield(A, 'statistic') && A.statistic == "median"; X.label = "median " + X.label; end
end


function c = groupColor(A, colors, g)
%groupColor  Group G's color: the plot's (COLORS, its groups are A's), else A's own.
if g <= size(colors, 1)
    c = colors(g, :);
else
    c = A.groups.color(g, :);
end
end
