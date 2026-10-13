function onSessionSectionToggled(obj, name)
%onSessionSectionToggled  Collapse the Sessions tab editor's section NAME, or expand it again.
%   NAME is "sessions", "matching" or "data". A section stays as left when
%   another session plot is selected, and between sessions (preference
%   SessionSectionsCollapsed).
i = find([obj.SessionSections.Name] == name, 1);
if isempty(i); return; end
obj.SessionSections(i).Expanded = ~obj.SessionSections(i).Expanded;
obj.layoutSessionEditor();
end
