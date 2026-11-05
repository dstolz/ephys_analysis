function onNewPanel(obj, opts)
%onNewPanel  Add a panel to the selected figure: the one the New panel window describes, or the one OPTS do.
%   The Panels section's New panel... button (and Add, after it makes a
%   blank figure) calls it with no options: the New panel window
%   (private/newPanelDialog) offers every panel type with a small
%   representative plot (a legend panel too: where the figure's legend
%   goes, one per figure), the panel's name and title, where it goes (the
%   largest empty space of the page; below, above, right or left of the
%   selected panel, which is halved for it; or drawn on the preview with
%   two clicks, offered while the preview shows the figure; the first
%   panel of a figure fills the page) and the type's key parameters.
%   OK adds the panel and selects it; Cancel adds nothing. The window
%   and the panel start from the options last set on a panel of the type
%   (rememberedPanelOptions: a preference, rememberPanelOptions), over the
%   type's defaults; the status bar says so. Edit > Reset panel options
%   to defaults gives a panel the defaults (onResetPanelOptions).
%   Under the types the window offers the saved figures that are panel
%   types (FigureTemplate.panelTypes: the built-in Raster over PSTH, then
%   yours, Save as panel type...): one picked places all its panels as
%   one block, arranged as saved, at the place chosen
%   (EphysAnalysisConfig.placeBlock: the saved page mapped onto that
%   place), its panels' ids made free in the figure; the first of them is
%   selected. They take the figure's event reference, window and trial
%   selection, or the saved figure's own (Alignment). Set=KEY (a
%   panelTypes Key: "builtin:rasterPsth", or your template's name) does
%   that without the window, with Where, Rect and Alignment ("figure" |
%   "own").
%
%   Type=TYPE skips the window, for scripts and tests, with the same
%   choices as name-value pairs: Where ("free", the default: the largest
%   empty space of the page, else below the selected panel; "below",
%   "above", "left", "right": beside the selected panel, which keeps the
%   half next to the new one; "rect": at Rect=[x y w h], 0-1 of the page;
%   "draw": two clicks on the preview, the corners of its rect
%   (startCornerMode "new", "block" for a saved figure: Arrange switches
%   on, the panel is added at the second click; the preview must show the
%   figure, else the status bar says so)), Id (""
%   = "<type>_<n>"), Title, Source (the first layer's source, "" = the
%   type's default layer's), Partner (a coherence panel's second layer,
%   "" = LFP), Binding ("" = the type's DefaultBinding; "fixed" wherever
%   the layer cannot follow the observation), Lines (an event-trace
%   panel: one events layer per line) and Options (a partial options
%   struct of the type, merged into its defaults: struct('bins',
%   struct('BinSec', 0.02))), Measure (a trial panel's: a partial
%   TrialMeasure merged into its first layer's measure, its from and to
%   field by field: struct('kind', "delay", 'from', struct('line',
%   "Stim"), 'to', struct('line', "Platform", 'edge', "offset"))) and
%   Remembered (false: the type's defaults;
%   true: the options remembered for the type over them, as the window
%   starts from, under Options).
%   onNewPanel(Where=W) without a Type opens the window with Place at W.
%
%   The panel is placed by EphysAnalysisConfig.placePanel and holds the
%   type's default layer, so it draws at once (a coherence panel two: its
%   seed, the observed unit, and its partner, that unit's channel's LFP; a
%   legend panel none). A second legend panel is refused: "The figure
%   already has a legend panel (legend_1)." The status bar says where it
%   went, in the Panels section's units: "Added psth_1 (PSTH) in the free
%   space, 9.0 x 6.0 cm at 0, 0." The edit ends as every structural one
%   does (commitFigureEdit, "Add panel"): a figure that observed the
%   dataset observes what a following layer reads, and an automatic
%   figure id follows the new panel.
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.placeBlock,
%   EphysAnalysisConfig.freeRect, EphysAnalysisConfig.defaultLayer,
%   EphysAnalysisConfig.panelTypes.
arguments
    obj (1,1) EphysFigGenApp
    opts.Type (1,1) string = ""
    opts.Set (1,1) string = ""
    opts.Alignment (1,1) string {mustBeMember(opts.Alignment, ["figure" "own"])} = "figure"
    opts.Where (1,1) string {mustBeMember(opts.Where, ["free" "below" "above" "left" "right" "rect" "draw"])} = "free"
    opts.Rect double = []
    opts.Id (1,1) string = ""
    opts.Title (1,1) string = ""
    opts.Source (1,1) string = ""
    opts.Partner (1,1) string = ""
    opts.Binding (1,1) string {mustBeMember(opts.Binding, ["" "observation" "fixed"])} = ""
    opts.Lines (1,:) string = string.empty(1, 0)
    opts.Options (1,1) struct = struct()
    opts.Measure (1,1) struct = struct()
    opts.Remembered (1,1) logical = false
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("New panel: add or select a figure first.");
    return
