function h = renderFigure(F, spec, target, opts)
%renderFigure  Draw one computed figure: its panels on one tiled layout, with one legend and the figure's title.
%   H = renderFigure(F, SPEC, TARGET, Name=Value) draws F, the result of
%   EphysAnalysisRunner.computeFigure (one observation of a figure: a unit,
%   a channel or the dataset), as SPEC says (Config.figureFor(id): the spec
%   F was computed with, its aesthetics free to differ, as when the
%   aesthetics editor redraws it). TARGET is an axes, uiaxes, figure,
%   uifigure, panel, tab, grid layout or tiled layout (renderLayout):
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
%   Notes and overlays  each panel's (SPEC.panels(k).note, .overlays, as a
%            plot's): the overlays drawn on the panel's axes (drawOverlays,
%            every one on them: a panel has no raster / data choice; a
%            coherence panel's x overlays on its phase strip too); the
%            note (drawNote) placed below, above, left or right takes a
%            band of the panel's tile beside its axes (the tile becomes a
%            small tiled layout of its own: the axes and a hidden axes,
%            Tag "noteHost", holding the text; the band is fitted to the
%            text once its looks are final, at most half the tile; a band
%            below or above keeps the axes' left edge and width those of
%            a plain tile; a panel with a band left or right keeps its own
%            time tick labels: figureTimeStack), placed over the panel or
%            at x, y it sits in the axes (placeNote). Their own looks are
%            rules after the design's and the user's and before
%            SPEC.aesthetics.
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
%   Aesthetics  by panel type: the design's (PlotDesign)
%            common rules on everything; on each panel's axes the design's
%            rules for its type and the user's remembered rules for that
%            kind of plot (PlotAesthetics.userRules: a look remembered for
%            PSTH plots also dresses PSTH panels); then on the whole figure
%            the design's and the user's "figure" rules and SPEC.aesthetics
%            (the figure's own), the later winning. In a visible figure
%            (Editable) a right-click on any component opens the aesthetics
%            editor on the figure (context kind "figure"; its redraw draws
%            F again with the new SPEC.aesthetics). A panel's box ("on" /
%            "off"; "auto" leaves the looks' Box) is set last, over all of them.
%
%   Options
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
%             magnitude in its tile; dressed with the panel type's looks),
%             note (its text, empty without one) and overlays (the lines
%             and patches drawn)
%     title   the figure's title text
%   Errors: renderFigure:Mismatch (F's panels are not SPEC's).
%
%   See also EphysAnalysisRunner.computeFigure, figurePanelRegistry,
%   EphysAnalysisConfig.figureFor, renderChronux, PlotAesthetics.

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
notes = cell(1, np);   % each panel's note (drawNote's N) and the band that holds it beside the axes ([] = in the axes)
bands = cell(1, np);
ovls = cell(1, np);    % each panel's overlays (drawOverlays' O)
for k = 1:nDraw
    p = panels(k);
    P = F.panels(k);
    band = [];
    if isempty(ax0) && besideNote(p)
        [ax, band] = notedTile(tl, tileOf(k), spanOf(k, :), nr, nc, p.note, style);
    elseif isempty(ax0)
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
    % the panel's overlays on its axes, and its note: in the band beside them, else in them
    ovls{k} = drawOverlays(struct('axes', ax), p.overlays);
    if ~isempty(extra{k}) && ~isempty(p.overlays)   % a coherence panel's phase strip shares its x axis: the x overlays go on it too
        xo = p.overlays([p.overlays.axis] == "x");
        if ~isempty(xo)
            O2 = drawOverlays(struct('axes', extra{k}), xo);
            ovls{k}.handles = [ovls{k}.handles O2.handles];
        end
    end
    host = ax;
    if ~isempty(band) && isgraphics(band); host = band; bands{k} = band; end
    notes{k} = drawNote(struct('layout', [], 'axes', host), p.note, style);
end
drawn = isgraphics(axs);
multi = nnz(drawn) > 1;
if multi; tileTicks(axs(drawn), style); end
labelSize = [];
if multi; labelSize = style.FontSize; end
sided = false(1, np);   % a band left or right of a panel's axes narrows them: no shared time axis with the panel below
for k = 1:np; sided(k) = isempty(ax0) && sideNote(panels(k)); end
figureTimeStack(axs, panels, isTime, labelSize, sided);

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
kRules = cell(1, np);
for k = find(drawn)
    r = kindRules(design, types(k));
    if opts.UserAesthetics && isvarname(types(k)); r = [r PlotAesthetics.userRules(types(k))]; end %#ok<AGROW>
    PlotAesthetics.apply(axs(k), r);
    for xa = reshape(extra{k}, 1, [])
        PlotAesthetics.apply(xa, r);
    end
    kRules{k} = r;
