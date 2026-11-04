function [T, ok] = editUnitMapping(fig, C, keys, file, nKept)
%editUnitMapping  Edit a unit mapping (a row per cell, a column per dataset) in a modal window over FIG.
%   [T, OK] = editUnitMapping(FIG, C, KEYS, FILE, NKEPT) shows the cell
%   array of text C (n x (1 + numel(KEYS)): the cell's name, then its unit
%   id(s) under each dataset key) in an editable table with the keys as
%   column heads. Add row appends an empty row, Remove row drops the rows
%   of the selected cells, Save returns the table (unitMappingTable: a
%   row without a name or two with the same name is said and the window
%   stays open) with OK true; Cancel or closing returns OK false. FILE
%   (for the title) and NKEPT (the columns of other datasets the file keeps)
%   are only shown. The window's UserData holds its controls (Table, Add,
%   Remove, Save, Cancel) for the tests.
%
%   See also onEditUnitMapping, unitMappingTable.
ok = false;
T = [];
keys = reshape(string(keys), 1, []);
m = numel(keys);
pos = [260 260 max(620, min(1200, 200 + 170 * m)) 480];
try
    p = getpixelposition(fig);
    pos(1:2) = max(1, p(1:2) + (p(3:4) - pos(3:4)) / 2);
catch
end
[~, base, ext] = fileparts(file);
d = uifigure('Name', char("Unit mapping: " + base + ext), 'Position', pos, 'WindowStyle', 'modal');
g = uigridlayout(d, [4 1], 'RowHeight', {'fit', '1x', 30, 36}, 'Padding', [12 12 12 12]);
hint = "A row per cell: its name, then under each dataset the unit id (the PSTH's unit number) the cell has there. " + ...
    """3 7"" is two units, averaged. Leave a field empty where the cell was not found. Saved to " + file + ".";
if nKept > 0
    hint = hint + sprintf(" The file's %d column(s) of other datasets are kept for the cells that keep their names.", nKept);
end
l = uilabel(g, 'Text', hint, 'WordWrap', 'on');
l.Layout.Row = 1;
tbl = uitable(g, 'Data', C, 'ColumnName', cellstr(["cell" keys]), 'RowName', {}, 'ColumnEditable', true, ...
    'ColumnFormat', repmat({'char'}, 1, 1 + m), 'ColumnWidth', [{140} repmat({'auto'}, 1, m)], ...
    'CellSelectionCallback', @(~, e) onSelect(e));
tbl.Layout.Row = 2;
tg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 120, 120}, 'Padding', [0 0 0 0]);
tg.Layout.Row = 3;
info = uilabel(tg, 'Text', '');
addB = uibutton(tg, 'Text', 'Add row', 'ButtonPushedFcn', @(~, ~) onAdd(), 'Tooltip', 'Add an empty cell at the end.');
rmB = uibutton(tg, 'Text', 'Remove row', 'ButtonPushedFcn', @(~, ~) onRemove(), ...
    'Tooltip', 'Remove the rows of the selected fields.');
bg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 120, 120}, 'Padding', [0 0 0 0]);
bg.Layout.Row = 4;
uilabel(bg, 'Text', '');
saveB = uibutton(bg, 'Text', 'Save', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(saveB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
d.UserData = struct('Table', tbl, 'Add', addB, 'Remove', rmB, 'Save', saveB, 'Cancel', cancelB);
rows = [];
uiwait(d);
if isvalid(d); delete(d); end

    function onSelect(e)
        rows = unique(e.Indices(:, 1));
    end

    function onAdd()
        X = tbl.Data;
        X(end + 1, :) = [{sprintf('cell%d', size(X, 1) + 1)} repmat({''}, 1, m)];
        tbl.Data = X;
        rows = [];
        info.Text = '';
    end

    function onRemove()
        X = tbl.Data;
        rows(rows > size(X, 1)) = [];
        if isempty(rows)
            info.Text = 'Select a field of the row to remove first.';
            return
        end
        X(rows, :) = [];
        tbl.Data = X;
        info.Text = sprintf('%d row(s) removed.', numel(rows));
        rows = [];
    end

    function finish(accept)
        if accept
            try
                T = unitMappingTable(tbl.Data, keys);
            catch ME
                uialert(d, ME.message, 'Unit mapping');
                return
            end
            ok = true;
        end
        uiresume(d);
    end
end
