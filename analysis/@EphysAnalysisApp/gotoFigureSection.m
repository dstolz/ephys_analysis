function gotoFigureSection(obj, name)
%gotoFigureSection  Go to the figure editor's section NAME: open it and its supersection if collapsed, scroll to it, focus its header.
%   NAME is as for onFigureSectionToggled. Ctrl+1 to Ctrl+9 and Ctrl+0
%   call this on the Figures tab (onKeyPress), the keys following the
%   editor's order: Observations 1, Event reference 2, Epoch window 3,
%   Trial selection 4, Panels 5, Selected panel 6, Panel alignment 7, Layers
%   8, Options 9, Text note 0; Sessions, Probe layout, Overlays,
%   Appearance and Looks have none. A section the figure does not show (no panel picked, say)
%   stays where it is, and the status bar says so.
i = find([obj.FigureSections.Name] == name, 1);
if isempty(i); return; end
S = obj.FigureSections(i);
if ~sectionShows(S)
    obj.setStatus("The " + S.Title + " section is not shown for this figure.");
    return
end
u = find([obj.FigureSupers.Name] == S.Super, 1);
if ~isempty(u) && ~obj.FigureSupers(u).Expanded
    obj.onFigureSuperToggled(S.Super);   % the supersection that holds it opens first
end
if ~obj.FigureSections(i).Expanded
    obj.onFigureSectionToggled(name);
end
drawnow;   % the layout settles before the scroll
try
    scroll(obj.FigureEditorGrid, S.Grid);
catch
end
try
    focus(S.Toggle);
catch
end
end


function tf = sectionShows(S)
%sectionShows  The section is shown for the figure, its supersection open or not: formLayout's test, before a supersection hides it.
tf = S.Visible && (isempty(S.Heights) || any(S.Shown));
end
