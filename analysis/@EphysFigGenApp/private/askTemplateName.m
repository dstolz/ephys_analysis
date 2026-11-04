function [name, description, ok, panel] = askTemplateName(fig, name, description, panel)
%askTemplateName  Ask for a new figure template's name and description in a small modal window over FIG.
%   [NAME, DESCRIPTION, OK, PANEL] = askTemplateName(FIG, NAME,
%   DESCRIPTION, PANEL): the fields start with NAME (the figure's id) and
%   DESCRIPTION; OK is false when it was canceled or closed. The name must
%   suit a file (FigureTemplate.checkName); one of yours that exists is
%   replaced only when the user agrees. The box "A panel type too" starts
%   at PANEL (default false) and gives PANEL: the template is then listed
%   in the New panel window as well, to place its panels in other figures.
%   With PANEL true the window is the Save as panel type... one ("Save
%   the figure as a panel type"); else "Save the figure as a template".
%   The window's UserData holds its controls (Name, Description, Panel,
%   Save, Cancel) for the tests. onFigureTemplate "save" and "panel".
%
%   See also FigureTemplate, askDesignName.
if nargin < 4; panel = false; end
ok = false;
pos = [300 300 520 230];
try
    p = getpixelposition(fig);
    pos(1:2) = max(1, p(1:2) + (p(3:4) - pos(3:4)) / 2);
catch
end
if panel
    title = 'Save the figure as a panel type';
    text = ['The figure shown becomes a panel type of yours: the New panel window lists it beside the built-in ' ...
        'types, and picking it places all its panels, arranged as here, next to the selected panel of any figure. ' ...
        'It is a template too (the Template list), so it can also be applied to figures.'];
else
    title = 'Save the figure as a template';
    text = ['Every setting of the figure shown but its id, title and enabled becomes a ' ...
        'template, to apply to other figures or to add as a new one (Apply...).'];
end
d = uifigure('Name', title, 'Position', pos, 'Resize', 'off', 'WindowStyle', 'modal');
g = uigridlayout(d, [5 2], 'RowHeight', {'fit', 26, 26, 24, 32}, 'ColumnWidth', {90, '1x'});
l = uilabel(g, 'WordWrap', 'on', 'Text', text);
l.Layout.Column = [1 2];
uilabel(g, 'Text', 'Name:');
ed = uieditfield(g, 'text', 'Value', char(name), 'Placeholder', 'e.g. Unit card');
uilabel(g, 'Text', 'Description:');
de = uieditfield(g, 'text', 'Value', char(description), 'Placeholder', 'what the figure is for (optional)');
uilabel(g, 'Text', '');
pb = uicheckbox(g, 'Text', 'A panel type too (listed in the New panel window)', 'Value', panel, ...
    'Tooltip', ['Ticked: New panel... offers this figure as a panel type, placing all its panels, arranged as they ' ...
    'are here, next to the selected panel. The panels are copied: they are ordinary panels of that figure afterwards.']);
uilabel(g, 'Text', '');
bg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 100, 100}, 'Padding', 0);
uilabel(bg, 'Text', '');
okB = uibutton(bg, 'Text', 'Save', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
d.UserData = struct('Name', ed, 'Description', de, 'Panel', pb, 'Save', okB, 'Cancel', cancelB);
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
            panel = logical(pb.Value);
            ok = true;
        end
        uiresume(d);
    end
end
