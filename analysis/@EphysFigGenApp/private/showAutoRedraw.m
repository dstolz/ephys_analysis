function showAutoRedraw(obj, t)
%showAutoRedraw  The Auto slider's tooltip (and its label's) at threshold T: the limit it gives, what the ends do; the label gray when off.
%   showAutoRedraw(OBJ) shows the slider's own value; showAutoRedraw(OBJ, T)
%   shows T (while it is dragged: onFigureAutoRedrawChanged). Called when
%   the tab is built, by loadPreferences and by onFigureAutoRedrawChanged.
%
%   See also autoRedrawLimit, onFigureAutoRedrawChanged.
s = obj.FigureAutoSlider;
if isempty(s) || ~isvalid(s); return; end
if nargin < 2; t = s.Value; end
[~, txt] = autoRedrawLimit(obj, t);
key = "Ctrl";
if ismac; key = "Cmd"; end
ends = " Left end: off, every edit waits for Preview. Right end: every edit redraws, however long that takes. " + ...
    "A figure across sessions waits for Preview whatever the setting.";
if t <= 0
    tip = "Auto redraw is off: press Preview after editing. Drag right to redraw after edits: the further right, " + ...
        "the slower a redraw an edit may start." + ends + " (" + key + "+T: on again)";
else
    tip = "Auto redraw " + txt + sprintf(" (%.2f)", t) + ": an edit redraws the preview when that is predicted to take " + ...
        txt + ", from the last preview: an edit of colors, fonts, labels or places only draws again, an edit of the data " + ...
        "also computes." + ends + " (" + key + "+T: off)";
end
s.Tooltip = tip;
L = findobj(s.Parent.Children, "flat", "Type", "uilabel");
gray = [0.5 0.5 0.5];
if t > 0; gray = [0 0 0]; end
set(L, "Tooltip", tip, "FontColor", gray);
end
