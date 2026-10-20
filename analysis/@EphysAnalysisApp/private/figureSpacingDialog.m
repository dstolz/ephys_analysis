function d = figureSpacingDialog(obj)
%figureSpacingDialog  Set the gaps between the selected figure's panels, in a window of its own (the Arrangement's Spacing... button).
%   D = figureSpacingDialog(OBJ) opens the "Panel spacing" window (Tag
%   figureSpacingDialog; one at a time: opening another closes it) on the
%   grid of the figure selected in the Figures tab (OBJ.SelectedFigure), and
%   returns it. A gap is the clear space between neighboring panels'
%   labels (renderFigure's layout: 0 makes plot areas flush where no label
%   sits between them).
%     Spacing          a preset (loose, compact, tight, none: 24, 12, 6, 0
%                      px each gap) or custom; the rows below are on with
%                      custom (grid.spacing)
%     Units            px, or % of the panels' size: a row gap a share of
%                      the mean row's plot height, a column gap of the mean
%                      column's plot width, so the figure keeps its look
%                      at any size (grid.gapUnits)
%     Between rows, Between columns   one gap each way; a change fills every
%                      gap of the table that way (grid.rowGap, colGap)
%     the table        every gap: between rows i and i + 1, between columns
%                      j and j + 1; an edit sets that gap apart (a value
%                      under 0 or not a number is refused). Kept as lists
%                      (grid.rowGaps, colGaps) only when they differ from
%                      the one gap each way
%   Apply gives the figure those gaps (commitFigureEdit: the editor, the
%   schematic and the preview follow) and keeps the window open, OK does
%   so and closes it, Cancel closes it. Apply goes to the figure the window
%   was opened on (by its id, named in the title), whichever is selected
%   then. The window's UserData holds its controls (FigureId, Spacing,
%   Units, RowGap, ColGap, Table, Apply, Ok, Cancel) for the tests.
%
%   See also buildFiguresTab, renderFigure, EphysAnalysisConfig.GridSpacings.

old = findall(groot, 'Type', 'figure', 'Tag', 'figureSpacingDialog');
delete(old);
d = [];
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("Spacing: select a figure first.");
    return
end
fig = obj.Config.Figures(k);
id = fig.id;
G = fig.grid;
nr = max(1, round(G.rows));
nc = max(1, round(G.cols));
names = EphysAnalysisConfig.GridSpacings;
px = EphysAnalysisConfig.GridSpacingPx;
labels = [names(1:numel(px)) + " (" + px + " px)", "custom"];
labels(names == "none") = "none (flush, 0 px)";

pos = obj.Fig.Position;
d = uifigure('Name', "Panel spacing: " + id, 'Position', [pos(1) + 160, pos(2) + 120, 470, 500], 'Tag', 'figureSpacingDialog');
addlistener(obj.Fig, 'ObjectBeingDestroyed', @(~, ~) delete(d(isvalid(d))));   % it goes with the app
g = uigridlayout(d, [7 1], 'RowHeight', {'fit', 24, 24, 24, '1x', 'fit', 36}, 'Padding', [12 12 12 12], 'RowSpacing', 8);
l = uilabel(g, 'WordWrap', 'on', 'Text', "The clear space between neighboring panels' labels in " + id + ". 0 makes " + ...
    "them touch: stacked time panels whose inner tick labels are dropped are flush.");
l.Layout.Row = 1;
sg = uigridlayout(g, [1 2], 'ColumnWidth', {110, '1x'}, 'Padding', [0 0 0 0]);
sg.Layout.Row = 2;
uilabel(sg, 'Text', 'Spacing:');
D.Spacing = uidropdown(sg, 'Items', labels, 'ItemsData', names, 'Value', pickFrom(G.spacing, names, "tight"), ...
    'ValueChangedFcn', @(~, ~) sync(), 'Tooltip', 'A preset gap between every two panels, or custom gaps (the rows below).');
ug = uigridlayout(g, [1 2], 'ColumnWidth', {110, '1x'}, 'Padding', [0 0 0 0]);
ug.Layout.Row = 3;
uilabel(ug, 'Text', 'Units:');
D.Units = uidropdown(ug, 'Items', ["px" "% of the panels' size"], 'ItemsData', EphysAnalysisConfig.GridGapUnits, ...
    'Value', pickFrom(G.gapUnits, EphysAnalysisConfig.GridGapUnits, "px"), 'ValueChangedFcn', @(~, ~) sync(), ...
    'Tooltip', "px: pixels at the size drawn. %: a row gap is a share of the mean row's plot height, a column gap " + ...
    "of the mean column's plot width, so the figure keeps its look at any size.");
vg = uigridlayout(g, [1 4], 'ColumnWidth', {110, '1x', 'fit', '1x'}, 'Padding', [0 0 0 0]);
vg.Layout.Row = 4;
uilabel(vg, 'Text', 'Between rows:');
D.RowGap = uieditfield(vg, 'numeric', 'Limits', [0 Inf], 'Value', safeGap(G.rowGap), ...
    'ValueChangedFcn', @(~, ~) fill("row"), 'Tooltip', 'The gap between every two rows (vertical): it fills every row gap below.');
uilabel(vg, 'Text', 'columns:');
D.ColGap = uieditfield(vg, 'numeric', 'Limits', [0 Inf], 'Value', safeGap(G.colGap), ...
    'ValueChangedFcn', @(~, ~) fill("col"), 'Tooltip', 'The gap between every two columns (horizontal): it fills every column gap below.');
D.Table = uitable(g, 'ColumnName', {'Between', 'Gap'}, 'RowName', {}, 'ColumnEditable', [false true], ...
    'ColumnWidth', {'1x', 110}, 'CellEditCallback', @(~, e) onEdit(e), ...
    'Tooltip', 'Each gap of the grid: edit one to set it apart from the others.');
