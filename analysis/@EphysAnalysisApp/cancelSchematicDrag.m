function cancelSchematicDrag(obj, msg)
%cancelSchematicDrag  Stop dragging a panel in the schematic without moving it (Escape, a release outside it).
%   The window's pointer callbacks come back as they were before the press
%   (onSchematicPress), the outline and the shaded target go (the
%   schematic is drawn again), and the status bar says MSG unless it is "".
if nargin < 2; msg = "Drag canceled."; end
D = obj.FigureDrag;
if isempty(D); return; end
obj.FigureDrag = [];
if isvalid(obj.Fig)
    obj.Fig.WindowButtonMotionFcn = D.oldMotion;
    obj.Fig.WindowButtonUpFcn = D.oldUp;
end
obj.drawFigureSchematic();
if msg ~= ""; obj.setStatus(msg); end
end
