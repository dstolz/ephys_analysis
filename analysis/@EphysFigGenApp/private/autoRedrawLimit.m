function [s, txt] = autoRedrawLimit(obj, t)
%autoRedrawLimit  The longest redraw an edit may start under the Figures tab's Auto slider, s: 0 = Auto off, Inf = every edit.
%   [S, TXT] = autoRedrawLimit(OBJ) maps the slider's threshold T
%   (FigureAutoSlider, 0 to 1; the preference FigureAutoRedraw) to seconds:
%     T = 0      0: Auto off, every edit waits for Preview
%     0 < T < 1  AutoRedrawScale * T / (1 - T): 0.67 s at 0.25, 2 s at the
%                default 0.5 (AutoRedrawDefault), 6 s at 0.75, 18 s at 0.9
%     T = 1      Inf: every edit redraws, however long that takes
%   An edit redraws the preview when the time it is predicted to take
%   (previewCost) is under S. TXT says S in words for the tooltip and the
%   status bar: "off", "under 2 s", "always".
%   autoRedrawLimit(OBJ, T) maps T instead of the slider's value (the
%   slider while it is dragged: onFigureAutoRedrawChanged).
%
%   See also previewCost, autoFigurePreview, onFigureAutoRedrawChanged.
if nargin < 2
    t = 0;
    if ~isempty(obj.FigureAutoSlider) && isvalid(obj.FigureAutoSlider); t = obj.FigureAutoSlider.Value; end
end
t = min(max(double(t), 0), 1);
if t <= 0
    s = 0;
    txt = "off";
elseif t >= 1
    s = Inf;
    txt = "always";
else
    s = obj.AutoRedrawScale * t / (1 - t);
    txt = "under " + secondsText(s);
end
end


function txt = secondsText(s)
%secondsText  S seconds in a few characters: "0.67 s", "2 s", "2.5 s", "18 s".
if s < 1
    txt = string(sprintf('%.2g s', s));
elseif s < 10
    txt = string(regexprep(sprintf('%.1f', s), '\.0$', '')) + " s";
else
    txt = string(sprintf('%.0f s', s));
end
end
