function onDesignChosen(obj, name)
%onDesignChosen  Draw every plot in design NAME (the Design menu or the preview's Design list).
%   PlotDesign.use: the choice is your preference, every plot on screen
%   that follows it (the preview too) is redrawn at once, and runs draw
%   their figures in it. A design that cannot be read says why.
arguments
    obj (1,1) EphysAnalysisApp
    name (1,1) string
end
try
    PlotDesign.use(name);
catch ME
    obj.refreshDesigns();
    uialert(obj.Fig, ME.message, "Plot design");
    return
end
obj.setStatus("Design: " + PlotDesign.currentName() + ". Every plot is drawn in it, the runs' figures too.");
end
