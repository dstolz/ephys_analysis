function file = writeUnitNotes(resultsDir, unitIds, notes)
%writeUnitNotes  Save per-unit notes next to a sort (cluster_notes.tsv).
%   FILE = EphysDataset.writeUnitNotes(resultsDir, UNITIDS, NOTES) sets the
%   note of each cluster id in UNITIDS to the matching NOTES entry and
%   rewrites cluster_notes.tsv in the phy folder under RESULTSDIR. Notes of
%   other clusters are kept; an empty note removes that cluster's row. Tabs
%   and line breaks become spaces, so each note stays one row phy can read.
%   readPhyUnits picks the notes up as units.notes on every read.
%
%   See also EphysDataset.readUnitNotes, EphysDataset.readPhyUnits.

arguments
    resultsDir (1,1) string
    unitIds (:,1) double
    notes (:,1) string
end

if numel(unitIds) ~= numel(notes)
    error('EphysDataset:writeUnitNotes:Size', ...
        '%d unit id(s) but %d note(s).', numel(unitIds), numel(notes));
end
dir0 = EphysDataset.resolvePhyDir(resultsDir);
if ~isfolder(dir0)
    error('EphysDataset:writeUnitNotes:NoResultsDir', 'Not a folder: %s', resultsDir);
end

[ids, txt] = EphysDataset.readUnitNotes(dir0);
notes(ismissing(notes)) = "";
notes = strtrim(regexprep(notes, '[\t\r\n]+', ' '));
for k = 1:numel(unitIds)
    at = find(ids == unitIds(k));
    if isempty(at)
        ids(end+1, 1) = unitIds(k); %#ok<AGROW>
        txt(end+1, 1) = notes(k); %#ok<AGROW>
    else
        txt(at) = notes(k);
    end
end
keep = txt ~= "";
[ids, order] = sort(ids(keep));
txt = txt(keep);
txt = txt(order);

file = string(fullfile(dir0, EphysDataset.UnitNotesFile));
body = "cluster_id" + sprintf('\t') + "notes" + newline;
if ~isempty(ids)
    body = body + strjoin((compose("%d", ids) + sprintf('\t') + txt).', newline) + newline;
end
tmp = file + ".tmp";
fid = fopen(tmp, 'w', 'n', 'UTF-8');
if fid < 0
    error('EphysDataset:writeUnitNotes:Write', 'Cannot write %s', tmp);
end
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, '%s', body);
clear cleaner
[ok, msg] = movefile(tmp, file, 'f');
if ~ok
    delete(tmp);
    error('EphysDataset:writeUnitNotes:Write', 'Cannot replace %s: %s', file, msg);
end
end