end
PlotDesign.paint(root, design);
r = kindRules(design, "figure");
if opts.UserAesthetics; r = [r PlotAesthetics.userRules("figure")]; end
% a panel's note and overlays: their own looks after the design's and the user's, before the figure's own
ownRules = cell(1, np);
for k = find(drawn)
    ownRules{k} = PlotAesthetics.emptyRules();
    if ~isempty(notes{k}); ownRules{k} = [ownRules{k} notes{k}.rules]; end
    if ~isempty(ovls{k}); ownRules{k} = [ownRules{k} ovls{k}.rules]; end
end
if any(~cellfun(@isempty, ownRules(drawn)))
    PlotAesthetics.apply(root, r);
    for k = find(drawn)
        if isempty(ownRules{k}); continue; end
        PlotAesthetics.apply(axs(k), ownRules{k});
        for xa = reshape(extra{k}, 1, [])
            PlotAesthetics.apply(xa, ownRules{k});
        end
    end
    PlotAesthetics.apply(root, specRules);
else
    PlotAesthetics.apply(root, [r specRules]);
end
for k = find(drawn)   % a note in a band beside the axes: that band is no tile, so its looks are given to it here
    if isempty(bands{k}) || isempty(notes{k}) || isempty(notes{k}.text); continue; end
    bandRules = [design.rules kRules{k} r notes{k}.rules specRules];
    if ~isempty(bandRules); PlotAesthetics.apply(bands{k}, bandRules([bandRules.role] == "note")); end
end
for k = find(drawn)   % a panel's own box wins over the design's, the remembered looks' and the figure's rules
    if panels(k).box ~= "auto"; set([axs(k) reshape(extra{k}, 1, [])], 'Box', char(panels(k).box)); end
end
for k = find(drawn)   % the notes go where they belong once their looks are final (their size measured)
    if isempty(notes{k}) || isempty(notes{k}.text); continue; end
    if isempty(bands{k})
        placeNote(notes{k}, panels(k).note);
    else
        fitNoteBand(axs(k), bands{k}, notes{k}.text);   % the band fitted to the text as drawn, then the text in its free part
        placeBandNote(notes{k}.text, panels(k).note, bands{k});
    end
end
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
    ctx.panelTypes = struct('id', sIds, 'type', types);   % each tile's panel type by the id it is tagged with (PlotDesign.capture)
    PlotAesthetics.enableEditing(target, ctx);
end

hp = repmat(struct('id', "", 'type', "", 'axes', gobjects(0), 'extraAxes', gobjects(0), 'note', gobjects(0), ...
    'overlays', gobjects(1, 0)), 1, np);
for k = 1:np
    hp(k).id = panels(k).id;
    hp(k).type = types(k);
    if drawn(k)
        hp(k).axes = axs(k);
        hp(k).extraAxes = extra{k};
        if ~isempty(notes{k}); hp(k).note = notes{k}.text; end
        if ~isempty(ovls{k}); hp(k).overlays = ovls{k}.handles; end
    end
end
h = struct('layout', tl, 'axes', axs(drawn), 'panels', hp, 'title', txt);
end


function tf = besideNote(p)
%besideNote  The panel has a note placed beside its axes (below, above, left or right): it takes a band of the tile.
tf = strtrim(string(p.note.text)) ~= "" && ismember(string(p.note.placement), ["below" "above" "left" "right"]);
end


function tf = sideNote(p)
%sideNote  The panel's note takes a band left or right of its axes: they are narrower than a plain tile's in the column.
tf = besideNote(p) && ismember(string(p.note.placement), ["left" "right"]);
end


function [ax, band] = notedTile(tl, tile, span, nr, nc, note, style)
%notedTile  A panel's tile as a small tiled layout of its own: the panel's axes and, beside it, a band for its note.
%   The band (a hidden axes, Tag "noteHost", so the aesthetics editor lists
%   no tile for it) is below, above, left or right of the axes as the note
%   is placed, a share of the tile in steps of a twentieth (at most half):
%   first estimated from the note's lines at its font size, then fitted to
%   the text as drawn once its looks are final (fitNoteBand). The small
%   layout has no padding or spacing, so a band below or above leaves the
%   axes' left edge and width those of a plain tile in the column.
place = string(note.placement);
across = ismember(place, ["below" "above"]);
n = 20;
b = bandUnits(tl, span, nr, nc, note, style, across, n);
if across
    inner = tiledlayout(tl, n, 1, 'TileSpacing', 'none', 'Padding', 'none');
