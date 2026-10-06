function [sorts, use] = reviewSorts(d)
%reviewSorts  Dataset D's sorted-output folders, as the Review tab's Sort dropdown lists them.
%   SORTS (struct array: dir, label): the dataset's own sorted output
%   (sortingResultsDir: its pinned SortingDir, else its Sorter's run
%   folder) first, when it holds a sort or is pinned; then each other
%   folder under its output folder holding one (spike_clusters.npy:
%   kilosort4, si_<sorter>, a sortSweep's variants, a copy), by path. A
%   label names the folder (relative to the output folder; "pinned" for
%   the SortingDir), its sorter and its unit count; "in use" marks the
%   dataset's own, which Export and the analysis read. USE: the one to
%   show, the dataset's own, else the most recently changed
%   (DatasetTracker.latestKilosortRun's choice); 0 for none.
%   See syncReviewDataset, onReviewUseSort.
sorts = struct('dir', {}, 'label', {});
use = 0;
out = string(d.outputFolder());
dirs = strings(0, 1);
if out ~= "" && isfolder(out)
    D = DatasetTracker.listFiles(out, "spike_clusters.npy");
    if ~isempty(D); dirs = unique(string({D.folder}).'); end
end
own = string(d.sortingResultsDir());
pinned = d.SortingDir ~= "";
hasOwn = pinned || isfile(fullfile(own, 'spike_clusters.npy'));
if hasOwn
    dirs = [own; dirs(EphysDataset.pathKey(dirs) ~= EphysDataset.pathKey(own))];
end
modified = NaT(numel(dirs), 1);
for k = 1:numel(dirs)
    run = DatasetTracker.kilosortRunAt(dirs(k));
    where = relativeTo(dirs(k), out);
    mine = hasOwn && k == 1;
    if mine && pinned; where = "pinned " + where; end
    if isempty(run)
        txt = where + ": not there now";
    else
        txt = where + ": " + EphysDataset.sorterLabel(sorterOfSort(dirs(k)));
        if isfinite(run.NumUnits); txt = txt + sprintf(", %d units", run.NumUnits); end
        modified(k) = run.Modified;
    end
    if mine; txt = txt + " - in use"; end
    sorts(k) = struct('dir', dirs(k), 'label', txt);
end
if hasOwn
    use = 1;
elseif ~isempty(dirs)
    [~, use] = max(modified);
end
end


function p = relativeTo(folder, root)
%relativeTo  FOLDER below ROOT as a path relative to it ("/" separators), else as given.
p = string(folder);
f = EphysProject.normalizeKey(folder);
r = EphysProject.normalizeKey(root);
if r ~= "" && startsWith(EphysDataset.pathKey(f), EphysDataset.pathKey(r) + "/")
    p = extractAfter(f, strlength(r) + 1);
end
end
