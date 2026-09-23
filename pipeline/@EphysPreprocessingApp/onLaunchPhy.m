function onLaunchPhy(obj, idx)
%onLaunchPhy  Open phy's template-gui on datasets' KS4 results.
%   onLaunchPhy(obj) opens the active dataset's (the Sorting tab's Open in
%   phy); onLaunchPhy(obj, IDX) each of datasets IDX, a window each (the
%   Tools panel). Resolves each dataset's kilosort4 results directory and
%   hands it to launchPhy, which checks for params.py and launches phy
%   detached so the app stays responsive.
%
%   See also EphysPreprocessingApp.launchPhy, EphysPreprocessingApp.onRunStep,
%   EphysPreprocessingApp.onOpenTool, EphysDataset.runKilosort.
arguments
    obj (1,1) EphysPreprocessingApp
    idx (1,:) double = obj.SelectedDatasetIdx
end
if isempty(obj.Project) || isempty(idx) || any(idx < 1 | idx > obj.Project.NumDatasets)
    uialert(obj.Fig, "Scan a project first.", "phy");
    return
end

% Keep each dataset's OutputDir in sync with the current Output root so the
% results path matches what Kilosort4 actually wrote.
obj.applyConfigToProject();

% Resolve the folder that actually holds params.py: the dataset's explicit
% SortingDir when set, else the auto-discovered run (<kilosort4>).
for i = idx
    d = obj.Project.Datasets(i);
    obj.launchPhy(d.sortingResultsDir(), d.Name);
end
end
