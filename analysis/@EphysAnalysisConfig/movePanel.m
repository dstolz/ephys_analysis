function [fig, moved] = movePanel(fig, id, direction)
%movePanel  Swap a panel with its same-shaped neighbor above, below, left or right.
%   [FIG, MOVED] = EphysAnalysisConfig.movePanel(FIG, ID, DIRECTION) swaps
%   the places (row, col) of panel ID of figure FIG (a Figures entry) and
%   the panel next to it in DIRECTION ("up", "down", "left" or "right")
%   when that panel has the same spans and lines up with it (the same
%   column for up / down, the same row for left / right). Otherwise FIG is
%   returned unchanged and MOVED is false.
%
%   Error: EphysAnalysisConfig:NoPanel.
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.removePanel.

arguments
    fig (1,1) struct
    id (1,1) string
    direction (1,1) string {mustBeMember(direction, ["up" "down" "left" "right"])}
end

moved = false;
k = [];
if ~isempty(fig.panels); k = find([fig.panels.id] == id, 1); end
if isempty(k)
    error('EphysAnalysisConfig:NoPanel', 'The figure has no panel "%s".', id);
end
P = fig.panels(k);
for q = [1:k-1, k+1:numel(fig.panels)]
    Q = fig.panels(q);
    if Q.rowSpan ~= P.rowSpan || Q.colSpan ~= P.colSpan; continue; end
    switch direction
        case "up",    next = Q.col == P.col && Q.row + Q.rowSpan == P.row;
        case "down",  next = Q.col == P.col && P.row + P.rowSpan == Q.row;
        case "left",  next = Q.row == P.row && Q.col + Q.colSpan == P.col;
        case "right", next = Q.row == P.row && P.col + P.colSpan == Q.col;
    end
    if next
        fig.panels(k).row = Q.row;
        fig.panels(k).col = Q.col;
        fig.panels(q).row = P.row;
        fig.panels(q).col = P.col;
        moved = true;
        return
    end
end
end
