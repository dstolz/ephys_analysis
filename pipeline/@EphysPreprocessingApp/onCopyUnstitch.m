function onNasUnstitch(obj)
%onNasUnstitch  Put the selected stitched NAS rows back as findNasSessions found them.
%   The rows holding the stitched Intan folder and ePsych files come back
%   from NasFound with their pairing status; paired rows are ticked again.

T = obj.NasSessions;
title = "Unstitch";
sel = [];
if ~isempty(T)
    sel = unique(obj.NasTable.Selection(:));
    sel = sel(sel <= height(T));
    sel = sel(T.Status(sel) == "stitched");
end
if isempty(sel)
    uialert(obj.Fig, "Select a stitched row to unstitch.", title);
    return
end

F = obj.NasFound;
back = false(height(F), 1);
for r = sel.'
    back = back | (F.IntanDir ~= "" & F.IntanDir == T.IntanDir(r)) ...
        | (F.EpsychFile ~= "" & ismember(F.EpsychFile, T.StitchFiles{r}));
end
keep = true(height(T), 1);
keep(sel) = false;
restored = F(back, :);

U = [T(keep, :); restored];
ticked = [obj.NasTicked(keep); restored.Status == "paired"];
copyStatus = [obj.NasCopyStatus(keep); strings(height(restored), 1)];
message = [obj.NasMessage(keep); strings(height(restored), 1)];

% in time order, as findNasSessions lists them
t = U.IntanTime;
t(isnat(t)) = U.EpsychTime(isnat(t));
[~, order] = sort(t);
obj.NasSessions = U(order, :);
obj.NasTicked = ticked(order);
obj.NasCopyStatus = copyStatus(order);
obj.NasMessage = message(order);
obj.refreshNasTable();

obj.nasLog(sprintf("Unstitched %d row(s): %s", numel(sel), strjoin(T.IntanDir(sel), ", ")));
obj.setStatus(sprintf("NAS: %s", obj.NasSummaryLabel.Text), "");
end
