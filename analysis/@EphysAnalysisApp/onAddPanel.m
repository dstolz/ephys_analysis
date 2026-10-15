function onAddPanel(obj, where)
%onAddPanel  Add a panel of the type picked (FigureAddType) above, below, left or right of the selected panel.
%   WHERE is "above", "below", "left" or "right": a new row (column) of the
%   grid next to the selected panel (EphysAnalysisConfig.placePanel); the
%   first panel of a figure goes to row 1, column 1. The new panel holds the
%   type's default layer (EphysAnalysisConfig.defaultLayer; a coherence
%   panel two, its seed and partner: the observed unit and its channel's
%   LFP), so it draws at once, and is selected.
arguments
    obj (1,1) EphysAnalysisApp
    where (1,1) string {mustBeMember(where, ["above" "below" "left" "right"])}
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
t = obj.FigureAddType;
L = EphysAnalysisConfig.defaultLayer(t);
if t == "coherence"   % the seed and its partner: the observed unit with its channel's LFP (figureTemplates' coherence)
    L2 = L;
    L2.source = "LFP";
    L = [L L2];
end
panel = struct('type', t, 'layers', L);
anchor = "";
j = obj.SelectedPanel;
if ~isempty(fig.panels) && j >= 1 && j <= numel(fig.panels); anchor = fig.panels(j).id; end
try
    fig = EphysAnalysisConfig.placePanel(fig, panel, where, anchor);
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
    at = where + " " + anchor;
end
commitFigureEdit(obj, cfg, "Added " + p.id + " " + at + " with its default layer (" + layerLabel(p.layers(1)) + ").");
end
