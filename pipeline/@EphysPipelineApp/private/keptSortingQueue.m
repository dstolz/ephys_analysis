function store = keptSortingQueue(group)
%keptSortingQueue  The Kilosort4 queues kept per project root (preference KeptSortingQueue).
%   STORE is a 1 x N struct array, one element per project root: root,
%   saved (when it was kept, "yyyy-MM-dd HH:mm") and runs (Name, key: the
%   dataset's folder relative to root, prepared: the result
%   EphysDataset.launchSorting starts). Empty when nothing is kept, or the
%   preference is not of that shape.
%
%   See also keepKSRuns, restoreKSQueue.
store = struct('root', {}, 'saved', {}, 'runs', {});
if ~AppPrefs.ispref(group, 'KeptSortingQueue'); return; end
v = AppPrefs.getpref(group, 'KeptSortingQueue');
if isstruct(v) && isequal(fieldnames(v), fieldnames(store))
    store = reshape(v, 1, []);
end
end
