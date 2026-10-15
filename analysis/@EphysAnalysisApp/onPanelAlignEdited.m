function onPanelAlignEdited(obj, part)
%onPanelAlignEdited  A value of the selected panel's own event reference, window or trial selection was edited.
%   PART is "ref", "window" or "selection". The ref and window rows can be
%   edited only while "Same as the figure" is unticked, the selection rows
%   only while "Trial selection as the figure" is unticked
%   (syncFigureEditor locks them while the panel is linked), so the panel
%   already has its own; a ref or window part it did not have of its own
%   (a config that gave it only one) is its own from this edit on.
arguments
    obj (1,1) EphysAnalysisApp
    part (1,1) string {mustBeMember(part, ["ref" "window" "selection"])}
end
E = obj.FigureEditor;
if obj.Applying; return; end
if part == "selection"
    if E.panelSameSel.Value; return; end
    obj.onConfigChanged("figure");
    return
end
if E.panelSame.Value; return; end
own = E.panelSame.UserData;
if ~(islogical(own) && numel(own) == 2); own = [false false]; end
own(part == ["ref" "window"]) = true;
E.panelSame.UserData = own;
obj.onConfigChanged("figure");
end
