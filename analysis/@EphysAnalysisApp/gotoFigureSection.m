function gotoFigureSection(obj, name)
%gotoFigureSection  Go to the figure editor's section NAME: open it if collapsed, scroll to it, focus its header.
%   NAME is as for onFigureSectionToggled. Ctrl+1 to Ctrl+9 and Ctrl+0
%   call this on the Figures tab (onKeyPress), the keys following the
%   editor's order: Observations 1, Arrangement 2, Panel 3, Event reference
%   4, Epoch window 5, Trial selection 6, Common options 7, Panel alignment
%   8, Layers 9, Options 0; Appearance and Looks have none. A section the figure does not show (no panel picked,
%   say) stays where it is, and the status bar says so.
i = find([obj.FigureSections.Name] == name, 1);
if isempty(i); return; end
S = obj.FigureSections(i);
if ~(S.Grid.Visible == "on")
    obj.setStatus("The " + S.Title + " section is not shown for this figure.");
    return
end
if ~S.Expanded
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
