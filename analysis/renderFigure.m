function h = renderFigure(F, spec, target, opts)
%renderFigure  Draw one computed figure: its panels on one tiled layout, with one legend and the figure's title.
%   H = renderFigure(F, SPEC, TARGET, Name=Value) draws F, the result of
%   EphysAnalysisRunner.computeFigure (one observation of a figure: a unit,
%   a channel or the dataset), as SPEC says (Config.figureFor(id): the spec
%   F was computed with, its aesthetics free to differ, as when the
%   aesthetics editor redraws it). TARGET is an axes, uiaxes, figure,
%   uifigure, panel, tab, grid layout or tiled layout, as renderPlot's:
%   renderers never create figures.
%
%   Layout   the arrangement's rows and columns become equal units
%            (figureTiles: relative sizes in quarter steps of the smallest,
%            at most 32 units a side), in one tiled layout (TileSpacing =
%            SPEC.grid.spacing; renderLayout) holding one axes per panel at
%            its cell and span. An axes TARGET draws panel 1 only.
%   Panels   each panel type's draw function (figurePanelRegistry: no
%            switch on the type here) draws its layers; a skipped layer
%            says why in the panel, a panel with nothing to draw says so in
%            its middle. SPEC.panels(k).title, when set, titles the panel;
%            with a title of the figure's own (SPEC.title, which names no
%            observation), the top-left panel names the observation.
%   Time     every panel sharing the figure's time axis (sharesTime; a
%            spectrogram, a coherogram on the epochs too) shows
%            [SPEC.window.pre post] (set on each: no linkaxes);
%            figureTimeStack labels a column's stack of time panels once,
%            at its bottom, and drops the inner x tick labels.
%   Title    SPEC.title, else "<id>: <observation> — <event> (<n> epochs)"
%            (a dataset figure names no observation; a figure with no
%            aligned panel no event; a figure merged across sessions,
%            figureSessionCompute, "(<N> sessions, <n> epochs)"); the
%            dataset as its subtitle ("3 sessions (SYNTH-01)" across
%            sessions). A merged F draws as one dataset's: its groups are
%            the series (sessions, subjects or all; "<series> · <group>"
%            with trialGroups "combine", told apart by line style), the
%            draw functions add each member session's pale line
%            (memberLines) and a heat map's session dividers; SPEC is
%            taken as figureSessionSpec gives it (as it was computed). An
%            observation of one trial group (a perGroup figure) names its
%            group: in the observation's label, else appended ("· <group>").
%   Legend   one, east of the panels (Style.LegendLocation, placeLegend):
%            the trial groups once (as a PSTH panel draws them, else a
%            continuous one, else a raster's bands), then the panels'
%            layer, unit, channel and mark entries, each label once. A
%            panel with a trial selection of its own (F.panels(k).
%            ownSelection) colors its own groups (groupPalette of its
%            groups) and lists its entries in a legend of its own inside
%            it (placeLegend, "inside"); its title then says its grouping
%            ("by <parameter>", "all trials") when it is not the figure's.
%   Style    SPEC.style: FontSize, LineWidth, ShowSEM, the Error* band
%            look, ShowZeroLine, ShowStop, Grid, Legend*, Colormap,
%            HeatColormap, SortShank / SortDepth, LabelShank / LabelDepth,
%            SiteSize. Its XLim, YLim and CLim are not used: the time
%            panels show the window, and each panel has its own
%            options.yLim / cLim.
%   Aesthetics  as renderPlot's, by panel type: the design's (PlotDesign)
%            common rules on everything; on each panel's axes the design's
%            rules for its type and the user's remembered rules for that
%            kind of plot (PlotAesthetics.userRules: a look remembered for
%            PSTH plots also dresses PSTH panels); then on the whole figure
%            the design's and the user's "figure" rules and SPEC.aesthetics
%            (the figure's own), the later winning. In a visible figure
%            (Editable) a right-click on any component opens the aesthetics
%            editor on the figure (context kind "figure"; its redraw draws
%            F again with the new SPEC.aesthetics).
%
%   Options (as renderPlot's)
%     Design          "" (default): the user's design (PlotDesign.current;
%                     none when UserAesthetics is false); a name; a design
%     UserAesthetics  the user's design and remembered rules (default true)
%     Editable        "auto" (default: in a visible figure), true or false
%     OnRemember      called with the figure's new aesthetics rules when the
%                     editor saves them with the figure (the app puts them
%                     in its config); [] (default): the editor can remember
%                     them only in the user's preferences
%
%   H fields
%     layout  the tiled layout ([] for an axes TARGET)
%     axes    the panels' axes drawn, in panel order
%     panels  one per SPEC.panels: id, type, axes (empty when not drawn),
%             extraAxes (a coherence panel's phase axes, drawn under its
%             magnitude in its tile; dressed with the panel type's looks)
%     title   the figure's title text
%   Errors: renderFigure:Mismatch (F's panels are not SPEC's).
%
%   See also EphysAnalysisRunner.computeFigure, figurePanelRegistry,
%   EphysAnalysisConfig.figureFor, renderPlot, PlotAesthetics.

arguments
    F (1,1) struct
    spec (1,1) struct
    target
    opts.Design = ""
    opts.UserAesthetics (1,1) logical = true
    opts.Editable = "auto"
    opts.OnRemember = []
end

if isfield(F, 'nSessions') && isfield(spec, 'sessions')
    spec = figureSessionSpec(spec);   % merged across sessions: drawn as computed (e.g. "combine" draws a PSTH's bars as lines)
end
[design, follows] = designFor(opts.Design, opts.UserAesthetics);
s = spec.style;
s.Design = design;
style = renderStyle(s);
style.XLim = [];   % the time panels show the window; y and color limits are each panel's options
style.YLim = [];
style.CLim = [];
outer = style;
outer.TileSpacing = spec.grid.spacing;
panels = spec.panels;
np = numel(panels);
types = strings(1, np);
for k = 1:np; types(k) = panels(k).type; end
fIds = strings(1, numel(F.panels));
for k = 1:numel(F.panels); fIds(k) = F.panels(k).id; end
sIds = strings(1, np);
for k = 1:np; sIds(k) = panels(k).id; end
if ~isequal(fIds, sIds)
    error('renderFigure:Mismatch', 'F holds the panels [%s], the spec [%s]: draw F with the spec it was computed with.', ...
        strjoin(fIds, ", "), strjoin(sIds, ", "));
end

if np > 0
    [nr, nc, tileOf, spanOf] = figureTiles(spec.grid, panels);
else
    nr = 1; nc = 1; tileOf = zeros(0, 1); spanOf = zeros(0, 2);
end
[tl, ax0] = renderLayout(target, nr, nc, outer);
PT = EphysAnalysisConfig.panelTypes();
reg = figurePanelRegistry();
G = F.groups;
colors = zeros(0, 3);
if istable(G) && height(G) > 0; colors = groupPalette(G, style); end
isTime = false(1, np);
for k = 1:np
    row = PT.Type == types(k);
    isTime(k) = any(row) && (PT.SharesTime(row) || overEpochs(panels(k)));
end
nDraw = np;
if ~isempty(ax0); nDraw = min(1, np); end
axs = gobjects(1, np);
extra = cell(1, np);   % each panel's further axes (a coherence panel's phase)
hks = cell(1, np);
for k = 1:nDraw
    p = panels(k);
    P = F.panels(k);
    if isempty(ax0)
        ax = nexttile(tl, tileOf(k), spanOf(k, :));
    else
        ax = ax0;
    end
    own = isfield(P, 'ownSelection') && P.ownSelection && istable(P.groups) && height(P.groups) > 0;
    colorsK = colors;   % a panel with a selection of its own colors its own groups
    if own; colorsK = groupPalette(P.groups, style); end
    look = lookFor(F, spec, p, P, style, colorsK, isTime(k));
    if isfield(reg, p.type)
        hk = reg.(p.type).draw(ax, P, look);
    else
        hk = figDrawResult(ax);
        figLayerNotes(ax, P, look, false, "Unknown panel type """ + p.type + """");
    end
    ax = hk.axes;
    role = string(ax.Tag);
    if ~ismember(role, ["axes" "rasterAxes"]); role = "axes"; end
    tagPart(ax, role, "", p.id);   % the aesthetics editor lists the tiles by panel id
    if p.sharesTime && ~isempty(look.W)
        xlim(ax, [spec.window.pre spec.window.post]);
    end
    if hk.yName ~= ""; ylabel(ax, hk.yName, 'Interpreter', 'none'); end
    ttl = p.title;
    if own; ttl = groupingTitle(ttl, p, spec); end
    if ttl ~= ""; title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none'); end
    if own   % its groups are not the figure's: a legend of its own, inside it; the figure's legend serves the others
        if style.Legend
            v = isgraphics(hk.legendHandles);
            if any(v)
                inside = style;
                inside.LegendLocation = "inside";
                placeLegend(ax, hk.legendHandles(v), hk.legendLabels(v), inside, [], "inside");
            end
        end
        hk.legendHandles = gobjects(1, 0);
        hk.legendLabels = strings(1, 0);
        hk.legendGroup = false(1, 0);
    end
    axs(k) = ax;
    if isfield(hk, 'extraAxes'); extra{k} = hk.extraAxes(isgraphics(hk.extraAxes)); end
    hks{k} = hk;
end
drawn = isgraphics(axs);
multi = nnz(drawn) > 1;
if multi; tileTicks(axs(drawn), style); end
labelSize = [];
if multi; labelSize = style.FontSize; end
figureTimeStack(axs, panels, isTime, labelSize);

% title: the figure's, or what it shows; the top-left panel names the observation under a title of the figure's own
txt = spec.title;
obs = F.observation;
named = isstruct(obs) && isfield(obs, 'kind') && obs.kind ~= "dataset" && isfield(obs, 'label') && string(obs.label) ~= "";
if txt ~= "" && named && any(drawn)
    on = find(drawn);
    [~, i] = sortrows([[panels(on).row].' [panels(on).col].']);
    k1 = on(i(1));
    if panels(k1).title == "" && strjoin(string(axs(k1).Title.String), "") == ""
        title(axs(k1), string(obs.label), 'FontWeight', 'normal', 'Interpreter', 'none');
    end
end
grpTxt = "";   % one figure per trial group: the group drawn
if isstruct(obs) && isfield(obs, 'groupLabel'); grpTxt = string(obs.groupLabel); end
if txt == ""
    txt = autoTitle(F, spec, named, grpTxt);
elseif grpTxt ~= ""
    txt = txt + " · " + grpTxt;
end
sub = string(F.dataset);
if ~isempty(tl)
    title(tl, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none');
    if sub ~= ""; subtitle(tl, sub, 'FontSize', style.FontSize, 'Interpreter', 'none'); end
elseif ~isempty(ax0)
    was = string(ax0.Title.String);
    title(ax0, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none');
    parts = [reshape(was(was ~= ""), 1, []) sub(sub ~= "")];
    if ~isempty(parts); subtitle(ax0, strjoin(parts, " | "), 'FontSize', style.FontSize, 'Interpreter', 'none'); end
end

% one legend: the groups once, then the layers', units', channels' and marks' entries
if style.Legend && any(drawn)
    [lh, ll] = legendEntries(hks, types, G);
    if ~isempty(lh)
        placeLegend(legendHost(axs(drawn), tl), lh, ll, style, tl, "east");
    end
end

% aesthetics: the design's common rules, each panel's kind, then the figure's
root = tl;
if isempty(root); root = ax0; end
specRules = PlotAesthetics.normalizeRules(spec.aesthetics);
PlotAesthetics.apply(root, design.rules);
for k = find(drawn)
    r = kindRules(design, types(k));
    if opts.UserAesthetics && isvarname(types(k)); r = [r PlotAesthetics.userRules(types(k))]; end %#ok<AGROW>
    PlotAesthetics.apply(axs(k), r);
    for xa = reshape(extra{k}, 1, [])
        PlotAesthetics.apply(xa, r);
    end
end
PlotDesign.paint(root, design);
r = kindRules(design, "figure");
if opts.UserAesthetics; r = [r PlotAesthetics.userRules("figure")]; end
PlotAesthetics.apply(root, [r specRules]);
if editable(opts.Editable, target)
    mapField = "";
    aurocMap = false;   % a heat map of auROCs is drawn in the diverging colormap
    for k = find(types == "heatmap")
        o = panels(k).options;
        aurocMap = aurocMap || (isfield(o, 'baseline') && isstruct(o.baseline) && o.baseline.Mode == "auroc");
    end
    for k = find(types == "spectrogram")   % a baseline-normalized spectrogram: diverging, centered on no change
        o = panels(k).options;
        aurocMap = aurocMap || (isfield(o, 'baseline') && isstruct(o.baseline) && o.baseline.Mode ~= "none");
    end
    cohgram = false;
    for k = find(types == "coherence")
        cohgram = cohgram || (isfield(panels(k).options, 'overTime') && panels(k).options.overTime);
    end
    if any(types == "corrmap") || aurocMap
        mapField = "diverging";
    elseif any(ismember(types, ["heatmap" "probemap" "spectrogram"])) || cohgram
        mapField = "heat";
    end
    ordinal = istable(G) && ismember('color', G.Properties.VariableNames) && isOrdinalGroups(G);
    ctx = struct('kind', "figure", 'id', spec.id, 'title', txt, 'root', root, 'target', target, 'plotRules', specRules, ...
        'onRemember', {opts.OnRemember}, 'design', design, 'followsDesign', follows, 'ordinal', ordinal, 'mapField', mapField, ...
        'redraw', @(newRules) renderFigure(F, setfield(spec, 'aesthetics', newRules), target, Design=opts.Design, ...
            UserAesthetics=opts.UserAesthetics, Editable=opts.Editable, OnRemember=opts.OnRemember));
    PlotAesthetics.enableEditing(target, ctx);
end

hp = repmat(struct('id', "", 'type', "", 'axes', gobjects(0), 'extraAxes', gobjects(0)), 1, np);
for k = 1:np
    hp(k).id = panels(k).id;
    hp(k).type = types(k);
    if drawn(k)
        hp(k).axes = axs(k);
        hp(k).extraAxes = extra{k};
    end
end
h = struct('layout', tl, 'axes', axs(drawn), 'panels', hp, 'title', txt);
end


function tf = overEpochs(p)
%overEpochs  A coherence panel drawn over time from the event (a coherogram on the aligned time base): a time panel.
o = p.options;
tf = p.type == "coherence" && isfield(o, 'overTime') && o.overTime && isfield(o, 'timeBase') && o.timeBase == "aligned";
end


function look = lookFor(F, spec, p, P, style, colors, isTime)
%lookFor  What a panel's draw function is given besides its result (figurePanelRegistry's LOOK).
W = [];
w = p.window;
if isstruct(w) && all(isfield(w, {'pre' 'post'})) && (~isfield(w, 'mode') || w.mode == "fixed")
    W = double([w.pre w.post]);
    if ~(numel(W) == 2 && all(isfinite(W)) && W(2) > W(1)); W = []; end
end
look = struct('style', style, 'colors', colors, 'W', W, 'spec', spec, 'panel', p, 'panelId', p.id, ...
    'isTop', p.row == 1, 'isBottom', p.row + p.rowSpan - 1 >= spec.grid.rows, 'epochs', [], 'groups', [], ...
    'observation', F.observation, 'isTime', isTime);
look.epochs = P.epochs;
if ~istable(look.epochs); look.epochs = F.epochs; end
look.groups = P.groups;
if ~istable(look.groups); look.groups = F.groups; end
end


function [lh, ll] = legendEntries(hks, types, G)
%legendEntries  The figure's legend: each group once (from the panel that draws the groups best), then the rest, each label once.
lh = gobjects(1, 0);
ll = strings(1, 0);
withGroups = false(1, numel(hks));
for k = 1:numel(hks)
    withGroups(k) = ~isempty(hks{k}) && any(hks{k}.legendGroup);
end
src = 0;
if istable(G) && height(G) > 1
    for t = ["psth" "continuous" "raster"]
        src = find(withGroups & types == t, 1);
        if ~isempty(src); break; end
    end
    if isempty(src); src = find(withGroups, 1); end
    if isempty(src); src = 0; end
end
if src > 0
    hk = hks{src};
    for i = find(hk.legendGroup)
        if any(ll == hk.legendLabels(i)); continue; end
        lh(end+1) = hk.legendHandles(i); %#ok<AGROW>
        ll(end+1) = hk.legendLabels(i); %#ok<AGROW>
    end
end
for k = 1:numel(hks)
    hk = hks{k};
    if isempty(hk); continue; end
    for i = find(~hk.legendGroup)
        if any(ll == hk.legendLabels(i)) || ~isgraphics(hk.legendHandles(i)); continue; end
        lh(end+1) = hk.legendHandles(i); %#ok<AGROW>
        ll(end+1) = hk.legendLabels(i); %#ok<AGROW>
    end
end
end


function host = legendHost(axs, tl)
%legendHost  The axes that holds the figure's legend: the first panel without a legend of its own.
%   Else, in a tiled layout, a hidden axes of it (tagged "legendHost", left
%   out of the tiles as placeLegend's are); drawn into one axes, that axes
%   (its legend is replaced: the draw functions offer their entries up).
for ax = reshape(axs, 1, [])
    if isempty(ax.Legend) || ~isvalid(ax.Legend)
        host = ax;
        return
    end
end
if ~isempty(tl) && isgraphics(tl)
    host = axes(tl, 'Visible', 'off', 'HitTest', 'off', 'PickableParts', 'none', 'Tag', 'legendHost');
    host.Layout.Tile = 1;
else
    host = axs(1);
end
end


function R = kindRules(D, kind)
%kindRules  A design's own rules for one kind of plot (its common rules apart).
R = PlotAesthetics.emptyRules();
kind = string(kind);
if isvarname(kind) && isfield(D, 'kinds') && isstruct(D.kinds) && isfield(D.kinds, kind) && ~isempty(D.kinds.(kind))
    R = PlotAesthetics.normalizeRules(D.kinds.(kind));
end
end


function t = groupingTitle(t, p, spec)
%groupingTitle  A panel title that says how the panel's own selection groups its trials, when not as the figure does.
gb = strings(1, 0);
fb = strings(1, 0);
if isfield(p, 'selection') && isstruct(p.selection) && isfield(p.selection, 'groupBy'); gb = string(p.selection.groupBy); end
if isstruct(spec.selection) && isfield(spec.selection, 'groupBy'); fb = string(spec.selection.groupBy); end
if isequal(reshape(gb, 1, []), reshape(fb, 1, [])); return; end
what = "all trials";
if ~isempty(gb); what = "by " + strjoin(gb, " x "); end
if t == ""
    t = what;
else
    t = t + " (" + what + ")";
end
end


function t = autoTitle(F, spec, named, grpTxt)
%autoTitle  "<id>: <observation> — <event> (<n> epochs)" (a trial group's observation names its group).
t = spec.id;
if t == ""; t = "Figure"; end
if named
    t = t + ": " + string(F.observation.label);
elseif grpTxt ~= ""
    t = t + ": " + grpTxt;
end
if istable(F.epochs) && isstruct(spec.ref)
    ev = eventRefLabel(spec.ref);
    w = spec.window;
    if isstruct(w) && isfield(w, 'mode') && w.mode == "between" && isfield(w, 'stop') && ~isempty(w.stop)
        ev = ev + " to " + eventRefLabel(w.stop);
    end
    if isfield(F, 'nSessions')   % merged across sessions (figureSessionCompute)
        t = t + " — " + ev + sprintf(" (%d session%s, %d epochs)", F.nSessions, plural(F.nSessions), height(F.epochs));
    else
        t = t + " — " + ev + sprintf(" (%d epochs)", height(F.epochs));
    end
elseif isfield(F, 'nSessions')
    t = t + sprintf(" (%d session%s)", F.nSessions, plural(F.nSessions));
end
end


function s = plural(n)
s = "";
if n ~= 1; s = "s"; end
end


function [D, follows] = designFor(design, userAesthetics)
%designFor  The design to draw in, and whether it is the user's choice (a new choice redraws it).
%   A copy of renderPlot's local designFor.
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


function tf = editable(mode, target)
%editable  Whether the right-click aesthetics editor goes on: "auto" = in a visible figure.
%   A copy of renderPlot's local editable.
if isstring(mode) || ischar(mode)
    if string(mode) ~= "auto"
        error('renderFigure:BadEditable', 'Editable is "auto", true or false.');
    end
    fig = ancestor(target, 'figure');
    tf = ~isempty(fig) && strcmp(fig.Visible, 'on');
else
    tf = logical(mode);
end
end
