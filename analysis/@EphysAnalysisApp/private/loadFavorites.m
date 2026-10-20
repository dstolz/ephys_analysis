function loadFavorites(obj)
%loadFavorites  Read every scanned dataset's stars: Favorites becomes a DatasetFavorites per dataset (the Runner's order).
%   Each reads <Name>_favorites.json in its dataset's output folder (one
%   small file; none: no star). A file that cannot be read gives no star,
%   and the Log says why. The units' sort is looked up only for a dataset
%   whose file stars units.
%
%   See also DatasetFavorites, onScan, refreshFavorites.
r = obj.Runner;
obj.Favorites = [];
if isempty(r) || isempty(r.Keys); return; end
F = cell(1, numel(r.Keys));
for k = 1:numel(r.Keys)
    F{k} = DatasetFavorites(r.Outputs(k));
    if F{k}.Problem ~= ""
        obj.log("Favorites of " + r.Names(k) + ": " + F{k}.Problem);
    end
end
obj.Favorites = [F{:}];
end
