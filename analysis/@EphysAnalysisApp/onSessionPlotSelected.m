function onSessionPlotSelected(obj, k)
%onSessionPlotSelected  Edit session plot K (its edits so far are already in the config).
%   The list follows a selection made in code; the preview is forgotten
%   when K is another session plot than before, and redrawn when Auto is on.
if isempty(k) || ~isnumeric(k); return; end
k = k(1);
if k < 1 || k > numel(obj.Config.SessionPlots); return; end
other = k ~= obj.SelectedSessionPlot;
obj.SelectedSessionPlot = k;
obj.refreshSessionList();
obj.applySessionEditor();
if ~other; return; end
resetSessionPreview(obj, "Press Preview to draw " + obj.Config.SessionPlots(k).id + " over its sessions.");
obj.autoSessionPreview();
end
