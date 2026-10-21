function loadNotes(obj)
%loadNotes  Read every scanned dataset's notes: Notes becomes a DatasetNotes per dataset (the Runner's order).
%   Each reads <Name>_notes.json in its dataset's output folder (one small
%   file; none: no note). A file that cannot be read gives no note, and the
%   Log says why. The units' sort is looked up only for a dataset whose
%   file holds unit notes.
%
%   See also DatasetNotes, onScan, refreshNotes, loadFavorites.
r = obj.Runner;
obj.Notes = [];
if isempty(r) || isempty(r.Keys); return; end
N = cell(1, numel(r.Keys));
for k = 1:numel(r.Keys)
    N{k} = DatasetNotes(r.Outputs(k));
    if N{k}.Problem ~= ""
        obj.log("Notes of " + r.Names(k) + ": " + N{k}.Problem);
    end
end
obj.Notes = [N{:}];
end
