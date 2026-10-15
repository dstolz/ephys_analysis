function onFigureSessionPicked(obj)
%onFigureSessionPicked  Another of a session figure's figures picked under the preview ("Figure:"): draw it, computing nothing.
%   A session figure with one figure per subject or per trial group keeps
%   them all (FigureSessionResults, refreshFigurePreview); the drop-down
%   picks the one drawn.
%
%   See also refreshFigurePreview, figureSessionCompute.
if isempty(obj.FigureSessionResults); return; end
obj.refreshFigurePreview(Redraw=true);
end
