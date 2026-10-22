function markObservations(obj)
%markObservations  Mark the observation picker's starred units and channels ("★ ") and those with a note ("✎ ") again, keeping the list and the pick.
%   After a star or a note changed: the items keep their text
%   (refreshFigureObservations') with the marks set anew (favoriteMarks,
%   noteMarks); nothing is listed again. A figure across sessions gets
%   the star of a match starred on any of its sessions (favoriteMarks
%   with the sessions' datasets, the picker's UserData.sessions) and no
%   note marks.
%
%   See also favoriteMarks, noteMarks, refreshFavorites, refreshNotes.
dd = obj.FigureObservationDropDown;
T = obj.FigureObservations;
k = obj.SelectedFigure;
if ~istable(T) || height(T) == 0 || k < 1 || k > numel(obj.Config.Figures)
    return
end
items = regexprep(reshape(string(dd.Items), 1, []), "^(★ )?(✎ )?", "");
if numel(items) ~= height(T); return; end
data = obj.Config.Figures(k).observe.data;
if obj.Config.Figures(k).sessions.enabled
    u = dd.UserData;
    if ~(isstruct(u) && isfield(u, 'sessions')); return; end
    dd.Items = favoriteMarks(obj, T, data, u.sessions) + items;
    keepFigurePicker(obj);
    return
end
dd.Items = favoriteMarks(obj, T, data) + noteMarks(obj, T, data) + items;
keepFigurePicker(obj);   % the figure's kept list with the new marks
end
