function syncReviewDataset(obj)
%syncReviewDataset  Show the active dataset's sorted output on the Review tab.
%   Lists the dataset's sorts in the Sort dropdown (reviewSorts: its own,
%   then every other folder under its output folder holding one) and loads
%   its own: the associated output (an explicit SortingDir, else its
%   Sorter's run folder, kilosort4 or si_<sorter>), else its most recently
%   changed sort so results in other folders are still found. A dataset
%   without sorted output clears the tab, and so does one whose hand-picked
%   folder is not there now (sortingMissing): no other sort stands in for
%   it, though Sort still lists the others to pick by hand; the folder
%   field then holds no other dataset's sort. Runs when the
%   active dataset changes while the Review tab is open, else when the tab
%   is next opened (ReviewDatasetIdx). Sort loads another of the dataset's
%   sorts (onReviewSortChanged), Use this sort makes the one shown the
%   dataset's own (onReviewUseSort); Browse... / Load still take any
%   results folder.
idx = obj.SelectedDatasetIdx;
obj.ReviewDatasetIdx = idx;
if idx < 1; return; end
obj.applyConfigToProject();
d = obj.Project.Datasets(idx);
[obj.ReviewSorts, use] = reviewSorts(d);
if d.sortingMissing()
    obj.showReviewSorts(d.SortingDir);
    clearReview(obj, d.Name + "'s sorted-output folder is not there now: " + d.SortingDir + ...
        ". Connect its disk or share, or choose another on the Sorting tab (Use folder... / Use auto).", d.SortingDir);
    return
end
if use == 0
    obj.showReviewSorts("");
    clearReview(obj, d.Name + " has no sorted output yet. Run the Sorting step, or pin a results folder on the Sorting tab.", "");
    return
end
folder = obj.ReviewSorts(use).dir;
obj.showReviewSorts(folder);
obj.ReviewFolderField.Value = char(folder);
obj.savePreferences();
try
    obj.loadReviewResults();
catch
    % loadReviewResults has already reported the failure in an alert.
end
end


function clearReview(obj, message, folder)
%clearReview  Empty the summary, units table and plots.
%   The folder field shows FOLDER (the missing pinned folder, else ""), so
%   Load, Open folder and phy no longer reach the previous dataset's sort.
obj.ReviewFolderField.Value = char(folder);
obj.ReviewData = struct([]);
obj.ReviewSelectedUnit = 0;
obj.ReviewSpikeWaves = struct([]);
obj.ReviewUnitsTable.Data = {};
obj.ReviewUseSortButton.Enable = "off";   % no sort shown
stylePhyButton(obj.ReviewPhyButton, "");
for ax = [obj.ReviewShankAxes, obj.ReviewISIAxes, obj.ReviewACGAxes, obj.ReviewAmpAxes, obj.ReviewRateAxes, obj.ReviewUnitShankAxes]
    cla(ax, 'reset');
end
obj.ReviewSummaryLabel.Text = message;
end
