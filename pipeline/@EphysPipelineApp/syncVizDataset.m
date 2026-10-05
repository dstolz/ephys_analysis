function syncVizDataset(obj)
%syncVizDataset  Flag a Visualize plot of a dataset other than the active one.
%   The status line says which dataset the plot shows (onVizViewChanged).
%   The tab loads the active dataset whenever it opens or the active
%   dataset changes while it is open, so a plot of another one lasts only
%   while the tab is hidden. The two are compared as datasets (handles, not
%   places in the project), so after a rescan a plot is out of date unless
%   the new project still holds its recording (onScan then points the plot
%   at it).
if isempty(obj.VizStatusLabel) || ~isvalid(obj.VizStatusLabel); return; end
obj.onVizViewChanged();
end
