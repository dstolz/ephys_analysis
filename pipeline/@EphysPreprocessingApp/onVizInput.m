function tf = onVizInput(obj, kind, evt)
%onVizInput  The wheel and the keys on the Visualize plot.
%   TF = obj.onVizInput(KIND, EVT) takes the figure's wheel ("scroll") and
%   key ("key") events while the Visualize tab is showing (passed on by
%   routeFigureInput) and returns whether it acted. They act only with the
%   pointer over the plot, so typing in a field is left alone:
%     wheel ............ zoom time about the pointer
%     Ctrl+wheel ....... scale the voltage
%     Shift+wheel ...... scroll the lanes
%     keys ............. EphysTraceViewer.handleKey (arrows, Page Up / Down,
%                        Home / End, + / -, A auto scale, R reset)
%   Escape turns artifact marking off. Wheel events carry no modifiers, so
%   the wheel reads ArtView.mods (the keys held, kept by routeFigureInput).
%
%   See also routeFigureInput, EphysTraceViewer.handleScroll,
%   EphysTraceViewer.handleKey.

tf = false;
v = obj.Viewer;
if ~obj.vizActive() || ~v.isOver(obj.Fig); return; end
switch kind
    case "scroll"
        v.handleScroll(evt.VerticalScrollCount, obj.ArtView.mods, obj.VizAxes.CurrentPoint(1, 1));
        tf = true;
    case "key"
        if string(evt.Key) == "escape" && obj.VizArtMode
            obj.VizArtButton.Value = false;
            obj.onVizArtToggle(false);
            tf = true;
            return
        end
        tf = v.handleKey(evt.Key, evt.Modifier);
end
end
