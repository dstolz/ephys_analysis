function onImportDesign(obj, file)
%onImportDesign  Copy a design file into your designs folder and draw in it.
%   Asks for FILE unless given, and before replacing a design of yours of
%   the same name (PlotDesign.import).
arguments
    obj (1,1) EphysFigGenApp
    file (1,1) string = ""
end
if file == ""
    [f, p] = uigetfile("*.json", "Import a plot design");
    figure(obj.Fig);
    if isequal(f, 0); return; end
    file = string(fullfile(p, f));
end
try
    name = PlotDesign.import(file);
catch ME
    if ME.identifier ~= "PlotDesign:Exists"
        obj.log("Import design failed: " + string(ME.message));
        AppDialog.alertFailure(obj.Fig, "Import design", "import the design", file, ME, ...
            Try="pick a design file (.json) made by this app", Details="Log tab");
        return
    end
    a = uiconfirm(obj.Fig, ME.message + " Replace it with the imported one?", "Import design", ...
        "Options", ["Replace" "Cancel"], "DefaultOption", 2, "CancelOption", 2);
    if a ~= "Replace"; return; end
    name = PlotDesign.import(file, Overwrite=true);
end
obj.onDesignChosen(name);
obj.setStatus("Imported design " + name + " into " + PlotDesign.folder() + ", and chose it.");
end
