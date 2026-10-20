function refreshFavorites(obj)
%refreshFavorites  Show the stars everywhere: the Favorites lists, the star toggles and the ★ marks.
%   FavoriteEntries becomes every starred dataset, channel and unit of the
%   scanned datasets (Favorites: a DatasetFavorites each, read on Scan), in
%   dataset order, each dataset's star, then its channels, then the units of
%   the sort it uses: dataset (its index), level, id and label
%   ("subj1_day1", "subj1_day1 · channel 5", "subj1_day1 · unit 12"). The
%   Favorites drop-downs of the Alignment and Figures tabs list them,
%   narrowed by their filters (fillFavorites); the Data tab's ★ column
%   (refreshDatasetsTable), the Dataset drop-downs (refreshDatasetLabels),
%   the observation picker (markObservations) and the star toggles
%   (syncStarButtons) follow. Nothing is read: the stars are those in
%   memory, which a toggle has just written.
%
%   See also DatasetFavorites, onStarToggled, onFavoritePicked, onScan.
r = obj.Runner;
dataset = zeros(0, 1);
level = strings(0, 1);
id = zeros(0, 1);
label = strings(0, 1);
if ~isempty(r) && numel(obj.Favorites) == numel(r.Keys)
    for k = 1:numel(r.Keys)
        L = obj.Favorites(k).list();
        n = height(L);
        if n == 0; continue; end
        lab = r.Names(k) + " · " + L.label;
        lab(L.level == "dataset") = r.Names(k);
        dataset = [dataset; repmat(k, n, 1)]; %#ok<AGROW>
        level = [level; L.level]; %#ok<AGROW>
        id = [id; L.id]; %#ok<AGROW>
        label = [label; lab]; %#ok<AGROW>
    end
end
obj.FavoriteEntries = table(dataset, level, id, label);
fillFavorites(obj, obj.AlignFavorites);
fillFavorites(obj, obj.FigureFavorites);
if ~isempty(r) && ~isempty(r.Keys)
    obj.refreshDatasetsTable();
    refreshDatasetLabels(obj);
end
markObservations(obj);
syncStarButtons(obj);
end
