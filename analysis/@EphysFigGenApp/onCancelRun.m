function onCancelRun(obj)
%onCancelRun  Stop a run (or a figure's Generate) before its next figure observation, or Redraw All.
%   The Export tab's Cancel and the toolbar's. While Redraw All goes
%   (FigureRedrawing, onRedrawAllFigures) it stops that instead: the
%   figure computing is canceled at its next checkpoint
%   (onCancelFigurePreview) and no other figure is drawn.
if obj.FigureRedrawing
    obj.FigureRedrawCanceled = true;
    obj.onCancelFigurePreview();
    obj.setStatus("Canceling Redraw All ...");
    return
end
if ~isempty(obj.Runner) && obj.Running
    obj.Runner.cancel();
    obj.setStatus("Canceling after the figure being drawn ...");
end
end
