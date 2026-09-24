function onPlotAlignEdited(obj, part)
%onPlotAlignEdited  A value of the plot's event reference, window or selection was edited.
%   PART is "ref", "window" or "selection". A section that showed the
%   Alignment tab's values ("Use default" ticked) now gives the plot its
%   own: those values with the edit. The Alignment tab's are unchanged.
arguments
    obj (1,1) EphysAnalysisApp
    part (1,1) string {mustBeMember(part, ["ref" "window" "selection"])}
end
if obj.Applying; return; end
box = struct('ref', "defaultRef", 'window', "defaultWindow", 'selection', "defaultSelection");
obj.PlotEditor.(box.(part)).Value = false;
obj.onConfigChanged("plot");
end
