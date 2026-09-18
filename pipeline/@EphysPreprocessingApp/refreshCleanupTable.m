function refreshCleanupTable(obj, part)
%refreshCleanupTable  Show the Clean up preview (CleanupPlan): its rows and the totals.
%   refreshCleanupTable(obj) fills the table with the plan rows that pass the
%   filters (regexp search on the file path, Subject ID, "Show the files that
%   remain") and updates the totals. refreshCleanupTable(obj, "summary")
%   updates only the totals and the Remove files... button, leaving the table
%   (and the user's sort of it) as it is.
%
%   Ticked Remove rows are tinted red, unticked ones grey; raw recording files
%   that are kept (no verified source copy) amber, since they are the ones a
%   user may have expected to go. CleanupRowMap maps each table row to its
%   plan row: the table may be sorted, but Data keeps the order set here.
arguments
    obj
    part (1,1) string {mustBeMember(part, ["all" "summary"])} = "all"
end
tbl = obj.CleanupTable;
if isempty(tbl) || ~isvalid(tbl); return; end
T = obj.CleanupPlan;
if isempty(T)
    removeStyle(tbl);
    tbl.Data = cell(0, 8);
    obj.CleanupRowMap = zeros(0, 1);
    obj.CleanupRunButton.Enable = "off";
    obj.CleanupSummaryLabel.Text = "Press Preview to see what would be removed and what would remain.";
    obj.CleanupShownLabel.Text = "";
    set(obj.CleanupSelectButtons, "Enable", "off");
    syncSubjects(obj.CleanupSubjectDropDown, string.empty(0, 1));
    return
end

rm = T.Action == "remove";
go = rm & T.Include;
nDs = numel(unique(T.Dataset));
nDsGo = numel(unique(T.Dataset(go)));
txt = sprintf("Would remove %d file(s), %s, from %d of %d dataset(s). %d file(s), %s, remain.", ...
    nnz(go), bytesText(sum(T.Bytes(go))), nDsGo, nDs, nnz(~go), bytesText(sum(T.Bytes(~go))));
if any(rm & ~T.Include)
    txt = txt + sprintf(" %d of them could be removed but are unticked.", nnz(rm & ~T.Include));
end
rawKept = unique(T.Dataset(~rm & T.Category == "raw"));
if ~isempty(rawKept) && obj.CleanupRawCheckBox.Value
    txt = txt + sprintf(" The raw recording of %d dataset(s) is kept (see Why).", numel(rawKept));
end
obj.CleanupSummaryLabel.Text = txt;
obj.CleanupRunButton.Enable = matlab.lang.OnOffSwitchState(any(go));
if part == "summary"
    vis = obj.CleanupRowMap;
    obj.CleanupShownLabel.Text = shownText(numel(vis), height(T), nnz(T.Include(vis)));
    return
end

syncSubjects(obj.CleanupSubjectDropDown, T.Subject);
vis = visibleRows(obj, T);
obj.CleanupRowMap = vis;
obj.CleanupShownLabel.Text = shownText(numel(vis), height(T), nnz(T.Include(vis)));
set(obj.CleanupSelectButtons, "Enable", matlab.lang.OnOffSwitchState(any(rm(vis))));

S = T(vis, :);
action = repmat("Keep", height(S), 1);
action(S.Action == "remove") = "Remove";
tbl.Data = [num2cell(S.Include), cellstr(action), cellstr(S.Dataset), cellstr(S.Subject), ...
    cellstr(S.What), num2cell(sizeMB(S.Bytes)), cellstr(S.File), cellstr(S.Reason)];
removeStyle(tbl);
styleRows(tbl, find(S.Action == "remove" & S.Include), [0.98 0.85 0.83]);
styleRows(tbl, find(S.Action == "remove" & ~S.Include), [0.92 0.92 0.92]);
styleRows(tbl, find(S.Action == "keep" & S.Category == "raw"), [1.00 0.93 0.75]);
end


function vis = visibleRows(obj, T)
%visibleRows  Plan rows passing the filters; a search matching no file tints the search field.
ok = true(height(T), 1);
if ~obj.CleanupShowKeptCheckBox.Value
    ok = ok & T.Action == "remove";
end
subj = string(obj.CleanupSubjectDropDown.Value);
if subj ~= "All subjects"
    ok = ok & T.Subject == subj;
end
field = obj.CleanupSearchField;
pat = strtrim(string(field.Value));
field.BackgroundColor = [1 1 1];
if pat ~= ""
    % regexpi does not throw on a malformed pattern, it matches nothing
    hit = ~cellfun(@isempty, regexpi(cellstr(T.File), char(pat), 'once'));
    if ~any(hit); field.BackgroundColor = [1.00 0.85 0.85]; end
    ok = ok & hit;
end
vis = find(ok);
if isempty(vis); vis = zeros(0, 1); end
end


function syncSubjects(dd, subjects)
%syncSubjects  "All subjects" plus the plan's subjects; keep the choice while it is still one of them.
items = ["All subjects"; unique(subjects(:))];
if isequal(string(dd.Items(:)), items); return; end
cur = string(dd.Value);
dd.Items = cellstr(items);
if any(items == cur)
    dd.Value = char(cur);
else
    dd.Value = 'All subjects';
end
end


function styleRows(tbl, rows, color)
if ~isempty(rows)
    addStyle(tbl, uistyle("BackgroundColor", color), "row", rows);
end
end


function s = shownText(nShown, nAll, nTicked)
s = sprintf("Showing %d of %d file(s); %d ticked.", nShown, nAll, nTicked);
end


function mb = sizeMB(b)
%sizeMB  Size in MB for a column that sorts numerically: whole MB from 100 MB, else 2 decimals.
mb = b / 2^20;
big = mb >= 100;
mb(big) = round(mb(big));
mb(~big) = round(mb(~big), 2);
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
