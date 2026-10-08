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
    uialert(obj.Fig, ME.message, "Delete design");
    return
end
obj.setStatus("Deleted design " + name + ".");
end
