function [pick, ok] = applyTemplateDialog(fig, t, F, k)
%applyTemplateDialog  Pick the figures a template is applied to, and its settings, in a modal window over FIG.
%   [PICK, OK] = applyTemplateDialog(FIG, T, F, K): T is the template
%   (FigureTemplate), F the config's figures and K the figure shown. The
%   window says the template (its name, description and shape:
%   FigureTemplate.summary) and lists:
%   - Apply to: a table of the figures, each with an Apply box (the
%     figure shown ticked) and its shape; All and None; the count
%   - Settings: a check box per part of a figure's settings
%     (figureSettingParts), all ticked: untick a part to keep the
%     figures' own
%   - Also add it as a new figure (ticked when there is no figure)
%   Apply returns PICK (Targets: the indices of the figures ticked, New:
%   the box, Parts: the parts ticked) with OK true; it refuses nothing
%   ticked to apply to, and no part ticked for the figures ticked. Cancel
%   (or closing the window) gives OK false. The window's UserData holds
%   its controls (Table, All, None, Count, Parts: a check box per part
%   by name, New, Ok, Cancel) for the tests.
%
%   See also onApplyTemplate, FigureTemplate, copyFigureSettings.
ok = false;
pick = struct('Targets', zeros(1, 0), 'New', false, 'Parts', strings(1, 0));
n = numel(F);
P = figureSettingParts();
pos = [300 300 700 480];
try
    q = getpixelposition(fig);
    pos(1:2) = max(1, q(1:2) + (q(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure('Name', 'Apply figure template', 'Position', pos, 'WindowStyle', 'modal');
g = uigridlayout(d, [5 2], 'RowHeight', {'fit', 22, '1x', 30, 36}, 'ColumnWidth', {'1x', 240}, 'Padding', [12 12 12 12]);
head = t.name;
if t.description ~= ""; head = head + ": " + t.description; end
head = head + newline + FigureTemplate.summary(t.figure) + newline + "Its settings are copied into the figures ticked, " + ...
    "once: a later change of the template reaches them only when you apply it again. Each keeps its id, title and enabled.";
if ~isempty(t.notes); head = head + newline + "Reading it: " + strjoin(t.notes, "; ") + "."; end
l = uilabel(g, 'Text', head, 'WordWrap', 'on');
l.Layout.Row = 1; l.Layout.Column = [1 2];
l = uilabel(g, 'Text', 'Apply to', 'FontWeight', 'bold');
l.Layout.Row = 2; l.Layout.Column = 1;
l = uilabel(g, 'Text', 'Settings', 'FontWeight', 'bold');
l.Layout.Row = 2; l.Layout.Column = 2;
ids = strings(n, 1);
shapes = strings(n, 1);
for i = 1:n
    ids(i) = F(i).id;
    if i == k; ids(i) = ids(i) + "  (shown)"; end
    shapes(i) = FigureTemplate.summary(F(i));
end
data = table(reshape((1:n) == k, [], 1), ids, shapes, 'VariableNames', {'Apply', 'Figure', 'Now'});
tbl = uitable(g, 'Data', data, 'ColumnEditable', [true false false], 'ColumnWidth', {50, '1x', '2x'}, ...
    'RowName', {}, 'CellEditCallback', @(~, ~) count());
tbl.Layout.Row = 3; tbl.Layout.Column = 1;
pg = uigridlayout(g, [height(P) + 1 1], 'RowHeight', [repmat({22}, 1, height(P)) {'1x'}], 'Padding', [0 0 0 0], 'RowSpacing', 4);
pg.Layout.Row = 3; pg.Layout.Column = 2;
parts = struct();
for i = 1:height(P)
    parts.(P.Part(i)) = uicheckbox(pg, 'Text', P.Label(i), 'Value', true, 'Tooltip', P.Description(i), ...
        'ValueChangedFcn', @(~, ~) count());
end
cg = uigridlayout(g, [1 3], 'ColumnWidth', {90, 90, '1x'}, 'Padding', [0 0 0 0]);
cg.Layout.Row = 4; cg.Layout.Column = 1;
allB = uibutton(cg, 'Text', 'All', 'ButtonPushedFcn', @(~, ~) tickAll(true), 'Tooltip', 'Tick every figure.');
noneB = uibutton(cg, 'Text', 'None', 'ButtonPushedFcn', @(~, ~) tickAll(false), 'Tooltip', 'Clear every tick.');
cnt = uilabel(cg, 'Text', '');
newB = uicheckbox(g, 'Text', 'Also add it as a new figure', 'Value', n == 0, 'ValueChangedFcn', @(~, ~) count(), ...
    'Tooltip', 'Add the whole template as a figure of its own (an automatic id), and show it.');
newB.Layout.Row = 4; newB.Layout.Column = 2;
og = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 120, 120}, 'Padding', [0 0 0 0]);
og.Layout.Row = 5; og.Layout.Column = [1 2];
uilabel(og, 'Text', '');
okB = uibutton(og, 'Text', 'Apply', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(og, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
count();
d.UserData = struct('Table', tbl, 'All', allB, 'None', noneB, 'Count', cnt, 'Parts', parts, 'New', newB, 'Ok', okB, 'Cancel', cancelB);
uiwait(d);
if isvalid(d); delete(d); end

    function tickAll(tf)
        tbl.Data.Apply(:) = tf;
        count();
    end

    function names = ticked()
        names = strings(1, 0);
        for p = reshape(P.Part, 1, [])
            if parts.(p).Value; names(end+1) = p; end %#ok<AGROW>
        end
    end

    function count()
        m = nnz(tbl.Data.Apply);
        txt = sprintf('%d of %d figures', m, n);
        if newB.Value; txt = txt + " and a new one"; end
        cnt.Text = txt;
    end

    function finish(accept)
        if accept
            targets = reshape(find(tbl.Data.Apply), 1, []);
            names = ticked();
            if isempty(targets) && ~newB.Value
                uialert(d, 'Tick the figures to apply the template to, or Also add it as a new figure.', 'Apply figure template');
                return
            end
            if ~isempty(targets) && isempty(names)
                uialert(d, 'Tick the settings to copy into the figures.', 'Apply figure template');
                return
            end
            pick = struct('Targets', targets, 'New', logical(newB.Value), 'Parts', names);
            ok = true;
        end
        uiresume(d);
    end
end
