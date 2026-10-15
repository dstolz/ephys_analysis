function onFigureSectionToggled(obj, name)
%onFigureSectionToggled  Collapse the figure editor's section NAME, or expand it again.
%   NAME is "observations", "arrangement", "panel", "ref", "window",
%   "selection", "common", "palign", "layers", "options", "note",
%   "overlays", "style", "looks" or "sessions". A
%   section stays as left when another figure is selected, and between
%   sessions (preference FigureSectionsCollapsed).
i = find([obj.FigureSections.Name] == name, 1);
if isempty(i); return; end
obj.FigureSections(i).Expanded = ~obj.FigureSections(i).Expanded;
obj.layoutFigureEditor();
if name == "arrangement"; obj.drawFigureSchematic(); end   % the schematic is made afresh when it shows again
end
