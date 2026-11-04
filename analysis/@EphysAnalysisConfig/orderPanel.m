function [fig, k] = orderPanel(fig, id, step)
%orderPanel  Bring a panel forward or send it back: its place in the figure's panels, which is the drawing order.
%   [FIG, K] = EphysAnalysisConfig.orderPanel(FIG, ID, STEP) moves panel
%   ID of figure FIG (a Figures entry) STEP places in FIG.panels: +1
%   brings it forward (drawn over the next panel), -1 sends it back; Inf
%   brings it to the front (last), -Inf sends it to the back (first). The
%   panels are drawn in that order, so where two rects overlap the later
%   panel is on top. The move stops at either end (a panel in front
%   brought forward stays). K is the panel's index after the move. Its
%   rect and every other panel's stay as they are.
%
%   Error: EphysAnalysisConfig:NoPanel.
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.rectOverlaps,
%   EphysAnalysisConfig.panelOrder.

arguments
    fig (1,1) struct
    id (1,1) string
    step (1,1) double {mustBeNonNan} = 1
end

j = [];
if ~isempty(fig.panels); j = find([fig.panels.id] == id, 1); end
if isempty(j)
    error('EphysAnalysisConfig:NoPanel', 'The figure has no panel "%s".', id);
end
n = numel(fig.panels);
k = j + step;
if isfinite(k); k = round(k); end
k = min(max(k, 1), n);
if k == j; return; end
order = [1:j-1, j+1:n];
order = [order(1:k-1), j, order(k:end)];
fig.panels = fig.panels(order);
end
