function applyCopyResult(obj, sel, R)
%applyCopyResult  Write a copySessions result back into the Copy tab's rows.
%   SEL are the rows of CopySessions the batch was made from, in order, so R
%   has one row for each. Called on every poll while a background copy runs,
%   so it only touches what can change.
if isempty(sel) || isempty(R) || height(R) ~= numel(sel)
    return
end
obj.CopySessions.DestDir(sel) = R.DestDir;
obj.CopyStatus(sel) = R.CopyStatus;
obj.CopyMessage(sel) = R.Message;
obj.refreshCopyTable();
end
