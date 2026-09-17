function onLaunchPhy(obj)
%onLaunchPhy  Open phy's template-gui on the active dataset's KS4 results.
%   Resolves the kilosort4 results directory of the active dataset and hands
%   it to launchPhy, which checks for params.py and launches phy detached so
%   the app stays responsive.
%
%   See also EphysPreprocessingApp.launchPhy, EphysPreprocessingApp.onRunStep,
%   EphysDataset.runKilosort.

d = obj.currentDataset();
if isempty(d)
    uialert(obj.Fig, "Scan a project first.", "phy");
    return
end

% Keep each dataset's OutputDir in sync with the current Output root so the
% results path matches what Kilosort4 actually wrote.
obj.applyConfigToProject();

% Resolve the folder that actually holds params.py: the dataset's explicit
% SortingDir when set, else the auto-discovered run (<kilosort4>/si/sorter_output
% for the SpikeInterface engine, <kilosort4> for the legacy engine).
obj.launchPhy(d.sortingResultsDir(), d.Name);
end
