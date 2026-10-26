function [tick, replot, ok] = applyToFiguresDialog(fig, header, T, current, tick, replot, titles, kinds)
%applyToFiguresDialog  Pick the figures (or panels) that take a change, in a modal window over FIG.
%   [TICK, REPLOT, OK] = applyToFiguresDialog(FIG, HEADER, T, CURRENT,
%   TICK, REPLOT, TITLES, KINDS): HEADER says the change ("Stack: One row per group,
%   from psth_1 of PSTH units"); T is changeTargets' rows, CURRENT their
%   values now as text (a string per row), TICK the ticks to start from (a logical
%   per row) and REPLOT the Replot box's; TITLES (a string per row) is
%   each row's figure title and KINDS (a string per row) its figure's
%   type, the panel types it holds ("psth + raster"). A table lists each
%   row: an Apply box, the figure, its panel and the panel's type (when
%   the change is a panel's) and its value now; each column sorts by a
%   click on its header. Above it, filters narrow the rows shown: a text
%   field (live; the figure's id or title, the panel's id, type or value
%   now), the panel's type, the figure's type and Show (all rows, those
%   that will change, those that have the value already). A row that
%   has the value already is gray, unticked and cannot be ticked. All and
%   None tick every row shown or none of them; the rows a filter hides
%   keep their ticks, as sorting leaves them; the count says how many of
%   all will change. Apply returns the ticks and the box with OK true;
%   Cancel (or closing the window) gives OK false. The window's UserData
%   holds its controls (Table, Text, PanelType, FigureType, Show, All,
%   None, Count, Replot, Ok, Cancel) for the tests.
%
%   See also onApplyToFigures, EphysAnalysisConfig.changeTargets.
arguments
    fig
    header
    T
    current
    tick
    replot
    titles (:,1) string = strings(numel(T), 1)
    kinds (:,1) string = strings(numel(T), 1)
end
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
g = uigridlayout(d, [6 1], 'RowHeight', {'fit', 28, '1x', 30, 22, 36}, 'Padding', [12 12 12 12]);
l = uilabel(g, 'Text', header + newline + "Tick the figures to give it too. The preview is not drawn again unless " + ...
    "Replot is ticked: a figure changed is marked out of date in the list.", 'WordWrap', 'on');
l.Layout.Row = 1;
figs = reshape(string({T.figureId}), [], 1);
ptypes = reshape(string({T.panelType}), [], 1);
values = reshape(string(current), [], 1);
values(same) = values(same) + "  (has it)";
if perPanel
    panels = reshape(string({T.panelId}), [], 1) + "  (" + ptypes + ")";
    full = table(figs, panels, values, 'VariableNames', {'Figure', 'Panel', 'Now'});
    widths = {50, '1x', '1x', '1x'};
else
    full = table(figs, values, 'VariableNames', {'Figure', 'Now'});
    widths = {50, '1x', '1x'};
end
searchable = lower(figs + " " + titles + " " + ptypes + " " + reshape(string({T.panelId}), [], 1) + " " + values);
vis = (1:n).';   % the rows shown, as rows of T (the table's Data is these, in this order; sorting only reorders its display)
fg = uigridlayout(g, [1 4], 'ColumnWidth', {'1x', 130, 130, 130}, 'Padding', [0 0 0 0], 'ColumnSpacing', 6);
fg.Layout.Row = 2;
filt = uieditfield(fg, 'text', 'Placeholder', 'Filter: figure id or title, panel, value...', ...
    'ValueChangingFcn', @(~, e) refilter(e.Value), 'ValueChangedFcn', @(s, ~) refilter(s.Value), ...
    'Tooltip', 'Show only the rows with this text in the figure id or title, the panel, its type or its value now.');
panelDD = dropFor(fg, 'All panel types', unique(ptypes(ptypes ~= ""), 'stable'), 'Show only the panels of this type.');
panelDD.Enable = matlab.lang.OnOffSwitchState(perPanel);
figDD = dropFor(fg, 'All figure types', unique(kinds(kinds ~= ""), 'stable'), 'Show only the figures of this type (the panel types they hold).');
showDD = uidropdown(fg, 'Items', {'Show all', 'Will change', 'Has it already'}, 'ItemsData', {'all', 'change', 'has'}, ...
    'Value', 'all', 'ValueChangedFcn', @(~, ~) refilter(), 'Tooltip', 'Show every row, those that will change, or those that have the value already.');
