function p = schematicPixel(obj, xy)
%schematicPixel  The window's pixel (as its CurrentPoint) of point XY in the schematic, while a panel is dragged.
%   P = schematicPixel(OBJ, XY) inverts the drag's tie of the pointer to the
%   schematic (onSchematicPress: its top-left corner's pixel and its scale
%   at the last motion): XY = [x y] in the schematic's units (0-1
%   across, 0-1 down the grid). [] when no panel is being dragged. The
%   tests set the window's CurrentPoint to P and call the pointer callbacks
%   the press installed.
p = [];
D = obj.FigureDrag;
if isempty(D); return; end
p = D.corner + (reshape(double(xy), 1, 2) - D.lim0) ./ D.scale;
end
