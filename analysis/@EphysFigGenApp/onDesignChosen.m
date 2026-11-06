function onDesignChosen(obj, name)
%onDesignChosen  Draw every figure in design NAME (the Design menu or either of the Figures tab's Design lists).
%   The preview's list and the Look section's (Design and looks) show the
%   design chosen from any of them (refreshDesigns).
%   PlotDesign.use: the choice is your preference, every figure on screen
%   that follows it (the preview too) is redrawn at once, and runs draw
%   their figures in it. A design that cannot be read says why.
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
obj.setStatus("Design: " + PlotDesign.currentName() + ". Every figure is drawn in it, the runs' figures too.");
end
