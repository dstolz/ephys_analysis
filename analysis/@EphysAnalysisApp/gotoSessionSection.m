function gotoSessionSection(obj, name)
%gotoSessionSection  Go to the Sessions tab editor's section NAME: open it if collapsed, scroll to it, focus its header.
%   NAME is as for onSessionSectionToggled ("sessions", "matching",
%   "data"). Ctrl+1 to Ctrl+3 call this on the Sessions tab (onKeyPress).
%   A section not shown (no session plot selected) stays where it is, and
%   the status bar says so.
i = find([obj.SessionSections.Name] == name, 1);
if isempty(i); return; end
S = obj.SessionSections(i);
if ~(S.Grid.Visible == "on")
    obj.setStatus("The " + S.Title + " section is not shown: select a session plot.");
    return
end
if ~S.Expanded
    obj.onSessionSectionToggled(name);
end
drawnow;   % the layout settles before the scroll
try
    scroll(obj.SessionEditorGrid, S.Grid);
catch
end
try
    focus(S.Toggle);
catch
end
end
