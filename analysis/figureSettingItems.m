function T = figureSettingItems(fig)
%figureSettingItems  Every setting of a figure that copies to other figures (or into a design), one by one.
%   T = figureSettingItems(FIG), FIG a figure (a Figures entry), has one
%   row per setting, grouped under figureSettingParts' parts in the
%   editor's order (the Copy figure settings window's tree):
%     Key      unique: "<part>.<name>" ("observe.data", "style.LineWidth",
%              "arrangement.layout", "looks.2"), a panel's
%              "panel.<panel id>.<name>" ("panel.psth_1.options.yLim")
%     Part     figureSettingParts' Part
%     Groups   the tree's levels between the part and the setting (a
%              string row): an Appearance group ("Colors"), or the panel
%              ("psth_1  (PSTH)") and its group ("Axes and limits")
%     Label    name shown in the app
%     Value    FIG's value, as text
%     Scope    "figure" (Paths from the figure), "panel" (Paths from the
%              panel Index) or "looks" (the rule Index of FIG.aesthetics)
%     Index    the panel's index (Scope "panel"), the rule's (Scope
%              "looks"); else 0
%     Paths    the fields it copies, from the figure or the panel (a
%              string row): "style.FontSize", "options.yLim", "ref"
%     Generic  the setting whatever the figure: a panel's
%              "panel:<type>.<name>", every look "looks", else the Key (the
%              window remembers ticks by it)
%     Design   true when it goes into a plot design too
%              (figureLookToDesign): the group colors (but "lines"), the
%              heat colors (when set) and each remembered look
%   Observations: each field of observe. Alignment: ref, window,
%   selection. Arrangement: "layout" (the grid's rows, columns, sizes and
%   per-gap lists, with every panel: the panels are the grid's) and
%   "spacing" (the spacing and the custom gaps). Panel settings, per panel:
%   Axes and limits (box, axis sides, yLimMode, yLim, cLim, yTicks,
%   scale), Colors and lines, Display and stacks, Marks and insets (first
%   spike, latency box, waveform), Data and analysis (every other option),
%   Size and alignment (size and place in its cell, its own event
%   reference / window / selection, its note's look but not its text).
%   Appearance: the Style fields a figure draws with, grouped (Lines and
%   error bands, Colors, Text and legend, Marks, Sorting and labels; Other
%   for a field not named here), not YLim, XLim, CLim, MaxTiles,
%   TileSpacing and StackSpacing (a figure does not use them). Remembered
%   looks: each rule. Across sessions: each field (the dataset keys with
%   the datasets, the mapping file with the matching).
%
%   See also figureSettingParts, copyFigureSettings, figureLookToDesign.
arguments
    fig (1,1) struct
end
R = struct('Key', {}, 'Part', {}, 'Groups', {}, 'Label', {}, 'Value', {}, 'Scope', {}, 'Index', {}, ...
    'Paths', {}, 'Generic', {}, 'Design', {});

% Observations
for f = string(fieldnames(fig.observe)).'
    add("observe", strings(1, 0), f, word(f, observeLabels()), "figure", 0, "observe." + f, false);
end
% Alignment
add("alignment", strings(1, 0), "ref", "Event reference", "figure", 0, "ref", false);
add("alignment", strings(1, 0), "window", "Epoch window", "figure", 0, "window", false);
add("alignment", strings(1, 0), "selection", "Trial selection", "figure", 0, "selection", false);
% Arrangement
g = fig.grid;
add("arrangement", strings(1, 0), "layout", "Grid and panels (types, places, options, layers)", "figure", 0, ...
    ["grid.rows" "grid.cols" "grid.rowHeights" "grid.colWidths" "grid.rowGaps" "grid.colGaps" "panels"], false, ...
    sprintf('%d x %d: %s', g.rows, g.cols, panelList(fig.panels)));
add("arrangement", strings(1, 0), "spacing", "Spacing between panels", "figure", 0, ...
    ["grid.spacing" "grid.gapUnits" "grid.rowGap" "grid.colGap"], false, spacingText(g));
% Panel settings
types = EphysAnalysisConfig.panelTypes();
for j = 1:numel(fig.panels)
    p = fig.panels(j);
    tl = types.Label(types.Type == p.type);
    if isempty(tl); tl = p.type; end
    head = p.id + "  (" + tl + ")";
    pa = @(group, name, label, paths, value) add("panel", [head group], name, label, "panel", j, paths, false, value);
    pa("Axes and limits", "box", "Box", "box", p.box);
    pa("Axes and limits", "sides", "Axis sides", ["xSide" "ySide"], p.xSide + ", " + p.ySide);
    for f = string(fieldnames(p.options)).'
        pa(optionGroup(f), "options." + f, word(f, optionLabels()), "options." + f, p.options.(f));
    end
    pa("Size and alignment", "size", "Size and place in its cell", ["size" "align" "valign"], ...
        sprintf('%g x %g, %s, %s', p.size(1), p.size(end), p.align, p.valign));
    pa("Size and alignment", "alignment", "Its own alignment (event, window, selection)", ["ref" "window" "selection"], ...
        alignText(p));
    nf = setdiff(string(fieldnames(p.note)).', "text", 'stable');
    pa("Size and alignment", "note", "Its note's look (not the text)", "note." + nf, p.note.placement);
end
% Appearance
unused = ["YLim" "XLim" "CLim" "MaxTiles" "TileSpacing" "StackSpacing"];   % a figure's limits, tiles and stacks are its panels' and grid's
S = styleGroups();
for f = setdiff(string(fieldnames(fig.style)).', unused, 'stable')
    grp = "Other";
    for s = 1:size(S, 1)
        if ismember(f, S{s, 2}); grp = S{s, 1}; break; end
    end
    v = fig.style.(f);
    design = (f == "Colormap" && ~strcmpi(string(v), "lines")) || (f == "HeatColormap" && string(v) ~= "");
    add("style", grp, f, word(f, styleLabels()), "figure", 0, "style." + f, design);
end
% Remembered looks
A = fig.aesthetics;
for r = 1:numel(A)
    label = PlotAesthetics.roleLabel(A(r).role) + ": " + A(r).property;
    if A(r).group ~= ""; label = label + " (" + A(r).group + ")"; end
    add("looks", strings(1, 0), string(r), label, "looks", r, "aesthetics", true, PlotAesthetics.valueText(A(r).value));
end
% Across sessions
L = sessionLabels();
with = struct('datasets', "datasetKeys", 'match', "mappingFile");   % the keys go with "list", the file with "mapping"
for f = string(fieldnames(fig.sessions)).'
    if ismember(f, ["datasetKeys" "mappingFile"]); continue; end
    paths = "sessions." + f;
    if isfield(with, f); paths = [paths "sessions." + with.(f)]; end
    add("sessions", strings(1, 0), f, word(f, L), "figure", 0, paths, false);
end
T = struct2table(R(:), 'AsArray', true);   % (never empty: every figure has its observe and style fields)

    function add(part, groups, name, label, scope, index, paths, design, value)
        if nargin < 9
            value = getPath(fig, paths(1));
        end
        key = part + "." + name;
        generic = key;
        if scope == "panel"
            key = "panel." + fig.panels(index).id + "." + name;
            generic = "panel:" + fig.panels(index).type + "." + name;
        elseif scope == "looks"
            generic = "looks";
        end
        R(end+1) = struct('Key', key, 'Part', part, 'Groups', {groups}, 'Label', label, 'Value', valueText(value), ...
            'Scope', scope, 'Index', index, 'Paths', {paths}, 'Generic', generic, 'Design', design); %#ok<AGROW>

    end
end


function v = getPath(s, path)
for t = split(path, ".").'
    s = s.(t);
end
v = s;
end


function t = word(f, L)
%word  F's label in L (a struct of labels by field), else F itself.
t = string(f);
if isfield(L, f); t = L.(f); end
end


function L = observeLabels()
L = struct('data', "Data observed", 'units', "Unit filter", 'channels', "Channels", 'starred', "Starred only", ...
    'perGroup', "Once per trial group");
end


function L = sessionLabels()
L = struct('enabled', "Drawn across sessions", 'datasets', "Datasets", 'facet', "One figure per", 'series', "Colored by", ...
    'colorOrder', "Color order", 'showMembers', "Each session under its summary", 'error', "Error band", ...
    'match', "Matching", 'minSessions', "Fewest sessions", 'trialGroups', "Trial groups");
end


function S = styleGroups()
S = {
    "Lines and error bands", ["LineWidth" "ShowSEM" "ErrorType" "ErrorResamples" "ErrorFaceColor" "ErrorFaceAlpha" ...
        "ErrorEdgeColor" "ErrorEdgeStyle" "ErrorEdgeWidth"]
    "Colors",                ["Colormap" "HeatColormap"]
    "Text and legend",       ["FontSize" "Legend" "LegendLocation" "LegendOrientation" "LegendBox"]
    "Marks",                 ["ShowStop" "ShowZeroLine" "ShowArtifactNote" "Grid" "SiteSize"]
    "Sorting and labels",    ["SortDepth" "SortShank" "LabelDepth" "LabelShank"]
    };
end


function L = styleLabels()
L = struct('LineWidth', "Line width", 'ShowSEM', "Error bands", 'ErrorType', "Error type", ...
    'ErrorResamples', "Bootstrap resamples", 'ErrorFaceColor', "Band color", 'ErrorFaceAlpha', "Band opacity", ...
    'ErrorEdgeColor', "Band edge color", 'ErrorEdgeStyle', "Band edge style", 'ErrorEdgeWidth', "Band edge width", ...
    'Colormap', "Group colors", 'HeatColormap', "Heat colors", 'FontSize', "Font size", 'Legend', "Legend", ...
    'LegendLocation', "Legend location", 'LegendOrientation', "Legend orientation", 'LegendBox', "Legend box", ...
    'ShowStop', "Stop event", 'ShowZeroLine', "Event line (t = 0)", 'ShowArtifactNote', "Artifact note", ...
    'Grid', "Grid lines", 'SiteSize', "Probe site size", 'SortDepth', "Sort by depth", 'SortShank', "Sort by shank", ...
    'LabelDepth', "Label the depth", 'LabelShank', "Label the shank");
end


function g = optionGroup(f)
%optionGroup  The group of a panel's option F.
if ismember(f, ["yLimMode" "yLim" "cLim" "yTicks" "scale"])
    g = "Axes and limits";
elseif ismember(f, ["colormap" "tickColor" "tickWidth" "backColor" "fill" "fillAlpha" "histStyle" "colorBy" "alpha" ...
        "edgeColor" "edgeWidth" "lineWidth" "lineStyle" "showBaseline" "baselineColor" "baselineStyle" "baselineWidth" ...
        "groupBands" "height" "minWidth" "rowSpacing"])
    g = "Colors and lines";
elseif ismember(f, ["display" "stack" "stackSpacing" "layout" "rows" "order" "rasterSort" "rasterSortEvent" ...
        "rasterSortOrder" "rasterByGroup" "maskAfterStop" "trials" "maxTrials" "group" "showPhase" "overTime"])
    g = "Display and stacks";
elseif ismember(f, ["firstSpike" "latencyBox" "waveform"])
    g = "Marks and insets";
else
    g = "Data and analysis";
end
end


function L = optionLabels()
L = struct('bins', "Bins", 'measure', "Measure", 'baseline', "Baseline", 'auroc', "auROC settings", 'display', "Display", ...
    'histStyle', "Histogram style", 'fill', "Fill", 'fillAlpha', "Fill opacity", 'normalize', "Normalize", ...
    'stack', "Stack", 'stackSpacing', "Stack spacing", 'latencyBox', "Latency box", ...
    'maskAfterStop', "Mask after the stop event", 'yLimMode', "Y limits mode", 'yLim', "Y limits", ...
    'colormap', "Colormap", 'cLim', "Color limits", 'waveform', "Unit waveform", 'rasterSort', "Raster sort", ...
    'rasterSortEvent', "Raster sort event", 'rasterSortOrder', "Raster sort order", 'rasterByGroup', "Raster by group", ...
    'tickColor', "Tick color", 'tickWidth', "Tick width", 'backColor', "Background color", 'yTicks', "Y ticks", ...
    'firstSpike', "First-spike latency", 'statistic', "Statistic", 'transform', "Transform", 'errorType', "Error type", ...
    'trials', "Trials", 'maxTrials', "Most trials", 'rows', "Rows", 'order', "Order", 'group', "Trial group", ...
    'layout', "Layout", 'value', "Value", 'metric', "Metric", 'correlation', "Correlation", 'fisherZ', "Fisher z", ...
    'param', "Parameter", 'seriesParam', "Series parameter", 'timeBase', "Time base", 'range', "Range", ...
    'segmentSec', "Segment (s)", 'taperMode', "Taper mode", 'TW', "Time-bandwidth (TW)", 'K', "Tapers (K)", ...
    'W', "Bandwidth (W)", 'p', "Error p (p)", 'pad', "Padding", 'fpass', "Frequency band", 'err', "Error bars", ...
    'errP', "Error p", 'detrend', "Detrend", 'scale', "Scale", 'spikeFs', "Spike sampling rate", ...
    'movingwin', "Moving window", 'overTime', "Over time", 'showPhase', "Phase", 'colorBy', "Color by", ...
    'height', "Height", 'alpha', "Opacity", 'edgeColor', "Edge color", 'edgeWidth', "Edge width", ...
    'minWidth', "Smallest width", 'lineWidth', "Line width", 'lineStyle', "Line style", 'showBaseline', "Baseline line", ...
    'baselineColor', "Baseline color", 'baselineStyle', "Baseline style", 'baselineWidth', "Baseline width", ...
    'rowSpacing', "Row spacing", 'groupBands', "Group bands");
end


function t = panelList(P)
if isempty(P)
    t = "no panels";
else
    t = strjoin([P.type], ", ");
end
end


function t = spacingText(g)
t = string(g.spacing);
if g.spacing == "custom"; t = t + sprintf(' (%g, %g %s)', g.rowGap, g.colGap, g.gapUnits); end
end


function t = alignText(p)
own = ["ref" "window" "selection"];
own = own(arrayfun(@(f) isstruct(p.(f)), own));
if isempty(own)
    t = "the figure's";
else
    t = "its own " + strjoin(own, ", ");
end
end


function t = valueText(v)
%valueText  A value as text: on / off, the text, the numbers, the default, or a summary of a struct.
if islogical(v) && isscalar(v)
    t = "off";
    if v; t = "on"; end
elseif isstring(v) || ischar(v)
    t = strjoin(string(v), ", ");
    if t == ""; t = "(blank)"; end
elseif isnumeric(v)
    if isempty(v)
        t = "(auto)";
    elseif isscalar(v)
        t = string(sprintf('%g', v));
    else
        t = "[" + strjoin(compose("%g", v(:).'), " ") + "]";
    end
elseif isstruct(v)
    try
        t = string(jsonencode(v));
    catch
        t = "(" + class(v) + ")";
    end
else
    t = "(" + class(v) + ")";
end
if strlength(t) > 60; t = extractBefore(t, 58) + "..."; end
end
