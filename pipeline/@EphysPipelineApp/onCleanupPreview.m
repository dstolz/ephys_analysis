function onCleanupPreview(obj)
%onCleanupPreview  List the selected datasets' files as Remove or Keep (planLocalCleanup).
%   Reads only file listings, the variable names of the outputs and the
%   sources of copied raw files; nothing is changed. The config's Signals /
%   Spikes / Export output folders are searched for the datasets' outputs
%   too. The plan's ticked (Include) Remove rows are what the Delete /
%   Recycle / Move files... button acts on; every Remove row starts ticked.
%   For a move, the folder is checked for the files already there
%   (refreshCleanupMove), and the table's In the folder column says what
%   If a file is already there would do with each.
obj.CleanupPlan = [];
obj.CleanupPlanKeys = string.empty(1, 0);
obj.CleanupMove = [];
idx = obj.selectedDatasetIndices();
if isempty(idx)
    obj.refreshCleanupTable();
    uialert(obj.Fig, "Scan a project on the Project tab first.", "Clean up");
    return
end
kinds = ["raw" "sorter_copy" "bin" "envelope"];
kinds = kinds([obj.CleanupRawCheckBox.Value, obj.CleanupSorterCopyCheckBox.Value, obj.CleanupBinCheckBox.Value, ...
    obj.CleanupEnvelopeCheckBox.Value]);
steps = obj.CleanupStepCheckBoxes;
kinds = [kinds, string({steps([steps.Value]).Tag})];
c = obj.Config;
searchDirs = strtrim([string(c.Signals.OutputDir), string(c.Spikes.OutputDir), string(c.Export.OutputDir)]);
obj.setStatus(sprintf("Clean up: listing the files of %d dataset(s) and checking the sources...", numel(idx)), "");
try
    T = planLocalCleanup(obj.Project.Datasets(idx), Remove=kinds, SearchDirs=searchDirs(searchDirs ~= ""));
catch ME
    obj.refreshCleanupTable();
    uialert(obj.Fig, ME.message, "Clean up");
    obj.setStatus("Clean up: preview failed.", "");
    return
end
% Subject (for the Subject ID filter) and Include (every Remove file ticked)
T.Subject = repmat("(none)", height(T), 1);
ds = obj.Project.Datasets(idx);
for d = ds(:).'
    s = EphysDataset.nameIdentity(d.Name, d.NamePattern).subject;
    if s ~= ""; T.Subject(T.Dataset == string(d.Name)) = s; end
end
T.Include = T.Action == "remove";
keys = obj.Project.datasetKeys();
obj.CleanupPlan = T;
obj.CleanupPlanKeys = keys(idx);
obj.refreshCleanupMove(true);
obj.refreshCleanupTable();
obj.setStatus("Clean up: " + obj.CleanupSummaryLabel.Text, "");
end
