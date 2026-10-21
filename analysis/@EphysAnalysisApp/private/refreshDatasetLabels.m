function refreshDatasetLabels(obj, idx)
%refreshDatasetLabels  The Dataset drop-downs' items: each dataset's name and its number of sorted units.
%   refreshDatasetLabels(OBJ) labels the datasets of the Alignment
%   and Figures tabs' Dataset drop-downs (the same items on each;
%   their ItemsData, the datasets' indices, and so the pick, are kept):
%     "subj1_day1  (14 units)"      a sort whose units have been counted
%     "subj1_day1"                  a sort not counted yet
%     "subj2_day1  (detected only)" no sort, a spikes file
%     "subj3_day1  (no sorting)"    neither
%   and "★ " before a starred dataset (Favorites), "✎ " before one with a
%   note (Notes; after the star: "★ ✎ subj1_day1").
%   Nothing is read here: whether a dataset has a sort or a spikes file
%   comes from its loaded source (hasUnits, hasDetected) when it has one,
%   else from the scan's files (DatasetOutputs.has), and the counts from
%   OBJ.DatasetUnits.
%
%   refreshDatasetLabels(OBJ, IDX) first takes the sorted units of
%   dataset IDX, the active one, whose units its Data tab has read already
%   (DatasetOutputs.load("sorting"), from the outputs' cache), and keeps
%   them in DatasetUnits by dataset key and sort folder (datasetSortKey):
%   a table of unitId, class, channel and depth (their probe y, µm), whose
%   height is the count and which labels the Favorites (listFavorites). It
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
if ~isa(obj.DatasetUnits, 'containers.Map')
    obj.DatasetUnits = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
units = obj.DatasetUnits;
if idx >= 1 && idx <= numel(r.Keys) && isKey(r.Sources, char(r.Keys(idx)))
    src = r.Sources(char(r.Keys(idx)));
    if src.hasUnits
        try
            units(datasetSortKey(r, idx)) = unitTable(src.outputs.load("sorting"));
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
        s = datasetSortKey(r, k);
        if isKey(units, s)
            c = height(units(s));
            items(k) = items(k) + sprintf("  (%d unit%s)", c, repmat('s', 1, c ~= 1));
        end
    elseif hasD
        items(k) = items(k) + "  (detected only)";
    else
        items(k) = items(k) + "  (no sorting)";
    end
end
if numel(obj.Notes) == n
    noted = arrayfun(@(d) d.hasNote("dataset"), obj.Notes);
    items(noted) = "✎ " + items(noted);
end
if numel(obj.Favorites) == n
    starred = [obj.Favorites.Dataset];
    items(starred) = "★ " + items(starred);
end
set([obj.AlignDatasetDropDown obj.FiguresDatasetDropDown], 'Items', items);
end


function T = unitTable(U)
%unitTable  The sorted units' unitId, class, channel and depth (their y, µm; NaN when not known) from DatasetOutputs.load("sorting").
n = numel(U.unitId);
T = table(double(U.unitId(:)), strings(n, 1), NaN(n, 1), NaN(n, 1), 'VariableNames', {'unitId', 'class', 'channel', 'depth'});
if isfield(U, 'class'); T.class = string(U.class(:)); end
if isfield(U, 'channel'); T.channel = double(U.channel(:)); end
if isfield(U, 'y'); T.depth = double(U.y(:)); end
end
