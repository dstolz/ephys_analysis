function onDesignsFolder(obj, action, folder)
%onDesignsFolder  Your designs folder: "open" it, or "choose" another (FOLDER, else asked).
%   Another folder -- one the lab shares, say -- is remembered
%   (PlotDesign.setFolder); the designs in it are listed at once.
arguments
    obj (1,1) EphysAnalysisApp
    action (1,1) string {mustBeMember(action, ["open" "choose"])}
    folder (1,1) string = ""
end
switch action
    case "open"
        f = PlotDesign.folder();
        if ~isfolder(f); mkdir(f); end
        openInSystem(f);
    case "choose"
        if folder == ""
            d = uigetdir(PlotDesign.folder(), "Keep my plot designs in");
            figure(obj.Fig);
            if isequal(d, 0); return; end
            folder = string(d);
        end
        PlotDesign.setFolder(folder);
        obj.setStatus("Your designs are kept in " + PlotDesign.folder() + ".");
end
end
