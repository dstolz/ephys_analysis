function C = buildFavorites(obj, parent, prop)
%buildFavorites  A Favorites row: a filter field and the drop-down of every starred dataset, channel and unit.
%   C = buildFavorites(OBJ, PARENT, PROP) builds them in a grid of their own
%   (C.Grid, placed by the caller) and returns C.Filter and C.DropDown;
%   PROP is the app property C goes into ("AlignFavorites" or
%   "FigureFavorites"), which their callbacks name. Typing in the filter
%   narrows the list (onFavoritesFilter); picking an entry goes to it
%   (onFavoritePicked). refreshFavorites fills the list.
%
%   See also refreshFavorites, onFavoritesFilter, onFavoritePicked, starButton.
C = struct();
C.Grid = uigridlayout(parent, [1 2], "ColumnWidth", {160, '1x'}, "ColumnSpacing", 6, "Padding", [0 0 0 0]);
C.Filter = uieditfield(C.Grid, "text", "Placeholder", "Filter favorites", ...
    "Tooltip", "Narrow the Favorites list as you type: every word must appear in an entry (dataset name, ""channel 5"", ""unit 12"", a class such as ""su"").", ...
    "ValueChangingFcn", @(~, evt) obj.onFavoritesFilter(prop, evt.Value), ...
    "ValueChangedFcn", @(f, ~) obj.onFavoritesFilter(prop, f.Value));
C.DropDown = uidropdown(C.Grid, "Items", "(scan to list the favorites)", "ItemsData", 0, ...
    "Tooltip", "Every starred dataset, channel and unit of the scanned datasets. Picking one makes its dataset active " + ...
    "and, when the figure selected on the Figures tab observes units or channels, previews that unit or channel.", ...
    "ValueChangedFcn", @(~, ~) obj.onFavoritePicked(prop));
end
