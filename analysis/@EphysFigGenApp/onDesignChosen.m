function onDesignChosen(obj, name)
%onDesignChosen  Draw every figure in design NAME (the Design menu or either of the Figures tab's Design lists).
%   The preview's list and the Look section's (Design and looks) show the
%   design chosen from any of them (refreshDesigns).
%   PlotDesign.use: the choice is your preference, every figure on screen
%   that follows it (the preview too) is redrawn at once, and runs draw
%   their figures in it; a run going meanwhile keeps the design it started
%   with (EphysAnalysisRunner.holdPageLooks), and the status bar says so.
%   A design that cannot be read says why.
arguments
    obj (1,1) EphysFigGenApp
    name (1,1) string
end
try
    PlotDesign.use(name);
catch ME
    obj.refreshDesigns();
    obj.log("Plot design failed: " + string(ME.message));
    AppDialog.alertFailure(obj.Fig, "Plot design", "use the design", name, ME, ...
        Try="pick another design from the list", Details="Log tab");
    return
end
msg = "Design: " + PlotDesign.currentName() + ". Every figure is drawn in it, the runs' figures too.";
if obj.Running   % the run keeps the design it started with (EphysAnalysisRunner.holdPageLooks)
    msg = msg + " The run going now keeps the design it started with; the next run draws in this one.";
end
obj.setStatus(msg);
end
