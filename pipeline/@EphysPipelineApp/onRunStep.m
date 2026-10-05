function onRunStep(obj, step)
%onRunStep  Run one step (even if it is disabled in the config).
arguments
    obj (1,1) EphysPreprocessingApp
    step (1,1) string
end
obj.runPipeline(Steps=step);
end
