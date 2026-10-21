function refreshEditMenu(obj)
%refreshEditMenu  The Edit menu's Undo and Redo: named after the step (Undo Add panel), grayed with none or off the Figures tab.
%   The history is the figure editor's (FigureHistory), so its items work
%   with the Figures tab showing only: Ctrl+Z in a field of another tab is
%   left to the field.
if isempty(obj.UndoMenu) || ~isvalid(obj.UndoMenu); return; end
H = obj.FigureHistory;
onTab = ~isempty(obj.Tabs) && isvalid(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabFigures;
set(obj.UndoMenu, "Text", strtrim("Undo " + H.undoLabel()), "Enable", matlab.lang.OnOffSwitchState(onTab && ~isempty(H.Undo)));
set(obj.RedoMenu, "Text", strtrim("Redo " + H.redoLabel()), "Enable", matlab.lang.OnOffSwitchState(onTab && ~isempty(H.Redo)));
end
