function onVizButtonUp(obj)
%onVizButtonUp  End the Visualize gesture in progress (artifact marking, pan or seek).

gesture = obj.VizGesture;
obj.VizGesture = "";
if gesture == ""; return; end
if isvalid(obj.Fig); obj.Fig.WindowButtonMotionFcn = ''; end
switch gesture
    case "mark"
        obj.finishVizArtDrag();
    case "pan"
        if ~isempty(obj.Viewer) && isvalid(obj.Viewer)
            obj.Viewer.endDrag();
        end
end
end