D.Table.Layout.Row = 5;
D.Note = uilabel(g, 'WordWrap', 'on', 'FontColor', [0.35 0.35 0.35], 'Text', "");
D.Note.Layout.Row = 6;
bg = uigridlayout(g, [1 4], 'ColumnWidth', {'1x', 100, 100, 100}, 'Padding', [0 0 0 0]);
bg.Layout.Row = 7;
uilabel(bg, 'Text', '');
D.Apply = uibutton(bg, 'Text', 'Apply', 'ButtonPushedFcn', @(~, ~) apply(false), 'Tooltip', 'Give the figure these gaps; the preview follows.');
D.Ok = uibutton(bg, 'Text', 'OK', 'ButtonPushedFcn', @(~, ~) apply(true), 'Tooltip', 'Apply, and close the window.');
D.Cancel = uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) delete(d), 'Tooltip', 'Close the window; what was applied stays.');
styleButton([D.Apply D.Cancel]);
styleButton(D.Apply, 'primary');
styleButton(D.Ok, 'confirm');
D.FigureId = id;
d.UserData = D;
rows = gapList(G.rowGaps, D.RowGap.Value, nr - 1);   % the custom gaps the table holds (kept while a preset shows)
cols = gapList(G.colGaps, D.ColGap.Value, nc - 1);
sync();

    function sync()
        %sync  The table's gaps, and the custom rows on with custom.
        custom = string(D.Spacing.Value) == "custom";
        set([D.Units D.RowGap D.ColGap], 'Enable', matlab.lang.OnOffSwitchState(custom));
        D.Table.ColumnEditable = [false custom];
        what = strings(0, 1);
        v = zeros(0, 1);
        for i = 1:nr - 1; what(end+1, 1) = sprintf("rows %d and %d", i, i + 1); end %#ok<AGROW>
        for j = 1:nc - 1; what(end+1, 1) = sprintf("columns %d and %d", j, j + 1); end %#ok<AGROW>
        if custom
            v = [rows cols].';
            unit = string(D.Units.Value);
        else
            v = repmat(px(names == string(D.Spacing.Value)), numel(what), 1);
            unit = "px";
        end
        D.Table.Data = table(what, v, 'VariableNames', {'Between', 'Gap'});
        D.Table.ColumnName = {'Between', char("Gap (" + unit + ")")};
        if isempty(what)
            D.Note.Text = "One panel's place: there is no gap between panels yet.";
        elseif custom && unit == "%"
            D.Note.Text = "A row gap is a share of the mean row's plot height, a column gap of the mean column's plot width.";
        elseif custom
            D.Note.Text = "Pixels at the size drawn (an export: its own size).";
        else
            D.Note.Text = "A preset: every gap the same. Pick custom to set the gaps yourself.";
        end
    end

    function fill(way)
        %fill  One gap each way: every gap that way takes it.
        if way == "row"
            rows(:) = D.RowGap.Value;
        else
            cols(:) = D.ColGap.Value;
        end
        sync();
    end

    function onEdit(e)
        %onEdit  A gap of its own: a number of at least 0, else refused.
        i = e.Indices(1);
        x = e.NewData;
        if ischar(x) || isstring(x); x = str2double(x); end
        if ~(isscalar(x) && isfinite(x) && x >= 0)
            sync();   % back to what it was
            return
        end
        if i <= nr - 1
            rows(i) = x;
        else
            cols(i - (nr - 1)) = x;
        end
        sync();
    end

    function apply(closing)
        %apply  The figure the window was opened on takes the gaps; the editor and the preview follow.
        if ~isvalid(obj) || ~isvalid(obj.Fig); delete(d); return; end
        cfg = obj.gatherConfig();
        id = followedFigureId(obj, id);   % renamed since the window opened (an automatic id that followed an edit)
        q = cfg.figureIndex(id);
        if q < 1
            obj.setStatus("Spacing: there is no figure " + id + " any more.");
            return
        end
        H = cfg.Figures(q).grid;
        H.spacing = string(D.Spacing.Value);
        if H.spacing == "custom"
            H.gapUnits = string(D.Units.Value);
            H.rowGap = D.RowGap.Value;
            H.colGap = D.ColGap.Value;
            H.rowGaps = apart(rows, H.rowGap);
            H.colGaps = apart(cols, H.colGap);
        end
        cfg.Figures(q).grid = H;
        msg = id + ": spacing " + H.spacing;
        if H.spacing == "custom"; msg = msg + " (" + gapWords(rows, H.rowGap, "row") + ", " + gapWords(cols, H.colGap, "column") + " " + H.gapUnits + ")"; end
        commitFigureEdit(obj, cfg, msg + ".");
        if closing; delete(d); end
    end
end


function v = pickFrom(v, allowed, default)
v = string(v);
if ~ismember(v, allowed); v = default; end
end


function v = safeGap(v)
%safeGap  A gap the field can show: a number of at least 0, else 6.
if ~(isscalar(v) && isfinite(v) && v >= 0); v = 6; end
end


function g = gapList(list, one, n)
%gapList  N gaps: LIST when it has N, else ONE each (a row).
g = reshape(double(list), 1, []);
if numel(g) ~= n; g = repmat(one, 1, n); end
end


function g = apart(g, one)
%apart  The gaps as a list only when they differ from the one gap ([] = each that one).
if all(g == one); g = []; end
end


function s = gapWords(g, one, what)
%gapWords  "6 between rows" or "rows 6, 12" for the status line.
if isempty(g) || all(g == one)
    s = one + " between " + what + "s";
else
    s = what + " gaps " + strjoin(string(g), ", ");
end
end
