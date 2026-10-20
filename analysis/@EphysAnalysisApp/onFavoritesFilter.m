function onFavoritesFilter(obj, which, text)
%onFavoritesFilter  The Favorites filter typed in: narrow that tab's Favorites list to the entries holding every word of TEXT.
%   WHICH is "AlignFavorites" or "FigureFavorites"; TEXT is the field's
%   text as typed (its value while typing), kept in the field's UserData
%   so the list stays narrowed when it is filled again. Case is ignored.
%
%   See also fillFavorites, refreshFavorites.
arguments
    obj (1,1) EphysAnalysisApp
    which (1,1) string {mustBeMember(which, ["AlignFavorites" "FigureFavorites"])}
    text (1,1) string = ""
end
C = obj.(which);
if ~isstruct(C) || ~isfield(C, 'Filter'); return; end
C.Filter.UserData = text;   % the field's Value lags while typing
fillFavorites(obj, C, text);
end