end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
anchor = "";
j = obj.SelectedPanel;
if ~isempty(fig.panels) && j >= 1 && j <= numel(fig.panels); anchor = fig.panels(j).id; end
PT = EphysAnalysisConfig.panelTypes();
remembered = opts.Remembered;
params = string.empty(1, 0);
if opts.Type == "" && opts.Set == ""
    [lines, params] = datasetItems(obj);
    start = struct();   % each type's options as the window starts from them: the remembered over the defaults
    for i = 1:height(PT)
        start.(PT.Type(i)) = mergeOptions(PT.DefaultOptions{i}, rememberedPanelOptions(obj, PT.Type(i), params));
    end
    sets = savedPanelTypes(obj);
    c = newPanelDialog(obj.Fig, fig, anchor, lines, params, start, sets, opts.Where, previewShowsFigure(obj));
    if isvalid(obj.Fig); figure(obj.Fig); end
    if isempty(c)
        obj.setStatus("New panel canceled: " + fig.id + " is unchanged.");
        return
    end
    opts = c;
    remembered = true;
elseif remembered
    [~, params] = datasetItems(obj);
end
if opts.Where == "draw" && opts.Set ~= ""   % a saved figure's block, drawn on the preview with two clicks
    drawOnPreview(obj, opts, remembered, "block");
    return
end
if opts.Set ~= ""   % a saved figure's panels, as one block
    placeSet(obj, cfg, k, opts.Set, opts.Where, anchor, opts.Rect, opts.Alignment);
    return
