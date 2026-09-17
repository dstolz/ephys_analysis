function onNasStitch(obj)
%onNasStitch  Merge the selected NAS rows into one recording with stitched ePsych files (stitchNasSessions).
%   Select the Intan folder's row and the rows of the ePsych files recorded
%   during it (Ctrl- or Shift-click), then Stitch. The stitched row is ticked
%   and its last copy result cleared; Unstitch puts the rows back.

T = obj.NasSessions;
title = "Stitch ePsych files";
if isempty(T) || height(T) == 0
    uialert(obj.Fig, "Find sessions first.", title);
    return
end
sel = unique(obj.NasTable.Selection(:));
sel = sel(sel <= height(T));
if numel(sel) < 2
    uialert(obj.Fig, "Select the Intan folder's row and the rows of its ePsych files (Ctrl-click), then Stitch.", title);
    return
end
try
    [S, row, kept] = stitchNasSessions(T, sel);
catch ME
    uialert(obj.Fig, ME.message, title);
    return
end

obj.NasSessions = S;
obj.NasTicked = obj.NasTicked(kept);
obj.NasCopyStatus = obj.NasCopyStatus(kept);
obj.NasMessage = obj.NasMessage(kept);
obj.NasTicked(row) = true;
obj.NasCopyStatus(row) = "";
obj.NasMessage(row) = "";
obj.refreshNasTable();
obj.NasTable.Selection = row;

[~, name] = fileparts(S.IntanDir(row));
obj.nasLog(sprintf("Stitched %s: %s", S.IntanDir(row), S.Note(row)));
obj.setStatus(sprintf("NAS: stitched %d ePsych files with %s.", numel(S.StitchFiles{row}), name), ...
    "The stitched row is ticked; Preview or Copy selected.");
end
