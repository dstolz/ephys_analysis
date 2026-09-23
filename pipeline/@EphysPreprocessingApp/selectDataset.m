function selectDataset(obj, idx, opts)
%selectDataset  Make dataset IDX (into Project.Datasets) the active dataset.
%   The active dataset is what every single-dataset control works on: the
%   Trials tab, Exclude channels, the manual artifact periods, the Artifacts
%   and Spikes previews, the sorted-output association and phy, Optimize
%   for probe, Visualize, Review and the behavior association. It is chosen
%   in the Dataset menu (a ticked dataset or one under All datasets), in
%   any tab's Dataset box or by clicking a row of the Project table, and all
%   of them show it: its menu items are checked,
%   every Dataset box shows it and its table row is highlighted.
%
%   When the active dataset changes, results shown for the previous one are
%   cleared (a loaded trial pairing, the Artifacts and Spikes previews), the
%   Review tab loads the new one's sorted output (now if it is open, else
%   when it is next opened) and a Visualize plot of the previous one is
%   flagged. IDX 0 = none (no datasets scanned).
%
%   Options: FromTable (the choice is a click on the table, whose row need
%   not be scrolled to) and Reset (the datasets were rebuilt by a scan:
%   reset those views even when IDX is unchanged).
arguments
    obj (1,1) EphysPreprocessingApp
    idx (1,1) double
    opts.FromTable (1,1) logical = false
    opts.Reset (1,1) logical = false
end
if isempty(obj.Project) || ~(idx >= 1 && idx <= obj.Project.NumDatasets)
    idx = 0;
end
changed = opts.Reset || idx ~= obj.SelectedDatasetIdx;
obj.SelectedDatasetIdx = idx;

% --- every control that shows the choice -------------------------------------
items = obj.DatasetMenuItems;
for k = 1:numel(items)
    if isvalid(items(k)); items(k).Checked = (k == idx); end
end
for item = obj.DatasetTickedItems(isvalid(obj.DatasetTickedItems))
    item.Checked = isequal(item.UserData, idx);
end
obj.refreshDatasetPickers();
obj.highlightDatasetRow(Scroll=~opts.FromTable);

% --- views of the active dataset ---------------------------------------------
if changed
    clearResults(obj);
    obj.populateVizFiles();
    obj.ReviewDatasetIdx = -1;   % reload when the Review tab shows
    obj.onSynthSourceChanged();  % a schedule read from the previous dataset no longer applies
end
obj.syncExcludeField();
obj.onProbeSelected();
obj.syncArtProbeControls();
obj.updatePhyButtonState();
obj.refreshSortingLabel();
obj.refreshManualArtifactsTable();
obj.refreshReferencePanel();
obj.syncVizDataset();
if obj.Tabs.SelectedTab == obj.TabReview && obj.ReviewDatasetIdx ~= idx
    obj.syncReviewDataset();
end
end


function clearResults(obj)
%clearResults  Forget the results shown for the previously active dataset.
obj.clearTrialsView();
d = obj.currentDataset();
if isempty(d)
    obj.ArtSummaryLabel.Text = "Scan a project, then press Detect / Preview.";
else
    obj.ArtSummaryLabel.Text = "Press Detect / Preview to analyze " + d.Name + ".";
end
obj.ArtStatusLabel.Text = "";
obj.ArtView.summary = [];
obj.ArtView.layout = [];         % read again (syncArtProbeControls)
obj.refreshArtChannelTable();
obj.ArtView.intervals = zeros(0, 2);
obj.ArtView.previewed = false;
obj.ArtView.chunk = [];
obj.ArtView.win = [];
obj.drawArtifactView();
obj.SpkPreviewTable.Data = cell(0, 5);
obj.SpkPreviewLabel.Text = "";
end
