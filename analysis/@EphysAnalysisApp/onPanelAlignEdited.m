function onPanelAlignEdited(obj, part)
%onPanelAlignEdited  A value of the selected panel's own event reference or window was edited.
%   PART is "ref" or "window" ("selection" is the figure's: its controls
%   are not shown, and an edit there does nothing). The panel takes that
%   part as its own -- the values shown, with the edit -- and "Same as the
%   figure" is unticked; the other part stays the figure's until edited
%   too. The panel then has its own epochs and its own time axis.
arguments
    obj (1,1) EphysAnalysisApp
    part (1,1) string {mustBeMember(part, ["ref" "window" "selection"])}
end
if obj.Applying || part == "selection"; return; end
E = obj.FigureEditor;
own = E.panelSame.UserData;
if ~(islogical(own) && numel(own) == 2); own = [false false]; end
own(part == ["ref" "window"]) = true;
E.panelSame.UserData = own;
E.panelSame.Value = false;
obj.onConfigChanged("figure");
end
