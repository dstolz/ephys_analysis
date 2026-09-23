function onOpenOutputFolder(obj, idx)
%onOpenOutputFolder  Open datasets' output folders in the system file browser.
%   onOpenOutputFolder(obj, IDX) opens the output folder of each of datasets
%   IDX (the Tools panel): <Output root>/<Name>, or the recording folder
%   without an output root (EphysDataset.outputFolder). A folder that is
%   not there yet (no step has written to it) is named in an alert.
%
%   See also EphysPreprocessingApp.onOpenTool.
arguments
    obj (1,1) EphysPreprocessingApp
    idx (1,:) double = obj.SelectedDatasetIdx
end
if isempty(obj.Project) || isempty(idx) || any(idx < 1 | idx > obj.Project.NumDatasets)
    uialert(obj.Fig, "Scan a project first.", "Output folder");
    return
end
obj.applyConfigToProject();   % the output root the field shows
missing = strings(0, 1);
opened = strings(1, 0);
for i = idx
    d = obj.Project.Datasets(i);
    f = d.outputFolder();
    if ~isfolder(f)
        missing(end + 1) = d.Name + ": " + f; %#ok<AGROW>
        continue
    end
    if ispc
        winopen(f);
    elseif ismac
        system(sprintf('open "%s"', f));
    else
        system(sprintf('xdg-open "%s" &', f));
    end
    opened(end + 1) = d.Name; %#ok<AGROW>
end
if isscalar(opened)
    obj.setStatus("Opened the output folder of " + opened + ".", "");
elseif ~isempty(opened)
    obj.setStatus(sprintf("Opened %d output folders.", numel(opened)), "");
end
if ~isempty(missing)
    uialert(obj.Fig, strjoin(["Not written yet (no step has run):"; missing], newline), "Output folder");
end
end
