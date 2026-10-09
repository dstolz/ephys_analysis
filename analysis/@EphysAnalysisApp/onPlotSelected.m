function onPlotSelected(obj, k)
%onPlotSelected  Edit plot K (its edits so far are already in the config); K(2:end) with it.
%   With several, K(1) is the plot in the editor and the preview, and an
%   edit goes to all of them (selectedPlots). The preview is redrawn when
%   K(1) is another plot than before.
k = reshape(k, 1, []);
k = unique(k(k >= 1 & k <= numel(obj.Config.Plots)), 'stable');
if isempty(k); return; end
other = k(1) ~= obj.SelectedPlot;
obj.SelectedPlot = k(1);
obj.AlsoSelected = k(2:end);
obj.refreshPlotList();   % the tree follows a selection made in code
obj.applyPlotEditor();
obj.refreshEpochDiagram();
if ~other; return; end
obj.PreviewResult = [];
obj.PreviewPage = 1;
obj.PreviewSeconds = 0;
obj.autoPreview();
end
