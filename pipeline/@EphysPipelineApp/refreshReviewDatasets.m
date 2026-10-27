function refreshReviewDatasets(obj, opts)
%refreshReviewDatasets  Fill the Review tab's Datasets table, the tab's choice of dataset.
%   One row per dataset the other tabs' Dataset boxes list (the Project
%   tab's ticked datasets, else every one, and always the active one; see
%   refreshDatasetPickers), with what its sorted output is now: the sorter
%   of the sort in use (sortingResultsDir; "missing" for a pinned folder
%   that is not there, "-" for none), its clusters and how many are good
%   and mua (the labels the units table shows: phy's, else the sorter's;
%   EphysDataset.labelCounts), when phy last saved there (cluster_info.tsv,
%   EphysDataset.phyStatus; "opened" when phy opened it but saved nothing)
%   and how many sorts it has (reviewSorts). The Sort cell is the sort picked
%   for review (reviewSortChoice; "(in use)" when none), a dropdown of the
%   sorts the datasets have (ColumnFormat). Rows are in the table's remembered sort (tableSort
%   "ReviewDatasets"), the active dataset's row selected; ReviewDatasetRows
%   maps each row of Data to its dataset, so a click picks the right one in
%   any order (onReviewDatasetSelected).
%
%   The project may be on a slow share, so each dataset's sort is read
%   once and kept (ReviewDatasetStats, by dataset key, with its list of sorts and the Sort choice), and only while the
%   Review tab is open: until then a row shows the name alone. A row is
%   read again when its sort in use changes (Use this sort, the Sorting
%   tab), when the tab shows the dataset (syncReviewDataset, and each time
%   the tab is opened, so phy's latest save shows), after Open in phy, a
%   sorting run's start or end, and for every dataset after a scan.
%   refreshReviewDatasets(Datasets=IDX) reads the datasets IDX (indices
%   into Project.Datasets) again, also while the tab is closed.
arguments
    obj (1,1) EphysPipelineApp
    opts.Datasets (1,:) double = []
end
tbl = obj.ReviewDatasetTable;
if isempty(tbl) || ~isvalid(tbl); return; end

n = 0;
if ~isempty(obj.Project); n = obj.Project.NumDatasets; end
if n == 0
    tbl.Data = cell(0, numel(tbl.ColumnName));
    obj.ReviewDatasetRows = zeros(1, 0);
    return
end

idx = obj.selectedDatasetIndices();
active = obj.SelectedDatasetIdx;
if active >= 1 && active <= n && ~ismember(active, idx)
    idx = sort([idx active]);
end
readNow = ~isempty(obj.Tabs) && isvalid(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabReview;

C = cell(numel(idx), 8);
for k = 1:numel(idx)
    i = idx(k);
    d = obj.Project.Datasets(i);
    key = string(obj.Project.datasetKey(i));
    folder = string(d.sortingResultsDir());
    j = find(string([obj.ReviewDatasetStats.key]) == key, 1);
    stale = isempty(j) || obj.ReviewDatasetStats(j).folder ~= folder;
    if ismember(i, opts.Datasets) || (stale && readNow)
        if isempty(j)
            j = numel(obj.ReviewDatasetStats) + 1;
            obj.ReviewDatasetStats(j).sorts = NaN;
            obj.ReviewDatasetStats(j).choice = "";
        elseif stale
            obj.ReviewDatasetStats(j).sorts = NaN;   % another sort in use: count its sorts again
        end
        obj.ReviewDatasetStats(j).key = key;
        obj.ReviewDatasetStats(j).folder = folder;
        obj.ReviewDatasetStats(j).cells = sortCells(d, folder);
        if i == obj.ReviewDatasetIdx
            list = obj.ReviewSorts;   % syncReviewDataset / onReviewRefresh have just listed them
        else
            list = reviewSorts(d);
        end
        obj.ReviewDatasetStats(j).list = list;
        ch = string(obj.ReviewDatasetStats(j).choice);
        if ch ~= "" && ~any(EphysDataset.pathKey(string({list.dir})) == EphysDataset.pathKey(ch))
            obj.ReviewDatasetStats(j).choice = "";   % that sort is gone
        end
        stale = false;
    end
    if i == obj.ReviewDatasetIdx && ~isempty(j)
        % The tab shows this dataset: its Sort list counts its sorts.
        obj.ReviewDatasetStats(j).sorts = numel(obj.ReviewSorts) - d.sortingMissing();
    end
    C{k, 1} = char(d.Name);
    if stale
        C(k, 2:8) = {'', '', [], [], [], '', []};
    else
        C{k, 2} = sortChoiceName(obj.ReviewDatasetStats(j));
        C(k, 3:7) = obj.ReviewDatasetStats(j).cells;
        C{k, 8} = num(obj.ReviewDatasetStats(j).sorts);
    end
end

[C, ord] = TableSort.apply(C, obj.tableSort("ReviewDatasets"), tbl.ColumnName);
tbl.Data = C;
names = strings(1, 0);
for s = obj.ReviewDatasetStats
    if ~isempty(s.list); names = [names, string({s.list.name})]; end %#ok<AGROW>
end
fmt = repmat({[]}, 1, numel(tbl.ColumnName));
fmt{2} = cellstr(["(in use)", unique(names, 'stable')]);
tbl.ColumnFormat = fmt;
obj.ReviewDatasetRows = reshape(idx(ord), 1, []);
row = find(obj.ReviewDatasetRows == active, 1);
if isempty(row); row = []; end
tbl.Selection = row;
end


function n = sortChoiceName(s)
%sortChoiceName  The Sort cell of a dataset's stats S: the picked sort's name, else "(in use)".
n = '(in use)';
if isempty(s.choice) || strlength(s.choice) == 0 || isempty(s.list); return; end
k = find(EphysDataset.pathKey(string({s.list.dir})) == EphysDataset.pathKey(string(s.choice)), 1);
if ~isempty(k); n = char(s.list(k).name); end
end


function c = sortCells(d, folder)
%sortCells  Dataset D's row past its name: sorter, units, good, mua, phy saved.
c = {'-', [], [], [], ''};
if d.sortingMissing()
    c{1} = 'missing';
    return
end
if ~isfile(fullfile(folder, 'spike_clusters.npy')); return; end
c{1} = char(sorterOfSort(folder));
n = EphysDataset.labelCounts(folder);
c(2:4) = {num(n.total), num(n.good), num(n.mua)};
p = EphysDataset.phyStatus(folder);
if p.state == "saved" && ~isnat(p.saved)
    c{5} = char(string(p.saved, 'yyyy-MM-dd HH:mm'));
elseif p.state ~= "none"
    c{5} = 'opened';
end
end


function v = num(x)
%num  A count for a table cell: [] (blank) when it is not known.
v = [];
if isfinite(x); v = x; end
end
