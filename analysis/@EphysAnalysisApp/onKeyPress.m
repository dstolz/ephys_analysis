function onKeyPress(obj, evt)
%onKeyPress  The figure's key presses: on the Figures tab Ctrl+1 to Ctrl+9 and Ctrl+0 go to a section of the figure editor; Page Up and Page Down step the observation.
%   Cmd instead of Ctrl on a Mac; the digit row or the number pad. EVT is
%   the WindowKeyPressFcn event (Key, Modifier). Only with the Figures tab
%   showing, and only the bare chord: with Alt or Shift held as well (AltGr
%   is Ctrl+Alt on Windows) the key is left alone. A section's key is named
%   in its header (formLayout): 1 to 9 for the first nine, 0 for the tenth;
%   gotoFigureSection goes there. Page Up and Page Down (no modifier) step
%   to the previous and next observation (onFigureObservationStep), left
%   alone while a preview computes or draws. Escape, while a panel is
%   dragged in the schematic, cancels the drag (cancelSchematicDrag), on
%   any tab.
if string(evt.Key) == "escape" && ~isempty(obj.FigureDrag)
    obj.cancelSchematicDrag();   % a panel dragged in the Figures tab's schematic stays where it was
    return
end
if obj.Tabs.SelectedTab ~= obj.TabFigures; return; end
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
