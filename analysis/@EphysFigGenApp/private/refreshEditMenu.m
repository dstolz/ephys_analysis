function refreshEditMenu(obj)
%refreshEditMenu  The Edit menu's Undo and Redo, and the toolbar's: named after the step (Undo Add panel), grayed with none or off the Figures tab.
%   Apply last change to figures... is enabled with Undo when that edit
%   has something other figures can take, and so is the Figures tab's
%   Apply last change... button, whose tooltip names the edit it would
%   give ("Apply last change to figures: Stack (Ctrl+Shift+A)": the last
%   step that is not itself one given to other figures, as
%   onApplyToFigures picks it), or why it gives none (a panel moved: its
%   place is its figure's own).
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
[step, why] = applyStep(H);
applyOn = matlab.lang.OnOffSwitchState(undoOn == "on" && step ~= "" && why == "");
if ~isempty(obj.ApplyMenu) && isvalid(obj.ApplyMenu); obj.ApplyMenu.Enable = applyOn; end   % the last edit, to other figures
if ismac; modifier = "Cmd+"; else; modifier = "Ctrl+"; end
if ~isempty(obj.FigureApplyLastButton) && isvalid(obj.FigureApplyLastButton)   % the Figures tab's button: as the menu item
    applyText = "Apply last change to figures";
    if step ~= ""; applyText = applyText + ": " + step; end
    tip = applyText + " (" + modifier + "Shift+A). Give it to other figures or panels, picked in a list (or hold " + ...
        extractBefore(modifier, "+") + " while you edit).";
    if why ~= ""; tip = """" + step + """ stays with its figure: " + why + ". Nothing to give other figures."; end
    set(obj.FigureApplyLastButton, "Enable", applyOn, "Tooltip", tip);
end
if ~isempty(obj.ToolbarUndoTool) && isvalid(obj.ToolbarUndoTool)
    set(obj.ToolbarUndoTool, "Tooltip", undoText + " (" + modifier + "Z)", "Enable", undoOn);
end
if ~isempty(obj.ToolbarRedoTool) && isvalid(obj.ToolbarRedoTool)
    set(obj.ToolbarRedoTool, "Tooltip", redoText + " (" + modifier + "Y)", "Enable", redoOn);
end
end


function [s, why] = applyStep(H)
%applyStep  The label of the edit Apply last change would give: the last step not itself one given to other figures ("" = none).
%   WHY says why it has nothing other figures can take ("" = it has), as onApplyToFigures finds it.
s = "";
why = "";
for i = numel(H.Undo):-1:1
    key = H.Undo(i).Key;
    if (isstring(key) || ischar(key)) && startsWith(string(key), "applyToFigures#"); continue; end   % onApplyToFigures' own steps
    step = H.Undo(i);
    s = step.Label;
    k = step.Selection(1);
    if k < 1 || k > numel(step.After) || numel(step.Before) ~= numel(step.After)
        why = "it added or removed a figure";
    elseif isempty(EphysAnalysisConfig.figureEditChanges(step.Before(k), step.After(k), step.Selection(2)))
        why = "an id, title, place, layer, overlay or note text is each figure's own";
    end
    return
end
end
