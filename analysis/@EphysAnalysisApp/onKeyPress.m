function onKeyPress(obj, evt)
%onKeyPress  The figure's key presses: Ctrl+1 to Ctrl+9 and Ctrl+0 go to a section of the plot editor.
%   Cmd instead of Ctrl on a Mac; the digit row or the number pad. EVT is
%   the WindowKeyPressFcn event (Key, Modifier). Only with the Plots tab
%   showing, and only the bare chord: with Alt or Shift held as well (AltGr
%   is Ctrl+Alt on Windows) the key is left alone. A section's key is named
%   in its header (formLayout): 1 to 9 for the first nine, 0 for the tenth;
%   gotoPlotSection goes there.
if obj.Tabs.SelectedTab ~= obj.TabPlots; return; end
mods = string(evt.Modifier);
if ~any(ismember(mods, ["control" "command"])) || any(ismember(mods, ["alt" "shift"])); return; end
key = erase(string(evt.Key), "numpad");
if strlength(key) ~= 1 || ~isstrprop(key, 'digit'); return; end
S = obj.PlotSections;
i = find([S.Key] == key, 1);
if isempty(i); return; end
obj.gotoPlotSection(S(i).Name);
end
