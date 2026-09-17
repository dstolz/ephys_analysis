function [ids, notes, file] = readUnitNotes(resultsDir)
%readUnitNotes  Per-unit notes saved next to a sort (cluster_notes.tsv).
%   [IDS, NOTES, FILE] = EphysDataset.readUnitNotes(resultsDir) reads
%   cluster_notes.tsv from the phy folder under RESULTSDIR (see
%   resolvePhyDir): IDS [n x 1] cluster ids, NOTES [n x 1] string. Missing
%   file or folder gives empty outputs. The file is phy's custom-label format
%   (a header "cluster_id<TAB>notes", then one "<id><TAB><text>" row per
%   cluster), so notes typed in phy (label field "notes") and on the Review
%   tab (writeUnitNotes) are the same notes.
%
%   See also EphysDataset.writeUnitNotes, EphysDataset.readPhyUnits.

arguments
    resultsDir (1,1) string
end

ids = zeros(0, 1); notes = strings(0, 1); file = "";
if resultsDir == ""; return; end
dir0 = EphysDataset.resolvePhyDir(resultsDir);
fp = fullfile(dir0, EphysDataset.UnitNotesFile);
if ~isfile(fp); return; end
file = string(fp);
lines = splitlines(string(fileread(fp)));
if isempty(lines); return; end
lines = lines(2:end);                              % header: cluster_id<TAB>notes
lines = lines(strtrim(lines) ~= "");
for k = 1:numel(lines)
    parts = split(lines(k), sprintf('\t'));
    v = str2double(parts(1));
    if ~isfinite(v); continue; end
    ids(end+1, 1) = v; %#ok<AGROW>
    note = "";
    if numel(parts) > 1; note = strtrim(strjoin(parts(2:end).', " ")); end
    notes(end+1, 1) = note; %#ok<AGROW>
end
end
