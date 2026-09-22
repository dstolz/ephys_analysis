function tf = onArtViewInput(obj, kind, evt)
%onArtViewInput  Scale the Artifacts tab's plot from the wheel and the keys.
%   TF = obj.onArtViewInput(KIND, EVT) acts on the figure's wheel ("scroll")
%   and key ("key") events, passed on by routeFigureInput while the
%   Artifacts tab is showing, and on Reset view ("reset"), and returns
%   whether it took the event. The wheel and the keys act with the pointer
%   over the plot:
%     wheel, Shift+wheel ......... zoom time about the pointer
%     Ctrl+wheel ................. scale the voltage (Ctrl+Shift+wheel too)
%     left / right arrow ......... pan time by a quarter of the view
%     Shift+left / right arrow ... zoom time out / in about the view's centre
%     up / down arrow, + / - ..... scale the voltage up / down
%     r .......................... reset (as Reset view)
%   Dragging pans too (the axes' own pan, along time only). The voltage
%   scale is ArtView.gain, a factor on the Scale fit kept from one artifact
%   to the next until a reset or a new Scale (with Scale: Manual they
%   change the lane spacing, ArtViewLanesField); the time zoom is the axes'
%   XLim, kept while the same window is drawn (drawArtifactView). Reset
%   shows the whole window at the Scale fit. Wheel events carry no
%   modifiers, so the wheel reads ArtView.mods (kept by routeFigureInput).
%
%   See also drawArtifactView, routeFigureInput.

tf = false;
w = obj.ArtView.win;
if isempty(w) || isfield(w, 'error'); return; end   % nothing drawn
if kind == "reset"
    obj.ArtView.gain = 1;
    obj.ArtView.drawn.key = [];          % the next draw starts on the whole window
    obj.drawArtifactView();
    tf = true;
    return
end
ax = obj.ArtViewAxes;
if ~overAxes(obj, ax); return; end

switch kind
    case "scroll"
        mods = obj.ArtView.mods;
        sc = evt.VerticalScrollCount;
        if any(mods == "control" | mods == "command")
            scaleVoltage(obj, 1.25 ^ (-sc));
        else
            zoomTime(obj, 1.25 ^ sc, ax.CurrentPoint(1, 1));
        end
    case "key"
        mods = string(evt.Modifier);
        if any(mods == "control" | mods == "command" | mods == "alt"); return; end
        shift = any(mods == "shift");
        switch string(evt.Key)
            case {"uparrow", "equal", "add"}
                scaleVoltage(obj, 1.25);
            case {"downarrow", "hyphen", "subtract"}
                scaleVoltage(obj, 1 / 1.25);
            case "rightarrow"
                if shift; zoomTime(obj, 1 / 1.5, []); else; panTime(obj, 0.25); end
            case "leftarrow"
                if shift; zoomTime(obj, 1.5, []); else; panTime(obj, -0.25); end
            case "r"
                tf = obj.onArtViewInput("reset", []);
                return
            otherwise
                return
        end
    otherwise
        return
end
tf = true;
end


function scaleVoltage(obj, f)
% Lanes F times taller (within limits), redrawn. A scale set by hand
% (Scale: Manual) changes the lane spacing instead.
if obj.ArtViewScaleDropDown.Value == "manual" && obj.ArtViewLanesField.Value > 0
    obj.ArtViewLanesField.Value = obj.ArtViewLanesField.Value / f;
    obj.drawArtifactView();
    return
end
obj.ArtView.gain = min(max(obj.ArtView.gain * f, 1 / 64), 1024);
obj.drawArtifactView();
end


function zoomTime(obj, f, anchor)
% The view F times wider, ANCHOR (ms; [] = the view's centre) staying put.
% No narrower than 20 samples.
ax = obj.ArtViewAxes;
xl = ax.XLim;
if isempty(anchor) || ~isfinite(anchor); anchor = mean(xl); end
anchor = min(max(anchor, xl(1)), xl(2));
span = obj.ArtView.drawn.span;
wid = min(max(diff(xl) * f, min(20e3 / obj.ArtView.win.Fs, diff(span))), diff(span));
a = anchor - (anchor - xl(1)) * wid / diff(xl);
setTime(obj, [a, a + wid]);
end


function panTime(obj, frac)
% The view moved by FRAC of its width.
xl = obj.ArtViewAxes.XLim;
setTime(obj, xl + frac * diff(xl));
end


function setTime(obj, xl)
% Show XL (ms), moved inside the window drawn. A zoom finer than the
% envelope drawn is redrawn (drawArtifactView keeps the XLim set here).
D = obj.ArtView.drawn;
wid = min(diff(xl), diff(D.span));
a = min(max(xl(1), D.span(1)), D.span(2) - wid);
obj.ArtViewAxes.XLim = [a, a + wid];
if D.decimated && 2 ^ ceil(log2(diff(D.span) / wid) - 1e-9) > D.factor
    obj.drawArtifactView();
end
end


function tf = overAxes(obj, ax)
% True when the pointer is inside AX (pixel coordinates).
pp = getpixelposition(ax, true);
cp = obj.Fig.CurrentPoint;
tf = cp(1) >= pp(1) && cp(1) <= pp(1) + pp(3) && cp(2) >= pp(2) && cp(2) <= pp(2) + pp(4);
end
