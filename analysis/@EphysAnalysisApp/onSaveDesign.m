function onSaveDesign(obj, name, description)
%onSaveDesign  Keep the preview's look as a design of yours, and draw in it.
%   PlotDesign.capture reads every property of every component of the
%   preview (with the rules it is drawn with), its ground and its group
%   colours; the design is saved in your designs folder and chosen. Asks
%   for the NAME and DESCRIPTION unless given (given: one of yours of that
%   name is replaced).
arguments
    obj (1,1) EphysAnalysisApp
    name (1,1) string = missing
    description (1,1) string = ""
end
if ~isappdata(obj.PreviewPanel, PlotAesthetics.ContextKey) || isempty(obj.PreviewResult)
    uialert(obj.Fig, "Preview a plot first: its look is what the design keeps.", "Save design");
    return
end
if ismissing(name)
    [name, description, ok] = PlotDesign.askName(obj.Fig, "", "");
    if ~ok; return; end
end
try
    D = PlotDesign.capture(obj.PreviewPanel, Name=name, Description=description);
    PlotDesign.save(D, name, Overwrite=true);
    name = PlotDesign.checkName(name);
    PlotDesign.use(name);
catch ME
    uialert(obj.Fig, ME.message, "Save design");
    return
end
obj.setStatus(sprintf("Saved design %s (%d settings) in %s, and chose it.", name, numel(D.rules), PlotDesign.folder()));
end
