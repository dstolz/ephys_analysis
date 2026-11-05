function [h, how] = renderFigure(F, spec, target, opts)
%renderFigure  Draw one computed figure: its panels at their places on the page, with one legend and the figure's title.
%   [H, HOW] = renderFigure(F, SPEC, TARGET, Name=Value) draws F, the result of
%   EphysAnalysisRunner.computeFigure (one observation of a figure: a unit,
%   a channel or the dataset), as SPEC says (Config.figureFor(id): the spec
%   F was computed with, its aesthetics free to differ, as when the
%   aesthetics editor redraws it). TARGET is an axes, uiaxes, figure,
%   uifigure, panel, tab or grid layout: renderers never create figures.
%
%   Layout   its own engine, not MATLAB's tiled layout: TARGET (emptied;
%            a grid layout gets a panel: figureCanvas) holds one axes per
%            panel, which figureLayout places in pixels once everything
%            is drawn and dressed, and again whenever TARGET changes size:
%            each panel at its rect (SPEC.panels(k).rect, 0-1 of the page
%            inside a margin, from its bottom-left corner), the title over
%            the page (figureArea), each plot area moved in only as far as
%            its labels need to keep SPEC.layout.padding clear of its
%            neighbors' labels and the page's edge (figurePlace; with
%            layout.boxesMean "outer" a rect holds the panel with its
%            labels). Panels put flush stay flush; plot edges that line up
%            stay lined up. An axes TARGET draws panel 1 only.
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
%            to the opposite side. Last of all (after the time stack),
%            xShow and yShow blank what the panel leaves out: "ticks" its
%            label, "label" its ticks (marks and numbers), "none" both
%            (blankAxes; every y axis of a yyaxis).
%   Time     every panel sharing the figure's time axis (sharesTime; a
%            spectrogram, a coherogram on the epochs too) shows
%            [SPEC.window.pre post] (set on each: no linkaxes);
%            figureTimeStack labels a stack of time panels put flush one
%            on the other once, at its bottom (at its top when their x
%            axes are on top), and drops the inner x tick labels; panels
%            with a gap between them keep theirs.
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
%   Variables  the label variables (figureLabelVariables: {Line},
%            {Response}, {Unit}, ...) in SPEC.title, a panel's title, xLabel,
%            yLabel and note text and a layer's name are filled in for F
%            (figureLabelFill; each panel's with its own alignment and trial
%            selection) before anything is drawn. A title of the figure's
%            own that names {Unit} or {Observation} is not followed by the
%            observation on the top-left panel; one that names {Group}
%            gets no "· <group>". The right-click editor edits the texts as
%            typed, with their variables.
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
%            those of a plain panel; a panel with a band left or right
%            keeps its own time tick labels: figureTimeStack), placed over
%            the panel or at x, y it sits in
%            the axes (placeNote). Their own looks are rules after the
%            design's and the user's and before SPEC.aesthetics.
%   Legend   one (none with Style.LegendLocation "none"): the trial groups
%            once (as a PSTH panel draws them, else a continuous one, else
%            a raster's bands), then the panels' layer, unit, channel and
%            mark entries, each label once. It never shrinks a plot area.
%            "auto": in the figure's legend panel (type "legend": its axes
%            hidden, Tag "legendHost"; the legend at its natural size,
%            aligned in the panel's box by the panel's options), else
%            floating, centered in the page's largest free space when it
%            fits there, else inside the first panel (figureLayout: again
%            at every layout); "inside": in the first panel (placeLegend).
%            A legend panel holding no legend says so in small gray text
%            in a preview (a visible figure, or Reuse), nothing in an
%            export. A
%            panel with a trial selection of its own (F.panels(k).
%            ownSelection) colors its own groups (groupPalette of its
%            groups) and lists its entries in a legend of its own inside
%            it (placeLegend, "inside"); its title then says its grouping
%            ("by <parameter>", "all trials") when it is not the figure's.
%   Style    SPEC.style: FontSize, LineWidth, ShowZeroLine, ShowStop,
%            ShowArtifactNote, Grid, Legend*, Colormap, HeatColormap,
%            SortShank / SortDepth, LabelShank / LabelDepth, SiteSize
%            (the error a panel draws and its bands' look are the
%            panel's: options.errorType, errorResamples, band). Its
%            XLim, YLim and CLim are not used: the time panels show the
%            window, and each panel has its own options.yLimMode /
%            yLim / cLim (panelYLimits: a panel with yLimMode "batch"
%            takes the range BatchYLim gives it, else its own).
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
%   Probe figures  F of kind "probeFigure" (figureProbeCompute's PF: the
%            figure computed for every unit or channel at its site on the
%            probe) is drawn by renderProbeFigure with the same options,
%            before anything is cleared, and its H and HOW are returned
%            (H: renderProbeFigure's fields; data tips there only with
%            DataTips=true; Reuse ignored, InPlaceOnly drawing nothing).
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
%     OnSelect        called with a panel's id, whether Ctrl (Cmd on a
%                     Mac) was down and whether Shift was, when the panel
%                     is clicked with Ctrl, with Shift or with the "alt"
%                     button (a Ctrl+Click reports "alt", as a right-click
%                     does, so the caller tells them apart: the figure's
%                     CurrentModifier is the second argument, and the app
%                     also has its own record of the key; a Shift+Click
%                     reports "extend"). On the panel's axes, labels and
%                     anything drawn in them; the app makes the panel the
%                     selected one of its figure editor (Shift: adds it to
%                     the panels selected, or takes it out). []
%                     (default): the panels take no such click
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
%                     the same result (F.panels(k), with the latencies it
%                     reads: an edit of the latency block draws again only
%                     the panels that read them), panel spec, group colors
%                     and batch range, while what every panel depends on is
%                     the same too (F but its panels, SPEC but its panels'
%                     contents and its layout, every panel's sides, time
%                     axis and note, which panels touch which and lie in
%                     one column (figureNeighbors of the rects) and the
%                     top-left one, the style, the design, the remembered
%                     looks, the size of TARGET; not the rects themselves:
%                     a moved panel keeps its automatic ticks until it is
%                     drawn again). Only the other panels are drawn
%                     again; the kept ones go back to where a new panel
%                     starts and everything drawn across the panels (tick
%                     sizes, the time stack, the legend, the title, the
%                     looks, the layout) is done again over all of them, so
%                     the figure is the one a whole drawing makes. A time
%                     panel drawn again whose x limits are not the figure's
%                     window (it could change its neighbors' time axis)
%                     draws everything; so does any other change. Kept
%                     parts keep their right-click menus and data tips.
%                     An edit of text only -- a panel's xLabel, yLabel or
%                     title, the figure's own title -- draws nothing: the
%                     new text is set on the label or title drawn and the
%                     layout done again from where a new drawing starts
%                     (inPlace), with the parts' data tips (they name their
%                     quantities after the labels) and the right-click
%                     editor's context (its redraw draws the new SPEC)
%                     following. Only text that shows something before and
%                     after (an empty label or title has no looks set and
%                     no menu) and that nothing else decides (a time panel
%                     with further axes; a title that is the type's own or
%                     names the observation) is set so. An edit of the
%                     panels' rects or of SPEC.layout alone (or with such
%                     text) draws nothing either: the parts go back to
%                     where a new drawing starts and figureLayout lays
%                     them out at the new rects (inPlace); one that
%                     changes which panels touch which (a time stack's
%                     labels change) or the top-left panel is drawn as
%                     above. Any other edit is drawn as above.
%     InPlaceOnly     false (default) or true: with Reuse (implied), only
%                     an edit inPlace can set is made; nothing is drawn
%                     when it cannot be (HOW is "", H []), so the caller
%                     can compute and draw as for any other edit (the app:
%                     autoFigurePreview, with no busy card for a label)
%     LayoutOnly      false (default) or true: lay the drawing TARGET keeps
%                     (from a drawing with Reuse) out at SPEC's rects and
%                     layout, whatever else differs: its parts go back to
%                     where a new drawing starts and figureLayout lays them
%                     out at the new places, the legend and the title
%                     with them; no text is set and nothing is drawn, so a
%                     time stack's labels and the top-left panel's title
%                     stay as drawn (HOW "layout"; the drawing kept is
%                     unchanged, so the next drawing with Reuse compares
%                     with what it shows). Done only when the drawing has
%                     SPEC's panels (the same ids, in order) and all its
%                     parts; else nothing (HOW "", H []). F is not read.
%                     The app's Arrange lays its preview out so after a
%                     drag (arrangedPreview), out of date or not
%     Scale           1 (default): the drawing at the sizes it is exported
%                     at. S: a drawing shown S times as wide as its export
%                     page at 96 dpi (the app's preview, drawn to fit its
%                     area): drawn as the export is (its axes first laid
%                     out on TARGET's size over S, so a draw function sees
%                     them against its fonts as the export's, and picks
%                     the same automatic ticks and limits), then every font size,
%                     line width, marker size, error bar cap and legend
%                     token times S (a scatter's marker area times S^2;
%                     PlotAesthetics.scaleSizes) and the layout's px
%                     (margin, padding, note spacing) too, before
%                     the layout. So everything keeps the proportion to the
%                     page it has in the export: whatever set the size (the
%                     style, a draw function, the design, the remembered
%                     looks, the figure's own) and however it was derived
%                     (the tick labels' FontSize - 2). The root keeps S
%                     (PlotAesthetics.drawScale): the aesthetics editor
%                     reads and sets the exported sizes
%
%   HOW: "drawn" (drawn, all of it or the panels Reuse could not keep),
%   "inplace" (only text set on the drawn handles, and the parts laid out
%   again), "layout" (LayoutOnly: laid out at SPEC's places), or ""
%   (InPlaceOnly or LayoutOnly and nothing done).
%
%   H fields
%     layout  what the figure is laid out on (TARGET, or the panel made in
%             a grid layout): its axes, the hidden axes of its title (Tag
%             "titleHost") and note bands, its legend ([] for an axes
%             TARGET). It keeps where everything went (appdata
%             FigureLayoutResult: figureLayout)
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
%   EphysAnalysisConfig.figureFor, figureLayout, renderChronux, renderProbeFigure,
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
    opts.OnSelect = []
    opts.DataTips = "auto"
    opts.BatchYLim = []
    opts.Reuse (1,1) logical = false
    opts.InPlaceOnly (1,1) logical = false
    opts.LayoutOnly (1,1) logical = false
    opts.Scale (1,1) double {mustBePositive, mustBeFinite} = 1
end
if opts.LayoutOnly   % the drawing kept, laid out at the new places: nothing drawn
    [h, how] = layoutOnly(spec, target);
    return
end
if isfield(F, 'kind') && string(F.kind) == "probeFigure"   % a probe figure (figureProbeCompute): every tile on one page
    args = namedargs2cell(rmfield(opts, 'LayoutOnly'));   % (a probe page has no layout-only path: handled above)
    [h, how] = renderProbeFigure(F, spec, target, args{:});
    return
end
how = "drawn";
if opts.InPlaceOnly; opts.Reuse = true; end

if isfield(F, 'nSessions') && isfield(spec, 'sessions')
    spec = figureSessionSpec(spec);   % merged across sessions: drawn as computed (e.g. "combine" draws a PSTH's bars as lines)
end
raw = spec;   % the texts as typed (the right-click editor edits them); the drawing's have their label variables filled in
[spec, F, titleVars] = figureLabelFill(F, spec);   % (titleVars: what the title names, as typed)
[design, follows] = figureDesignFor(opts.Design, opts.UserAesthetics);
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
    isTime(k) = any(row) && (PT.SharesTime(row) || figureOverEpochs(panels(k)));
    P = F.panels(k);
    own(k) = isfield(P, 'ownSelection') && P.ownSelection && istable(P.groups) && height(P.groups) > 0;
    colorsOf{k} = colors;
    if own(k); colorsOf{k} = groupPalette(P.groups, style); end
end
isLeg = types == "legend";   % a legend panel: its hidden axes hold the figure's legend
kept = false(1, np);   % the panels whose drawing is kept from the last one (Reuse)
prior = [];
if opts.Reuse
    keys = drawingKeys(F, spec, style, design, opts, colorsOf, isTime, target);
    h = inPlace(F, spec, target, keys, opts, own, design, follows, raw, titleVars);
    if ~isempty(h)   % only text changed: set on what is drawn
        how = "inplace";
        return
    end
    if opts.InPlaceOnly
        h = [];
        how = "";
        return
    end
    prior = priorDrawing(target, keys);
    if ~isempty(prior); kept = prior.same; end
end
if any(kept)
    canvas = target;
    ax0 = [];
    keepOnly(canvas, prior, kept);   % the rest of the last drawing goes
    was = PlotAesthetics.drawScale(canvas);
    for k = find(kept); PlotAesthetics.scaleSizes(prior.parts{k}, 1 / was); end   % back to the export's sizes, as a new panel is drawn
else
    [canvas, ax0] = figureCanvas(target);
end
scaleKey = char(PlotAesthetics.ScaleKey);
for x = [canvas ax0]   % drawn at the export's sizes (the looks set them so), scaled once everything is drawn
    if isappdata(x, scaleKey); rmappdata(x, scaleKey); end
end
if ~isempty(canvas); L0 = firstLayout(canvas, spec, panels, isLeg, style, opts.Scale); end
nDraw = np;
if ~isempty(ax0); nDraw = min(1, np) * ~(np > 0 && isLeg(1)); end   % one axes: panel 1 (not a legend panel: it would hide it)
axs = gobjects(1, np);
extra = cell(1, np);   % each panel's further axes (a coherence panel's phase)
hks = cell(1, np);
notes = cell(1, np);   % each panel's note (drawNote's N) and the band that holds it beside the axes ([] = in the axes)
bands = cell(1, np);
ovls = cell(1, np);    % each panel's overlays (drawOverlays' O)
labs = cell(1, np);    % each panel's x and y labels: the axes that show them and the type's own text (panelAxes)
yExt = NaN(np, 2);     % each panel's y extent (a panel with yLimMode), for a run's batch range
for k = 1:nDraw
    p = panels(k);
    P = F.panels(k);
    if kept(k)   % drawn alike before (Reuse): its parts, back where they were before the layout placed them
        axs(k) = prior.axes(k);
        [extra{k}, hks{k}, notes{k}, bands{k}, ovls{k}, labs{k}] = deal(prior.extra{k}, prior.hks{k}, prior.notes{k}, ...
            prior.bands{k}, prior.ovls{k}, prior.labels{k});
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
        ax = axes(canvas, 'Units', 'pixels', 'Position', max(L0.panels(k).box, [-Inf -Inf 1 1]));
        setappdata(ax, 'FigurePanel', p.id);   % a panel of the layout (drawCoherencePanel splits it for its phase)
        if besideNote(p)
            band = axes(canvas, 'Units', 'pixels', 'Position', max(L0.panels(k).band, [-Inf -Inf 1 1]), 'Visible', 'off', ...
                'HitTest', 'off', 'PickableParts', 'none', 'XLim', [0 1], 'YLim', [0 1], 'Tag', 'noteHost');
        end
    else
        ax = ax0;
    end
    look = figureLookFor(F, spec, p, P, style, colorsOf{k}, isTime(k));
    look.batchYLim = figureBatchFor(opts.BatchYLim, p.id);
    if isfield(reg, p.type)
        hk = reg.(p.type).draw(ax, P, look);
    else
        hk = figDrawResult(ax);
        figLayerNotes(ax, P, look, false, "Unknown panel type """ + p.type + """");
    end
    ax = hk.axes;
    if ~isLeg(k)   % (a legend panel's axes stay its hidden legendHost: no tile of the aesthetics editor)
        role = string(ax.Tag);
        if ~ismember(role, ["axes" "rasterAxes"]); role = "axes"; end
        tagPart(ax, role, "", p.id);   % the aesthetics editor lists the tiles by panel id
    end
    if p.sharesTime && ~isempty(look.W)
        xlim(ax, [spec.window.pre spec.window.post]);
    end
    if hk.yName ~= ""; ylabel(ax, hk.yName, 'Interpreter', 'none'); end
    ttl = p.title;
    if own(k); ttl = groupingTitle(ttl, p, spec); end
    if ttl ~= "" && ~isLeg(k); title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none'); end
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
    yExt(k, :) = figureExtentOf(hk, ax, p);
    if isfield(hk, 'extraAxes'); extra{k} = hk.extraAxes(isgraphics(hk.extraAxes)); end
    labs{k} = panelAxes([ax reshape(extra{k}, 1, [])], p);   % its own axis sides and labels, over what its type drew
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
sided = false(1, np);   % a band left or right of a panel's axes: narrower than its rect
for k = 1:np; sided(k) = isempty(ax0) && sideNote(panels(k)); end
hidden = figureTimeStack(axs, panels, isTime, labelSize, sided);
for k = find(drawn & ~isLeg)   % what each panel's axes leave out (xShow, yShow), over what the stack and its type drew
    blankAxes([axs(k) reshape(extra{k}, 1, [])], panels(k));
end

% title: the figure's, or what it shows; the top-left panel names the observation under a title of the figure's own
[txt, named] = figureAutoTitle(F, spec, titleVars);
obs = F.observation;
if spec.title ~= "" && named && any(drawn & ~isLeg) && ~any(ismember(["Unit" "Observation"], titleVars))
    k1 = firstPanel(spec, drawn & ~isLeg);
    if panels(k1).title == "" && strjoin(string(axs(k1).Title.String), "") == ""
        title(axs(k1), string(obs.label), 'FontWeight', 'normal', 'Interpreter', 'none');
    end
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

% one legend: the groups once, then the layers', units', channels' and marks' entries; in the legend panel, floating in the
% free space or inside the first panel (figureLayout places the first two once the panels are laid out: G2)
lgd = [];
G2 = [];
iLeg = find(isLeg & drawn, 1);
loc = string(style.LegendLocation);
if style.Legend && loc ~= "none" && any(drawn & ~isLeg)
    [lh, ll] = figureLegendEntries(hks, types, G);
    if ~isempty(lh)
        ls = style;
        if isempty(canvas)   % one axes: in it
            lgd = placeLegend(legendHost(axs(drawn), canvas), lh, ll, ls, [], "best");
        elseif loc == "auto" && ~isempty(iLeg)
            ls.LegendLocation = "none";
            lgd = placeLegend(axs(iLeg), lh, ll, ls, [], "none");
            G2 = struct('handle', lgd, 'mode', "panel", 'panel', iLeg, 'options', panels(iLeg).options);
        elseif loc == "auto"
            ls.LegendLocation = "none";
            lgd = placeLegend(legendHost(axs(drawn & ~isLeg), canvas), lh, ll, ls, [], "none");
            G2 = struct('handle', lgd, 'mode', "float", 'panel', 0, 'options', []);
        else
            lgd = placeLegend(legendHost(axs(drawn & ~isLeg), canvas), lh, ll, ls, [], "best");
        end
    end
end
if ~isempty(iLeg)   % a legend panel holding no legend says why, in a preview only (light gray)
    old = findall(axs(iLeg), '-depth', 1, 'Type', 'text');
    delete(old(arrayfun(@(t) isappdata(t, 'LegendPanelNote'), old)));
    if isempty(G2) && (opts.Reuse || figureEditable(opts.Editable, target))
        why = "No legend entries";
        if ~style.Legend || loc == "none"
            why = "The legend is off (Legend location: none)";
        elseif loc == "inside"
            why = "The legend is inside the first panel (Legend location: inside)";
        end
        t = text(axs(iLeg), 0.5, 0.5, why, 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', max(6, style.FontSize - 2), 'Color', [0.65 0.65 0.65], 'Interpreter', 'none', 'Clipping', 'off', ...
            'HitTest', 'off', 'PickableParts', 'none');
        setappdata(t, 'LegendPanelNote', true);
        tagPart(t, "note");
    end
end

% aesthetics: the design's common rules, each panel's kind, then the figure's
root = canvas;
if isempty(root); root = ax0; end
specRules = PlotAesthetics.normalizeRules(spec.aesthetics);
PlotAesthetics.apply(root, design.rules);
kRules = cell(1, np);
for k = find(drawn)
    r = figureKindRules(design, types(k));
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
r = figureKindRules(design, "figure");
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
if opts.Scale ~= 1 && ~isempty(root)   % shown larger or smaller than exported: every size in proportion, then laid out
    PlotAesthetics.scaleSizes(root, opts.Scale);
    setappdata(root, scaleKey, opts.Scale);
end
if isempty(canvas)   % one axes: its note goes where it belongs once its looks are final (its size measured)
    for k = find(drawn)
        if ~isempty(notes{k}) && ~isempty(notes{k}.text); placeNote(notes{k}, panels(k).note); end
    end
else   % the layout, once everything is drawn and dressed: every axes, band, the legend and the title, then the notes
    figureLayout(canvas, layoutOf(spec, panels, axs, extra, notes, bands, th, G2, isLeg, opts.Scale));
end
if figureEditable(opts.Editable, target)
    PlotAesthetics.enableEditing(target, figureEditContext(F, raw, target, opts, root, design, follows, txt));
end

if ~isempty(opts.OnSelect)
    for k = find(drawn)
        figurePickable([axs(k) reshape(extra{k}, 1, [])], @(ctrl, shift) opts.OnSelect(panels(k).id, ctrl, shift));
    end
end

h = figureHandles(canvas, spec, axs, extra, notes, ovls, yExt, txt);
if figureEditable(opts.DataTips, target)   % after the right-click menus: it adds its item to them
    hT = h;
    for k = find(kept)   % a kept panel's parts have theirs
        hT.panels(k).axes = gobjects(0);
        hT.panels(k).extraAxes = gobjects(0);
    end
    FigureDataTips.attach(F, spec, hT);
end
if opts.Reuse && ~isempty(canvas) && isequal(canvas, target)   % what the next drawing with Reuse can keep
    setappdata(target, drawingAppdata(), struct('keys', keys, 'axes', axs, 'extra', {extra}, 'hks', {hks}, 'notes', {notes}, ...
        'bands', {bands}, 'ovls', {ovls}, 'yExt', yExt, 'parts', {parts}, 'pos', {pos}, 'legend', lgd, 'title', th, ...
        'spec', spec, 'labels', {labs}, 'hidden', hidden, 'txt', txt, 'titleVars', titleVars));
elseif isappdata(target, drawingAppdata())
    rmappdata(target, drawingAppdata());
end
end


function L = panelAxes(A, p)
%panelAxes  A panel's own axis sides and label texts over what its type drew: P.xSide, ySide, xLabel, yLabel.
%   L = panelAxes(A, P). A: the panel's axes, top to bottom (a coherence
%   panel's phase strip under its magnitude). Each one's y axis goes to
%   P.ySide, but a yyaxis' (a stacked line panel's: a y axis on each side
%   already). With P.xSide "top" the first axes' x axis goes on top, with
%   the tick labels and label the last one had (the axes under it drop
%   theirs). A label of the panel's own replaces the one drawn: the x label
%   on the axes that shows the x axis (on a time axis figureTimeStack
%   decides whether it shows), the first axes' y label (a yyaxis' left
%   one). A color bar outside on the side an axis moves to goes to the
%   opposite side, out of its labels' way. L (inPlace sets a new label
%   text with it): x, y (the axes whose x label and y label the panel's
%   own replaces) and xAuto, yAuto (the labels drawn there before, {String
%   Interpreter}: what a blank label of the panel's own shows); [] when
%   nothing is drawn.
L = [];
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
yl = top.YAxis(1).Label;   % (a yyaxis: its left one)
L = struct('x', xa, 'xAuto', {{xa.XLabel.String, xa.XLabel.Interpreter}}, 'y', top, 'yAuto', {{yl.String, yl.Interpreter}});
if p.xLabel ~= ""; xlabel(xa, p.xLabel, 'Interpreter', 'none'); end
if p.yLabel ~= ""
    set(yl, 'String', p.yLabel, 'Interpreter', 'none');
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


function blankAxes(A, p)
%blankAxes  Blank what a panel's axes leave out: P.xShow, P.yShow "ticks" (the label goes), "label" (the ticks go), "none" (both).
%   A: the panel's axes (a coherence panel's phase strip with its
%   magnitude). The ticks go with their marks and numbers; the axis line
%   stays. Every y axis of a yyaxis goes alike.
A = A(isgraphics(A));
for a = reshape(A, 1, [])
    if hidesPart(p.xShow, "label"); a.XLabel.String = ''; end
    if hidesPart(p.xShow, "ticks"); a.XTick = []; end
    for r = reshape(a.YAxis, 1, [])
        if hidesPart(p.yShow, "label"); r.Label.String = ''; end
        if hidesPart(p.yShow, "ticks"); r.TickValues = []; end
    end
end
end


function tf = hidesPart(show, part)
%hidesPart  True when an axis showing SHOW (EphysAnalysisConfig.PanelAxisShows) leaves out PART ("label" or "ticks").
if part == "label"
    tf = ismember(show, ["ticks" "none"]);
else
    tf = ismember(show, ["label" "none"]);
end
end


function h = inPlace(F, spec, target, keys, opts, own, design, follows, raw, titleVars)
%inPlace  Make the drawing TARGET keeps (Reuse) the one SPEC draws by setting text on it and laying it out again: H as renderFigure returns it; [] = it cannot be.
%   Only when SPEC differs from the spec drawn in text and places alone --
%   a panel's xLabel, yLabel, title or rect, the figure's own title, its
%   layout -- and everything else a drawing depends on (drawingKeys: F,
%   the style, design and looks, which panels touch which and the top-left
%   one, the target's size, each panel's result and colors) is the same.
%   New rects and layout go into what figureLayout lays out (appdata
%   FigureLayout: each panel's rect, layout's boxesMean and paddingPx).
%   Each text is set where a drawing puts it: a panel's own label,
%   else the type's (panelAxes' xAuto, yAuto), in the axes panelAxes set it
%   in; a time panel's x label as figureTimeStack names it (nothing where
%   the stack hides it); a panel's title of its own (with groupingTitle's
%   words, as a drawing adds them: OWN, renderFigure's); the figure's
%   title. It cannot be when a text that changes shows nothing before or
%   after (an empty label or title is no component: no looks were set on
%   it and it has no menu), when a panel's title or the figure's is not its
%   own before or after (the type's, or the observation's on the top-left
%   panel), when the figure's title starts or stops naming {Unit},
%   {Observation} or {Group} (TITLEVARS, figureLabelFill's), or when a time panel with further axes (a coherogram's)
%   changes its x label. Then the parts go back to where a new drawing
%   starts, as Reuse puts its kept panels, and figureLayout lays them out
%   again (a new text can take more room); the data tips of the panels
%   whose labels changed are made again (they name their quantities after
%   the labels); the right-click editor's context takes SPEC (its redraw,
%   title and axis edits); and the drawing kept records SPEC, so the next
%   one compares with it. Only texts and interpreters are set, no size:
%   drawn at a Scale (in the global key, so the same one), the fonts keep
%   the scaled sizes they have, and figureLayout lays the parts out with
%   the scale it kept, as after a whole drawing at that scale.
h = [];
if ~isappdata(target, drawingAppdata()); return; end
D = getappdata(target, drawingAppdata());
np = numel(keys.panels);
if ~isstruct(D) || ~isfield(D, 'spec') || numel(D.keys.panels) ~= np || ~isequaln(D.keys.global, keys.global) ...
        || ~isequal(D.keys.ownTime, keys.ownTime)
    return
end
named = ["Unit" "Observation" "Group"];   % a title that starts or stops naming these changes the top-left panel's title or the group's: drawn
if ~isfield(D, 'titleVars') || ~isequal(ismember(named, D.titleVars), ismember(named, titleVars)); return; end
if ~all(isgraphics(D.axes)) || ~all(cellfun(@(p) all(isgraphics(p)), D.parts))
    return   % the drawing is gone (a canceled preview cleared the target): drawn again
end
P = spec.panels;
Q = D.spec.panels;
was = D.spec;   % the spec drawn with the new texts and places: anything else that differs is drawn
was.title = spec.title;
was.layout = spec.layout;
for k = 1:np
    K = D.keys.panels{k};
    for f = ["xLabel" "yLabel" "title"]
        was.panels(k).(f) = P(k).(f);
        K.p.(f) = P(k).(f);
    end
    was.panels(k).rect = P(k).rect;
    if ~isequaln(K, keys.panels{k}); return; end
end
if ~isequaln(was, spec); return; end
moved = ~isequaln(D.spec.layout, spec.layout);   % new places: laid out again at them
for k = 1:np
    moved = moved || ~isequaln(Q(k).rect, P(k).rect);
end
drawn = isgraphics(D.axes);
for k = find(drawn)
    if ~all(isgraphics(D.parts{k})); return; end
end
sets = cell(0, 3);    % each text to set: its object, String, Interpreter ("" = as it is)
tips = false(1, np);  % the panels whose data tips name their quantities anew
for k = find(drawn)
    p = P(k);
    q = Q(k);
    L = D.labels{k};
    if p.xLabel ~= q.xLabel && hidesPart(p.xShow, "label")   % blanked (blankAxes): it stays so
        tips(k) = true;
    elseif p.xLabel ~= q.xLabel
        if keys.panels{k}.isTime   % figureTimeStack names it, or hides it
            if ~isempty(D.extra{k}); return; end
            if D.hidden(k)   % it shows nothing; its interpreter as panelAxes left it
                [~, i] = ownOr(p.xLabel, L.xAuto);
                sets(end+1, :) = {D.axes(k).XLabel, '', i}; %#ok<AGROW>
            else
                name = p.xLabel;
                if name == ""; name = "Time (s)"; end
                sets(end+1, :) = {D.axes(k).XLabel, name, "none"}; %#ok<AGROW>
            end
        else
            [s, i] = ownOr(p.xLabel, L.xAuto);
            if ~isgraphics(L.x) || ~shows(L.x.XLabel.String) || ~shows(s); return; end
            sets(end+1, :) = {L.x.XLabel, s, i}; %#ok<AGROW>
        end
        tips(k) = true;
    end
    if p.yLabel ~= q.yLabel && hidesPart(p.yShow, "label")
        tips(k) = true;
    elseif p.yLabel ~= q.yLabel
        [s, i] = ownOr(p.yLabel, L.yAuto);
        if ~isgraphics(L.y); return; end
        lab = L.y.YAxis(1).Label;
        if ~shows(lab.String) || ~shows(s); return; end
        sets(end+1, :) = {lab, s, i}; %#ok<AGROW>
        tips(k) = true;
    end
    if p.title ~= q.title
        if p.title == "" || q.title == ""; return; end   % the type's title, or the observation's, before or after
        ttl = p.title;
        if own(k); ttl = groupingTitle(ttl, p, spec); end
        sets(end+1, :) = {D.axes(k).Title, ttl, ""}; %#ok<AGROW>
    end
end
txt = D.txt;
if spec.title ~= D.spec.title   % the figure's own before and after (the global key says whether it has one)
    if isempty(D.title) || ~isgraphics(D.title); return; end
    txt = figureAutoTitle(F, spec, titleVars);
    sets(end+1, :) = {D.title.Title, txt, ""};
end
for i = 1:size(sets, 1)
    set(sets{i, 1}, 'String', sets{i, 2});
    if sets{i, 3} ~= ""; set(sets{i, 1}, 'Interpreter', sets{i, 3}); end
end
if ~isempty(sets) || moved
    for k = find(drawn)   % where a new drawing starts: the layout makes what a drawing makes
        A = D.parts{k};
        for i = 1:numel(A)
            set(A(i), 'Units', 'pixels', 'Position', D.pos{k}(i, :));
            cb = A(i).Colorbar;
            if ~isempty(cb) && isvalid(cb); cb.Location = cb.Location; end   % placed from its axes again, as a new one is
        end
    end
    S = [];
    if isappdata(target, 'FigureLayout'); S = getappdata(target, 'FigureLayout'); end
    if moved && isstruct(S) && isfield(S, 'panels') && numel(S.panels) == np
        for k = 1:np; S.panels(k).rect = double(P(k).rect); end
        S.layout = layoutSettings(spec.layout, S.scale);
        figureLayout(target, S);   % the same axes, bands, legend and title at the new places
    else
        figureLayout(target);   % as it was laid out (the same axes, bands, legend and title)
    end
end
h = figureHandles(target, spec, D.axes, D.extra, D.notes, D.ovls, D.yExt, txt);
if any(tips) && figureEditable(opts.DataTips, target)
    hT = h;
    for k = find(~tips)   % the others' tips name what they named
        hT.panels(k).axes = gobjects(0);
        hT.panels(k).extraAxes = gobjects(0);
    end
    FigureDataTips.attach(F, spec, hT);
end
if figureEditable(opts.Editable, target) && isappdata(target, PlotAesthetics.ContextKey)
    setappdata(target, PlotAesthetics.ContextKey, figureEditContext(F, raw, target, opts, target, design, follows, txt));
end
D.spec = spec;
D.keys = keys;
D.txt = txt;
D.titleVars = titleVars;
setappdata(target, drawingAppdata(), D);
end


function [h, how] = layoutOnly(spec, target)
%layoutOnly  renderFigure's LayoutOnly: the drawing TARGET keeps laid out at SPEC's rects and layout, nothing else changed.
%   As inPlace lays out new places (its parts back where a new drawing
%   starts, then figureLayout at the new rects), but whatever else SPEC
%   changes and with the drawing kept as it is (D: what it shows).
h = [];
how = "";
if ~isappdata(target, drawingAppdata()) || ~isappdata(target, 'FigureLayout'); return; end
D = getappdata(target, drawingAppdata());
S = getappdata(target, 'FigureLayout');
if ~isstruct(D) || ~isfield(D, 'spec') || ~isstruct(S) || ~isfield(S, 'panels') || isfield(S, 'layoutFcn'); return; end
np = numel(spec.panels);
ids = strings(1, np);
for k = 1:np; ids(k) = spec.panels(k).id; end
drawnIds = strings(1, numel(D.spec.panels));
for k = 1:numel(D.spec.panels); drawnIds(k) = D.spec.panels(k).id; end
laidIds = strings(1, numel(S.panels));
for k = 1:numel(S.panels); laidIds(k) = string(S.panels(k).id); end
if ~isequal(ids, drawnIds) || ~isequal(ids, laidIds); return; end
drawn = isgraphics(D.axes);
for k = find(drawn)
    if ~all(isgraphics(D.parts{k})); return; end
end
for k = find(drawn)   % where a new drawing starts: the layout makes what a drawing makes
    A = D.parts{k};
    for i = 1:numel(A)
        set(A(i), 'Units', 'pixels', 'Position', D.pos{k}(i, :));
        cb = A(i).Colorbar;
        if ~isempty(cb) && isvalid(cb); cb.Location = cb.Location; end   % placed from its axes again, as a new one is
    end
end
for k = 1:np; S.panels(k).rect = double(spec.panels(k).rect); end
S.layout = layoutSettings(spec.layout, S.scale);
figureLayout(target, S);
h = figureHandles(target, D.spec, D.axes, D.extra, D.notes, D.ovls, D.yExt, D.txt);
how = "layout";
end


function [s, i] = ownOr(own, auto)
%ownOr  A label's text and interpreter: the panel's own (OWN, no interpreter), else the type's (AUTO: {String Interpreter}).
if own ~= ""
    s = own;
    i = "none";
else
    s = auto{1};
    i = string(auto{2});
end
end


function tf = shows(s)
%shows  A title's or label's String shows something (PlotAesthetics lists only those).
tf = ~isempty(s) && any(strlength(string(s)) > 0, 'all');
end


function h = figureHandles(canvas, spec, axs, extra, notes, ovls, yExt, txt)
%figureHandles  renderFigure's H: the layout, the panels' axes drawn (AXS(k) no graphics object: not drawn), each panel's parts, the title TXT.
np = numel(spec.panels);
drawn = isgraphics(axs);
hp = repmat(struct('id', "", 'type', "", 'axes', gobjects(0), 'extraAxes', gobjects(0), 'note', gobjects(0), ...
    'overlays', gobjects(1, 0), 'yExtent', [NaN NaN]), 1, np);
for k = 1:np
    hp(k).id = spec.panels(k).id;
    hp(k).type = spec.panels(k).type;
    hp(k).yExtent = yExt(k, :);
    if drawn(k)
        hp(k).axes = axs(k);
        hp(k).extraAxes = extra{k};
        if ~isempty(notes{k}); hp(k).note = notes{k}.text; end
        if ~isempty(ovls{k}); hp(k).overlays = ovls{k}.handles; end
    end
end
h = struct('layout', canvas, 'axes', axs(drawn), 'panels', hp, 'title', txt);
end


function k = drawingAppdata()
%drawingAppdata  The appdata of a target that keeps its last drawing for the next one (Reuse).
k = 'FigureDrawing';
end


function K = drawingKeys(F, spec, style, design, opts, colorsOf, isTime, target)
%drawingKeys  What a drawing depends on (Reuse): global (what every panel's does) and each panel's own.
%   global  F but its panels, creation time and latency summary; SPEC but
%           its panels, its latency block (the panels that read it carry
%           their latencies in their results), its layout (inPlace lays a
%           new one out) and its id (its title only as there being one:
%           the top-left panel then names the observation); each panel's
%           id, type, sides, time axis and note; which panels touch which
%           and lie in one column (figureNeighbors of the rects at
%           RectTol: below, above, left, right, inColumn; the time stack
%           and the draw functions' inTimeColumn read them) and the
%           top-left panel's id, but not the rects themselves; the style,
%           the design, the user's remembered looks of the panels' kinds
%           and of "figure"; BatchYLim; editing and data tips on; TARGET's
%           size in pixels; Scale
%   panels  each one's result (F.panels(k)), spec but its rect, group
%           colors, time axis and batch range
%   ownTime  each panel on a time axis whose x limits are not the
%           figure's window (its own window, or one from event to event)
P = spec.panels;
np = numel(P);
place = struct('id', {}, 'type', {}, 'xSide', {}, 'ySide', {}, 'sharesTime', {}, 'note', {});
for k = 1:np
    place(k) = struct('id', P(k).id, 'type', P(k).type, 'xSide', P(k).xSide, 'ySide', P(k).ySide, ...
        'sharesTime', P(k).sharesTime, 'note', P(k).note);
end
N = figureNeighbors(reshape([zeros(1, 0) P.rect], 4, []).', EphysAnalysisConfig.RectTol);
rel = struct('below', N.below, 'above', N.above, 'left', N.left, 'right', N.right, 'inColumn', N.inColumn);
first = "";
if np > 0
    k1 = firstPanel(spec, string([P.type]) ~= "legend");
    if k1 > 0; first = P(k1).id; end
end
Fg = rmfield(F, intersect({'panels' 'created' 'spec' 'latency'}, fieldnames(F)));
Sg = rmfield(spec, intersect({'panels' 'id' 'autoId' 'enabled' 'title' 'latency' 'layout'}, fieldnames(spec)));
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
K.global = struct('F', Fg, 'spec', Sg, 'place', place, 'neighbors', rel, 'first', first, 'style', style, 'design', design, ...
    'rules', rules, 'batch', {opts.BatchYLim}, 'editable', figureEditable(opts.Editable, target), ...
    'tips', figureEditable(opts.DataTips, target), 'size', sz, 'scale', opts.Scale);
K.panels = cell(1, np);
K.ownTime = false(1, np);
for k = 1:np
    K.panels{k} = struct('P', F.panels(k), 'p', rmfield(P(k), 'rect'), 'colors', colorsOf{k}, 'isTime', isTime(k), ...
        'batch', {figureBatchFor(opts.BatchYLim, P(k).id)});
    K.ownTime(k) = isTime(k) && ~(P(k).sharesTime && ~isempty(figureFixedWindow(P(k).window)));
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


function tf = besideNote(p)
%besideNote  The panel has a note placed beside its axes (below, above, left or right): it takes a band of its area.
tf = strtrim(string(p.note.text)) ~= "" && ismember(string(p.note.placement), ["below" "above" "left" "right"]);
end


function tf = sideNote(p)
%sideNote  The panel's note takes a band left or right of its axes: they are narrower than a plain panel's in the column.
tf = besideNote(p) && ismember(string(p.note.placement), ["left" "right"]);
end


function L = firstLayout(canvas, spec, panels, isLeg, style, scale)
%firstLayout  Where the panels' axes and note bands go before anything is drawn: labels and bands estimated from the font size.
%   figureLayout places them once they are drawn; this is where they are
%   drawn (a draw function sees a plot of about its final size). With
%   SCALE (renderFigure's Scale) not 1 they are laid out on the export's
%   page (CANVAS's size over SCALE), so everything is drawn as the export
%   draws it -- the axes' size against the fonts, which sets the automatic
%   ticks and limits a draw function reads -- before it is scaled.
%   ISLEG(k): panel k is a legend panel (no labels).
px = 96 / 72 * style.FontSize;   % the font size in pixels
sz = [700 500];   % the canvas's size, when it cannot be read yet
try
    p = getpixelposition(canvas);
    if all(p(3:4) > 40); sz = p(3:4) / scale; end
catch
end
C = struct('rect', {}, 'inset', {}, 'band', {}, 'need', {}, 'shares', {}, 'fixed', {});
for k = 1:numel(panels)
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
    if isLeg(k); ins = [0 0 0 0]; end
    C(k) = struct('rect', double(panels(k).rect), 'inset', ins, 'band', band, 'need', need, 'shares', 1, 'fixed', isLeg(k));
end
A = figureArea(sz, Top=3 * px, Margin=6);
lay = layoutSettings(spec.layout, 1);
L = figurePlace(A, C, Mode=lay.boxesMean, Padding=lay.paddingPx);
end


function S = layoutOf(spec, panels, axs, extra, notes, bands, th, G2, isLeg, scale)
%layoutOf  What figureLayout lays out: each panel's axes (a coherence panel's phase under its magnitude, a third of it) at its rect, note and band, the title and the legend.
%   G2: the figure's legend as figureLayout places it ([] = none, or
%   inside a panel). ISLEG(k): panel k is a legend panel. SCALE:
%   renderFigure's Scale, which multiplies the layout's px (figureLayout).
P = struct('id', {}, 'axes', {}, 'shares', {}, 'rect', {}, 'fixed', {}, 'note', {}, 'text', {}, 'band', {});
for k = 1:numel(panels)
    A = [axs(k) reshape(extra{k}, 1, [])];
    t = [];
    if ~isempty(notes{k}) && ~isempty(notes{k}.text); t = notes{k}.text; end
    P(k) = struct('id', panels(k).id, 'axes', A, 'shares', [2 ones(1, numel(A) - 1)], 'rect', double(panels(k).rect), ...
        'fixed', isLeg(k), 'note', panels(k).note, 'text', t, 'band', bands{k});
end
S = struct('layout', layoutSettings(spec.layout, scale), 'panels', P, 'title', th, 'legend', G2, 'margin', 6, 'scale', scale);
end


function lay = layoutSettings(layout, scale)
%layoutSettings  Figure.layout as figureLayout reads it: boxesMean, and the padding in px (cm at 96 dpi, times SCALE).
lay = struct('boxesMean', string(layout.boxesMean), 'paddingPx', double(layout.padding) * 96 / 2.54 * scale);
end


function k = firstPanel(spec, ok)
%firstPanel  The top-left panel of SPEC (EphysAnalysisConfig.panelOrder) among those OK marks; 0 = none.
order = EphysAnalysisConfig.panelOrder(spec);
order = order(ok(order));
k = 0;
if ~isempty(order); k = order(1); end
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
