function onFavoritePicked(obj, which)
%onFavoritePicked  A favorite picked from a Favorites drop-down: go to it.
%   WHICH is "AlignFavorites" or "FigureFavorites". The entry's dataset
%   becomes the active one (selectDataset). A starred unit or channel is
%   then picked in the Figures tab's observation list when the figure
%   selected there observes that kind (goToFavorite). The drop-down goes
%   back to its first item, so the same entry can be picked again.
%
%   See also refreshFavorites, fillFavorites, selectDataset, goToFavorite.
arguments
    obj (1,1) EphysAnalysisApp
    which (1,1) string {mustBeMember(which, ["AlignFavorites" "FigureFavorites"])}
end
C = obj.(which);
dd = C.DropDown;
i = dd.Value;
dd.Value = 0;
E = obj.FavoriteEntries;
if isempty(obj.Runner) || ~istable(E) || ~isnumeric(i) || ~isscalar(i) || i < 1 || i > height(E); return; end
goToFavorite(obj, E(i, :));
end
