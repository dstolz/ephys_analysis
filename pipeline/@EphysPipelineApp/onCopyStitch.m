function onCopyStitch(obj)
%onCopyStitch  Merge the selected source rows into one recording with stitched ePsych files (stitchCopySessions).
%   Select the recording folder's row and the rows of the ePsych files recorded
%   during it (Ctrl- or Shift-click), then Stitch. The stitched row is ticked
%   and its last copy result cleared; Unstitch puts the rows back.

T = obj.CopySessions;
title = "Stitch ePsych files";
if isempty(T) || height(T) == 0
    uialert(obj.Fig, "Find sessions first.", title);
    return
end
sel = unique(obj.CopyTable.Selection(:));
sel = sel(sel <= height(T));
if numel(sel) < 2
    uialert(obj.Fig, "Select the recording folder's row and the rows of its ePsych files (Ctrl-click), then Stitch.", title);
    return
end
try
    [S, row, kept] = stitchCopySessions(T, sel);
catch ME
    uialert(obj.Fig, ME.message, title);
    return
end

obj.CopySessions = S;
obj.CopyTicked = obj.CopyTicked(kept);
obj.CopyStatus = obj.CopyStatus(kept);
obj.CopyMessage = obj.CopyMessage(kept);
obj.CopyTicked(row) = true;
obj.CopyStatus(row) = "";
obj.CopyMessage(row) = "";
made = row;   % the stitched session's row of S
obj.refreshCopyTable();   % in the remembered sort, which may move the row
row = find(obj.CopySessions.Status == "stitched" & obj.CopySessions.RecordingDir == S.RecordingDir(made), 1);
obj.CopyTable.Selection = row;

[~, name, ext] = fileparts(S.RecordingDir(made));
name = name + ext;
obj.copyLog(sprintf("Stitched %s: %s", S.RecordingDir(made), S.Note(made)));
obj.setStatus(sprintf("Copy: stitched %d ePsych files with %s.", numel(S.StitchFiles{made}), name), ...
    "The stitched row is ticked; Preview or Copy selected.");
end
