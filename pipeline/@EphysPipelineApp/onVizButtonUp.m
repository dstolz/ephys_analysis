function onVizButtonUp(obj)
%onVizButtonUp  End the Visualize gesture in progress (pan or seek).

gesture = obj.VizGesture;
obj.VizGesture = "";
if gesture == ""; return; end
if isvalid(obj.Fig); obj.Fig.WindowButtonMotionFcn = ''; end
if gesture == "pan" && ~isempty(obj.Viewer) && isvalid(obj.Viewer)
    obj.Viewer.endDrag();
end
end
