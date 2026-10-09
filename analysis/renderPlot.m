function h = renderPlot(R, spec, target, opts)
%renderPlot  Draw a computed result the way its plot spec says.
%   H = renderPlot(R, SPEC, TARGET, Page=P) dispatches on SPEC.kind (a plot
%   entry, e.g. from EphysAnalysisConfig.plotFor; [] = the defaults for
%   R.kind) to renderPSTH, renderRaster, renderEvoked, renderRates,
%   renderTuning, renderHeatmap, renderProbeMap, renderCorrMap,
%   renderBehavior or renderWaveforms, with SPEC.style, the layout,
%   SPEC.waveform (psth, raster and tuning: each unit's waveform from
%   R.waveforms in its tile; waveforms: the plot's own settings),
%   the raster's sort and event marks (rasterSort, rasterSortOrder,
%   rasterByGroup, rasterEvents), and page P of a grid (plotPageCount
%   pages). TARGET is an axes,
%   uiaxes, figure, uifigure, panel, tab, grid layout or tiled layout: the
%   app draws its previews into a panel, the runner into an invisible
%   classic figure (newExportFigure). It adds a title -- SPEC.title, else
%   "<Kind>: <line> <edge> (<n> epochs)" -- with the dataset and page as a
%   subtitle.
%
%   Aesthetics: every component drawn is named by its role and group
%   (tagPart). The plot is drawn in a design (PlotDesign: its ground, group
%   colours and colormaps), and after drawing the rules are applied: the
%   design's, the user's for SPEC.kind (PlotAesthetics.userRules), then
%   the plot's own (SPEC.aesthetics), so the later win. In a visible figure
%   a right-click on any component opens PlotAestheticsDialog, which edits
%   the plot live, or picks another design (every plot on screen that
%   follows the chosen design is redrawn in it) or saves the plot's look as
%   one.
%
%   Options
%     Page            page of a grid (default 1)
%     Design          "" (default): the design the user chose
%                     (PlotDesign.current; none when UserAesthetics is
%                     false); a design's name; or a design (PlotDesign.load)
%     UserAesthetics  apply the user's design and remembered rules
%                     (default true; false: only SPEC.aesthetics)
%     Editable        "auto" (default: when TARGET's figure is visible),
%                     true or false: the right-click aesthetics editor
%     OnRemember      called with the plot's new aesthetics rules when the
%                     editor saves them with the plot (the app puts them in
%                     its config); [] (default): the editor can remember
%                     them only in the user's preferences
%
%   H: what the renderer returned plus title (the text used) and page.
%
%   See also plotPageCount, plotCaption, EphysAnalysisRunner.renderPlotFigures,
%   PlotAesthetics, PlotAestheticsDialog.

arguments
    R (1,1) struct
    spec
    target
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.Design = ""
    opts.UserAesthetics (1,1) logical = true
    opts.Editable = "auto"
    opts.OnRemember = []
end

spec = plotSpecFor(R, spec);
[design, follows] = designFor(opts.Design, opts.UserAesthetics);
style = spec.style;
style.Design = design;
nPages = plotPageCount(R, spec);
page = min(opts.Page, nPages);
switch spec.kind
    case "psth"
        h = renderPSTH(R, target, Layout=spec.layout, WithRaster=spec.withRaster, SortBy=spec.rasterSort, ...
            SortOrder=spec.rasterSortOrder, ByGroup=spec.rasterByGroup, EventMarks=spec.rasterEvents, HistStyle=spec.histStyle, ...
            Fill=spec.fill, FillAlpha=spec.fillAlpha, Normalize=spec.normalize, Stack=spec.stack, ...
            Spacing=spec.stackSpacing, Page=page, Waveform=spec.waveform, Style=style);
    case "raster"
        h = renderRaster(R, target, Page=page, SortBy=spec.rasterSort, SortOrder=spec.rasterSortOrder, ...
            ByGroup=spec.rasterByGroup, EventMarks=spec.rasterEvents, Waveform=spec.waveform, Style=style);
    case "evoked"
        h = renderEvoked(R, target, Layout=spec.layout, Page=page, Style=style);
    case "rate"
        h = renderRates(R, target, Layout=spec.layout, Style=style);
    case "tuning"
        h = renderTuning(R, target, Layout=spec.layout, Page=page, Waveform=spec.waveform, Style=style);
    case "heatmap"
        h = renderHeatmap(R, target, Order=spec.order, Style=style);
    case "probemap"
        h = renderProbeMap(R, [], target, Style=style);
    case "corrmap"
        h = renderCorrMap(R, target, Style=style);
    case "behavior"
        h = renderBehavior(R, target, Layout=spec.layout, Jitter=spec.jitter, XScale=spec.xScale, Style=style);
    case "waveforms"
        h = renderWaveforms(R, target, Layout=spec.layout, Page=page, Waveform=spec.waveform, Style=style);
    otherwise
        error('renderPlot:BadKind', 'Unknown plot kind "%s".', spec.kind);
end

txt = spec.title;
if txt == ""; txt = autoTitle(R, spec); end
sub = strings(1, 0);
if isfield(R, 'dataset') && string(R.dataset) ~= ""; sub(end+1) = string(R.dataset); end
if nPages > 1; sub(end+1) = sprintf("page %d of %d", page, nPages); end
if ~isempty(h.layout)
    title(h.layout, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none');
    if ~isempty(sub)
        subtitle(h.layout, strjoin(sub, " | "), 'FontSize', style.FontSize, 'Interpreter', 'none');
    end
elseif ~isempty(h.axes)
    ax = h.axes(1);
    was = string(ax.Title.String);
    title(ax, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none');
    parts = [was(was ~= "") sub];
    if ~isempty(parts)
        subtitle(ax, strjoin(parts, " | "), 'FontSize', style.FontSize, 'Interpreter', 'none');
    end
end
h.title = txt;
h.page = page;

root = h.layout;
if isempty(root) && ~isempty(h.axes); root = h.axes(1); end
if isempty(root); return; end
plotRules = PlotAesthetics.normalizeRules(spec.aesthetics);
rules = plotRules;
if opts.UserAesthetics
    rules = [PlotAesthetics.userRules(spec.kind) rules];
end
rules = [PlotDesign.rulesFor(design, spec.kind) rules];
PlotDesign.paint(root, design);
PlotAesthetics.apply(root, rules);
if editable(opts.Editable, target)
    ctx = struct('kind', spec.kind, 'id', spec.id, 'title', txt, 'root', root, 'target', target, 'plotRules', plotRules, ...
        'onRemember', {opts.OnRemember}, 'design', design, 'followsDesign', follows, ...
        'ordinal', isfield(R, 'groups') && istable(R.groups) && ismember('color', R.groups.Properties.VariableNames) ...
            && isOrdinalGroups(R.groups), 'mapField', mapFieldOf(R, spec), ...
        'redraw', @(newRules) renderPlot(R, setfield(spec, 'aesthetics', newRules), target, Page=page, ...
            Design=opts.Design, UserAesthetics=opts.UserAesthetics, Editable=opts.Editable, OnRemember=opts.OnRemember)); %#ok<SFLD>
    PlotAesthetics.enableEditing(target, ctx);
end
end


function [D, follows] = designFor(design, userAesthetics)
%designFor  The design to draw in, and whether it is the user's choice (a new choice redraws it).
follows = false;
if isstruct(design)
    D = design;
elseif string(design) ~= ""
    D = PlotDesign.load(string(design));
elseif userAesthetics
    D = PlotDesign.current();
    follows = true;
else
    D = PlotDesign.none();
end
end


function f = mapFieldOf(R, spec)
%mapFieldOf  Which of a design's colormaps the plot's images are drawn in ("" = none).
switch spec.kind
    case "corrmap",  f = "diverging";
    case "probemap", f = "heat";
    case "heatmap"
        f = "heat";
        if R.kind == "psth" && isAuroc(R); f = "diverging"; end
    otherwise,       f = "";
end
end


function tf = editable(mode, target)
%editable  Whether the right-click aesthetics editor goes on: "auto" = in a visible figure.
if isstring(mode) || ischar(mode)
    if string(mode) ~= "auto"
        error('renderPlot:BadEditable', 'Editable is "auto", true or false.');
    end
    fig = ancestor(target, 'figure');
    tf = ~isempty(fig) && strcmp(fig.Visible, 'on');
else
    tf = logical(mode);
end
end


function t = autoTitle(R, spec)
%autoTitle  "<Kind>: <line> <edge> (<n> epochs)".
K = EphysAnalysisConfig.plotKinds();
label = K.Label(K.Kind == spec.kind);
if spec.kind == "probemap"
    what = "units";
    if spec.source == "detected"; what = "channels"; end
    t = sprintf("%s: %s (%d %s)", label, R.valueName, R.n, what);
    return
end
if spec.kind == "behavior"
    t = sprintf("%s: %s by %s (%d epochs)", label, R.yName, R.param, height(R.values));
    return
end
if spec.kind == "waveforms"
    what = "units";
    if spec.source == "detected"; what = "channels"; end
    t = sprintf("%s (%d %s)", label, R.n, what);
    return
end
ev = "";
nEp = NaN;
if isfield(R, 'epochs') && istable(R.epochs)
    U = R.epochs.Properties.UserData;
    nEp = height(R.epochs);
    if isstruct(U) && isfield(U, 'ref')
        ev = eventRefLabel(U.ref);
        if isfield(U, 'window') && U.window.mode == "between" && ~isempty(U.window.stop)
            ev = ev + " to " + eventRefLabel(U.window.stop);
        end
    end
elseif isstruct(spec.ref)
    ev = eventRefLabel(spec.ref);
end
if ~isfinite(nEp) && isfield(R, 'n'); nEp = sum(R.n(:)); end
if spec.kind == "tuning"
    label = label + " (" + R.param + ")";
end
if spec.kind == "corrmap"
    type = "Pearson";
    if R.type == "spearman"; type = "Spearman"; end
    label = label + " (" + type + ", " + R.metric + " rate)";
end
t = label;
if ev ~= ""; t = t + ": " + ev; end
if isfinite(nEp); t = t + sprintf(" (%d epochs)", nEp); end
end
