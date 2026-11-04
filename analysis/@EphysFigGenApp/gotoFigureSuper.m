function gotoFigureSuper(obj, name)
%gotoFigureSuper  Go to the figure editor's supersection NAME: open it if collapsed, scroll to its header and focus it.
%   NAME is as for onFigureSuperToggled. Alt+1 (Figure), Alt+2 (Panel)
%   and Alt+3 (Look) call this on the Figures tab (onKeyPress); Option on
%   a Mac. With no figure selected the headers are hidden and the status
%   bar says so.
u = find([obj.FigureSupers.Name] == name, 1);
if isempty(u); return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("No figure is selected: add one, or pick one in the list.");
    return
end
if ~obj.FigureSupers(u).Expanded
    obj.onFigureSuperToggled(name);
end
h = obj.FigureSupers(u).Header;
drawnow;   % the layout settles before the scroll
try
    scroll(obj.FigureEditorGrid, h);
catch
end
try
    focus(h);
catch
end
end
