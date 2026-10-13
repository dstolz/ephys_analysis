function [from, parts, ok] = pickPlotSettings(fig, P, targets)
%pickPlotSettings  Pick a plot and the parts of its settings to copy onto plots TARGETS, in a small modal window over FIG.
%   [FROM, PARTS, OK] = pickPlotSettings(FIG, P, TARGETS) offers every plot
%   of P (Config.Plots) but the TARGETS (indices into P) in a From
%   drop-down, by id and plot type, and a box per part of a plot's
%   settings (plotSettingParts: the plot editor's sections and the
%   remembered looks). A part shows only when the plot picked and every
%   target share it; the others are off, their tooltip saying why. The
%   boxes start ticked and keep their ticks while another plot is picked.
%   All and None tick every box shown or none; Copy returns FROM (an index
%   into P) and the ticked PARTS (a string row) with OK true; Cancel (or
%   closing the window) gives OK false. The window's UserData holds its
%   controls (From, Boxes: a struct by part, All, None, Ok, Cancel) for
%   the tests.
%
%   See also onCopyPlotSettings, copyPlotSettings, plotSettingParts.
ok = false;
parts = string.empty(1, 0);
others = setdiff(1:numel(P), targets, 'stable');
from = others(1);
K = EphysAnalysisConfig.plotKinds();
labelOf = @(kd) K.Label(K.Kind == kd);
names = arrayfun(@(k) P(k).id + "  (" + labelOf(P(k).kind) + ")", others);
T0 = plotSettingParts(P(targets(1)).kind);
n = height(T0);
pos = [300 300 520 420];
try
    q = getpixelposition(fig);
    pos(1:2) = max(1, q(1:2) + (q(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure('Name', 'Copy plot settings', 'Position', pos, 'WindowStyle', 'modal');
g = uigridlayout(d, [5 1], 'RowHeight', {'fit', 30, '1x', 30, 36}, 'Padding', [12 12 12 12]);
if isscalar(targets)
    onto = sprintf("%s (%s)", P(targets).id, labelOf(P(targets).kind));
else
    onto = sprintf("the %d plots selected", numel(targets));
end
l = uilabel(g, 'Text', "Copy the parts ticked from the plot picked onto " + onto + ". The plot keeps its id, type, title " + ...
    "and every part left unticked. A part the two plot types do not share cannot be ticked; its tooltip says why.", ...
    'WordWrap', 'on');
l.Layout.Row = 1;
fg = uigridlayout(g, [1 2], 'ColumnWidth', {'fit', '1x'}, 'Padding', [0 0 0 0]);
fg.Layout.Row = 2;
uilabel(fg, 'Text', 'From:');
fromDD = uidropdown(fg, 'Items', names, 'ItemsData', others, 'Value', from, 'ValueChangedFcn', @(~, ~) offer(), ...
    'Tooltip', 'The plot whose settings are copied.');
bg = uigridlayout(g, [ceil(n / 2) 2], 'RowHeight', repmat({22}, 1, ceil(n / 2)), 'Padding', [0 0 0 0], 'RowSpacing', 4);
bg.Layout.Row = 3;
boxes = struct();
wanted = true(n, 1);   % the user's ticks, kept while a part is off
for i = 1:n
    b = uicheckbox(bg, 'Text', T0.Label(i), 'Value', true, 'ValueChangedFcn', @(src, ~) remember(i, src.Value));
    b.Layout.Row = mod(i - 1, ceil(n / 2)) + 1;
    b.Layout.Column = floor((i - 1) / ceil(n / 2)) + 1;
    boxes.(T0.Part(i)) = b;
end
cg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 90, 90}, 'Padding', [0 0 0 0]);
cg.Layout.Row = 4;
cnt = uilabel(cg, 'Text', '');
allB = uibutton(cg, 'Text', 'All', 'ButtonPushedFcn', @(~, ~) tickAll(true), 'Tooltip', 'Tick every part that can be copied.');
noneB = uibutton(cg, 'Text', 'None', 'ButtonPushedFcn', @(~, ~) tickAll(false), 'Tooltip', 'Clear every tick.');
og = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 120, 120}, 'Padding', [0 0 0 0]);
og.Layout.Row = 5;
uilabel(og, 'Text', '');
okB = uibutton(og, 'Text', 'Copy', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(og, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
offer();
d.UserData = struct('From', fromDD, 'Boxes', boxes, 'All', allB, 'None', noneB, 'Ok', okB, 'Cancel', cancelB);
uiwait(d);
if isvalid(d); delete(d); end

    function offer()
        %offer  The boxes of the plot picked: on where it and every target share the part.
        src = P(fromDD.Value);
        shared = true(n, 1);
        why = strings(n, 1);
        for t = targets
            T = plotSettingParts(P(t).kind, src.kind);
            gone = shared & ~T.Shared;
            why(gone) = T.Reason(gone);
            shared = shared & T.Shared;
        end
        for j = 1:n
            b = boxes.(T0.Part(j));
            b.Enable = matlab.lang.OnOffSwitchState(shared(j));
            b.Value = shared(j) && wanted(j);
            if shared(j)
                b.Tooltip = "";
            else
                b.Tooltip = "Not copied: " + why(j) + ".";
            end
        end
        count();
    end

    function remember(j, tf)
        wanted(j) = tf;
        count();
    end

    function tickAll(tf)
        wanted(:) = tf;
        offer();
    end

    function ticked = tickedParts()
        on = arrayfun(@(j) boxes.(T0.Part(j)).Value, 1:n);
        ticked = T0.Part(on).';
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
