function [tick, replot, ok] = applyToFiguresDialog(fig, header, T, current, tick, replot)
%applyToFiguresDialog  Pick the figures (or panels) that take a change, in a modal window over FIG.
%   [TICK, REPLOT, OK] = applyToFiguresDialog(FIG, HEADER, T, CURRENT,
%   TICK, REPLOT): HEADER says the change ("Stack: One row per group,
%   from psth_1 of PSTH units"); T is changeTargets' rows, CURRENT their
%   values now as text (a string per row), TICK the ticks to start from (a logical
%   per row) and REPLOT the Replot box's. A table lists each row: an
%   Apply box, the figure, its panel and the panel's type (when the
%   change is a panel's) and its value now. A row that has the value
%   already is gray, unticked and cannot be ticked. All and None tick
%   every row or none; the count says how many will change. Apply returns
%   the ticks and the box with OK true; Cancel (or closing the window)
%   gives OK false. The window's UserData holds its controls (Table, All,
%   None, Count, Replot, Ok, Cancel) for the tests.
%
%   See also onApplyToFigures, EphysAnalysisConfig.changeTargets.
ok = false;
n = numel(T);
same = reshape([T.same], [], 1);
tick = reshape(logical(tick), [], 1) & ~same;
perPanel = any([T.panel] >= 1);
pos = [300 300 620 460];
try
    q = getpixelposition(fig);
    pos(1:2) = max(1, q(1:2) + (q(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure('Name', 'Apply to figures', 'Position', pos, 'WindowStyle', 'modal');
g = uigridlayout(d, [5 1], 'RowHeight', {'fit', '1x', 30, 22, 36}, 'Padding', [12 12 12 12]);
l = uilabel(g, 'Text', header + newline + "Tick the figures to give it too. The preview is not drawn again unless " + ...
    "Replot is ticked: a figure changed is marked out of date in the list.", 'WordWrap', 'on');
l.Layout.Row = 1;
figs = reshape(string({T.figureId}), [], 1);
values = reshape(string(current), [], 1);
values(same) = values(same) + "  (has it)";
if perPanel
    panels = reshape(string({T.panelId}), [], 1) + "  (" + reshape(string({T.panelType}), [], 1) + ")";
    data = table(tick, figs, panels, values, 'VariableNames', {'Apply', 'Figure', 'Panel', 'Now'});
    widths = {50, '1x', '1x', '1x'};
else
    data = table(tick, figs, values, 'VariableNames', {'Apply', 'Figure', 'Now'});
    widths = {50, '1x', '1x'};
end
tbl = uitable(g, 'Data', data, 'ColumnEditable', [true false(1, width(data) - 1)], 'ColumnWidth', widths, ...
    'RowName', {}, 'CellEditCallback', @(~, e) edited(e));
tbl.Layout.Row = 2;
if any(same)
    addStyle(tbl, uistyle('FontColor', [0.55 0.55 0.55]), 'row', find(same).');
end
cg = uigridlayout(g, [1 3], 'ColumnWidth', {90, 90, '1x'}, 'Padding', [0 0 0 0]);
cg.Layout.Row = 3;
allB = uibutton(cg, 'Text', 'All', 'ButtonPushedFcn', @(~, ~) tickAll(true), 'Tooltip', 'Tick every figure that can change.');
noneB = uibutton(cg, 'Text', 'None', 'ButtonPushedFcn', @(~, ~) tickAll(false), 'Tooltip', 'Clear every tick.');
cnt = uilabel(cg, 'Text', '');
rb = uicheckbox(g, 'Text', 'Replot the changed figures now', 'Value', logical(replot), ...
    'Tooltip', "Draw each changed figure's preview again at once (the figure shown and those kept drawn), one after the other.");
rb.Layout.Row = 4;
og = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 120, 120}, 'Padding', [0 0 0 0]);
og.Layout.Row = 5;
uilabel(og, 'Text', '');
okB = uibutton(og, 'Text', 'Apply', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(og, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
count();
d.UserData = struct('Table', tbl, 'All', allB, 'None', noneB, 'Count', cnt, 'Replot', rb, 'Ok', okB, 'Cancel', cancelB);
uiwait(d);
if isvalid(d); delete(d); end

    function edited(e)
        r = e.Indices(1);
        if same(r)   % it has the value already: nothing to tick
            tbl.Data.Apply(r) = false;
        end
        count();
    end

    function tickAll(tf)
        tbl.Data.Apply = tf & ~same;
        count();
    end

    function count()
        k = nnz(tbl.Data.Apply & ~same);
        cnt.Text = sprintf('%d of %d will change', k, nnz(~same));
    end

    function finish(accept)
        if accept
            tick = reshape(tbl.Data.Apply & ~same, 1, n);
            replot = logical(rb.Value);
            ok = true;
        end
        uiresume(d);
    end
end
