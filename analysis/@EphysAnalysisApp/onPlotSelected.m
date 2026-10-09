function onPlotSelected(obj, k)
%onPlotSelected  Edit plot K (its edits so far are already in the config).
if isempty(k) || k < 1 || k > numel(obj.Config.Plots); return; end
obj.SelectedPlot = k;
obj.refreshPlotList();   % the tree follows a selection made in code
obj.applyPlotEditor();
obj.PreviewResult = [];
obj.PreviewPage = 1;
obj.PreviewSeconds = 0;
obj.autoPreview();
end
