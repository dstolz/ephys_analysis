function s = copySummaryText(~, title, R)
%copySummaryText  One line counting how a copySessions result came out.
%   Only the statuses that occur are named, e.g.
%   "Copy sessions: 3 copied, 1 already present."
statuses = ["planned", "copying", "copied", "already_present", "skipped", "failed", "cancelled"];
counts = arrayfun(@(st) nnz(R.CopyStatus == st), statuses);
shown = counts > 0;
if ~any(shown)
    s = title + ": nothing to do.";
    return
end
parts = compose("%d %s", counts(shown).', replace(statuses(shown).', "_", " "));
s = sprintf("%s: %s.", title, strjoin(parts, ", "));
end
