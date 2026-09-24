function onPlotSectionToggled(obj, name)
%onPlotSectionToggled  Collapse the plot editor's section NAME, or expand it again.
%   NAME is "units", "ref", "window", "selection", "bins", "kind" or
%   "style". A section stays as left when another plot is selected, and
%   between sessions (preference PlotSectionsCollapsed).
i = find([obj.PlotSections.Name] == name, 1);
if isempty(i); return; end
obj.PlotSections(i).Expanded = ~obj.PlotSections(i).Expanded;
obj.layoutPlotEditor();
end
