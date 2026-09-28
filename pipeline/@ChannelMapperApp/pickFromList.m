function [k, ok] = pickFromList(fig, titleText, items, prompt)
%pickFromList  Choose one of ITEMS in a small modal window over FIG.
%   [K, OK] = ChannelMapperApp.pickFromList(FIG, TITLE, ITEMS, PROMPT)
%   returns the index of the chosen item; OK is false when cancelled.
arguments
    fig
    titleText (1,1) string
    items (1,:) string
    prompt (1,1) string = ""
end
k = 0;
ok = false;
if isempty(items)
    return
end
pos = [300 300 560 380];
try
    p = fig.Position;
    pos(1:2) = p(1:2) + [p(3) - pos(3), p(4) - pos(4)] / 2;
catch
end
d = uifigure('Name', char(titleText), 'Position', pos);
try
    d.WindowStyle = 'modal';
catch
end
g = uigridlayout(d, [3 1]);
g.RowHeight = {'fit', '1x', 30};
uilabel(g, 'Text', char(prompt), 'WordWrap', 'on');
lb = uilistbox(g, 'Items', cellstr(items), 'ItemsData', num2cell(1:numel(items)), 'Value', 1, ...
    'DoubleClickedFcn', @(~, ~) finish(true));
bg = uigridlayout(g, [1 3]);
bg.ColumnWidth = {'1x', 'fit', 'fit'};
bg.Padding = [0 0 0 0];
uilabel(bg, 'Text', '');
okB = uibutton(bg, 'Text', 'Open', 'ButtonPushedFcn', @(~, ~) finish(true));
uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
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
            k = lb.Value;
        end
        uiresume(d);
    end
end
