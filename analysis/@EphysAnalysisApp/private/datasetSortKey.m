function s = datasetSortKey(r, k)
%datasetSortKey  Dataset K's key in DatasetUnits: its dataset key and its sort folder ("<key>|<sort folder>").
%   R is the EphysAnalysisRunner. The units read for a dataset stay under
%   this key when another dataset is opened, and go stale only when its
%   sort folder changes.
%
%   See also refreshDatasetLabels, listFavorites.
d = reshape(string(r.Outputs(k).SortingDir), 1, []);
if isempty(d); d = ""; end
s = char(string(r.Keys(k)) + "|" + strjoin(d, ";"));
end
