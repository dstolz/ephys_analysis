function onFigureSuperToggled(obj, name)
%onFigureSuperToggled  Collapse the figure editor's supersection NAME (every section under its header), or expand it again.
%   NAME is "figure" (Observations, Event reference, Epoch window, Trial
%   selection, Sessions, Arrangement), "panel" (Panel, Panel alignment,
%   Layers, Options, Text note, Overlays) or "look" (Appearance, Looks).
%   Its sections keep their own collapsed state inside it. It stays as
%   left when another figure is selected, and between sessions
%   (preference FigureSupersectionsCollapsed).
u = find([obj.FigureSupers.Name] == name, 1);
if isempty(u); return; end
obj.FigureSupers(u).Expanded = ~obj.FigureSupers(u).Expanded;
obj.layoutFigureEditor();
if ismember("arrangement", obj.FigureSupers(u).Sections); obj.drawFigureSchematic(); end   % the schematic is made afresh when it shows again
end