end
row = PT.Type == opts.Type;
if ~any(row)
    obj.setStatus("New panel: unknown panel type """ + opts.Type + """.");
    return
end
t = opts.Type;
if t == "legend" && ~isempty(fig.panels) && any([fig.panels.type] == "legend")
    other = fig.panels(find([fig.panels.type] == "legend", 1)).id;
    obj.setStatus("The figure already has a legend panel (" + other + ").");
    return
end
if opts.Where == "draw"   % two clicks on the preview: the panel is added at the second (startCornerMode)
    drawOnPreview(obj, opts, remembered, "new");
    return
end
L = EphysAnalysisConfig.defaultLayer(t);   % a legend panel: none
if t == "coherence"   % the seed and its partner: the observed unit with its channel's LFP (figureTemplates' coherence)
    L2 = L;
    L2.source = "LFP";
    L = [L L2];
end
if opts.Source ~= "" && t ~= "eventTrace" && ~isempty(L); L(1).source = opts.Source; end
if t == "coherence" && opts.Partner ~= ""; L(2).source = opts.Partner; end
if t == "eventTrace" && ~isempty(opts.Lines)   % a row per line
    L = repmat(L(1), 1, numel(opts.Lines));
    for q = 1:numel(opts.Lines); L(q).event.line = opts.Lines(q); end
end
if ~isempty(fieldnames(opts.Measure)) && ~isempty(L) && L(1).source == "trials"   % a trial panel's measure: its kind, events, parameter
    L(1).measure = EphysAnalysisConfig.normalizeSection("TrialMeasure", mergeOptions(L(1).measure, opts.Measure));
end
rows = "items";
if isfield(opts.Options, 'rows'); rows = string(opts.Options.rows); end
for q = 1:numel(L)
    if opts.Binding ~= ""; L(q).binding = opts.Binding; end
    if ~figureEditorChoices(t, L(q).source, rows, Observed=fig.observe.data).Bindable; L(q).binding = "fixed"; end
end
mem = struct();
if remembered; mem = rememberedPanelOptions(obj, t, params); end
panel = struct('id', opts.Id, 'type', t, 'title', opts.Title, 'layers', L, ...
    'options', mergeOptions(mergeOptions(PT.DefaultOptions{row}, mem), opts.Options));
fig0 = fig;
try
    fig = EphysAnalysisConfig.placePanel(fig, panel, opts.Where, anchor, opts.Rect);
catch ME
    obj.setStatus("New panel: " + string(ME.message));
    return
end
cfg.Figures(k) = fig;
obj.SelectedPanel = numel(fig.panels);
obj.SelectedLayer = 1;
p = fig.panels(end);
[pageCm, dpi] = figurePage(obj, fig);
msg = "Added " + p.id + " (" + PT.Label(row) + ") " + placeWords(fig0, opts.Where, anchor) + ", " + ...
    rectText(p.rect, obj.FigureRectUnits, pageCm, dpi) + ".";
if ~isempty(p.layers); msg = msg + " Its layer: " + layerLabel(p.layers(1), p.type) + "."; end
if ~isempty(fieldnames(mem))
    msg = msg + " Its options start from those last set on a " + PT.Label(row) + " panel (" + ...
        strjoin(string(fieldnames(mem)).', ", ") + "; Edit > Reset panel options to defaults).";
end
commitFigureEdit(obj, cfg, msg, Action="Add panel");
end


function drawOnPreview(obj, opts, remembered, what)
%drawOnPreview  Where "draw": wait for two clicks on the preview (startCornerMode WHAT), then add the panel or block OPTS describe at their rect.
%   The options go with the corners (FigureCorners.payload) and come back
%   here as Where "rect" with the rect drawn (cornerClick), starting from
%   the remembered options as they would now (REMEMBERED).
o = struct();
for f = ["Type" "Set" "Alignment" "Id" "Title" "Source" "Partner" "Binding" "Lines" "Options" "Measure"]
    if isfield(opts, f); o.(f) = opts.(f); end
end
o.Remembered = remembered;
obj.startCornerMode(what, o);
end


function s = placeWords(fig0, where, anchor)
%placeWords  Where placePanel (placeBlock) put something new in figure FIG0, in words: "in the free space", "below raster_1 (raster_1 halved)".
%   FIG0 is the figure before; a "free" with no free space and an anchor
%   went below it (placeTarget).
if isempty(fig0.panels)
    s = "filling the page";
    return
end
if where == "free"
    if ~isempty(EphysAnalysisConfig.freeRect(fig0))
        s = "in the free space";
        return
    end
    where = "below";   % no free space: below the anchor
end
switch where
    case "rect"
        s = "at the place given";
    case {"below" "above"}
        s = where + " " + anchor + " (" + anchor + " halved)";
    otherwise
        s = where + " of " + anchor + " (" + anchor + " halved)";
end
end


function placeSet(obj, cfg, k, key, where, anchor, rect, alignment)
%placeSet  The saved figure KEY's panels into figure K of CFG at WHERE (of ANCHOR, or RECT), as one block; the first of them selected.
fig = cfg.Figures(k);
fig0 = fig;
try
    [block, label] = FigureTemplate.panelFigure(key);
    [fig, ids] = EphysAnalysisConfig.placeBlock(fig, block, where, anchor, rect, Alignment=alignment);
catch ME
    obj.setStatus("New panel: " + string(ME.message));
    return
end
cfg.Figures(k) = fig;
obj.SelectedPanel = numel(fig.panels) - numel(ids) + 1;
obj.SelectedLayer = 1;
how = "";
if alignment == "own"; how = " with its own event reference, window and trial selection"; end
commitFigureEdit(obj, cfg, "Added " + label + " (" + strjoin(ids, ", ") + ") " + placeWords(fig0, where, anchor) + how + ".", ...
    Action="Add " + label);
end


function T = savedPanelTypes(obj)
%savedPanelTypes  The saved figures New panel offers as panel types (FigureTemplate.panelTypes); the built-in one alone when yours cannot be read.
try
    T = FigureTemplate.panelTypes();
catch ME
    obj.setStatus("New panel: your panel types could not be read: " + string(ME.message));
    T = FigureTemplate.panelTypes(Yours=false);
end
end


function o = mergeOptions(o, part)
%mergeOptions  The options O with the fields PART gives, nested structs merged field by field.
for f = string(fieldnames(part)).'
    if isfield(o, f) && isstruct(o.(f)) && isstruct(part.(f)) && isscalar(part.(f))
        o.(f) = mergeOptions(o.(f), part.(f));
    else
        o.(f) = part.(f);
    end
end
end


function [lines, params] = datasetItems(obj)
%datasetItems  The active dataset's lines (its digital and trial lines, "Trial" first) and trial parameters.
lines = "Trial";
params = string.empty(1, 0);
if isempty(obj.Runner) || obj.ActiveIdx < 1; return; end
try
    src = obj.Runner.source(obj.ActiveIdx);
    params = src.paramNames;
    lines = [lines string(fieldnames(src.events)).'];
    if src.hasTrials && height(src.trials) > 0; lines = [lines string(fieldnames(src.trials.TrialEvents)).']; end
catch
end
lines = unique(lines, 'stable');
end
