function onMovePanel(obj, direction)
%onMovePanel  Swap the selected panel with its same-shaped neighbor "up", "down", "left" or "right" (movePanel).
%   Without such a neighbor nothing moves, and the status bar says so.
arguments
    obj (1,1) EphysAnalysisApp
    direction (1,1) string {mustBeMember(direction, ["up" "down" "left" "right"])}
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
id = fig.panels(j).id;
[fig, moved] = EphysAnalysisConfig.movePanel(fig, id, direction);
if ~moved
    side = struct('up', "above it", 'down', "below it", 'left', "to its left", 'right', "to its right");
    obj.setStatus(id + " has no panel of the same shape " + side.(direction) + " to swap with.");
    return
end
cfg.Figures(k) = fig;
commitFigureEdit(obj, cfg, "Moved " + id + " " + direction + ".", Action="Move panel");
end
