function a = onOpenAnalysisApp(obj, idx)
%onOpenAnalysisApp  Open the analysis app (EphysAnalysisApp) on this project's outputs.
%   onOpenAnalysisApp(obj) (File menu) opens it on the whole project:
%   with a project root set, on that root, output root, name pattern and
%   Open Ephys recording mode, else with its own last config.
%   onOpenAnalysisApp(obj, IDX) (the Tools panel) opens it on the scanned
%   project with datasets IDX selected by their keys (its Source.Selection
%   "list": only they are ticked to run, the first of them active), or
%   with every dataset selected ("all") when IDX is every dataset. A = the
%   app ([] when it did not open).
%
%   The analysis app lives in the repository's analysis folder, which the
%   pipeline never depends on: without it on the path this only says so.
%
%   See also EphysAnalysisApp, EphysPreprocessingApp.onOpenTool.
arguments
    obj (1,1) EphysPreprocessingApp
    idx (1,:) double = zeros(1, 0)
end
a = [];
if ~exist('EphysAnalysisApp', 'class')
    uialert(obj.Fig, "EphysAnalysisApp is not on the MATLAB path. Add the repository's analysis folder " + ...
        "(addpath_nogit on the repository adds it).", "Open analysis app");
    return
end
P = obj.gatherProjectSection();
rec = obj.gatherAcquisitionSection().OpenEphys.Recordings;
if ~isempty(idx) && ~isempty(obj.Project)
    % The keys are relative to the root the project was scanned from.
    idx = unique(idx);
    keys = string.empty(1, 0);
    if numel(idx) < obj.Project.NumDatasets
        allKeys = obj.Project.datasetKeys();
        keys = allKeys(idx);
    end
    a = EphysAnalysisApp(obj.Project.Root, OutputRoot=P.OutputRoot, NamePattern=P.NamePattern, ...
        Recordings=rec, Datasets=keys);
    if isempty(keys)
        what = obj.Project.Root;
    elseif isscalar(keys)
        what = obj.Project.Datasets(idx).Name;
    else
        what = sprintf("%d datasets", numel(keys));
    end
    obj.setStatus("Opened the analysis app on " + what + ".", "");
elseif P.Root ~= "" && isfolder(P.Root)
    a = EphysAnalysisApp(P.Root, OutputRoot=P.OutputRoot, NamePattern=P.NamePattern, Recordings=rec);
    obj.setStatus("Opened the analysis app on " + P.Root + ".", "");
else
    a = EphysAnalysisApp();
    obj.setStatus("Opened the analysis app.", "");
end
if nargout == 0
    clear a
end
end
