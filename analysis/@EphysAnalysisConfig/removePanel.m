function fig = removePanel(fig, id)
%removePanel  Drop a panel from a figure; the other panels keep their places.
%   FIG = EphysAnalysisConfig.removePanel(FIG, ID) removes panel ID from
%   figure FIG (a Figures entry). Nothing else moves: the space it held is
%   left free (freeRect finds it), and the panels after it keep their
%   order.
%
%   Error: EphysAnalysisConfig:NoPanel.
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.placeBlock,
%   EphysAnalysisConfig.orderPanel.

arguments
    fig (1,1) struct
    id (1,1) string
end

k = [];
if ~isempty(fig.panels); k = find([fig.panels.id] == id, 1); end
if isempty(k)
    error('EphysAnalysisConfig:NoPanel', 'The figure has no panel "%s".', id);
end
fig.panels(k) = [];
end
