function [keys, ok] = pickSessionDatasets(fig, T, keys)
%pickSessionDatasets  Tick the datasets a session plot draws, in a small modal window over FIG.
%   [KEYS, OK] = pickSessionDatasets(FIG, T, KEYS) shows the scanned
%   datasets, the rows of T (a sessionTable: key, name, subject, dateText),
%   in a table with a Use box each, ticked for the keys KEYS already
%   chosen, and the dataset's Name, Subject, Date and Key as the Data tab
%   shows them. All and None tick every row or none; OK returns the ticked
%   datasets' keys in the table's order (1 x n string), Cancel (or closing
%   the window) leaves KEYS as it was with OK false. Keys of KEYS that no
%   row has are not kept (the window says how many). The window's UserData
%   holds its controls (Table, All, None, Ok, Cancel) for the tests.
%
%   See also onPickSessionDatasets, sessionTable.
ok = false;
keys = reshape(string(keys), 1, []);
n = height(T);
unknown = nnz(~ismember(keys, string(T.key)));
pos = [300 300 780 470];
try
    p = getpixelposition(fig);
    pos(1:2) = max(1, p(1:2) + (p(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure('Name', 'Pick the datasets', 'Position', pos, 'WindowStyle', 'modal');
g = uigridlayout(d, [4 1], 'RowHeight', {'fit', '1x', 30, 36}, 'Padding', [12 12 12 12]);
hint = "Tick the datasets this session plot draws. Key is what the Data tab's Key column shows and what the " + ...
    "config keeps.";
if unknown > 0
    hint = hint + sprintf(" %d key(s) of the session plot are not among the scanned datasets and are dropped by OK.", unknown);
end
l = uilabel(g, 'Text', hint, 'WordWrap', 'on');
l.Layout.Row = 1;
Use = ismember(string(T.key), keys);
D = table(Use, string(T.name), string(T.subject), string(T.dateText), string(T.key), ...
    'VariableNames', {'Use', 'Name', 'Subject', 'Date', 'Key'});
tbl = uitable(g, 'Data', D, 'RowName', {}, 'ColumnEditable', [true false false false false], ...
    'ColumnWidth', {45, 'auto', 100, 90, 'auto'}, 'CellEditCallback', @(~, ~) count());
tbl.Layout.Row = 2;
cg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 90, 90}, 'Padding', [0 0 0 0]);
cg.Layout.Row = 3;
cnt = uilabel(cg, 'Text', '');
allB = uibutton(cg, 'Text', 'All', 'ButtonPushedFcn', @(~, ~) tickAll(true), 'Tooltip', 'Tick every dataset.');
noneB = uibutton(cg, 'Text', 'None', 'ButtonPushedFcn', @(~, ~) tickAll(false), 'Tooltip', 'Clear every tick.');
bg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 120, 120}, 'Padding', [0 0 0 0]);
bg.Layout.Row = 4;
uilabel(bg, 'Text', '');
okB = uibutton(bg, 'Text', 'OK', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
d.UserData = struct('Table', tbl, 'All', allB, 'None', noneB, 'Ok', okB, 'Cancel', cancelB);
count();
uiwait(d);
if isvalid(d); delete(d); end

    function count()
        cnt.Text = sprintf('%d of %d datasets ticked', nnz(tbl.Data.Use), n);
    end

    function tickAll(tf)
        X = tbl.Data;
        X.Use(:) = tf;
        tbl.Data = X;
        count();
    end

    function finish(accept)
        if accept
            keys = reshape(string(tbl.Data.Key(tbl.Data.Use)), 1, []);
            ok = true;
        end
        uiresume(d);
    end
end
