function followKeptKSRuns(obj)
%followKeptKSRuns  Follow again the Kilosort4 runs going when the app last closed.
%   The runs keepKSRuns kept (the preference KeptSortingRuns) join KSRuns,
%   and the monitor (pollKSRuns) follows them as it does any background
%   run: their logs stream on from where they were, they take slots of
%   Sorting.MaxConcurrent, a dataset of theirs is not sorted again while
%   they go, and a run that ended while the app was closed is logged as
%   done or failed at the first tick. Left out, and logged: a run whose
%   results folder is gone, and one that has not ended (sortRunState
%   "running") but has no process left, as when the computer restarted
%   under it (EphysDataset.sortRunProcesses). The preference is then
%   cleared. The constructor calls it; an error here is logged, never
%   thrown.
%
%   See also keepKSRuns, pollKSRuns, EphysDataset.sortRunProcesses.

g = obj.PrefGroup;
if ~AppPrefs.ispref(g, 'KeptSortingRuns'); return; end
try
    runs = keptSortingRuns(g);
    AppPrefs.rmpref(g, 'KeptSortingRuns');
    if isempty(runs); return; end
    gone = ~isfolder([runs.resultsDir]);
    for r = runs(gone)
        obj.log("[sorting] %s: going when the app last closed, but its folder is gone (%s); not followed", ...
            r.Name, r.resultsDir);
    end
    runs = runs(~gone);
    if isempty(runs); return; end
    lost = false(size(runs));
    running = arrayfun(@(r) EphysDataset.sortRunState(r.statusFile), runs) == "running";
    if any(running)
        n = EphysDataset.sortRunProcesses([runs(running).statusFile]);   % NaN: the search failed, so followed
        lost(running) = n == 0;
    end
    if any(lost)   % one that ended in the meantime is followed: the monitor reports how it ended
        lost(lost) = arrayfun(@(r) EphysDataset.sortRunState(r.statusFile), runs(lost)) == "running";
    end
    for r = runs(lost)
        obj.log("[sorting] %s: going when the app last closed, but no process of it is left " + ...
            "(did the computer restart?); not followed. Sort it again to finish it.", r.Name);
    end
    follow = runs(~lost);
    if isempty(follow); return; end
    [follow.done] = deal(false);
    obj.KSRuns = [obj.KSRuns, follow];
    what = sortersLabel(arrayfun(@(r) string(r.resultsDir), follow));
    obj.log("[sorting] following again %d %s run(s) going when the app last closed: %s", ...
        numel(follow), what, strjoin([follow.Name], ", "));
    obj.setStatus(sprintf("Following %d %s run(s) still going when the app last closed.", numel(follow), what), ...
        "Watch them on the Run tab (the label under the log); Stop runs... stops them.");
    obj.startKSMonitor();
catch ME
    obj.log("[error] the sorting runs going when the app last closed could not be followed again: %s", ME.message);
end
end
