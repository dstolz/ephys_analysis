function onEditTags(obj, idx)
%onEditTags  Open the tag dialog on datasets IDX (indices into Project.Datasets).
%   obj.onEditTags() (Tags... and Dataset > Tags...) works on the ticked
%   datasets, those on rows the filters hide included, as Assign probe
%   does: bulk mode (add to all / remove from all) when two or more are
%   ticked, single mode for one, and the active dataset when none is
%   ticked. obj.onEditTags(IDX) (a click on a Tags cell) edits those.
%
%   The dialog (TagDialog, kept in obj.TagDialog) offers the tags in use
%   on the project's datasets. On OK each dataset it changes gets its new
%   set (EphysDataset.Tags), its manifest is written (saveManifests) and
%   the table and its tag filter follow; the status bar says what was
%   done, and with "Skip that dataset" which datasets were left out and
%   why. Tags are not part of the config: an edit never marks it unsaved.
%   The bulk policy chosen is kept for the session (TagPolicy), also when
%   the dialog is canceled. Refused while a run is going; with a dialog
%   open already, that one comes to the front.
%
%   See also TagDialog, TagSet, onDatasetsTableClicked.
if obj.refuseWhileRunning("Tags"); return; end
dlg = obj.TagDialog;
if ~isempty(dlg) && isvalid(dlg) && isvalid(dlg.Fig)
    figure(dlg.Fig);
    return
end
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    uialert(obj.Fig, "Scan a project first.", "Tags");
    return
end
if nargin < 2
    idx = obj.tickedDatasetIndices();
    if isempty(idx); idx = obj.SelectedDatasetIdx; end
end
idx = reshape(idx(idx >= 1 & idx <= obj.Project.NumDatasets), 1, []);
if isempty(idx)
    uialert(obj.Fig, "Tick datasets in the Project table, or choose one in the Dataset box.", "Tags");
    return
end

targets = obj.Project.Datasets(idx);
labels = [targets.Name];
vocab = TagSet.vocabulary(arrayfun(@(d) d.Tags, obj.Project.Datasets, 'UniformOutput', false));
obj.TagDialog = TagDialog(arrayfun(@(d) d.Tags, targets, 'UniformOutput', false), vocab, ...
    Labels=labels, Parent=obj.Fig, Policy=obj.TagPolicy, ...
    OnDone=@(r) applyTags(obj, idx, targets, r));
end


function applyTags(obj, idx, targets, r)
%applyTags  The dialog closed: store, save and show the new tag sets.
%   R is [] (canceled, or nothing changed) or TagDialog's result: each
%   target with R.applied(k) gets R.sets{k}.
if ~isempty(obj.TagDialog) && isvalid(obj.TagDialog)
    obj.TagPolicy = obj.TagDialog.Policy;   % chosen even when canceled
end
if isempty(r); return; end
applied = reshape(logical(r.applied), 1, []);
for k = find(applied)
    targets(k).Tags = r.sets{k};
end
obj.saveManifests(targets(applied));
obj.refreshDatasetsTable(Datasets=idx(applied));

names = [targets.Name];
tags = TagSet.toText(r.tags, TagSet.DisplayDelimiter);
switch r.mode
    case "set"
        if isempty(r.tags)
            obj.setStatus(names(1) + " has no tags now.");
        else
            obj.setStatus("Tagged " + names(1) + ": " + tags + ".");
        end
    case "remove"
        obj.setStatus(sprintf("Removed %s from %d datasets.", tags, numel(targets)));
    otherwise   % "add"
        if all(applied)
            obj.setStatus(sprintf("Tagged %d datasets: added %s.", numel(targets), tags));
        else
            skipped = ~applied;
            obj.setStatus(sprintf("Added %s to %d of %d datasets; skipped %d over the tag limit.", ...
                tags, nnz(applied), numel(targets), nnz(skipped)), ...
                "remove tags from " + strjoin(names(skipped) + " (" + r.why(skipped) + ")", "; ") + ", then add again.");
        end
end
end
