function [txt, ok] = askLabelText(fig, axisName, panel, txt)
%askLabelText  Ask for a panel's own x or y label in a small modal window over FIG.
%   [TXT, OK] = askLabelText(FIG, AXISNAME, PANEL, TXT): AXISNAME "X" or
%   "Y", PANEL the panel's id, TXT the label shown now (the field starts
%   with it). A blank TXT is the automatic label (the panel type's). OK is
%   false when it was canceled or closed. PlotAesthetics' "Edit label
%   text...".

ok = false;
pos = [300 300 460 160];
try
    p = getpixelposition(fig);
    pos(1:2) = max(1, p(1:2) + (p(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure('Name', char(axisName + " label"), 'Position', pos, 'Resize', 'off', 'WindowStyle', 'modal');
g = uigridlayout(d, [3 1], 'RowHeight', {'fit', 26, 32});
uilabel(g, 'WordWrap', 'on', 'Text', char("The " + lower(axisName) + " axis label of panel " + panel + ...
    ". Leave it blank for the automatic label."));
ed = uieditfield(g, 'text', 'Value', char(txt), 'Placeholder', 'automatic');
bg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 100, 100}, 'Padding', 0);
uilabel(bg, 'Text', '');
okB = uibutton(bg, 'Text', 'OK', 'ButtonPushedFcn', @(~, ~) finish(true));
uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
focus(ed);
uiwait(d);
if isvalid(d); delete(d); end

    function finish(accept)
        if accept
            txt = strtrim(string(ed.Value));
            ok = true;
        end
        uiresume(d);
    end
end
