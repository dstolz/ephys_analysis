function onPanelTypeChanged(obj)
%onPanelTypeChanged  The selected panel takes the type picked in the Panel section.
%   Its options start afresh from the new type's (panelTypes'
%   DefaultOptions), keeping the values both types have (bins, baseline --
%   its mode when the new type takes it --, measure, the mask, limits, the
%   group shown); the waveform inset or panel starts afresh. The layers the
%   new type cannot draw are dropped; those kept are fixed where the type
%   draws only fixed layers, and take the new type's binding (following the
%   observation on a raster, PSTH, continuous or waveforms panel) where the
%   old type could only fix them (a heat map's, probe map's or correlation
%   map's units); a layer both types could bind keeps its binding. With
%   none left the type's default layer is
%   added. A type not aligned to events uses the figure's event and window.
%   The status bar says what changed.
if obj.Applying; return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
new = string(obj.FigureEditor.panelType.Value);
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
p = fig.panels(j);
old = p.type;
if new == old; return; end
PT = EphysAnalysisConfig.panelTypes();
row = PT.Type == new;

% the layers it can draw
keep = false(1, numel(p.layers));
for i = 1:numel(p.layers)
    keep(i) = EphysAnalysisConfig.categoryOf(p.layers(i).source, new) ~= "";
end
dropped = strings(1, 0);
for i = find(~keep); dropped(end+1) = layerLabel(p.layers(i)); end %#ok<AGROW>
L = p.layers(keep);
follows = strings(1, 0);   % the layers that follow the observation now
for i = 1:numel(L)
    canNew = figureEditorChoices(new, L(i).source).Bindable;
    if ~canNew
        L(i).binding = "fixed";
    elseif ~figureEditorChoices(old, L(i).source).Bindable && L(i).binding ~= PT.DefaultBinding(row)
        L(i).binding = PT.DefaultBinding(row);   % fixed only because the old type could not follow: the new type's own binding
        if L(i).binding == "observation"; follows(end+1) = L(i).source; end %#ok<AGROW>
    end
end
added = "";
if isempty(L)
    L = EphysAnalysisConfig.defaultLayer(new);
    added = "; added its default layer (" + layerLabel(L) + ")";
end
p.layers = L;

% its options: the new type's, with the values both have
op = PT.DefaultOptions{row};
i = find([L.enabled], 1);
if isempty(i); i = 1; end
first = L(i).source;
modes = figureEditorChoices(new, first).BaselineModes;
for f = string(fieldnames(op)).'
    % same names, other meanings: an inset vs a waveforms panel's own waveform; a continuous panel's display (lines |
    % stacked) and stackSpacing (an offset in the signal's units) vs a rate panel's display (bar | box | points) and a
    % PSTH's stackSpacing (x the tallest PSTH); a continuous panel's trials (off | faint | only) vs an event-trace
    % panel's (overlay | rows): the new type's defaults
    if ismember(f, ["waveform" "display" "stackSpacing" "trials"]) || ~isfield(p.options, f); continue; end
    v = p.options.(f);
    if f == "baseline" && ~ismember(v.Mode, modes); v.Mode = "none"; end
    op.(f) = v;
end
p.options = op;
if ~PT.Aligned(row)
    p.ref = "default";
    p.window = "default";
    p.selection = "default";
end
p.type = new;
fig.panels(j) = p;
cfg.Figures(k) = fig;
obj.SelectedLayer = 1;
was = old;
if any(PT.Type == old); was = word(PT.Label(PT.Type == old)); end
msg = p.id + " is now a " + word(PT.Label(row)) + " panel (was a " + was + " panel): options reset";
if ~isempty(dropped); msg = msg + "; dropped " + strjoin(dropped, ", "); end
if ~isempty(follows); msg = msg + "; its " + strjoin(follows, " and ") + " layer now follows the observation"; end
commitFigureEdit(obj, cfg, msg + added + ".");
end


function w = word(label)
%word  A type's label as a word in a sentence: lower case, but an acronym (PSTH).
w = label;
if label ~= upper(label); w = lower(label); end
end
