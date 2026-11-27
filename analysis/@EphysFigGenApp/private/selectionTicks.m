function [ticked, missing, legacy] = selectionTicks(r, S)
%selectionTicks  The Run ticks a source's selection gives over a runner's datasets, and the keys it names that are not there.
%   [TICKED, MISSING] = selectionTicks(R, S), R an EphysAnalysisRunner
%   and S a config's Source (R a scan of it): with S.Selection "all" every
%   dataset of R is ticked (TICKED, a logical row over R.Keys); with "list"
%   those S.Datasets names -- in project mode as the runner finds them
%   (EphysProject.findByKey: "\" or "/", and on Windows case, alike), in
%   folders mode by the folder (EphysAnalysisRunner.selectedFolders:
%   EphysDataset.pathKey). MISSING: the keys of S.Datasets that name none
%   of R's datasets (onScan and tickConfigSelection report them on the
%   status bar and in the Log: selectionNotes).
%
%   [..., LEGACY] = ... is true for a folders-mode "list" saved before
%   folders mode had a selection of its own (a project's keys, which name
%   no folder: EphysAnalysisRunner.selectedFolders): every dataset is
%   ticked, as such a config ran then, and MISSING is empty.
%
%   See also onScan, tickConfigSelection, gatherSourceSection, selectionNotes.
n = numel(r.Keys);
missing = string.empty(1, 0);
legacy = false;
if string(S.Selection) ~= "list"
    ticked = true(1, n);
    return
end
want = reshape(string(S.Datasets), 1, []);
if string(S.Mode) == "project" && ~isempty(r.Project)
    pk = r.Project.findByKey(want);   % 0 = not found
    known = r.Project.datasetKeys();
    ticked = ismember(r.Keys, known(pk(pk > 0)));
    missing = want(pk == 0);
else
    S.Folders = r.Keys;   % the folders scanned
    [sel, missing, legacy] = EphysAnalysisRunner.selectedFolders(S);
    ticked = ismember(r.Keys, sel);
end
ticked = reshape(logical(ticked), 1, []);
end
