function [name, description, ok] = askTemplateName(fig, name, description)
%askTemplateName  Ask for a new figure template's name and description in a small modal window over FIG.
%   [NAME, DESCRIPTION, OK] = askTemplateName(FIG, NAME, DESCRIPTION): the
%   fields start with NAME (the figure's id) and DESCRIPTION; OK is false
%   when it was canceled or closed. The name must suit a file
%   (FigureTemplate.checkName); one of yours that exists is replaced only
%   when the user agrees. The window's UserData holds its controls (Name,
%   Description, Save, Cancel) for the tests. onFigureTemplate "save".
%
%   See also FigureTemplate, askDesignName.
ok = false;
pos = [300 300 500 200];
try
    p = getpixelposition(fig);
    pos(1:2) = max(1, p(1:2) + (p(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure('Name', 'Save the figure as a template', 'Position', pos, 'Resize', 'off', 'WindowStyle', 'modal');
g = uigridlayout(d, [4 2], 'RowHeight', {'fit', 26, 26, 32}, 'ColumnWidth', {90, '1x'});
l = uilabel(g, 'WordWrap', 'on', 'Text', ['Every setting of the figure shown but its id, title and enabled becomes a ' ...
    'template, to apply to other figures or to add as a new one (Apply...).']);
l.Layout.Column = [1 2];
uilabel(g, 'Text', 'Name:');
ed = uieditfield(g, 'text', 'Value', char(name), 'Placeholder', 'e.g. Unit card');
uilabel(g, 'Text', 'Description:');
de = uieditfield(g, 'text', 'Value', char(description), 'Placeholder', 'what the figure is for (optional)');
uilabel(g, 'Text', '');
bg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 100, 100}, 'Padding', 0);
uilabel(bg, 'Text', '');
okB = uibutton(bg, 'Text', 'Save', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
d.UserData = struct('Name', ed, 'Description', de, 'Save', okB, 'Cancel', cancelB);
focus(ed);
uiwait(d);
if isvalid(d); delete(d); end

    function finish(accept)
        if accept
            try
                nm = FigureTemplate.checkName(ed.Value);
            catch ME
                uialert(d, ME.message, 'Template name');
                return
            end
            old = FigureTemplate.fileOf(nm);
            if old ~= ""
                [~, stem] = fileparts(old);
                a = uiconfirm(d, sprintf('You already have a template called "%s". Replace it?', stem), ...
                    'Replace template', 'Options', {'Replace', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
                if a ~= "Replace"; return; end
            end
            name = nm;
            description = strtrim(string(de.Value));
            ok = true;
        end
        uiresume(d);
    end
end
