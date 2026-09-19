function onCopyUnstitch(obj)
%onCopyUnstitch  Put the selected stitched source rows back as findCopySessions found them.
%   The rows holding the stitched recording folder and ePsych files come back
%   from CopyFound with their pairing status; paired rows are ticked again.

T = obj.CopySessions;
title = "Unstitch";
sel = [];
if ~isempty(T)
    sel = unique(obj.CopyTable.Selection(:));
    sel = sel(sel <= height(T));
    sel = sel(T.Status(sel) == "stitched");
end
if isempty(sel)
    uialert(obj.Fig, "Select a stitched row to unstitch.", title);
    return
end

F = obj.CopyFound;
back = false(height(F), 1);
for r = sel.'
    back = back | (F.RecordingDir ~= "" & F.RecordingDir == T.RecordingDir(r)) ...
        | (F.EpsychFile ~= "" & ismember(F.EpsychFile, T.StitchFiles{r}));
end
keep = true(height(T), 1);
keep(sel) = false;
restored = F(back, :);

U = [T(keep, :); restored];
ticked = [obj.CopyTicked(keep); restored.Status == "paired"];
copyStatus = [obj.CopyStatus(keep); strings(height(restored), 1)];
message = [obj.CopyMessage(keep); strings(height(restored), 1)];

% in time order, as findCopySessions lists them
t = U.RecordingTime;
t(isnat(t)) = U.EpsychTime(isnat(t));
[~, order] = sort(t);
obj.CopySessions = U(order, :);
obj.CopyTicked = ticked(order);
obj.CopyStatus = copyStatus(order);
obj.CopyMessage = message(order);
obj.refreshCopyTable();

obj.copyLog(sprintf("Unstitched %d row(s): %s", numel(sel), strjoin(T.RecordingDir(sel), ", ")));
obj.setStatus(sprintf("Copy: %s", obj.CopySummaryLabel.Text), "");
end