else
    inner = tiledlayout(tl, 1, n, 'TileSpacing', 'none', 'Padding', 'none');
end
inner.Layout.Tile = tile;
inner.Layout.TileSpan = span;
ax = nexttile(inner, 1);
band = nexttile(inner, n);
spanBand(ax, band, place, n, b);
set(band, 'Visible', 'off', 'HitTest', 'off', 'PickableParts', 'none', 'XLim', [0 1], 'YLim', [0 1], 'Tag', 'noteHost');
setappdata(band, 'NoteBand', struct('n', n, 'b', b, 'place', place, 'free', [0 0 1 1]));
end


function spanBand(holder, band, place, n, b)
%spanBand  The axes (or the layout holding it) and the band in the small layout: the band B of its N steps, on the note's side.
switch place
    case "below"
        holder.Layout.Tile = 1;      holder.Layout.TileSpan = [n - b 1];
        band.Layout.Tile = n - b + 1; band.Layout.TileSpan = [b 1];
    case "above"
        band.Layout.Tile = 1;        band.Layout.TileSpan = [b 1];
        holder.Layout.Tile = b + 1;  holder.Layout.TileSpan = [n - b 1];
    case "left"
        band.Layout.Tile = 1;        band.Layout.TileSpan = [1 b];
        holder.Layout.Tile = b + 1;  holder.Layout.TileSpan = [1 n - b];
    otherwise   % right
        holder.Layout.Tile = 1;      holder.Layout.TileSpan = [1 n - b];
        band.Layout.Tile = n - b + 1; band.Layout.TileSpan = [1 b];
end
end


function b = bandUnits(tl, span, nr, nc, note, style, across, n)
%bandUnits  How many of the tile's N steps the note's band takes at first: its lines (across: their height; beside: their width) over the tile's size.
fs = style.FontSize;
if isfinite(note.fontSize) && note.fontSize > 0; fs = note.fontSize; end
lines = splitlines(strip(string(note.text), 'right'));
tall = numel(lines) * fs * 1.3 + 10 + 2.8 * style.FontSize;   % points, with the axes' tick labels and label beside it
wide = max(strlength(lines)) * fs * 0.6 + 12 + 4 * style.FontSize;
if abs(sind(note.rotation)) > 0.7; [tall, wide] = deal(wide, tall); end
room = [576 432];   % the container's size in points (a default when it cannot be read)
try
    px = getpixelposition(tl.Parent);
    if all(px(3:4) > 20); room = px(3:4) * 72 / get(groot, 'ScreenPixelsPerInch'); end
catch
end
if across
    need = tall;
    have = room(2) * span(1) / max(nr, 1) * 0.85;
else
    need = wide;
    have = room(1) * span(2) / max(nc, 1) * 0.85;
end
b = min(n / 2, max(1, ceil(n * need / max(have, 1))));
end


function fitNoteBand(ax, band, t)
%fitNoteBand  Size the band to the note as drawn (its looks final) and the axes' labels that reach into it.
%   The text's extent and the room the axes' tick labels and axis label
%   take on that side (they are drawn into the band: the small layout has
%   no spacing) give the band's share of the tile, at most half; the band's
%   free part (BAND's appdata NoteBand.free, [x0 y0 x1 y1] in its normalized
%   units) is where placeBandNote puts the text.
S = getappdata(band, 'NoteBand');
if isempty(S) || isempty(t) || ~isgraphics(t); return; end
inner = band.Parent;
holder = ax;
while ~isempty(holder.Parent) && holder.Parent ~= inner && isa(holder.Parent, 'matlab.graphics.layout.TiledChartLayout')
    holder = holder.Parent;   % a coherence panel's pair layout holds its axes
