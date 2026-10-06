function refreshCleanupTable(obj, part)
%refreshCleanupTable  Show the Clean up preview (CleanupPlan): its rows and the totals.
%   refreshCleanupTable(obj) fills the table with the plan rows that pass the
%   filters (regexp search on the file path, Subject ID, "Show the files that
%   remain") and updates the totals. refreshCleanupTable(obj, "summary")
%   updates only the totals and the Delete / Recycle / Move files... button, leaving the table
%   (and the user's sort of it) as it is.
%
%   Ticked Remove rows are tinted red, unticked ones grey; raw recording files
%   that are kept (no verified source copy) amber, since they are the ones a
%   user may have expected to go. While a move's folder is checked
%   (CleanupMove, refreshCleanupMove) a ninth column, In the folder, says
%   what is already at each file's place there and what the move would do
%   (If a file is already there), and the ticked files it does not simply
%   move are tinted lavender. The rows are in the plan's order (Remove
%   first, largest first), or in that of the remembered header click
%   (tableSort "Cleanup"), which holds for every preview and the next
%   session. CleanupRowMap maps each row of Data to its plan row, in
%   whichever order Data has; a header click reorders only the display, so
%   Data keeps the order set here.
arguments
    obj
    part (1,1) string {mustBeMember(part, ["all" "summary"])} = "all"
end
tbl = obj.CleanupTable;
if isempty(tbl) || ~isvalid(tbl); return; end
T = obj.CleanupPlan;
if isempty(T)
    removeStyle(tbl);
    showFolderColumn(tbl, false);
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
M = obj.CleanupMove;
dest = strtrim(string(obj.CleanupDestField.Value));
if string(obj.CleanupMethodDropDown.Value) == "move" && any(go)
    if isempty(M)
        txt = txt + " Choose the folder to move them into (a full path): it is then checked for the files already there.";
    else
        txt = txt + cleanupMoveSentence(T, M, dest);
    end
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
obj.CleanupShownLabel.Text = shownText(numel(vis), height(T), nnz(T.Include(vis)));
set(obj.CleanupSelectButtons, "Enable", matlab.lang.OnOffSwitchState(any(rm(vis))));

S = T(vis, :);
action = repmat("Keep", height(S), 1);
action(S.Action == "remove") = "Remove";
D = [num2cell(S.Include), cellstr(action), cellstr(S.Dataset), cellstr(S.Subject), ...
    cellstr(S.What), num2cell(sizeMB(S.Bytes)), cellstr(S.File), cellstr(S.Reason)];
showFolderColumn(tbl, ~isempty(M));
if ~isempty(M)
    D = [D, cellstr(folderText(S, M(vis, :), dest))];
end
[D, ord] = TableSort.apply(D, obj.tableSort("Cleanup"), tbl.ColumnName);
S = S(ord, :);
obj.CleanupRowMap = vis(ord);   % the plan row of each row of Data, in its order
tbl.Data = D;
removeStyle(tbl);
styleRows(tbl, find(S.Action == "remove" & S.Include), [0.98 0.85 0.83]);
styleRows(tbl, find(S.Action == "remove" & ~S.Include), [0.92 0.92 0.92]);
styleRows(tbl, find(S.Action == "keep" & S.Category == "raw"), [1.00 0.93 0.75]);
if ~isempty(M)
    Ms = M(obj.CleanupRowMap, :);
    styleRows(tbl, find(S.Action == "remove" & S.Include & (Ms.Taken ~= "" | Ms.To ~= Ms.Target)), [0.88 0.84 0.98]);
end
end


function showFolderColumn(tbl, show)
%showFolderColumn  Add or drop the ninth column, In the folder (a move's check), keeping the other eight as built.
if show == (numel(tbl.ColumnName) == 9); return; end
if show
    tbl.ColumnName = [tbl.ColumnName(:).', {'In the folder'}];
    tbl.ColumnWidth = [tbl.ColumnWidth, {'2x'}];
    tbl.ColumnEditable = [tbl.ColumnEditable, false];
    tbl.ColumnFormat = [tbl.ColumnFormat, {'char'}];
else
    tbl.ColumnName = tbl.ColumnName(1:8);
    tbl.ColumnWidth = tbl.ColumnWidth(1:8);
    tbl.ColumnEditable = tbl.ColumnEditable(1:8);
    tbl.ColumnFormat = tbl.ColumnFormat(1:8);
end
end


function txt = folderText(S, M, dest)
%folderText  The In the folder column: what the move's folder holds at each file's place and what the move would do.
%   A ticked Remove file is described as it would go: skipped, overwriting
%   the file there, or to the dataset's new version folder; an unticked one
%   (it stays anyway) only by what is there. Keep rows are blank.
txt = strings(height(S), 1);
dest = strip(strrep(dest, "/", filesep), 'right', filesep);
for k = 1:height(S)
    if M.Target(k) == ""; continue; end   % not a Remove file
    switch M.Taken(k)
        case "file"
            there = sprintf("Already there (%s, %s)", bytesText(M.TakenBytes(k)), string(M.TakenDate(k), "yyyy-MM-dd HH:mm"));
        case "folder"
            there = "A folder of that name is there";
        otherwise
            there = "";
    end
    if ~(S.Action(k) == "remove" && S.Include(k))
        txt(k) = there;
    elseif M.To(k) == "" && there == ""
        txt(k) = "Skipped, it stays here: " + M.Note(k);
    elseif M.To(k) == ""
        txt(k) = there + ": skipped, it stays here";
    elseif ~strcmpi(M.To(k), M.Target(k))
        v = extractAfter(M.Version(k), strlength(dest) + 1);
        if there == ""
            txt(k) = "Goes to the new version folder " + v;
        else
            txt(k) = there + "; this one goes to the new version folder " + v;
        end
    elseif there ~= ""
        txt(k) = there + ": overwritten";
    end
end
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
