function h = renderFigure(F, spec, target, opts)
%renderFigure  Draw one computed figure: its panels laid out on its grid, with one legend and the figure's title.
%   H = renderFigure(F, SPEC, TARGET, Name=Value) draws F, the result of
%   EphysAnalysisRunner.computeFigure (one observation of a figure: a unit,
%   a channel or the dataset), as SPEC says (Config.figureFor(id): the spec
%   F was computed with, its aesthetics free to differ, as when the
%   aesthetics editor redraws it). TARGET is an axes, uiaxes, figure,
%   uifigure, panel, tab or grid layout: renderers never create figures.
%
%   Layout   its own engine, not MATLAB's tiled layout: TARGET (emptied;
%            a grid layout gets a panel: figureCanvas) holds one axes per
%            panel, which figureLayout places in pixels once everything
%            is drawn and dressed (figureArrange: the plot areas of the
%            rows and columns line up across the grid, in the exact
%            proportions of SPEC.grid.rowHeights and colWidths; between
%            them the room the labels there take and the gap of
%            SPEC.grid.spacing, the clear space between neighboring panels'
%            labels: a preset, "none" making a stack's plot areas flush, or
%            "custom" gaps in px or %; a panel of SPEC.panels(k).size
%            smaller than its cell sits at its align / valign), and again
%            whenever TARGET changes size. An axes TARGET draws panel 1
%            only.
%   Panels   each panel type's draw function (figurePanelRegistry: no
%            switch on the type here) draws its layers; a skipped layer
%            says why in the panel, a panel with nothing to draw says so in
%            its middle. SPEC.panels(k).title, when set, titles the panel;
%            with a title of the figure's own (SPEC.title, which names no
%            observation), the top-left panel names the observation.
%   Axes     once the type has drawn, the panel's own axis sides and labels
%            (panelAxes): its x axis' ticks and label on the bottom or the
%            top (SPEC.panels(k).xSide; a coherence panel's on top of its
%            magnitude, its phase strip dropping them), its y axis' on the
%            left or the right (ySide; not a stacked line panel's -- a
%            PSTH, continuous, spectrum, coherence or tuning panel with
%            options.stack -- which has one on each side); xLabel and yLabel, when set, replace the labels
%            drawn. A color bar outside on the side an axis moves to goes
%            to the opposite side.
%   Time     every panel sharing the figure's time axis (sharesTime; a
%            spectrogram, a coherogram on the epochs too) shows
%            [SPEC.window.pre post] (set on each: no linkaxes);
%            figureTimeStack labels a column's stack of time panels once,
%            at its bottom (at its top when their x axes are on top), and
%            drops the inner x tick labels.
%   Title    SPEC.title, else "<id>: <observation> — <event> (<n> epochs)"
%            (a dataset figure names no observation; a figure with no
%            aligned panel no event; a figure merged across sessions,
%            figureSessionCompute, "(<N> sessions, <n> epochs)"); the
%            dataset as its subtitle ("3 sessions (SYNTH-01)" across
%            sessions). With Style.ShowArtifactNote, a line under the
%            subtitle when drawn epochs touch an artifact period (a
%            selection with excludeArtifacts off keeps them): "3 of 40
%            epochs touch an artifact period", by panel when the panels'
%            epochs differ. A merged F draws as one dataset's: its groups are
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
%            coherence panel's x overlays on its phase strip too, which
%            takes the bottom third of its plot area); the note (drawNote)
%            placed below, above, left or right takes a band of the
%            panel's area beside its axes (a hidden axes, Tag "noteHost",
%            holding the text and the panel's labels on that side; fitted
%            to the text once its looks are final, at most half the area;
%            a band below or above keeps the axes' left edge and width
%            those of a plain panel; a panel with a band left or right, or
%            smaller than its cell, keeps its own time tick labels:
%            figureTimeStack), placed over the panel or at x, y it sits in
%            the axes (placeNote). Their own looks are rules after the
%            design's and the user's and before SPEC.aesthetics.
%   Legend   one, in a band east of the panels (Style.LegendLocation: or
%            north, south, west; "inside" in a panel; placeLegend):
%            the trial groups once (as a PSTH panel draws them, else a
%            continuous one, else a raster's bands), then the panels'
%            layer, unit, channel and mark entries, each label once. A
%            panel with a trial selection of its own (F.panels(k).
%            ownSelection) colors its own groups (groupPalette of its
%            groups) and lists its entries in a legend of its own inside
%            it (placeLegend, "inside"); its title then says its grouping
%            ("by <parameter>", "all trials") when it is not the figure's.
%   Style    SPEC.style: FontSize, LineWidth, ShowSEM, the Error* band
%            look, ShowZeroLine, ShowStop, ShowArtifactNote, Grid, Legend*, Colormap,
%            HeatColormap, SortShank / SortDepth, LabelShank / LabelDepth,
%            SiteSize. Its XLim, YLim and CLim are not used: the time
%            panels show the window, and each panel has its own
%            options.yLimMode / yLim / cLim (panelYLimits: a panel with
%            yLimMode "batch" takes the range BatchYLim gives it, else
%            its own).
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
%     OnGoto          called with a right-clicked part's role and its panel's id
%                     ("" for the figure's own parts) by the menu's "Go to
%                     setting" (the app goes to the figure editor's setting
%                     that controls the part: figureRoleSettings); [] (default):
%                     the menu has no such item
%     OnAxisEdit      called with the ids of the panels to change (a string
%                     row: the right-clicked one, or every panel of the
%                     figure for "Move every panel's X axis to top", ...)
%                     and the panel fields the right-click menu of an axis
%                     label or a panel's axes changed (a struct of xLabel,
%                     yLabel, xSide or ySide: "Edit label text...", "Move
%                     to top", "Edit X label text...", ...); the app keeps
%                     them in its config and draws the figure again. []
%                     (default): the figure is drawn again here with them
%                     (they are not kept)
%     DataTips        "auto" (default: in a visible figure), true or false:
%                     data tips that name the point's quantities, trial,
%                     unit or channel, panel and dataset (FigureDataTips;
%                     the fields are the user's preference)
%     BatchYLim       a run's shared y ranges (figureBatchYLim: a struct
%                     array of id, lim, n): a panel of that id with
%                     options.yLimMode "batch" draws at lim; [] (default) =
%                     none, each such panel takes its own range
%     Reuse           false (default) or true (the app's preview): TARGET (a
%                     figure, panel or tab) keeps what was drawn (appdata
%                     FigureDrawing), and the next drawing with Reuse keeps
%                     the panels of the last one that would be drawn alike:
%                     the same result (F.panels(k)), panel spec, group colors
%                     and batch range, while what every panel depends on is
%                     the same too (F but its panels, SPEC but its panels'
%                     contents, every panel's place, sides, time axis and
%                     note, the style, the design, the remembered looks, the
%                     size of TARGET). Only the other panels are drawn
%                     again; the kept ones go back to where a new panel
%                     starts and everything drawn across the panels (tick
%                     sizes, the time stack, the legend, the title, the
%                     looks, the layout) is done again over all of them, so
%                     the figure is the one a whole drawing makes. A time
%                     panel drawn again whose x limits are not the figure's
%                     window (it could change its neighbors' time axis)
%                     draws everything; so does any other change. Kept
%                     parts keep their right-click menus and data tips.
%
%   H fields
%     layout  what the figure is laid out on (TARGET, or the panel made in
%             a grid layout): its axes, the hidden axes of its title (Tag
%             "titleHost") and note bands, its legend ([] for an axes
%             TARGET)
%     axes    the panels' axes drawn, in panel order
%     panels  one per SPEC.panels: id, type, axes (empty when not drawn),
%             extraAxes (a coherence panel's phase axes, drawn under its
%             magnitude; dressed with the panel type's looks),
%             note (its text, empty without one), overlays (the lines
%             and patches drawn) and yExtent (a panel with yLimMode: its
%             y extent in its values' units, [lo hi], the draw function's
%             (a stack's rows) else its axes' y limits as drawn; [NaN NaN]
%             otherwise), which figureYExtents reads for a run's range
%     title   the figure's title text
%   Errors: renderFigure:Mismatch (F's panels are not SPEC's),
%   renderFigure:BadTarget.
%
%   See also EphysAnalysisRunner.computeFigure, figurePanelRegistry,
%   EphysAnalysisConfig.figureFor, figureLayout, renderChronux,
%   PlotAesthetics.

arguments
    F (1,1) struct
    spec (1,1) struct
    target
    opts.Design = ""
    opts.UserAesthetics (1,1) logical = true
    opts.Editable = "auto"
    opts.OnRemember = []
    opts.OnGoto = []
    opts.OnAxisEdit = []
    opts.DataTips = "auto"
    opts.BatchYLim = []
    opts.Reuse (1,1) logical = false
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

PT = EphysAnalysisConfig.panelTypes();
reg = figurePanelRegistry();
G = F.groups;
colors = zeros(0, 3);
if istable(G) && height(G) > 0; colors = groupPalette(G, style); end
isTime = false(1, np);
own = false(1, np);         % a panel with a trial selection of its own
colorsOf = cell(1, np);     % each panel's group colors: such a panel colors its own groups
for k = 1:np
    row = PT.Type == types(k);
    isTime(k) = any(row) && (PT.SharesTime(row) || overEpochs(panels(k)));
    P = F.panels(k);
    own(k) = isfield(P, 'ownSelection') && P.ownSelection && istable(P.groups) && height(P.groups) > 0;
    colorsOf{k} = colors;
    if own(k); colorsOf{k} = groupPalette(P.groups, style); end
end
cells = panelCells(spec.grid, panels);
kept = false(1, np);   % the panels whose drawing is kept from the last one (Reuse)
prior = [];
if opts.Reuse
    keys = drawingKeys(F, spec, style, design, opts, colorsOf, isTime, target);
    prior = priorDrawing(target, keys);
    if ~isempty(prior); kept = prior.same; end
end
if any(kept)
    canvas = target;
    ax0 = [];
    keepOnly(canvas, prior, kept);   % the rest of the last drawing goes
else
    [canvas, ax0] = figureCanvas(target);
end
if ~isempty(canvas); L0 = firstLayout(canvas, spec.grid, panels, cells, style); end
nDraw = np;
if ~isempty(ax0); nDraw = min(1, np); end
axs = gobjects(1, np);
extra = cell(1, np);   % each panel's further axes (a coherence panel's phase)
hks = cell(1, np);
notes = cell(1, np);   % each panel's note (drawNote's N) and the band that holds it beside the axes ([] = in the axes)
bands = cell(1, np);
ovls = cell(1, np);    % each panel's overlays (drawOverlays' O)
yExt = NaN(np, 2);     % each panel's y extent (a panel with yLimMode), for a run's batch range
for k = 1:nDraw
    p = panels(k);
    P = F.panels(k);
    if kept(k)   % drawn alike before (Reuse): its parts, back where they were before the layout placed them
        axs(k) = prior.axes(k);
        [extra{k}, hks{k}, notes{k}, bands{k}, ovls{k}] = deal(prior.extra{k}, prior.hks{k}, prior.notes{k}, prior.bands{k}, prior.ovls{k});
        yExt(k, :) = prior.yExt(k, :);
        A = prior.parts{k};
        for i = 1:numel(A)
            set(A(i), 'Units', 'pixels', 'Position', prior.pos{k}(i, :));
            cb = A(i).Colorbar;
            if ~isempty(cb) && isvalid(cb); cb.Location = cb.Location; end   % placed from its axes again, as a new one is
        end
        continue
    end
    band = [];
    if isempty(ax0)   % the panel's axes at its first place (figureLayout places it once its labels are known)
        ax = axes(canvas, 'Units', 'pixels', 'Position', L0.panels(k).box);
        setappdata(ax, 'FigurePanel', p.id);   % a panel of the layout (drawCoherencePanel splits it for its phase)
        if besideNote(p)
            band = axes(canvas, 'Units', 'pixels', 'Position', max(L0.panels(k).band, [-Inf -Inf 1 1]), 'Visible', 'off', ...
                'HitTest', 'off', 'PickableParts', 'none', 'XLim', [0 1], 'YLim', [0 1], 'Tag', 'noteHost');
        end
    else
        ax = ax0;
    end
    look = lookFor(F, spec, p, P, style, colorsOf{k}, isTime(k));
    look.batchYLim = batchFor(opts.BatchYLim, p.id);
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
    if own(k); ttl = groupingTitle(ttl, p, spec); end
    if ttl ~= ""; title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none'); end
    if own(k)   % its groups are not the figure's: a legend of its own, inside it; the figure's legend serves the others
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
    yExt(k, :) = extentOf(hk, ax, p);
    if isfield(hk, 'extraAxes'); extra{k} = hk.extraAxes(isgraphics(hk.extraAxes)); end
    panelAxes([ax reshape(extra{k}, 1, [])], p);   % its own axis sides and labels, over what its type drew
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
if opts.Reuse && ~isempty(canvas)   % each panel's parts where they are before the layout places them (Reuse keeps them)
    parts = cell(1, np);
    pos = cell(1, np);
    for k = find(drawn)
        A = axs(k);   % in the order a drawing makes them: its axes, its note band, its further axes
        if ~isempty(bands{k}) && isgraphics(bands{k}); A = [A bands{k}]; end %#ok<AGROW>
        A = [A reshape(extra{k}, 1, [])]; %#ok<AGROW>
        parts{k} = A;
        q = get(A, 'Position');
        if ~iscell(q); q = {q}; end
        pos{k} = vertcat(q{:});
    end
    if any(kept)   % the kept axes are older: every panel's axes in panel order again (the aesthetics editor numbers its tiles so)
        A = reshape([parts{:}], [], 1);
        kids = canvas.Children;   % newest first
        at = arrayfun(@(c) any(c == A), kids);
        if nnz(at) == numel(A) && ~isequal(kids(at), flipud(A))
            kids(at) = flipud(A);
            canvas.Children = kids;
        end
    end
end
multi = nnz(drawn) > 1;
if multi; tileTicks(axs(drawn), style); end
labelSize = [];
if multi; labelSize = style.FontSize; end
sided = false(1, np);   % a band left or right of a panel's axes, or a panel smaller than its cell: not the column's width
for k = 1:np; sided(k) = isempty(ax0) && (sideNote(panels(k)) || any(cells(k).size < 1)); end
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
note = "";   % the drawn epochs that touch an artifact period: a line under the subtitle
if style.ShowArtifactNote; note = artifactNote(F, panels, drawn); end
th = [];
if ~isempty(canvas)   % a hidden axes whose title and subtitle are the figure's (PlotAesthetics: plotTitle, plotSubtitle)
    th = axes(canvas, 'Units', 'pixels', 'Position', [1 1 1 1], 'Visible', 'off', 'HitTest', 'off', 'Tag', 'titleHost');
    title(th, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none', 'Visible', 'on');
    lines = [sub; note];
    lines = lines(lines ~= "");
    if ~isempty(lines); subtitle(th, lines, 'FontSize', style.FontSize, 'Interpreter', 'none', 'Visible', 'on'); end
elseif ~isempty(ax0)
    was = string(ax0.Title.String);
    title(ax0, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none');
    parts = [reshape(was(was ~= ""), 1, []) sub(sub ~= "")];
    lines = note(note ~= "");
    if ~isempty(parts); lines = [strjoin(parts, " | "); lines]; end
    if ~isempty(lines); subtitle(ax0, lines, 'FontSize', style.FontSize, 'Interpreter', 'none'); end
end

% one legend: the groups once, then the layers', units', channels' and marks' entries
lgd = [];
if style.Legend && any(drawn)
    [lh, ll] = legendEntries(hks, types, G);
    if ~isempty(lh)
        ls = style;
        side = legendSide(style);
        if ~isempty(canvas) && side ~= ""   % in the band beside the panels figureLayout gives it
            ls.LegendLocation = "none";
            if string(ls.LegendOrientation) == "auto" && ismember(side, ["north" "south"]); ls.LegendOrientation = "horizontal"; end
        end
        lgd = placeLegend(legendHost(axs(drawn), canvas), lh, ll, ls, [], "east");
    end
end

% aesthetics: the design's common rules, each panel's kind, then the figure's
root = canvas;
if isempty(root); root = ax0; end
specRules = PlotAesthetics.normalizeRules(spec.aesthetics);
PlotAesthetics.apply(root, design.rules);
kRules = cell(1, np);
for k = find(drawn)
    r = kindRules(design, types(k));
    if opts.UserAesthetics && isvarname(types(k)); r = [r PlotAesthetics.userRules(types(k))]; end %#ok<AGROW>
    if types(k) == "raster" && isfield(panels(k).options, 'tickWidth') && panels(k).options.tickWidth > 0
        % the panel's tick width wins over the design's and the user's kind rules (the figure's own rules still win)
        r = [r PlotAesthetics.normalizeRules(struct('role', "rasterTicks", 'group', "", 'property', "LineWidth", ...
            'value', panels(k).options.tickWidth))]; %#ok<AGROW>
    end
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
if isempty(canvas)   % one axes: its note goes where it belongs once its looks are final (its size measured)
    for k = find(drawn)
        if ~isempty(notes{k}) && ~isempty(notes{k}.text); placeNote(notes{k}, panels(k).note); end
    end
else   % the layout, once everything is drawn and dressed: every axes, band, the legend and the title, then the notes
    figureLayout(canvas, layoutOf(spec, panels, cells, axs, extra, notes, bands, th, lgd, style));
end
if editable(opts.Editable, target)
    mapField = "";
    aurocMap = false;   % a heat map of auROCs is drawn in the diverging colormap
    heat = types == "heatmap";
    for k = find(types == "psth")   % a PSTH drawn as a heat map
        heat(k) = isfield(panels(k).options, 'display') && panels(k).options.display == "heatmap";
    end
    for k = find(heat)
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
    elseif any(heat) || any(ismember(types, ["probemap" "spectrogram"])) || cohgram
        mapField = "heat";
    end
    ordinal = istable(G) && ismember('color', G.Properties.VariableNames) && isOrdinalGroups(G);
    ctx = struct('kind', "figure", 'id', spec.id, 'title', txt, 'root', root, 'target', target, 'plotRules', specRules, ...
        'onRemember', {opts.OnRemember}, 'onGoto', {opts.OnGoto}, 'design', design, 'followsDesign', follows, 'ordinal', ordinal, 'mapField', mapField, ...
        'redraw', @(newRules) renderFigure(F, setfield(spec, 'aesthetics', newRules), target, Design=opts.Design, ...
            UserAesthetics=opts.UserAesthetics, Editable=opts.Editable, OnRemember=opts.OnRemember, OnGoto=opts.OnGoto, ...
            OnAxisEdit=opts.OnAxisEdit, BatchYLim=opts.BatchYLim));
    ctx.panelTypes = struct('id', sIds, 'type', types);   % each tile's panel type by the id it is tagged with (PlotDesign.capture)
    ctx.panelIds = sIds;   % "Move every panel's X axis to top": every panel of the figure
    ctx.onAxisEdit = @(panel, change) axisEdited(F, spec, target, opts, panel, change);   % an axis label's or axes' menu (PlotAesthetics)
    PlotAesthetics.enableEditing(target, ctx);
end

hp = repmat(struct('id', "", 'type', "", 'axes', gobjects(0), 'extraAxes', gobjects(0), 'note', gobjects(0), ...
    'overlays', gobjects(1, 0), 'yExtent', [NaN NaN]), 1, np);
for k = 1:np
    hp(k).id = panels(k).id;
    hp(k).type = types(k);
    hp(k).yExtent = yExt(k, :);
    if drawn(k)
        hp(k).axes = axs(k);
        hp(k).extraAxes = extra{k};
        if ~isempty(notes{k}); hp(k).note = notes{k}.text; end
        if ~isempty(ovls{k}); hp(k).overlays = ovls{k}.handles; end
    end
end
h = struct('layout', canvas, 'axes', axs(drawn), 'panels', hp, 'title', txt);
if editable(opts.DataTips, target)   % after the right-click menus: it adds its item to them
    hT = h;
    for k = find(kept)   % a kept panel's parts have theirs
        hT.panels(k).axes = gobjects(0);
        hT.panels(k).extraAxes = gobjects(0);
    end
    FigureDataTips.attach(F, spec, hT);
end
if opts.Reuse && ~isempty(canvas) && isequal(canvas, target)   % what the next drawing with Reuse can keep
    setappdata(target, drawingAppdata(), struct('keys', keys, 'axes', axs, 'extra', {extra}, 'hks', {hks}, 'notes', {notes}, ...
        'bands', {bands}, 'ovls', {ovls}, 'yExt', yExt, 'parts', {parts}, 'pos', {pos}, 'legend', lgd, 'title', th));
elseif isappdata(target, drawingAppdata())
    rmappdata(target, drawingAppdata());
end
end


function panelAxes(A, p)
%panelAxes  A panel's own axis sides and label texts over what its type drew: P.xSide, ySide, xLabel, yLabel.
%   A: the panel's axes, top to bottom (a coherence panel's phase strip
%   under its magnitude). Each one's y axis goes to P.ySide, but a yyaxis'
%   (a stacked line panel's: a y axis on each side already). With P.xSide "top"
%   the first axes' x axis goes on top, with the tick labels and label the
%   last one had (the axes under it drop theirs). A label of the panel's
%   own replaces the one drawn: the x label on the axes that shows the x
%   axis (on a time axis figureTimeStack decides whether it shows), the
%   first axes' y label (a yyaxis' left one). A color bar outside on the
%   side an axis moves to goes to the opposite side, out of its labels'
%   way.
A = A(isgraphics(A));
if isempty(A); return; end
top = A(1);
if p.ySide == "right"
    for a = A
        if isscalar(a.YAxis); a.YAxisLocation = 'right'; end
    end
end
xa = A(end);   % the axes whose x axis shows its tick labels and label
if p.xSide == "top"
    top.XAxisLocation = 'top';
    if numel(A) > 1   % the strip under it told the x axis: the first one tells it now
        lab = A(end).XLabel;
        xlabel(top, lab.String, 'Interpreter', lab.Interpreter, 'FontSize', lab.FontSize);
        top.XTickLabelMode = 'auto';
        for a = A(2:end)
            a.XTickLabel = [];
            a.XLabel.String = '';
        end
    end
    xa = top;
end
if p.xLabel ~= ""; xlabel(xa, p.xLabel, 'Interpreter', 'none'); end
if p.yLabel ~= ""
    set(top.YAxis(1).Label, 'String', p.yLabel, 'Interpreter', 'none');   % (a yyaxis: its left one)
end
for a = A
    cb = a.Colorbar;
    if isempty(cb) || ~isvalid(cb); continue; end
    loc = string(cb.Location);
    if p.ySide == "right" && loc == "eastoutside"
        cb.Location = 'westoutside';
    elseif p.xSide == "top" && loc == "northoutside"
        cb.Location = 'southoutside';
    end
end
end


function axisEdited(F, spec, target, opts, panel, change)
%axisEdited  A right-click axis edit of the panels PANEL (ids; CHANGE: their new xLabel, yLabel, xSide or ySide).
%   OnAxisEdit keeps it (the app: in its config, then it draws the figure
%   again); without one the figure is drawn again here with it.
if ~isempty(opts.OnAxisEdit)
    opts.OnAxisEdit(panel, change);
    return
end
ks = find(ismember([spec.panels.id], panel));
if isempty(ks); return; end
for k = ks
    for f = string(fieldnames(change)).'
        spec.panels(k).(f) = change.(f);
    end
end
args = namedargs2cell(opts);
renderFigure(F, spec, target, args{:});
end


function lim = batchFor(B, id)
%batchFor  The run's shared y range for panel ID (BatchYLim: id, lim), [] when it has none.
lim = [];
if isempty(B) || ~isstruct(B) || ~isfield(B, 'id'); return; end
k = find([B.id] == id, 1);
if ~isempty(k); lim = B(k).lim; end
end


function k = drawingAppdata()
%drawingAppdata  The appdata of a target that keeps its last drawing for the next one (Reuse).
k = 'FigureDrawing';
end


function K = drawingKeys(F, spec, style, design, opts, colorsOf, isTime, target)
%drawingKeys  What a drawing depends on (Reuse): global (what every panel's does) and each panel's own.
%   global  F but its panels and creation time; SPEC but its panels and
%           its id (its title only as there being one: the top-left panel
%           then names the observation); each panel's id, type, place,
%           sides, time axis and note (the time stack, the layout and the
%           draw functions' inTimeColumn read them across panels); the
%           style, the design, the user's remembered looks of the panels'
%           kinds and of "figure"; BatchYLim; editing and data tips on;
%           TARGET's size in pixels
%   panels  each one's result (F.panels(k)), spec, group colors, time
%           axis and batch range
%   ownTime  each panel on a time axis whose x limits are not the
%           figure's window (its own window, or one from event to event)
P = spec.panels;
np = numel(P);
place = struct('id', {}, 'type', {}, 'cell', {}, 'align', {}, 'xSide', {}, 'ySide', {}, 'sharesTime', {}, 'note', {});
for k = 1:np
    place(k) = struct('id', P(k).id, 'type', P(k).type, 'cell', {[P(k).row P(k).col P(k).rowSpan P(k).colSpan ...
        reshape(double(P(k).size), 1, [])]}, 'align', string(P(k).align) + "|" + string(P(k).valign), 'xSide', P(k).xSide, ...
        'ySide', P(k).ySide, 'sharesTime', P(k).sharesTime, 'note', P(k).note);
end
Fg = rmfield(F, intersect({'panels' 'created' 'spec'}, fieldnames(F)));
Sg = rmfield(spec, intersect({'panels' 'id' 'autoId' 'enabled' 'title'}, fieldnames(spec)));
Sg.titled = spec.title ~= "";
rules = struct();
if opts.UserAesthetics
    for t = unique([string([P.type]) "figure"])
        if isvarname(t); rules.(t) = PlotAesthetics.userRules(t); end
    end
end
sz = [0 0];
try
    q = getpixelposition(target);
    sz = q(3:4);
catch
end
K = struct();
K.global = struct('F', Fg, 'spec', Sg, 'place', place, 'style', style, 'design', design, 'rules', rules, ...
    'batch', {opts.BatchYLim}, 'editable', editable(opts.Editable, target), 'tips', editable(opts.DataTips, target), 'size', sz);
K.panels = cell(1, np);
K.ownTime = false(1, np);
for k = 1:np
    K.panels{k} = struct('P', F.panels(k), 'p', P(k), 'colors', colorsOf{k}, 'isTime', isTime(k), ...
        'batch', {batchFor(opts.BatchYLim, P(k).id)});
    K.ownTime(k) = isTime(k) && ~(P(k).sharesTime && ~isempty(fixedWindow(P(k).window)));
end
end


function prior = priorDrawing(target, keys)
%priorDrawing  TARGET's last drawing (Reuse) with same(k) true for each panel that would be drawn alike now; [] = draw everything.
%   Only a figure, panel or tab (its own canvas) keeps one. Everything is
%   drawn when the global key differs, when the panels differ in number,
%   or when a time panel with x limits of its own is drawn again (its
%   neighbors' time axis could change: figureTimeStack).
prior = [];
if ~(isa(target, 'matlab.ui.Figure') || isa(target, 'matlab.ui.container.Panel') || isa(target, 'matlab.ui.container.Tab')) ...
        || ~isappdata(target, drawingAppdata())
    return
end
D = getappdata(target, drawingAppdata());
np = numel(keys.panels);
if ~isstruct(D) || numel(D.keys.panels) ~= np || ~isequaln(D.keys.global, keys.global); return; end
same = false(1, np);
for k = 1:np
    same(k) = isgraphics(D.axes(k)) && all(isgraphics(D.parts{k})) && isequaln(D.keys.panels{k}, keys.panels{k});
end
if any(~same & keys.ownTime); return; end
prior = D;
prior.same = same;
end


function keepOnly(canvas, prior, kept)
%keepOnly  Delete what CANVAS holds but the kept panels' parts: their axes, further axes, note bands, and their color bars and own legends.
%   The figure's legend (on a panel's axes, or a hidden host) and title go:
%   they are made again.
keep = gobjects(1, 0);
for k = find(kept)
    for a = reshape(prior.parts{k}, 1, [])
        keep = [keep a]; %#ok<AGROW>
        if isprop(a, 'Colorbar') && ~isempty(a.Colorbar) && isvalid(a.Colorbar); keep = [keep a.Colorbar]; end %#ok<AGROW>
        if isprop(a, 'Legend') && ~isempty(a.Legend) && isvalid(a.Legend) && ~isequal(a.Legend, prior.legend)
            keep = [keep a.Legend]; %#ok<AGROW>
        end
    end
end
if ~isempty(prior.legend) && isgraphics(prior.legend); delete(prior.legend); end
gone = canvas.Children;
gone = gone(arrayfun(@(g) ~any(g == keep), gone));
delete(gone);
end


function W = fixedWindow(w)
%fixedWindow  [pre post] of a fixed epoch window W, [] for any other (between events, or none).
W = [];
if isstruct(w) && all(isfield(w, {'pre' 'post'})) && (~isfield(w, 'mode') || w.mode == "fixed")
    W = double([w.pre w.post]);
    if ~(numel(W) == 2 && all(isfinite(W)) && W(2) > W(1)); W = []; end
end
end


function e = extentOf(hk, ax, p)
%extentOf  A panel's y extent as drawn (yLimMode panels only): the draw function's yExtent, else its axes' y limits.
e = [NaN NaN];
if ~isfield(p.options, 'yLimMode'); return; end
if isfield(hk, 'yExtent') && numel(hk.yExtent) == 2 && all(isfinite(hk.yExtent))
    e = double(reshape(hk.yExtent, 1, 2));
elseif isgraphics(ax) && isscalar(ax.YAxis)
    e = double(ylim(ax));
end
end


function tf = besideNote(p)
%besideNote  The panel has a note placed beside its axes (below, above, left or right): it takes a band of its area.
tf = strtrim(string(p.note.text)) ~= "" && ismember(string(p.note.placement), ["below" "above" "left" "right"]);
end


function tf = sideNote(p)
%sideNote  The panel's note takes a band left or right of its axes: they are narrower than a plain panel's in the column.
tf = besideNote(p) && ismember(string(p.note.placement), ["left" "right"]);
end


function C = panelCells(grid, panels)
%panelCells  Each panel's rows and columns (clipped to the grid), its size in its cell and its alignment there.
nr = max(1, round(double(grid.rows)));
nc = max(1, round(double(grid.cols)));
C = struct('r1', {}, 'r2', {}, 'c1', {}, 'c2', {}, 'size', {}, 'align', {}, 'valign', {});
for k = 1:numel(panels)
    p = panels(k);
    r = min(max(1, round(p.row)), nr);
    c = min(max(1, round(p.col)), nc);
    s = double(p.size);
    if ~(numel(s) == 2 && all(isfinite(s) & s > 0)); s = [1 1]; end
    C(k) = struct('r1', r, 'r2', min(nr, r + max(1, round(p.rowSpan)) - 1), 'c1', c, ...
        'c2', min(nc, c + max(1, round(p.colSpan)) - 1), 'size', min(reshape(s, 1, 2), 1), ...
        'align', string(p.align), 'valign', string(p.valign));
end
end


function L = firstLayout(canvas, grid, panels, cells, style)
%firstLayout  Where the panels' axes and note bands go before anything is drawn: labels and bands estimated from the font size.
%   figureLayout places them once they are drawn; this is where they are
%   drawn (a draw function sees a plot of about its final size).
px = 96 / 72 * style.FontSize;   % the font size in pixels
sz = [700 500];   % the canvas's size, when it cannot be read yet
try
    p = getpixelposition(canvas);
    if all(p(3:4) > 40); sz = p(3:4); end
catch
end
C = struct('r1', {}, 'r2', {}, 'c1', {}, 'c2', {}, 'size', {}, 'align', {}, 'valign', {}, 'inset', {}, ...
    'band', {}, 'need', {}, 'shares', {});
for k = 1:numel(panels)
    c = cells(k);
    band = "";
    need = 0;
    if besideNote(panels(k))
        note = panels(k).note;
        fs = style.FontSize;
        if isfinite(note.fontSize) && note.fontSize > 0; fs = note.fontSize; end
        lines = splitlines(strip(string(note.text), 'right'));
        tall = numel(lines) * fs * 1.3;   % points
        wide = max(strlength(lines)) * fs * 0.6;
        if abs(sind(note.rotation)) > 0.7; [tall, wide] = deal(wide, tall); end
        band = string(note.placement);
        if ismember(band, ["below" "above"])
            need = 96 / 72 * tall + 3 * px + 12;
        else
            need = 96 / 72 * wide + 4.5 * px + 12;
        end
    end
    ins = [4.5 3 0.5 0] * px;   % [left bottom right top]: the y labels left, the x labels below
    if panels(k).ySide == "right"; ins([1 3]) = ins([3 1]); end
    if panels(k).xSide == "top"; ins([2 4]) = ins([4 2]); end
    C(k) = struct('r1', c.r1, 'r2', c.r2, 'c1', c.c1, 'c2', c.c2, 'size', c.size, 'align', c.align, 'valign', c.valign, ...
        'inset', ins, 'band', band, 'need', need, 'shares', 1);
end
L = figureArrange(sz, grid, C, Top=3 * px, Margin=6);
end


function S = layoutOf(spec, panels, cells, axs, extra, notes, bands, th, lgd, style)
%layoutOf  What figureLayout lays out: each panel's axes (a coherence panel's phase under its magnitude, a third of it), note and band, the title and the legend.
P = struct('axes', {}, 'shares', {}, 'r1', {}, 'r2', {}, 'c1', {}, 'c2', {}, 'size', {}, 'align', {}, 'valign', {}, ...
    'note', {}, 'text', {}, 'band', {});
for k = 1:numel(panels)
    c = cells(k);
    A = [axs(k) reshape(extra{k}, 1, [])];
    t = [];
    if ~isempty(notes{k}) && ~isempty(notes{k}.text); t = notes{k}.text; end
    P(k) = struct('axes', A, 'shares', [2 ones(1, numel(A) - 1)], 'r1', c.r1, 'r2', c.r2, 'c1', c.c1, 'c2', c.c2, ...
        'size', c.size, 'align', c.align, 'valign', c.valign, 'note', panels(k).note, 'text', t, 'band', bands{k});
end
S = struct('grid', spec.grid, 'panels', P, 'title', th, 'legend', lgd, 'side', legendSide(style), 'margin', 6);
end


function side = legendSide(style)
%legendSide  The side of the panels the figure's legend takes a band on: "north", "south", "east" (auto) or "west"; "" in a panel (inside).
side = string(style.LegendLocation);
if side == "auto"; side = "east"; end
if ~ismember(side, ["north" "south" "east" "west"]); side = ""; end
end


function tf = overEpochs(p)
%overEpochs  A coherence panel drawn over time from the event (a coherogram on the aligned time base): a time panel.
o = p.options;
tf = p.type == "coherence" && isfield(o, 'overTime') && o.overTime && isfield(o, 'timeBase') && o.timeBase == "aligned";
end


function look = lookFor(F, spec, p, P, style, colors, isTime)
%lookFor  What a panel's draw function is given besides its result (figurePanelRegistry's LOOK).
W = fixedWindow(p.window);
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


function host = legendHost(axs, canvas)
%legendHost  The axes that holds the figure's legend: the first panel without a legend of its own.
%   Else, on the canvas, a hidden axes (tagged "legendHost", left out of
%   the tiles as placeLegend's are); drawn into one axes, that axes (its
%   legend is replaced: the draw functions offer their entries up).
for ax = reshape(axs, 1, [])
    if isempty(ax.Legend) || ~isvalid(ax.Legend)
        host = ax;
        return
    end
end
if ~isempty(canvas) && isgraphics(canvas)
    host = axes(canvas, 'Units', 'pixels', 'Position', [1 1 1 1], 'Visible', 'off', 'HitTest', 'off', ...
        'PickableParts', 'none', 'Tag', 'legendHost');
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


function t = artifactNote(F, panels, drawn)
%artifactNote  "<a> of <n> epochs touch an artifact period": the drawn panels' epochs kept with one; "" when none is.
%   Each drawn panel on epochs counts its own (F.panels(k).epochs), else
%   the figure's, by their artifact column (epochTable's: only a selection
%   with excludeArtifacts off keeps such epochs). Panels with one count
%   share one sentence; when the counts differ, each names its panels:
%   "Epochs that touch an artifact period: 3 of 40 (raster_1, psth_1);
%   5 of 38 (psth_2)".
t = "";
counts = zeros(0, 2);
names = strings(0, 1);
for k = find(drawn)
    P = F.panels(k);
    if P.skip ~= "" || ~istable(P.groups) || ~any([P.layers.skip] == ""); continue; end   % not on epochs, or nothing drawn
    E = P.epochs;
    if ~istable(E); E = F.epochs; end
    if ~istable(E) || ~ismember("artifact", string(E.Properties.VariableNames)); continue; end
    counts(end+1, :) = [nnz(E.artifact) height(E)]; %#ok<AGROW>
    names(end+1, 1) = panels(k).title; %#ok<AGROW>
    if names(end) == ""; names(end) = panels(k).id; end
end
if ~any(counts(:, 1) > 0); return; end
[u, ~, j] = unique(counts, 'rows', 'stable');
if size(u, 1) == 1
    t = sprintf("%d of %d epochs touch an artifact period", u(1), u(2));
    return
end
parts = strings(1, 0);
for i = reshape(find(u(:, 1) > 0), 1, [])
    parts(end+1) = sprintf("%d of %d (%s)", u(i, 1), u(i, 2), strjoin(reshape(names(j == i), 1, []), ", ")); %#ok<AGROW>
end
t = "Epochs that touch an artifact period: " + strjoin(parts, "; ");
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
