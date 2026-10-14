function onPanelAlignEdited(obj, part)
%onPanelAlignEdited  A value of the selected panel's own event reference or window was edited.
%   PART is "ref" or "window" ("selection" is the figure's: its controls
%   are not shown, and an edit there does nothing). The rows can be edited
%   only while "Same as the figure" is unticked (syncFigureEditor locks
%   them while the panel is linked), so the panel already has its own; a
%   part it did not have of its own (a config that gave it only one) is
%   its own from this edit on.
arguments
    obj (1,1) EphysAnalysisApp
    part (1,1) string {mustBeMember(part, ["ref" "window" "selection"])}
end
E = obj.FigureEditor;
if obj.Applying || part == "selection" || E.panelSame.Value; return; end
own = E.panelSame.UserData;
if ~(islogical(own) && numel(own) == 2); own = [false false]; end
own(part == ["ref" "window"]) = true;
E.panelSame.UserData = own;
obj.onConfigChanged("figure");
end
