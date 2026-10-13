function selectDataset(obj, idx)
%selectDataset  Make dataset IDX the active one: load its source and refresh what shows it.
%   The previous dataset's cached signals and spikes are freed. The Data
%   tab's panes, the dataset boxes, the alignment count, the line and
%   parameter lists, the epoch diagram (when open), (auto-preview) the
%   plot preview and the Chronux tab (another dataset's file and result
%   are dropped) follow.
if isempty(obj.Runner) || idx < 1 || idx > numel(obj.Runner.Keys); return; end
if obj.ActiveIdx >= 1 && obj.ActiveIdx ~= idx && obj.ActiveIdx <= numel(obj.Runner.Outputs)
    obj.Runner.Outputs(obj.ActiveIdx).clearCache();
end
if obj.ActiveIdx ~= idx
    obj.ChronuxResult = [];
    obj.ChronuxIndex = [];
    obj.ChronuxFile = "";
end
obj.ActiveIdx = idx;
obj.PreviewResult = [];
obj.PreviewPage = 1;
obj.PreviewSeconds = 0;
obj.setStatus("Loading " + obj.Runner.Names(idx) + " ...");
drawnow limitrate;
try
    obj.Runner.source(idx);
catch ME
    obj.setStatus("Cannot read " + obj.Runner.Names(idx) + ": " + string(ME.message));
end
set([obj.AlignDatasetDropDown obj.PlotsDatasetDropDown obj.ChronuxDatasetDropDown], 'Value', idx);
obj.refreshDatasetsTable();
obj.refreshDatasetInfo();
wasApplying = obj.Applying;
obj.Applying = true;
obj.fillAlignItems(obj.AlignControls);
obj.fillAlignItems(obj.PlotAlignControls);
obj.Applying = wasApplying;
if obj.SelectedPlot >= 1; obj.applyPlotEditor(); end
obj.refreshAlignPreview();
obj.refreshEpochDiagram();
obj.autoPreview();
if obj.Tabs.SelectedTab == obj.TabChronux; obj.refreshChronuxTab(); end
obj.setStatus("Active dataset: " + obj.Runner.Names(idx));
end
