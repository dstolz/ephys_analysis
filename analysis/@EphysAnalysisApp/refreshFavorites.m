function refreshFavorites(obj)
%refreshFavorites  Show the stars everywhere: the Favorites lists, the star toggles and the ★ marks.
%   FavoriteEntries becomes every starred dataset, channel and unit of the
%   scanned datasets (Favorites: a DatasetFavorites each, read on Scan),
%   labeled "subj1_day1", "subj1_day1 · channel 5 · 850 µm",
%   "subj1_day1 · unit 12 · su · ch 5 · 850 µm" (the class, channel and
%   depth once the dataset has been opened: listFavorites), and the
%   Favorites drop-downs of the Alignment and Figures tabs list them,
%   narrowed by their filters (fillFavorites); the Data tab's ★ column
%   (refreshDatasetsTable), the Dataset drop-downs (refreshDatasetLabels),
%   the observation picker and the star toggles (syncStarButtons) follow.
%   The picker's marks are set again (markObservations), or, when the
%   selected figure keeps only the starred observations (observe.starred),
%   it is listed again (refreshFigureObservations Force), the preview
%   following when the pick changed. Nothing is read: the stars are those
%   in memory, which a toggle has just written.
%
%   See also DatasetFavorites, listFavorites, onStarToggled, onFavoritePicked, onScan.
r = obj.Runner;
listFavorites(obj);
if ~isempty(r) && ~isempty(r.Keys)
    obj.refreshDatasetsTable();
    refreshDatasetLabels(obj);
end
k = obj.SelectedFigure;
if k >= 1 && k <= numel(obj.Config.Figures) && obj.Config.Figures(k).observe.starred
    dd = obj.FigureObservationDropDown;
    before = string(dd.Items(dd.ItemsData == dd.Value));   % ItemsData 1:n (0 when empty)
    obj.refreshFigureObservations(Force=true);
    after = string(dd.Items(dd.ItemsData == dd.Value));
    if ~isequal(regexprep(before, "^(★ )?(✎ )?", ""), regexprep(after, "^(★ )?(✎ )?", ""))
        obj.autoFigurePreview();
    end
else
    markObservations(obj);
end
syncStarButtons(obj);
end