tbl = uitable(g, 'Data', [table(tick, 'VariableNames', {'Apply'}) full], 'ColumnEditable', [true false(1, width(full))], ...
    'ColumnWidth', widths, 'RowName', {}, 'ColumnSortable', true, 'CellEditCallback', @(~, e) edited(e));
tbl.Layout.Row = 3;
cg = uigridlayout(g, [1 3], 'ColumnWidth', {90, 90, '1x'}, 'Padding', [0 0 0 0]);
cg.Layout.Row = 4;
allB = uibutton(cg, 'Text', 'All', 'ButtonPushedFcn', @(~, ~) tickAll(true), 'Tooltip', 'Tick every row shown that can change.');
noneB = uibutton(cg, 'Text', 'None', 'ButtonPushedFcn', @(~, ~) tickAll(false), 'Tooltip', 'Clear the tick of every row shown.');
cnt = uilabel(cg, 'Text', '');
rb = uicheckbox(g, 'Text', 'Replot the changed figures now', 'Value', logical(replot), ...
    'Tooltip', "Draw each changed figure's preview again at once (the figure shown and those kept drawn), one after the other.");
rb.Layout.Row = 5;
og = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 120, 120}, 'Padding', [0 0 0 0]);
og.Layout.Row = 6;
uilabel(og, 'Text', '');
okB = uibutton(og, 'Text', 'Apply', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(og, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
refilter();
d.UserData = struct('Table', tbl, 'Text', filt, 'PanelType', panelDD, 'FigureType', figDD, 'Show', showDD, 'All', allB, 'None', noneB, 'Count', cnt, 'Replot', rb, 'Ok', okB, 'Cancel', cancelB);
uiwait(d);
if isvalid(d); delete(d); end

    function dd = dropFor(parent, all, items, tip)
        dd = uidropdown(parent, 'Items', [{all} cellstr(items(:)).'], 'ItemsData', [{''} cellstr(items(:)).'], 'Value', '', ...
            'ValueChangedFcn', @(~, ~) refilter(), 'Tooltip', tip);
    end

    function pull()
        % the ticks of the rows shown, as the table has them (a test may set its Data), into TICK
        if height(tbl.Data) == numel(vis)
            tick(vis) = tbl.Data.Apply & ~same(vis);
        end
    end

    function refilter(text)
        % show the rows that pass every filter; those hidden keep their ticks (TICK is the whole)
        pull();
        if nargin < 1; text = filt.Value; end
        keep = true(n, 1);
        for w = split(lower(strtrim(string(text))), whitespacePattern).'
            keep = keep & contains(searchable, w);
        end
        if panelDD.Value ~= ""; keep = keep & ptypes == string(panelDD.Value); end
        if figDD.Value ~= ""; keep = keep & kinds == string(figDD.Value); end
        switch showDD.Value
            case 'change', keep = keep & ~same;
            case 'has', keep = keep & same;
        end
        vis = find(keep);
        tbl.Data = [table(tick(vis), 'VariableNames', {'Apply'}) full(vis, :)];
        removeStyle(tbl);
        if any(same(vis))
            addStyle(tbl, uistyle('FontColor', [0.55 0.55 0.55]), 'row', find(same(vis)).');
        end
        count();
    end

    function edited(e)
        r = e.Indices(1);   % Indices are rows of Data (the rows shown), whatever the sort; DisplayIndices are not
        if same(vis(r))   % it has the value already: nothing to tick
            tbl.Data.Apply(r) = false;
        end
        pull();
        count();
    end

    function tickAll(tf)
        tick(vis) = tf & ~same(vis);
        tbl.Data.Apply = tick(vis);
        count();
    end

    function count()
        pull();
        cnt.Text = sprintf('%d of %d will change', nnz(tick & ~same), nnz(~same));
    end

    function finish(accept)
        if accept
            pull();
            tick = reshape(tick & ~same, 1, n);
            replot = logical(rb.Value);
            ok = true;
        end
        uiresume(d);
    end
end
