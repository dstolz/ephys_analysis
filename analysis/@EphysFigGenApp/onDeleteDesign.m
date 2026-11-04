function onDeleteDesign(obj, name, opts)
%onDeleteDesign  Delete design NAME of yours, after asking (Confirm=false: without).
%   Its file goes; if it was chosen, Default is (PlotDesign.remove).
arguments
    obj (1,1) EphysAnalysisApp
    name (1,1) string
    opts.Confirm (1,1) logical = true
end
if opts.Confirm
    a = uiconfirm(obj.Fig, "Delete your design " + name + "? Its file is deleted.", "Delete design", ...
        "Options", ["Delete" "Cancel"], "DefaultOption", 2, "CancelOption", 2, "Icon", "warning");
    if a ~= "Delete"; return; end
end
try
    PlotDesign.remove(name);
catch ME
    obj.log("Delete design failed: " + string(ME.message));
    AppDialog.alertFailure(obj.Fig, "Delete design", "delete the design", name, ME, ...
        Try="close any program that has the design's file open, then try again", Details="Log tab");
    return
end
obj.setStatus("Deleted design " + name + ".");
end
