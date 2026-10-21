function onNewPanel(obj, opts)
%onNewPanel  Add a panel to the selected figure: the one the New panel window describes, or the one OPTS do.
%   The Panels section's New panel... button (and Add, after it makes a
%   blank figure) calls it with no options: the New panel window
%   (private/newPanelDialog) offers every panel type with a small
%   representative plot, the panel's name and title, where it goes
%   (above, below, left or right of the selected panel; the first panel
%   of a figure goes to row 1, column 1) and the type's key parameters.
%   OK adds the panel and selects it; Cancel adds nothing.
%
%   Type=TYPE skips the window, for scripts and tests, with the same
%   choices as name-value pairs: Where ("below"), Id ("" = "<type>_<n>"),
%   Title, Source (the first layer's source, "" = the type's default
%   layer's), Partner (a coherence panel's second layer, "" = LFP),
%   Binding ("" = the type's DefaultBinding; "fixed" wherever the layer
%   cannot follow the observation), Lines (an event-trace panel: one
%   events layer per line) and Options (a partial options struct of the
%   type, merged into its defaults: struct('bins', struct('BinSec',
%   0.02))).
%
%   The panel is placed by EphysAnalysisConfig.placePanel (a new row or
%   column next to the selected panel) and holds the type's default
%   layer, so it draws at once (a coherence panel two: its seed, the
%   observed unit, and its partner, that unit's channel's LFP). The edit
%   ends as every structural one does (commitFigureEdit): a figure that
%   observed the dataset observes what a following layer reads, and an
%   automatic figure id follows the new panel.
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.defaultLayer,
%   EphysAnalysisConfig.panelTypes.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Type (1,1) string = ""
    opts.Where (1,1) string {mustBeMember(opts.Where, ["above" "below" "left" "right"])} = "below"
    opts.Id (1,1) string = ""
    opts.Title (1,1) string = ""
    opts.Source (1,1) string = ""
    opts.Partner (1,1) string = ""
    opts.Binding (1,1) string {mustBeMember(opts.Binding, ["" "observation" "fixed"])} = ""
    opts.Lines (1,:) string = string.empty(1, 0)
    opts.Options (1,1) struct = struct()
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
if opts.Type == ""
    [lines, params] = datasetItems(obj);
    c = newPanelDialog(obj.Fig, fig, anchor, lines, params);
    if isvalid(obj.Fig); figure(obj.Fig); end
    if isempty(c)
        obj.setStatus("New panel canceled: " + fig.id + " is unchanged.");
        return
    end
    opts = c;
end
PT = EphysAnalysisConfig.panelTypes();
row = PT.Type == opts.Type;
if ~any(row)
    obj.setStatus("New panel: unknown panel type """ + opts.Type + """.");
    return
end
t = opts.Type;
L = EphysAnalysisConfig.defaultLayer(t);
if t == "coherence"   % the seed and its partner: the observed unit with its channel's LFP (figureTemplates' coherence)
    L2 = L;
    L2.source = "LFP";
    L = [L L2];
end
if opts.Source ~= "" && t ~= "eventTrace"; L(1).source = opts.Source; end
if t == "coherence" && opts.Partner ~= ""; L(2).source = opts.Partner; end
if t == "eventTrace" && ~isempty(opts.Lines)   % a row per line
    L = repmat(L(1), 1, numel(opts.Lines));
    for q = 1:numel(opts.Lines); L(q).event.line = opts.Lines(q); end
end
rows = "items";
if isfield(opts.Options, 'rows'); rows = string(opts.Options.rows); end
for q = 1:numel(L)
    if opts.Binding ~= ""; L(q).binding = opts.Binding; end
    if ~figureEditorChoices(t, L(q).source, rows, Observed=fig.observe.data).Bindable; L(q).binding = "fixed"; end
end
panel = struct('id', opts.Id, 'type', t, 'title', opts.Title, 'layers', L, ...
    'options', mergeOptions(PT.DefaultOptions{row}, opts.Options));
try
    fig = EphysAnalysisConfig.placePanel(fig, panel, opts.Where, anchor);
catch ME
    obj.setStatus("Config: " + string(ME.message));
    return
end
cfg.Figures(k) = fig;
obj.SelectedPanel = numel(fig.panels);
obj.SelectedLayer = 1;
p = fig.panels(end);
if anchor == ""
    at = "at row 1, column 1";
else
    at = opts.Where + " " + anchor;
end
commitFigureEdit(obj, cfg, "Added " + p.id + " (" + PT.Label(row) + ") " + at + " with " + layerLabel(p.layers(1)) + ".", Action="Add panel");
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
