function onKeyPress(obj, evt)
%onKeyPress  The figure's key presses: Ctrl+1 to Ctrl+9 and Ctrl+0 go to a section of the plot editor; Page Up and Page Down flip the preview's pages.
%   Cmd instead of Ctrl on a Mac; the digit row or the number pad. EVT is
%   the WindowKeyPressFcn event (Key, Modifier). Only with the Plots tab
%   showing, and only the bare chord: with Alt or Shift held as well (AltGr
%   is Ctrl+Alt on Windows) the key is left alone. A section's key is named
%   in its header (formLayout): 1 to 9 for the first nine, 0 for the tenth;
%   gotoPlotSection goes there. Page Up and Page Down (no modifier) are the
%   < and > buttons (onPreviewPage), left alone while a preview computes or
%   draws.
%   On the Sessions tab the same keys act on its editor and preview:
%   Ctrl+1 to Ctrl+3 go to its sections (gotoSessionSection), Page Up and
%   Page Down flip its pages (onSessionPreviewPage).
%   On the Figures tab Ctrl+1 to Ctrl+9 and Ctrl+0 go to the figure
%   editor's sections (gotoFigureSection); Page Up and Page Down step to
%   the previous and next observation (onFigureObservationStep: there are
%   no pages). Escape, while a panel is dragged in the schematic, cancels
%   the drag (cancelSchematicDrag).
if string(evt.Key) == "escape" && ~isempty(obj.FigureDrag)
    obj.cancelSchematicDrag();   % a panel dragged in the Figures tab's schematic stays where it was
    return
end
tab = obj.Tabs.SelectedTab;
if tab == obj.TabFigures
    figureKey(obj, evt);
    return
end
if tab ~= obj.TabPlots && tab ~= obj.TabSessions; return; end
sessions = tab == obj.TabSessions;
mods = string(evt.Modifier);
if isempty(mods) && any(string(evt.Key) == ["pageup" "pagedown"])
    step = 1 - 2 * (string(evt.Key) == "pageup");
    if sessions
        if ~ismember(obj.SessionPreviewState, ["computing" "drawing"]); obj.onSessionPreviewPage(step); end
    elseif ~ismember(obj.PreviewState, ["computing" "drawing"])
        obj.onPreviewPage(step);
    end
    return
end
if ~any(ismember(mods, ["control" "command"])) || any(ismember(mods, ["alt" "shift"])); return; end
key = erase(string(evt.Key), "numpad");
if strlength(key) ~= 1 || ~isstrprop(key, 'digit'); return; end
if sessions
    S = obj.SessionSections;
    i = find([S.Key] == key, 1);
    if ~isempty(i); obj.gotoSessionSection(S(i).Name); end
    return
end
S = obj.PlotSections;
i = find([S.Key] == key, 1);
if isempty(i); return; end
obj.gotoPlotSection(S(i).Name);
end


function figureKey(obj, evt)
%figureKey  A key on the Figures tab: Page Up / Down step the observation, Ctrl+digit goes to a section.
mods = string(evt.Modifier);
if isempty(mods) && any(string(evt.Key) == ["pageup" "pagedown"])
    if ~ismember(obj.FigurePreviewState, ["computing" "drawing"])
        obj.onFigureObservationStep(1 - 2 * (string(evt.Key) == "pageup"));
    end
    return
end
if ~any(ismember(mods, ["control" "command"])) || any(ismember(mods, ["alt" "shift"])); return; end
key = erase(string(evt.Key), "numpad");
if strlength(key) ~= 1 || ~isstrprop(key, 'digit'); return; end
S = obj.FigureSections;
i = find([S.Key] == key, 1);
if ~isempty(i); obj.gotoFigureSection(S(i).Name); end
end
