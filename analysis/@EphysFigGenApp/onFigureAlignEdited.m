function onFigureAlignEdited(obj, part)
%onFigureAlignEdited  A value of the figure's event reference, window or selection was edited.
%   PART is "ref", "window" or "selection". A section that showed the
%   Alignment tab's values ("Use default" ticked) now gives the figure its
%   own: those values with the edit. The Alignment tab's are unchanged. A
%   panel that uses the figure's alignment shows the new values.
arguments
    obj (1,1) EphysAnalysisApp
    part (1,1) string {mustBeMember(part, ["ref" "window" "selection"])}
end
if obj.Applying; return; end
box = struct('ref', "defaultRef", 'window', "defaultWindow", 'selection', "defaultSelection");
obj.FigureEditor.(box.(part)).Value = false;
obj.onConfigChanged("figure", "Figure " + lower(partNames(part)));
obj.applyFigureEditorDefaults();
end


function n = partNames(part)
%partNames  What an alignment PART is called in an undo step.
names = ["Event" "Window" "Trial selection"];
n = names(part == ["ref" "window" "selection"]);
end
