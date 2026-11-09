function onEditVariables(obj, idx)
%onEditVariables  Open the variable dialog on datasets IDX (indices into Project.Datasets).
%   obj.onEditVariables() (Variables... and Dataset > Variables...) works
%   on the rows selected in the Project table (selectedRowDatasets),
%   ticked or not, and on the active dataset when none is selected.
%   obj.onEditVariables(IDX) (a click on a Variables cell) edits those.
%
%   The dialog (VariableDialog, kept in obj.VariableDialog) shows a row per
%   dataset and a column per variable, and offers the variables in use on
%   the project's other datasets. On OK each dataset it changes gets its
%   new set (EphysDataset.setVariables, which logs every change with the
%   time and the user in the manifest's variable_history), its manifest
%   is written (saveManifests) and the table follows; the status bar says
%   what was done. Variables are not part of the config: an edit never
%   marks it unsaved. Refused while a run is going; with a dialog open
%   already, that one comes to the front.
%
%   See also VariableDialog, DatasetVariables, onEditTags.
if obj.refuseWhileRunning("Variables"); return; end
dlg = obj.VariableDialog;
if ~isempty(dlg) && isvalid(dlg) && isvalid(dlg.Fig)
    figure(dlg.Fig);
    return
end
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    obj.alertNoProject("Variables");
    return
end
if nargin < 2
    idx = selectedRowDatasets(obj);
    if isempty(idx); idx = obj.SelectedDatasetIdx; end
end
idx = reshape(idx(idx >= 1 & idx <= obj.Project.NumDatasets), 1, []);
if isempty(idx)
    uialert(obj.Fig, "Select rows in the Project table, or choose a dataset in the Dataset box.", "Variables");
    return
end

targets = obj.Project.Datasets(idx);
sets = arrayfun(@(d) d.Variables, obj.Project.Datasets, 'UniformOutput', false);
obj.VariableDialog = VariableDialog(arrayfun(@(d) d.Variables, targets, 'UniformOutput', false), ...
    DatasetVariables.vocabulary(sets), Labels=[targets.Name], Parent=obj.Fig, ...
    OnDone=@(r) applyVariables(obj, idx, targets, r));
end


function applyVariables(obj, idx, targets, r)
%applyVariables  The dialog closed: store, save and show the new sets.
%   R is [] (canceled, or nothing changed) or VariableDialog's result:
%   each target with R.changed(k) gets R.sets{k}, renames as R.renamed{k}.
if isempty(r); return; end
changed = reshape(logical(r.changed), 1, []);
added = cell(1, numel(targets));
for k = 1:numel(targets)
    added{k} = DatasetVariables.emptyHistory();
    if ~changed(k); continue; end
    try
        added{k} = targets(k).setVariables(r.sets{k}, Renamed=r.renamed{k});
    catch ME
        obj.setStatus(AppDialog.failure("save the variables", targets(k).Name, ME.message));
        return
    end
end
obj.saveManifests(targets(changed));
obj.refreshDatasetsTable(Datasets=idx(changed));
obj.setStatus(VariableDialog.describe(added, [targets.Name]));
end
