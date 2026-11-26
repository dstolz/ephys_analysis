function tickConfigSelection(obj)
%tickConfigSelection  The Run ticks from the config's own selection, for a config opened without a scan of its own.
%   A config opened when its source cannot be scanned (openConfigFile: its
%   root does not answer; scanOpened: the scan did not get as far as
%   listing the datasets) keeps the datasets of the last scan. While those
%   are the scan of its source (scanIsCurrent: the same root, say, now out
%   of reach), gatherSourceSection takes the config's selection from the
%   Run ticks, and the ticks are the config's shown before: so they are
%   set from the opened config's Selection and Datasets (selectionTicks).
%   The keys it ticks that the datasets listed lack (that scan is older
%   than the config: a recording added since, say) are said on the status
%   bar and in the Log (selectionNotes, Kept=true) and kept in its
%   selection (TickedNotListed: gatherSourceSection adds them to the ticked
%   keys) until a scan lists the source anew, so a Save does not drop
%   datasets the config names; meanwhile Run, Plan, Generate selected
%   figure and Test report stop with an alert to press Scan
%   (scanIsCurrent), since a run would draw only the datasets listed and
%   record a config that names the others. A folders-mode list of a
%   project's keys ticks every folder and is said likewise.
%   While the datasets listed are another source's the ticks are left
%   alone: they are not gathered then, and the config keeps its own
%   selection.
%
%   See also scanOpened, openConfigFile, selectionTicks, selectionNotes, gatherSourceSection.
obj.TickedNotListed = string.empty(1, 0);   % this config's own, below; never the last config's
if isempty(obj.Runner) || ~scanIsCurrent(obj, obj.Config.Source); return; end
S = obj.Config.Source;
[ticked, missing, legacy] = selectionTicks(obj.Runner, S);
obj.Ticked = ticked;
obj.TickedNotListed = missing;   % the config's own keys the old listing lacks: kept in its selection until a scan
obj.refreshDatasetsTable();
refreshDatasetLabels(obj);   % the Dataset drop-downs list the ticked datasets
note = selectionNotes(obj, S, missing, legacy, Kept=true);
if note ~= ""; obj.setStatus(string(obj.StatusBar.Text) + note); end
end
