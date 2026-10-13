function onChronuxSectionToggled(obj, name)
%onChronuxSectionToggled  Collapse the Chronux tab's section NAME, or expand it again.
%   NAME is "time", "tapers", "freq", "moving", "baseline" or "display". A
%   section stays as left between sessions (preference
%   ChronuxSectionsCollapsed).
i = find([obj.ChronuxSections.Name] == name, 1);
if isempty(i); return; end
obj.ChronuxSections(i).Expanded = ~obj.ChronuxSections(i).Expanded;
obj.ChronuxSections = formStack(obj.ChronuxSections, obj.ChronuxEditorGrid);
end
