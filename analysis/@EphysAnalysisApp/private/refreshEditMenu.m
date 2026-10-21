function refreshEditMenu(obj)
%refreshEditMenu  The Edit menu's Undo and Redo, and the toolbar's: named after the step (Undo Add panel), grayed with none or off the Figures tab.
%   The tools carry the name and the shortcut in their tooltips ("Undo Add
%   panel (Ctrl+Z)") and follow the menu items' Enable.
%   The history is the figure editor's (FigureHistory), so its items work
%   with the Figures tab showing only: Ctrl+Z in a field of another tab is
%   left to the field.
if isempty(obj.UndoMenu) || ~isvalid(obj.UndoMenu); return; end
H = obj.FigureHistory;
onTab = ~isempty(obj.Tabs) && isvalid(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabFigures;
undoText = strtrim("Undo " + H.undoLabel());
redoText = strtrim("Redo " + H.redoLabel());
undoOn = matlab.lang.OnOffSwitchState(onTab && ~isempty(H.Undo));
redoOn = matlab.lang.OnOffSwitchState(onTab && ~isempty(H.Redo));
set(obj.UndoMenu, "Text", undoText, "Enable", undoOn);
set(obj.RedoMenu, "Text", redoText, "Enable", redoOn);
if ismac; modifier = "Cmd+"; else; modifier = "Ctrl+"; end
if ~isempty(obj.ToolbarUndoTool) && isvalid(obj.ToolbarUndoTool)
    set(obj.ToolbarUndoTool, "Tooltip", undoText + " (" + modifier + "Z)", "Enable", undoOn);
end
if ~isempty(obj.ToolbarRedoTool) && isvalid(obj.ToolbarRedoTool)
    set(obj.ToolbarRedoTool, "Tooltip", redoText + " (" + modifier + "Y)", "Enable", redoOn);
end
end
