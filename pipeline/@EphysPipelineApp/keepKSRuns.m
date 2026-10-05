function keepKSRuns(obj, withQueue)
%keepKSRuns  Keep the background Kilosort4 runs for the app's next launch.
%   obj.keepKSRuns(WITHQUEUE) stores in the preferences what a later launch
%   needs to take the runs back:
%     KeptSortingRuns   the runs going (KSRuns not done: their status file,
%                       log, results folder, device and start), which keep
%                       running as processes; the next launch follows them
%                       again (followKeptKSRuns)
%     KeptSortingQueue  with WITHQUEUE true, the queued runs (KSQueue), per
%                       project root (the one each was queued in): each
%                       run's dataset key (its folder relative to that
%                       root) and prepared result, what
%                       EphysDataset.launchSorting needs. They are offered
%                       back once that root is next scanned
%                       (offerKeptKSQueue).
%   What is kept already (by another window, or for a root not scanned
%   since) stays; a run kept twice (the same results folder) is kept once,
%   as this call has it. onClose calls it, once the user has chosen to keep
%   or drop the queue.
%
%   See also followKeptKSRuns, restoreKSQueue, onClose.

g = obj.PrefGroup;
going = obj.KSRuns(~[obj.KSRuns.done]);
if ~isempty(going)
    runs = [keptSortingRuns(g), reshape(going, 1, [])];
    [~, last] = unique(EphysDataset.pathKey([runs.resultsDir]), 'last');
    AppPrefs.setpref(g, 'KeptSortingRuns', runs(sort(last)));
end

if ~withQueue || isempty(obj.KSQueue); return; end
store = keptSortingQueue(g);
stamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));
roots = unique([obj.KSQueue.root], 'stable');
for root = roots(roots ~= "")
    runs = struct('Name', {}, 'key', {}, 'prepared', {});
    for q = obj.KSQueue([obj.KSQueue.root] == root)
        runs(end+1) = struct('Name', q.Name, 'key', string(EphysPipelineConfig.datasetKey(root, q.dataset.Folder)), ...
            'prepared', q.prepared); %#ok<AGROW>
    end
    i = find(EphysDataset.pathKey([store.root]) == EphysDataset.pathKey(root), 1);
    if isempty(i)
        store(end+1) = struct('root', root, 'saved', stamp, 'runs', runs); %#ok<AGROW>
    else
        old = store(i).runs;
        store(i).runs = [old(~ismember(dirKeys(old), dirKeys(runs))), runs];
        store(i).saved = stamp;
    end
end
AppPrefs.setpref(g, 'KeptSortingQueue', store);
end


function k = dirKeys(runs)
%dirKeys  The results folders of kept queued runs, as comparable keys.
k = strings(1, numel(runs));
for j = 1:numel(runs)
    k(j) = EphysDataset.pathKey(runs(j).prepared.resultsDir);
end
end
