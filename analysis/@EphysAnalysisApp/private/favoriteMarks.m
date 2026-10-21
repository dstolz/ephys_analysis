function m = favoriteMarks(obj, T, data, sessions)
%favoriteMarks  "★ " before each starred observation of T (figureObservations' table on the active dataset), else "".
%   DATA is the figure's observe.data: a sorted unit is starred by its id
%   on the sort in use, a detection channel ("detected") and a channel by
%   their recording channel, the dataset by its own star
%   (DatasetFavorites.observationStarred). The picker's ItemsData are T's
%   rows and the figure's pick is kept by T.label, so the mark changes
%   neither.
%
%   M = favoriteMarks(OBJ, T, DATA, SESSIONS) marks the matched
%   observations of a figure across sessions (figureSessionObservations'
%   T; SESSIONS the dataset index of each session, its columns): a match
%   is starred when it is starred on any of its sessions, as Starred only
%   keeps it -- for a site, any of the units on it (unitIds), else the
%   session's own observation (perSession).
%
%   The stars are those in memory (Favorites), which a toggle has just
%   written.
%
%   See also refreshFigureObservations, markObservations, DatasetFavorites,
%   figureSessionObservations.
arguments
    obj
    T
    data (1,1) string
    sessions double = []
end
n = 0;
if istable(T); n = height(T); end
m = strings(1, n);
if n == 0 || isempty(obj.Runner); return; end
if nargin < 4
    if obj.ActiveIdx < 1 || numel(obj.Favorites) < obj.ActiveIdx; return; end
    on = reshape(obj.Favorites(obj.ActiveIdx).observationStarred(T, data), 1, []);
else
    on = false(1, n);
    if ~ismember("perSession", string(T.Properties.VariableNames)); return; end
    for r = 1:n
        P = T.perSession{r};
        ids = T.unitIds{r};
        for k = 1:min(numel(sessions), height(P))
            d = sessions(k);
            if ~P.present(k) || d < 1 || d > numel(obj.Favorites); continue; end
            fav = obj.Favorites(d);
            if T.kind(r) == "unit" && data ~= "detected" && k <= numel(ids) && ~isempty(ids{k})
                on(r) = any(fav.isStarred("unit", ids{k}));
            else
                on(r) = fav.observationStarred(P(k, :), data);
            end
            if on(r); break; end
        end
    end
end
m(on) = "★ ";
end
