function m = favoriteMarks(obj, T, data)
%favoriteMarks  "★ " before each starred observation of T (figureObservations' table on the active dataset), else "".
%   DATA is the figure's observe.data: a sorted unit is starred by its id
%   on the sort in use, a detection channel ("detected") and a channel by
%   their recording channel, the dataset by its own star. The picker's
%   ItemsData are T's rows and the figure's pick is kept by T.label, so the
%   mark changes neither.
%
%   See also refreshFigureObservations, markObservations, DatasetFavorites.
n = 0;
if istable(T); n = height(T); end
m = strings(1, n);
if n == 0 || isempty(obj.Runner) || obj.ActiveIdx < 1 || numel(obj.Favorites) < obj.ActiveIdx; return; end
fav = obj.Favorites(obj.ActiveIdx);
on = false(1, n);
for kind = ["dataset" "unit" "channel"]
    rows = reshape(T.kind == kind, 1, []);
    if ~any(rows); continue; end
    switch kind
        case "dataset"
            on(rows) = fav.Dataset;
        case "unit"
            if data == "detected"
                on(rows) = fav.isStarred("channel", reshape(T.channel(rows), 1, []));
            else
                on(rows) = fav.isStarred("unit", reshape(T.unitId(rows), 1, []));
            end
        case "channel"
            on(rows) = fav.isStarred("channel", reshape(T.channel(rows), 1, []));
    end
end
m(on) = "★ ";
end
