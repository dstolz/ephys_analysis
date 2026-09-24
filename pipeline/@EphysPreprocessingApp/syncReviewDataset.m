function syncReviewDataset(obj)
%syncReviewDataset  Show the active dataset's sorted output on the Review tab.
%   Loads the dataset's associated output (an explicit SortingDir, else the
%   auto-discovered run), falling back to the DatasetTracker's latest
%   Kilosort4 run so results in non-default folders are still found. A
%   dataset without sorted output clears the tab, and so does one whose
%   hand-picked folder is not there now (sortingMissing): no other sort
%   stands in for it. Runs when the active dataset changes while the Review
%   tab is open, else when the tab is next opened (ReviewDatasetIdx).
%   Browse... / Load still take any results folder.
idx = obj.SelectedDatasetIdx;
obj.ReviewDatasetIdx = idx;
if idx < 1; return; end
obj.applyConfigToProject();
d = obj.Project.Datasets(idx);
if d.sortingMissing()
    clearReview(obj, d.Name + "'s sorted-output folder is not there now: " + d.SortingDir + ...
        ". Connect its disk or share, or choose another on the Sorting tab (Use folder... / Use auto).");
    return
end
folder = "";
if d.hasKilosortResults()
    folder = string(d.sortingResultsDir());
else
    run = d.tracker().latestKilosortRun();
    if ~isempty(run) && run.HasResults
        folder = string(run.Dir);
    end
end
if folder == ""
    clearReview(obj, d.Name + " has no Kilosort4 output yet. Run the Sorting step, or pin a results folder on the Sorting tab.");
    return
end
obj.ReviewFolderField.Value = char(folder);
obj.savePreferences();
try
    obj.loadReviewResults();
catch
    % loadReviewResults has already reported the failure in an alert.
end
end


function clearReview(obj, message)
%clearReview  Empty the summary, units table and plots.
obj.ReviewData = struct([]);
obj.ReviewSelectedUnit = 0;
obj.ReviewSpikeWaves = struct([]);
obj.ReviewUnitsTable.Data = {};
for ax = [obj.ReviewShankAxes, obj.ReviewISIAxes, obj.ReviewACGAxes, obj.ReviewAmpAxes, obj.ReviewRateAxes, obj.ReviewUnitShankAxes]
    cla(ax, 'reset');
end
obj.ReviewSummaryLabel.Text = message;
end
