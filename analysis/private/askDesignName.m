function [name, description, ok] = askDesignName(fig, name, description)
%askDesignName  Ask for a new plot design's name and description in a small modal window over FIG.
%   [NAME, DESCRIPTION, OK] = askDesignName(FIG, NAME, DESCRIPTION); OK is
%   false when it was cancelled or closed. The name must suit a file and
%   not be a built-in design's (PlotDesign.checkName); one of yours that
%   exists is replaced only when the user agrees. PlotDesign.askName.

ok = false;
pos = [300 300 480 190];
try
    p = getpixelposition(fig);
    pos(1:2) = max(1, p(1:2) + (p(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure('Name', 'Save the look as a design', 'Position', pos, 'Resize', 'off', 'WindowStyle', 'modal');
g = uigridlayout(d, [4 2], 'RowHeight', {'fit', 26, 26, 32}, 'ColumnWidth', {90, '1x'});
l = uilabel(g, 'WordWrap', 'on', 'Text', ['Every property of every component of this plot, its ground ' ...
    'and its group colours become a design you can choose for any plot.']);
l.Layout.Column = [1 2];
uilabel(g, 'Text', 'Name:');
ed = uieditfield(g, 'text', 'Value', char(name), 'Placeholder', 'e.g. Lab meeting');
uilabel(g, 'Text', 'Description:');
de = uieditfield(g, 'text', 'Value', char(description), 'Placeholder', 'what the look is for (optional)');
uilabel(g, 'Text', '');
bg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 100, 100}, 'Padding', 0);
uilabel(bg, 'Text', '');
okB = uibutton(bg, 'Text', 'Save', 'ButtonPushedFcn', @(~, ~) finish(true));
uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
focus(ed);
uiwait(d);
if isvalid(d); delete(d); end

    function finish(accept)
        if accept
            try
                nm = PlotDesign.checkName(ed.Value);
            catch ME
                uialert(d, ME.message, 'Design name');
                return
            end
            if isfile(fullfile(PlotDesign.folder(), nm + ".json"))
                a = uiconfirm(d, sprintf('You already have a design called "%s". Replace it?', nm), ...
                    'Replace design', 'Options', {'Replace', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
                if a ~= "Replace"; return; end
            end
            name = nm;
            description = strtrim(string(de.Value));
            ok = true;
        end
        uiresume(d);
    end
end
