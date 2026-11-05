function [s, part] = previewCost(obj)
%previewCost  How long drawing the shown figure again would take now, s, predicted from its last preview.
%   [S, PART] = previewCost(OBJ) is what autoFigurePreview and
%   arrangedPreview hold against the Auto slider's limit (autoRedrawLimit).
%   refreshFigurePreview times each preview in two parts
%   (FigurePreviewCost): computing the figure's data and drawing them.
%   When the data key is the one last computed (previewDataKey: the
%   figure's data spec, the dataset, the observation, the scan), as after
%   an edit of colors, fonts, labels, titles or places, the runner reuses
%   what it computed, so only the drawing counts (PART "draw"); otherwise
%   both (PART "compute"). The compute's time is that of the last preview
%   that computed the data, so an edit of the looks between two data edits
%   does not hide what the next one costs.
%   S is 0 when the time was forgotten (FigurePreviewSeconds 0: another
%   figure shown, another dataset or config, the first preview after the
%   app starts, which also loads the graphics): drawn once, then timed. S
%   is Inf when the last preview failed, was canceled or waits for Preview
%   (a large signal extract): only Preview draws it. PART is "" for both.
%
%   See also autoRedrawLimit, previewDataKey, autoFigurePreview, refreshFigurePreview.
s = obj.FigurePreviewSeconds;
part = "";
if s == 0 || ~isfinite(s); return; end
C = obj.FigurePreviewCost;
if isempty(C.key); return; end   % no parts kept: the whole last preview
if isequaln(C.key, previewDataKey(obj, obj.SelectedFigure))
    s = C.draw;
    part = "draw";
else
    s = C.compute + C.draw;
    part = "compute";
end
end
