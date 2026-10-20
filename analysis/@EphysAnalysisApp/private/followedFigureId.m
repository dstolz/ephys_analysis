function id = followedFigureId(obj, id)
%followedFigureId  The id figure ID has now: ID itself while a figure has it, else the id it was renamed to (FigureIdRenames).
%   ID = followedFigureId(OBJ, ID) follows the renames trackFigureIds
%   noted (an automatic id that followed an edit, an id typed), so a
%   window or a callback that kept a figure's id reaches the same figure
%   after it was renamed. An id that was never renamed and is gone (the
%   figure removed) comes back as it is: obj.Config.figureIndex says 0.
%
%   See also trackFigureIds.
id = string(id);
for hop = 1:100   % the renames hold no cycle (trackFigureIds); a bound all the same
    if obj.Config.figureIndex(id) > 0 || ~isKey(obj.FigureIdRenames, char(id)); return; end
    id = string(obj.FigureIdRenames(char(id)));
end
end
