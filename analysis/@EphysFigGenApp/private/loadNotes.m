function loadNotes(obj)
%loadNotes  Read every scanned dataset's notes: Notes becomes a DatasetNotes per dataset (the Runner's order).
%   Each reads <Name>_notes.json in its dataset's output folder (one small
%   file; none: no note). A file that cannot be read gives no note, and the
%   Log says why. The units' sort is looked up only for a dataset whose
%   file holds unit notes.
%
%   The notepad that is open (NotePadWindow) writes through the object of
%   its note, so a re-scan, which makes these objects again, first has the
%   note in the pad written, and afterwards moves the pad onto the new
%   object of the same file: two objects writing one file would each drop
%   the other's notes (DatasetNotes.save writes its whole state). A pad
%   on a dataset the scan no longer lists stays as it is.
%
%   See also DatasetNotes, onScan, refreshNotes, loadFavorites.
r = obj.Runner;
pad = obj.NotePadWindow;
if ~isempty(pad) && isvalid(pad)
    pad.save();   % what is typed in the pad is in the file before the new objects read it
    padItem = pad.Item;
else
    pad = [];
end
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
if ~isempty(pad) && isvalid(pad) && ~isempty(padItem)
    k = find(arrayfun(@(n) isequal(string(n.File), string(padItem.notes.File)), obj.Notes), 1);
    if ~isempty(k)
        padItem.notes = obj.Notes(k);
        pad.open(padItem);   % the pad now writes through the object the app uses
    end
end
end
