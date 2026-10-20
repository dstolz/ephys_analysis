function fillFavorites(obj, C, text)
%fillFavorites  List the favorites (FavoriteEntries) in the Favorites drop-down of C, narrowed by the filter TEXT.
%   TEXT (default: the filter's text as last typed, else its value) keeps the entries whose label holds
%   every word of it, ignoring case. The first item says how many there
%   are (and match); it is the drop-down's value between picks, so the same
%   entry can be picked again.
%
%   See also refreshFavorites, onFavoritesFilter, buildFavorites.
if ~isstruct(C) || ~isfield(C, 'DropDown') || ~isvalid(C.DropDown); return; end
if nargin < 3
    text = C.Filter.Value;
    if isstring(C.Filter.UserData) && isscalar(C.Filter.UserData); text = C.Filter.UserData; end
end
E = obj.FavoriteEntries;
n = 0;
if istable(E); n = height(E); end
words = split(lower(strtrim(string(text))));
words = words(words ~= "");
keep = true(n, 1);
for w = reshape(words, 1, [])
    keep = keep & contains(lower(E.label), w);
end
if isempty(obj.Runner)
    head = "(scan to list the favorites)";
elseif n == 0
    head = "(no favorites: star a dataset, channel or unit)";
elseif isempty(words)
    head = sprintf("★ %d favorite%s", n, repmat('s', 1, n ~= 1));
else
    head = sprintf("★ %d of %d favorite%s match", nnz(keep), n, repmat('s', 1, n ~= 1));
end
rows = reshape(find(keep), 1, []);
labels = strings(1, 0);
if n > 0; labels = reshape(E.label(rows), 1, []); end
dd = C.DropDown;
dd.ItemsData = [];
set(dd, "Items", [head labels], "ItemsData", [0 rows], "Value", 0);
end
