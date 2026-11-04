function focusFigurePane(obj, step)
%focusFigurePane  Put the keyboard focus in the Figures tab's next (STEP 1) or previous (STEP -1) column: the figure list, the editor, the preview's controls.
%   F6 and Shift+F6 call this (onKeyPress), round from the last column F6
%   went to (FigureFocusPane; a click elsewhere is not known to it). The
%   figure list is the tree; the editor its first control that shows (the
%   Id field, else the first supersection's header); the preview's
%   controls the Observation drop-down, else the Preview button. Tab and
%   Shift+Tab then move on from there. The status bar names the column.
names = ["the figure list" "the editor" "the preview"];
i = mod(obj.FigureFocusPane - 1 + step, 3) + 1;
if obj.FigureFocusPane == 0 && step < 0; i = 3; end
obj.FigureFocusPane = i;
switch i
    case 1
        target = obj.FiguresTree;
    case 2
        target = obj.FigureEditor.id;
        if ~strcmp(target.Visible, 'on') || ~strcmp(target.Parent.Visible, 'on')
            target = obj.FigureSearchField;
            U = obj.FigureSupers;
            if ~isempty(U) && strcmp(U(1).Header.Visible, 'on'); target = U(1).Header; end
        end
    otherwise
        target = obj.FigureObservationDropDown;
        if ~strcmp(target.Enable, 'on'); target = obj.FigurePreviewButton; end
end
try
    focus(target);
catch
end
obj.setStatus("Keyboard focus: " + names(i) + " (F6: the next column, Shift+F6: the previous).");
end
