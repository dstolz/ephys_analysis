function [from, parts, ok] = pickFigureSettings(fig, F, target)
%pickFigureSettings  Pick a figure and the parts of its settings to copy onto figure TARGET, in a small modal window over FIG.
%   [FROM, PARTS, OK] = pickFigureSettings(FIG, F, TARGET) offers every
%   figure of F (Config.Figures) but TARGET (an index into F) in a From
%   drop-down, by id and panel count, and a box per part of a figure's
%   settings (figureSettingParts), each ticked, its tooltip the part's
%   description. All and None tick every box or none; Copy returns FROM
%   (an index into F) and the ticked PARTS (a string row) with OK true;
%   Cancel (or closing the window) gives OK false. The window's UserData
%   holds its controls (From, Boxes: a struct by part, All, None, Ok,
%   Cancel) for the tests.
%
%   See also onCopyFigureSettings, copyFigureSettings, figureSettingParts, pickPlotSettings.
ok = false;
parts = string.empty(1, 0);
others = setdiff(1:numel(F), target, 'stable');
from = others(1);
names = arrayfun(@(k) F(k).id + "  (" + numel(F(k).panels) + " panels)", others);
T = figureSettingParts();
n = height(T);
pos = [300 300 480 340];
try
    q = getpixelposition(fig);
    pos(1:2) = max(1, q(1:2) + (q(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure('Name', 'Copy figure settings', 'Position', pos, 'WindowStyle', 'modal');
g = uigridlayout(d, [5 1], 'RowHeight', {'fit', 30, '1x', 30, 36}, 'Padding', [12 12 12 12]);
l = uilabel(g, 'Text', "Copy the parts ticked from the figure picked onto " + F(target).id + ". The figure keeps its id, " + ...
    "title, enabled and every part left unticked.", 'WordWrap', 'on');
l.Layout.Row = 1;
fg = uigridlayout(g, [1 2], 'ColumnWidth', {'fit', '1x'}, 'Padding', [0 0 0 0]);
fg.Layout.Row = 2;
uilabel(fg, 'Text', 'From:');
fromDD = uidropdown(fg, 'Items', names, 'ItemsData', others, 'Value', from, 'Tooltip', 'The figure whose settings are copied.');
nr = ceil(n / 2);
bg = uigridlayout(g, [nr 2], 'RowHeight', repmat({22}, 1, nr), 'Padding', [0 0 0 0], 'RowSpacing', 4);
bg.Layout.Row = 3;
boxes = struct();
for i = 1:n
    b = uicheckbox(bg, 'Text', T.Label(i), 'Value', true, 'Tooltip', T.Description(i), 'ValueChangedFcn', @(~, ~) count());
    b.Layout.Row = mod(i - 1, nr) + 1;
    b.Layout.Column = floor((i - 1) / nr) + 1;
    boxes.(T.Part(i)) = b;
end
cg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 90, 90}, 'Padding', [0 0 0 0]);
cg.Layout.Row = 4;
cnt = uilabel(cg, 'Text', '');
allB = uibutton(cg, 'Text', 'All', 'ButtonPushedFcn', @(~, ~) tickAll(true), 'Tooltip', 'Tick every part.');
noneB = uibutton(cg, 'Text', 'None', 'ButtonPushedFcn', @(~, ~) tickAll(false), 'Tooltip', 'Clear every tick.');
og = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 120, 120}, 'Padding', [0 0 0 0]);
og.Layout.Row = 5;
uilabel(og, 'Text', '');
okB = uibutton(og, 'Text', 'Copy', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(og, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
count();
d.UserData = struct('From', fromDD, 'Boxes', boxes, 'All', allB, 'None', noneB, 'Ok', okB, 'Cancel', cancelB);
uiwait(d);
if isvalid(d); delete(d); end

    function tickAll(tf)
        for j = 1:n
            boxes.(T.Part(j)).Value = tf;
        end
        count();
    end

    function ticked = tickedParts()
        on = arrayfun(@(j) boxes.(T.Part(j)).Value, 1:n);
        ticked = T.Part(on).';
    end

    function count()
        k = numel(tickedParts());
        cnt.Text = sprintf('%d part(s) to copy', k);
        okB.Enable = matlab.lang.OnOffSwitchState(k > 0);
    end

    function finish(accept)
        if accept
            from = fromDD.Value;
            parts = tickedParts();
            ok = true;
        end
        uiresume(d);
    end
end
