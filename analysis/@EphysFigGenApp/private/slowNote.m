function t = slowNote(obj)
%slowNote  The status line's word when the Auto slider's limit leaves edits of the figure just drawn waiting for Preview.
%   "" when Auto is off or always redraws, or the time was not counted.
t = "";
limit = autoRedrawLimit(obj);
if limit == 0 || isinf(limit) || obj.FigurePreviewSeconds == 0; return; end
C = obj.FigurePreviewCost;
if C.draw >= limit
    t = ": slow to draw, so edits wait for Preview";
elseif C.compute + C.draw >= limit
    t = ": slow to compute, so only edits of the look (colors, fonts, labels, places) redraw; the others wait for Preview";
end
end
