function tickConfigSelection(obj)
%tickConfigSelection  The Run ticks from the config's own selection, for a config opened without a scan of its own.
%   A config opened when its source cannot be scanned (openConfigFile: its
%   root does not answer; scanOpened: the scan did not get as far as
%   listing the datasets) keeps the datasets of the last scan. While those
%   are the scan of its source (scanIsCurrent: the same root, say, now out
%   of reach), gatherSourceSection takes the config's selection from the
%   Run ticks, and the ticks are the config's shown before: so they are
%   set from the opened config's Selection and Datasets (selectionTicks).
%   While the datasets listed are another source's the ticks are left
%   alone: they are not gathered then, and the config keeps its own
%   selection.
%
%   See also scanOpened, openConfigFile, selectionTicks, gatherSourceSection.
if isempty(obj.Runner) || ~scanIsCurrent(obj, obj.Config.Source); return; end
obj.Ticked = selectionTicks(obj.Runner, obj.Config.Source);
obj.refreshDatasetsTable();
refreshDatasetLabels(obj);   % the Dataset drop-downs list the ticked datasets
end
