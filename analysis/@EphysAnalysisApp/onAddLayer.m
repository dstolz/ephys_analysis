function onAddLayer(obj)
%onAddLayer  Add a layer of the source picked beside Add (FigureAddSource) to the selected panel, and pick it.
%   Only the sources the panel's type draws are offered. The layer is bound
%   as the type binds a new one (its DefaultBinding), and fixed where it
%   cannot follow the observation (events, a heat map's, ...). An
%   events layer starts as marks of every Stim onset in the epoch (the
%   EventMark defaults); pick its line and edge below.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
p = fig.panels(j);
ch = figureEditorChoices(p.type, "");
src = obj.FigureAddSource;
if ~ismember(src, ch.Sources)
    if isempty(ch.Sources); return; end
    src = ch.Sources(1);
end
L = EphysAnalysisConfig.defaults("Layer");
L.source = src;
PT = EphysAnalysisConfig.panelTypes();
L.binding = PT.DefaultBinding(PT.Type == p.type);
if ~figureEditorChoices(p.type, src).Bindable; L.binding = "fixed"; end
if isempty(p.layers)
    p.layers = L;
else
    p.layers(end+1) = L;
end
fig.panels(j) = p;
cfg.Figures(k) = fig;
obj.SelectedLayer = numel(p.layers);
commitFigureEdit(obj, cfg, "Added a " + ch.SourceLabels(ch.Sources == src) + " layer to " + p.id + ".", Action="Add layer");
end
