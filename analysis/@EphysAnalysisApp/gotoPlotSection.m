function gotoPlotSection(obj, name)
%gotoPlotSection  Go to the plot editor's section NAME: open it if collapsed, scroll to it, focus its header.
%   NAME is as for onPlotSectionToggled ("units", "ref", "window",
%   "selection", "bins", "kind", "style", "waveform" or "note"). Ctrl+1 to
%   Ctrl+9 call this (onKeyPress), the keys following the editor's order,
%   not what the plot shows. A section the selected plot does not show
%   stays where it is, and the status bar says so. Opening a collapsed
%   section is the toggle's: it stays open, and is remembered so.
%   Focus on the header lets Tab walk into the section's rows.
i = find([obj.PlotSections.Name] == name, 1);
if isempty(i); return; end
S = obj.PlotSections(i);
if ~(S.Grid.Visible == "on")
    obj.setStatus("The " + S.Title + " section is not shown for this plot.");
    return
end
if ~S.Expanded
    obj.onPlotSectionToggled(name);
end
drawnow;   % the layout settles before the scroll
try
    scroll(obj.PlotEditorGrid, S.Grid);
catch
end
try
    focus(S.Toggle);
catch
end
end
