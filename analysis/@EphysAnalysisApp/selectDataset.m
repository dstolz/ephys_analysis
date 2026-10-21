function selectDataset(obj, idx)
%selectDataset  Make dataset IDX the active one: load its source and refresh what shows it.
%   The previous dataset's cached signals and spikes are freed. The Data
%   tab's panes, the dataset boxes, the Dataset drop-downs' labels (its
%   sorted units counted: refreshDatasetLabels), the Favorites lists (its
%   units' class, channel and depth and its channels' depth now known:
%   listFavorites), its star toggles, the alignment count, the line and
%   parameter lists, the epoch diagram (when open), the Figures tab's
%   observation picker (its pick kept by label) and preview
%   (autoFigurePreview) follow. The status bar says what it is loading
%   ("Loading <name> (dataset 3/12): its files ...").
if isempty(obj.Runner) || idx < 1 || idx > numel(obj.Runner.Keys); return; end
if obj.ActiveIdx >= 1 && obj.ActiveIdx ~= idx && obj.ActiveIdx <= numel(obj.Runner.Outputs)
    obj.Runner.Outputs(obj.ActiveIdx).clearCache();
end
obj.ActiveIdx = idx;
name = obj.Runner.Names(idx);
obj.setStatus(sprintf("Loading %s (dataset %d/%d): its files ...", name, idx, numel(obj.Runner.Keys)));
drawnow limitrate;
try
    obj.Runner.source(idx);
    obj.setStatus("Loading " + name + ": its units, lines and observations ...");
catch ME
    obj.setStatus("Cannot read " + name + ": " + string(ME.message));
end
set([obj.AlignDatasetDropDown obj.FiguresDatasetDropDown], 'Value', idx);
obj.refreshDatasetsTable();
obj.refreshDatasetInfo();
refreshDatasetLabels(obj, idx);
listFavorites(obj);   % its entries labeled with what was just read
syncStarButtons(obj);   % the dataset's star
wasApplying = obj.Applying;
obj.Applying = true;
obj.fillAlignItems(obj.AlignControls);
obj.fillAlignItems(obj.FigureAlignControls);
obj.fillAlignItems(obj.PanelAlignControls);
obj.Applying = wasApplying;
if obj.SelectedFigure >= 1; obj.applyFigureEditor(); end
obj.FigurePreviewResult = [];
obj.FigurePreviewSeconds = 0;
obj.refreshFigureObservations();
obj.refreshAlignPreview();
obj.refreshEpochDiagram();
obj.autoFigurePreview();
obj.setStatus("Active dataset: " + name);
end
