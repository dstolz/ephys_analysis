function [value, ok] = promptText(fig, titleText, prompt, default)
%promptText  Ask for one line of text in a small modal window over FIG.
%   [VALUE, OK] = ChannelMapperApp.promptText(FIG, TITLE, PROMPT, DEFAULT);
%   OK is false when it was cancelled or closed.
arguments
    fig
    titleText (1,1) string
    prompt (1,1) string
    default (1,1) string = ""
end
value = default;
ok = false;
pos = [300 300 460 150];
try
    p = fig.Position;
    pos(1:2) = p(1:2) + [p(3) - pos(3), p(4) - pos(4)] / 2;
catch
end
d = uifigure('Name', char(titleText), 'Position', pos, 'Resize', 'off');
try
    d.WindowStyle = 'modal';
catch
end
g = uigridlayout(d, [3 2]);
g.RowHeight = {'fit', 'fit', 30};
g.ColumnWidth = {'1x', 'fit'};
l = uilabel(g, 'Text', char(prompt), 'WordWrap', 'on');
l.Layout.Column = [1 2];
ed = uieditfield(g, 'text', 'Value', char(default));
ed.Layout.Column = [1 2];
uilabel(g, 'Text', '');
bg = uigridlayout(g, [1 2]);
bg.Padding = [0 0 0 0];
okB = uibutton(bg, 'Text', 'OK', 'ButtonPushedFcn', @(~, ~) finish(true));
uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
focus(ed);
uiwait(d);
if isvalid(d)
    delete(d);
end
try
    figure(fig);
catch
end

    function finish(accept)
        ok = accept;
        if accept
            value = string(ed.Value);
        end
        uiresume(d);
    end
end
