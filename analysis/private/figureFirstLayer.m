function [j, layers] = figureFirstLayer(layers, label)
%figureFirstLayer  The one layer a single-layer panel draws: its first enabled layer.
%   [J, LAYERS] = figureFirstLayer(LAYERS, LABEL) is the index of the first
%   enabled layer of LAYERS (figurePanelLayers: skip is not "disabled"; 0
%   when there is none) and LAYERS with every later enabled layer skipped
%   ("<LABEL> draws its first enabled layer only"), as validate warns. The
%   first one may itself carry a skip reason (figureSkipReason): the panel
%   then shows it rather than drawing a later layer.
%
%   See also figurePanelLayers, EphysAnalysisRunner.computeFigure.

arguments
    layers struct
    label (1,1) string
end
on = find(arrayfun(@(l) l.skip ~= "disabled", layers));
j = 0;
if isempty(on); return; end
j = on(1);
for i = on(2:end)
    layers(i).skip = label + " draws its first enabled layer only";
end
end