end
units = t.Units;
t.Units = 'points';
ext = t.Extent;
t.Units = units;
fs = ax.FontSize;
deco = 4;   % points the axes' labels take on the band's side
switch S.place
    case "below"
        if ~isempty(ax.XTickLabel); deco = deco + 1.5 * fs; end
        if strjoin(string(ax.XLabel.String), "") ~= ""; deco = deco + 1.5 * ax.XLabel.FontSize; end
    case "above"
        if strjoin(string(ax.Title.String), "") ~= ""; deco = deco + 1.6 * ax.Title.FontSize; end
        if strjoin(string(ax.Subtitle.String), "") ~= ""; deco = deco + 1.5 * ax.Subtitle.FontSize; end
    case "left"
        lab = string(ax.YTickLabel);
        if ~isempty(lab); deco = deco + 0.6 * fs * max(strlength(lab)) + 6; end
        if strjoin(string(ax.YLabel.String), "") ~= ""; deco = deco + 1.6 * ax.YLabel.FontSize; end
    otherwise
        if numel(ax.YAxis) > 1; deco = deco + 0.6 * fs * 6 + 1.6 * fs; end   % a right y axis
end
across = ismember(S.place, ["below" "above"]);
need = deco + 12;
if across; need = need + ext(4); else; need = need + ext(3); end
bp = sizeIn(band);
if across; have = bp(2) * S.n / S.b; else; have = bp(1) * S.n / S.b; end
b = min(S.n / 2, max(1, ceil(S.n * need / max(have, 1))));
if b ~= S.b
    spanBand(holder, band, S.place, S.n, b);
    S.b = b;
    bp = sizeIn(band);
end
dim = bp(1 + across);   % the band's size across it, points
f = min(0.9, deco / max(dim, 1));   % its share the axes' labels take, next to the axes
switch S.place
    case "below", S.free = [0 0 1 1 - f];
    case "above", S.free = [0 f 1 1];
    case "left",  S.free = [0 0 1 - f 1];
    otherwise,    S.free = [f 0 1 1];
end
setappdata(band, 'NoteBand', S);
end


function wh = sizeIn(ax)
%sizeIn  An axes' width and height in points (laid out first when it has not been yet).
wh = [0 0];
for attempt = 1:2
    units = ax.Units;
    ax.Units = 'points';
    p = ax.Position;
    ax.Units = units;
    wh = p(3:4);
    if all(wh > 2); return; end
    if attempt == 1; drawnow limitrate; end
end
wh = max(wh, 1);
end


function placeBandNote(t, note, band)
%placeBandNote  A note in the band beside its panel, in the part the axes' labels leave free (fitNoteBand).
%   Along the band by its alignment (below / above: align across the
%   panel; left / right: valign up it), in the middle across it. A note
%   turned a quarter (|sin(rotation)| > 0.7) reads along y: its horizontal
%   alignment comes from valign (bottom / middle / top: left / center /
%   right at +90, mirrored at -90), its vertical alignment is middle, and
%   valign puts it up the band.
if isempty(t) || ~isgraphics(t); return; end
if note.box
    t.EdgeColor = t.Color;
    t.LineWidth = 0.75;
end
S = getappdata(band, 'NoteBand');
fr = [0 0 1 1];
if isstruct(S) && isfield(S, 'free'); fr = S.free; end
t.Units = 'normalized';
share = @(v, order) shareOf(v, order);
alongX = @(s) fr(1) + (fr(3) - fr(1)) * (0.02 + 0.96 * s);
alongY = @(s) fr(2) + (fr(4) - fr(2)) * (0.02 + 0.96 * s);
midX = (fr(1) + fr(3)) / 2;
midY = (fr(2) + fr(4)) / 2;
across = ismember(string(note.placement), ["below" "above"]);
sv = share(note.valign, ["bottom" "middle" "top"]);
if abs(sind(note.rotation)) > 0.7
    order = ["left" "center" "right"];
    if sind(note.rotation) < 0; order = flip(order); end
    t.HorizontalAlignment = char(order(round(2 * sv) + 1));
    t.VerticalAlignment = 'middle';
    if across
        t.Position = [alongX(share(note.align, ["left" "center" "right"])), alongY(sv), 0];
    else
        t.Position = [midX, alongY(sv), 0];
    end
elseif across
    t.Position = [alongX(share(note.align, ["left" "center" "right"])), midY, 0];
    t.HorizontalAlignment = char(note.align);
    t.VerticalAlignment = 'middle';
else
    t.Position = [midX, alongY(sv), 0];
    t.HorizontalAlignment = 'center';
    t.VerticalAlignment = char(note.valign);
end
end


function s = shareOf(v, order)
%shareOf  0, 0.5 or 1 for the first, second or third of ORDER (0.5 when V is none of them).
s = (find(string(v) == order, 1) - 1) / 2;
if isempty(s); s = 0.5; end
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
