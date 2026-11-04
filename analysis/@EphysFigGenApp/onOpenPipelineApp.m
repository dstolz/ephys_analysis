function onOpenPipelineApp(obj)
%onOpenPipelineApp  Launch EphysPipelineApp (the pipeline GUI).
if ~exist('EphysPipelineApp', 'class')
    uialert(obj.Fig, "EphysPipelineApp is not on the MATLAB path (add the repository's pipeline folder).", ...
        "Open pipeline app");
    return
end
EphysPipelineApp;
obj.setStatus("Opened the pipeline app.");
end
