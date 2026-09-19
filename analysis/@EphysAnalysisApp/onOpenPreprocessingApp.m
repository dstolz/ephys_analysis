function onOpenPreprocessingApp(obj)
%onOpenPreprocessingApp  Launch EphysPreprocessingApp (the pipeline GUI).
if ~exist('EphysPreprocessingApp', 'class')
    uialert(obj.Fig, "EphysPreprocessingApp is not on the MATLAB path (add the repository's pipeline folder).", ...
        "Open preprocessing app");
    return
end
EphysPreprocessingApp;
obj.setStatus("Opened the preprocessing app.");
end
