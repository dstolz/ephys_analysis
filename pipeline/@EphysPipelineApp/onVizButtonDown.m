function onVizButtonDown(obj)
%onVizButtonDown  Begin a gesture on the Visualize plot.
%   (A press on the overview strip is the strip's own ButtonDownFcn, see
%   buildVisualizeTab: it centers the view there, and a drag follows.) On
%   the plot, any press starts a pan that follows the pointer in time and
%   across the lanes (EphysTraceViewer.beginDrag). The figure's motion
%   callback is set for the gesture and cleared by onVizButtonUp.

if ~obj.vizActive(); return; end
v = obj.Viewer;
fig = obj.Fig;
if ~v.isOver(fig); return; end

obj.VizGesture = "pan";
v.beginDrag(fig.CurrentPoint);
fig.WindowButtonMotionFcn = @(~, ~) v.dragTo(fig.CurrentPoint);
end
