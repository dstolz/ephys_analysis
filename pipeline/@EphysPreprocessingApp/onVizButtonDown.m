function onVizButtonDown(obj)
%onVizButtonDown  Begin a gesture on the Visualize plot or its overview strip.
%   On the overview strip a press (and a drag) centres the view there. On
%   the plot, in artifact-marking mode a plain left press starts a
%   rubber band that defines an artifact period (finishVizArtDrag);
%   otherwise any press starts a pan that follows the pointer in time and
%   across the lanes (EphysTraceViewer.beginDrag). The figure's motion
%   callback is set for the gesture and cleared by onVizButtonUp.

if ~obj.vizActive(); return; end
v = obj.Viewer;
fig = obj.Fig;
ov = obj.VizOverviewAxes;
if v.isOver(fig, ov)
    obj.VizGesture = "seek";
    v.seekOverview(ov.CurrentPoint(1, 1));
    fig.WindowButtonMotionFcn = @(~, ~) v.seekOverview(ov.CurrentPoint(1, 1));
    return
end
if ~v.isOver(fig); return; end

% Artifact marking takes the plain left button when its mode is on.
if obj.VizArtMode && strcmp(fig.SelectionType, 'normal')
    obj.VizGesture = "mark";
    obj.VizArtDrag = struct( ...
        'active', true, ...
        'x0',     obj.VizAxes.CurrentPoint(1, 1), ...
        'axPix',  obj.VizAxes.InnerPosition);
    fig.WindowButtonMotionFcn = @(~, ~) obj.onVizArtMotion();
    return
end

obj.VizGesture = "pan";
v.beginDrag(fig.CurrentPoint);
fig.WindowButtonMotionFcn = @(~, ~) v.dragTo(fig.CurrentPoint);
end
