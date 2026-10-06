function onSorterChanged(obj)
%onSorterChanged  The Sorter drop-down changed: Kilosort4 <-> a SpikeInterface sorter.
%   The parameters the text area holds are kept first, for the sorter they
%   belong to (SIParamsShown), and the config takes the new sorter (both
%   in one onConfigChanged); then the new sorter's controls show
%   (showSorterControls) and the config takes its parameters as shown. The
%   datasets' sorted output follows the sorter (EphysDataset.sortRunDir),
%   so the Sorted output box is refreshed.
%
%   See also showSorterControls, gatherSortingSection.
obj.onConfigChanged();
obj.showSorterControls();
obj.onConfigChanged();
obj.refreshSortingLabel();
obj.setStatus("Sorter: " + EphysDataset.sorterLabel(obj.Config.Sorting.Sorter) + ".");
end
