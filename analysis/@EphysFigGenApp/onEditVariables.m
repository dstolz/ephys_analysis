function dlg = onEditVariables(obj, idx)
%onEditVariables  The variable dialog (VariableDialog) on datasets IDX (indices into Runner.Outputs).
%   obj.onEditVariables() (the Data table's right-click Variables...)
%   works on the rows selected in the Data table, else on the active
%   dataset; obj.onEditVariables(IDX) (a click on a Variables cell) on
%   those. The dialog has a row per dataset and a column per variable, and
%   offers the variables in use on the scanned datasets. On OK each changed
%   dataset's set is written to its manifest (writeManifestVariables: the
%   manifest in effect, else the dataset's own; every change is logged with
%   the time and the user in variable_history), the sources loaded already
%   take the new values (src.variables, src.variableInfo), the table
%   follows, the figure preview too (autoFigurePreview: a label naming a
%   variable, {probeDepth}, prints its value; figureViewKey holds the
%   active dataset's values) and the status bar says what was done. Variables are not part
%   of the config: an edit never marks it unsaved. With a dialog open
%   already, that one comes to the front. DLG is the dialog ([] when none
%   opened).
%
%   See also VariableDialog, DatasetVariables, writeManifestVariables.
dlg = [];
if ~isempty(obj.VariableDialog) && isvalid(obj.VariableDialog) && isvalid(obj.VariableDialog.Fig)
    dlg = obj.VariableDialog;
    figure(dlg.Fig);
    return
end
r = obj.Runner;
if isempty(r) || isempty(r.Keys)
    AppDialog.alert(obj.Fig, "Scan for datasets first (Data tab).", "Variables");
    return
end
if nargin < 2
    idx = zeros(1, 0);
    T = obj.DatasetsTable.Data;
    sel = obj.DatasetsTable.Selection;
    if ~isempty(sel) && istable(T) && ismember('Idx', T.Properties.VariableNames)
        rows = unique(sel(:, 1));
        idx = reshape(unique(T.Idx(rows(rows >= 1 & rows <= height(T)))), 1, []);
    end
    if isempty(idx); idx = obj.ActiveIdx; end
end
idx = reshape(idx(idx >= 1 & idx <= numel(r.Outputs)), 1, []);
if isempty(idx)
    AppDialog.alert(obj.Fig, "Select rows in the Data table, or click a dataset to make it the active one.", "Variables");
    return
end
sets = obj.datasetVariableSets();   % each dataset's: its loaded source's, else its manifest's
dlg = VariableDialog(sets(idx), DatasetVariables.vocabulary(sets), Labels=reshape(r.Names(idx), 1, []), ...
    Parent=obj.Fig, Visible=obj.Fig.Visible == "on", OnDone=@(res) applyVariables(obj, idx, res));
obj.VariableDialog = dlg;
end


function applyVariables(obj, idx, res)
%applyVariables  The dialog closed: write each changed dataset's new set, update the loaded sources and the table.
obj.VariableDialog = [];
if isempty(res) || ~isvalid(obj); return; end
r = obj.Runner;
changed = reshape(logical(res.changed), 1, []);
added = cell(1, numel(idx));
failed = strings(1, 0);
for j = 1:numel(idx)
    added{j} = DatasetVariables.emptyHistory();
    if ~changed(j); continue; end
    k = idx(j);
    out = r.Outputs(k);
    try
        target = out.ManifestFile;   % string.empty when there is none
        if ~isempty(target) && target(1) ~= ""
            target = target(1);
        elseif ~isempty(out.Dataset)
            target = out.Dataset;
        else
            error('EphysFigGenApp:NoManifest', 'it has no manifest');
        end
        [s, added{j}] = writeManifestVariables(target, Set=res.sets{j}, Renamed=res.renamed{j});
    catch ME
        failed(end+1) = r.Names(k) + ": " + string(ME.message); %#ok<AGROW>
        continue
    end
    out.clearCache();   % its manifest (CacheData) is read again
    key = char(r.Keys(k));
    if isKey(r.Sources, key)
        src = r.Sources(key);
        src.variables = DatasetVariables.values(s);
        src.variableInfo = DatasetVariables.info(s);
        S = r.Sources;   % a containers.Map: the runner keeps the new one
        S(key) = src;
    end
end
obj.refreshDatasetsTable();
if any(changed); obj.autoFigurePreview(); end   % a label naming a dataset variable ({probeDepth}) prints the new value
if ~isempty(failed)
    obj.setStatus("Variables not written: " + strjoin(failed, "; "));
else
    obj.setStatus(VariableDialog.describe(added, reshape(r.Names(idx), 1, [])));
end
end
