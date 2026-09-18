function onOpenAnalysisApp(obj)
%onOpenAnalysisApp  Open the analysis app (EphysAnalysisApp) on this project's outputs.
%   The analysis app lives in the repository's analysis folder, which the
%   pipeline never depends on: without it on the path this only says so.
%   With a project root set it opens on that root and output root, else
%   with its own last config.
if ~exist('EphysAnalysisApp', 'class')
    uialert(obj.Fig, "EphysAnalysisApp is not on the MATLAB path. Add the repository's analysis folder " + ...
        "(addpath_nogit on the repository adds it).", "Open analysis app");
    return
end
P = obj.gatherProjectSection();
if P.Root ~= "" && isfolder(P.Root)
    EphysAnalysisApp(P.Root, OutputRoot=P.OutputRoot);
    obj.setStatus("Opened the analysis app on " + P.Root + ".", "");
else
    EphysAnalysisApp();
    obj.setStatus("Opened the analysis app.", "");
end
end
