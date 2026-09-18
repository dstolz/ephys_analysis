function refreshCleanupTable(obj)
%refreshCleanupTable  Show the Clean up preview (CleanupPlan): its rows and the totals.
%   Remove rows are tinted red; raw recording files that are kept (no
%   verified source copy) amber, since they are the ones a user may have
%   expected to go. "Show the files that remain" hides or shows the Keep rows.
tbl = obj.CleanupTable;
if isempty(tbl) || ~isvalid(tbl); return; end
removeStyle(tbl);
T = obj.CleanupPlan;
if isempty(T)
    tbl.Data = {};
    obj.CleanupRunButton.Enable = "off";
    obj.CleanupSummaryLabel.Text = "Press Preview to see what would be removed and what would remain.";
    return
end

rm = T.Action == "remove";
nDs = numel(unique(T.Dataset));
nDsRm = numel(unique(T.Dataset(rm)));
txt = sprintf("Would remove %d file(s), %s, from %d of %d dataset(s). %d file(s), %s, remain.", ...
    nnz(rm), bytesText(sum(T.Bytes(rm))), nDsRm, nDs, nnz(~rm), bytesText(sum(T.Bytes(~rm))));
rawKept = unique(T.Dataset(~rm & T.Category == "raw"));
if ~isempty(rawKept) && obj.CleanupRawCheckBox.Value
    txt = txt + sprintf(" The raw recording of %d dataset(s) is kept (see Why).", numel(rawKept));
end
obj.CleanupSummaryLabel.Text = txt;
obj.CleanupRunButton.Enable = matlab.lang.OnOffSwitchState(any(rm));

if ~obj.CleanupShowKeptCheckBox.Value
    T = T(rm, :);
end
action = repmat("Keep", height(T), 1);
action(T.Action == "remove") = "Remove";
sizes = arrayfun(@bytesText, T.Bytes);
tbl.Data = table(action, T.Dataset, T.What, sizes, T.File, T.Reason, ...
    'VariableNames', {'Action', 'Dataset', 'What', 'Size', 'File', 'Why'});
r = find(T.Action == "remove");
if ~isempty(r)
    addStyle(tbl, uistyle("BackgroundColor", [0.98 0.85 0.83]), "row", r);
end
r = find(T.Action == "keep" & T.Category == "raw");
if ~isempty(r)
    addStyle(tbl, uistyle("BackgroundColor", [1.00 0.93 0.75]), "row", r);
end
end


function s = bytesText(b)
units = ["B", "KB", "MB", "GB", "TB"];
k = 1;
while b >= 1024 && k < numel(units)
    b = b / 1024; k = k + 1;
end
if k == 1
    s = sprintf("%d B", round(b));
else
    s = sprintf("%.1f %s", b, units(k));
end
end
