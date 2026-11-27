function [k, id] = figureIndexOf(obj, id)
%figureIndexOf  The index of the figure ID names now, following its renames; 0 when it is gone.
%   [K, ID] = figureIndexOf(OBJ, ID) is Config.figureIndex of the id the
%   figure has now: ID itself while a figure has it, else the id it was
%   renamed to since (followedFigureId: an automatic id that followed an
%   edit of its panels or data, an id typed). ID comes back as that id.
%   The command line's figures (OBJ.Plots: PlotFigureNode) keep a figure's
%   id and find the figure with this each time they are used.
%
%   See also followedFigureId, trackFigureIds, PlotConsole.
arguments
    obj (1,1) EphysFigGenApp
    id (1,1) string
end
id = followedFigureId(obj, id);
k = obj.Config.figureIndex(id);
end
