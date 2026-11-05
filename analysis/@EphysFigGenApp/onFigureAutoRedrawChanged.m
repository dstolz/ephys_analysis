function onFigureAutoRedrawChanged(obj, t)
%onFigureAutoRedrawChanged  The Figures tab's Auto slider moved: the limit it gives said, an out-of-date preview drawn when it now may be; kept as a preference (FigureAutoRedraw).
%   onFigureAutoRedrawChanged(OBJ) is the slider's release (and Ctrl+T:
%   pressFigureButton). The threshold goes to the nearest 0.05; a setting
%   above 0 is kept for Ctrl+T (FigureAutoLast). The status bar says what
%   edits now do (autoRedrawLimit), and the slider's tooltip the limit
%   (showAutoRedraw). A preview out of date is drawn when the new limit
%   lets it (autoFigurePreview); one that is current is left as it is.
%   onFigureAutoRedrawChanged(OBJ, T) is the slider while it is dragged, at
%   T: only the status bar and the tooltip follow.
%
%   See also autoRedrawLimit, autoFigurePreview, showAutoRedraw.
s = obj.FigureAutoSlider;
final = nargin < 2;
if final
    t = round(s.Value * 20) / 20;   % in steps of 0.05
    s.Value = t;
    if t > 0; obj.FigureAutoLast = t; end
end
[~, txt] = autoRedrawLimit(obj, t);
showAutoRedraw(obj, t);
if t <= 0
    msg = "Auto redraw off: press Preview after editing.";
elseif t >= 1
    msg = "Auto redraw always: every edit redraws the preview, however long that takes.";
else
    msg = "Auto redraw " + txt + sprintf(" (%.2f)", t) + ": an edit redraws the preview when that takes " + txt + ...
        "; a slower one waits for Preview.";
end
obj.setStatus(msg);
if ~final; return; end
obj.savePreferences();
if t > 0 && ~figureViewFresh(obj)
    obj.autoFigurePreview();
    obj.setStatus(msg);   % (the preview's own messages go to the line under it)
end
end
