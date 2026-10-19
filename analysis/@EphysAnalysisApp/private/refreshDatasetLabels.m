function refreshDatasetLabels(obj, idx)
%refreshDatasetLabels  The Dataset drop-downs' items: each dataset's name and its number of sorted units.
%   refreshDatasetLabels(OBJ) labels the datasets of the Alignment,
%   Figures and Chronux tabs' Dataset drop-downs (the same items on each;
%   their ItemsData, the datasets' indices, and so the pick, are kept):
%     "subj1_day1  (14 units)"      a sort whose units have been counted
%     "subj1_day1"                  a sort not counted yet
%     "subj2_day1  (detected only)" no sort, a spikes file
%     "subj3_day1  (no sorting)"    neither
%   Nothing is read here: whether a dataset has a sort or a spikes file
%   comes from its loaded source (hasUnits, hasDetected) when it has one,
%   else from the scan's files (DatasetOutputs.has), and the counts from
%   OBJ.DatasetUnitCounts.
%
%   refreshDatasetLabels(OBJ, IDX) first counts the sorted units of
%   dataset IDX, the active one, whose units its Data tab has read already
%   (DatasetOutputs.load("sorting"), from the outputs' cache), and keeps
%   the count in DatasetUnitCounts by dataset key and sort folder, so it
%   stays when another dataset is opened and goes stale only when the sort
%   folder changes. A dataset is counted the first time it is opened, so a
%   share's folders are never walked for the counts.
%
%   See also selectDataset, onScan, refreshDatasetsTable.
arguments
    obj (1,1) EphysAnalysisApp
    idx (1,1) double = 0
end
r = obj.Runner;
if isempty(r) || isempty(r.Keys); return; end
if ~isa(obj.DatasetUnitCounts, 'containers.Map')
    obj.DatasetUnitCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
end
counts = obj.DatasetUnitCounts;
if idx >= 1 && idx <= numel(r.Keys) && isKey(r.Sources, char(r.Keys(idx)))
    src = r.Sources(char(r.Keys(idx)));
    if src.hasUnits
        try
            U = src.outputs.load("sorting");
            counts(sortKey(r, idx)) = numel(U.unitId);
        catch
        end
    end
end
n = numel(r.Keys);
items = reshape(string(r.Names), 1, []);
for k = 1:n
    out = r.Outputs(k);
    key = char(r.Keys(k));
    if isKey(r.Sources, key)
        src = r.Sources(key);
        hasU = src.hasUnits;
        hasD = src.hasDetected;
    else
        hasU = out.has("sorting");
        hasD = out.has("spikes");   % the spikes file holds the detections
    end
    if hasU
        s = sortKey(r, k);
        if isKey(counts, s)
            c = counts(s);
            items(k) = items(k) + sprintf("  (%d unit%s)", c, repmat('s', 1, c ~= 1));
        end
    elseif hasD
        items(k) = items(k) + "  (detected only)";
    else
        items(k) = items(k) + "  (no sorting)";
    end
end
set([obj.AlignDatasetDropDown obj.FiguresDatasetDropDown], 'Items', items);
end


function s = sortKey(r, k)
%sortKey  Dataset K's key in DatasetUnitCounts: its dataset key and its sort folder.
d = reshape(string(r.Outputs(k).SortingDir), 1, []);
if isempty(d); d = ""; end
s = char(string(r.Keys(k)) + "|" + strjoin(d, ";"));
end
