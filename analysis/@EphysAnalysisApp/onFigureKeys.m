function w = onFigureKeys(obj)
%onFigureKeys  A window listing every key of the Figures tab: the "?" button over the editor, and Help > Figures tab keys.
%   W is the window, "Figures tab keys": a table of the keys (onKeyPress)
%   and what each does, with Close (Escape, or closing the app, closes it
%   too). One window at a
%   time: a second call brings the open one to the front. Ctrl is Cmd and
%   Alt is Option on a Mac.
old = findall(groot, 'Type', 'figure', 'Tag', 'EphysFigureKeys');
if ~isempty(old)
    w = old(1);
    figure(w);
    return
end
c = "Ctrl";
a = "Alt";
if ismac; c = "Cmd"; a = "Option"; end
K = [ ...
    a + "+1, " + a + "+2, " + a + "+3",  "Go to a supersection of the editor: Figure, Panel, Look (it opens if collapsed; Tab then moves into it)"
    c + "+1 ... " + c + "+9, " + c + "+0", "Go to a section: Observations 1, Event reference 2, Epoch window 3, Trial selection 4, Panels 5, Selected panel 6, Panel alignment 7, Layers 8, Options 9, Text note 0 (each header names its key)"
    c + "+F",                          "Go to the search field: type part of a setting's name"
    "Enter (searching)",                 "Go to the match picked, else the first: its supersection and section open, the editor scrolls to it, its control takes the focus"
    "Down, Up (searching)",              "Pick another match (the editor shows it); Tab also moves into the list of matches"
    "Escape (searching)",                "Clear the search"
    "F6, Shift+F6",                      "Go to the next or previous column: the figure list, the editor, the preview's controls"
    "Tab, Shift+Tab",                    "Move through the controls, top to bottom (collapsed sections are skipped)"
    "Space, Enter (on a header)",        "Collapse or expand that supersection or section"
    c + "+], " + c + "+[",             "Select the next or previous panel of the figure (round at the ends); the preview outlines it"
    c + "+" + a + "+arrows",           "Select the panel above, below, left or right of the selected one"
    "Page Up, Page Down",                "Preview the previous or next observation"
    "Escape (dragging a panel)",         "Cancel the drag in the schematic"
    c + "+N, " + c + "+O, " + c + "+S", "New, open, save the config (the File menu)"];
w = uifigure('Name', 'Figures tab keys', 'Tag', 'EphysFigureKeys', 'Position', [obj.Fig.Position(1:2) + [80 80] 720 470], ...
    'WindowStyle', 'alwaysontop');
g = uigridlayout(w, [3 1], 'RowHeight', {'fit', '1x', 30});
uilabel(g, 'Text', "With the Figures tab showing. The search, the sections and the panels are also reached with the mouse: " + ...
    "the search field over the editor, the headers, the schematic.", 'WordWrap', 'on');
t = uitable(g, 'Data', table(K(:, 1), K(:, 2), 'VariableNames', ["Key" "Does"]), 'ColumnWidth', {190, 'auto'}, ...
    'RowName', {}, 'ColumnEditable', false, 'Tag', 'keysTable');
t.Layout.Row = 2;
b = uibutton(g, 'Text', 'Close', 'ButtonPushedFcn', @(~, ~) delete(w));
styleButton(b, "primary");
w.WindowKeyPressFcn = @(f, evt) closeOnEscape(f, evt);
addlistener(obj.Fig, 'ObjectBeingDestroyed', @(~, ~) delete(w(isvalid(w))));   % it closes with the app
end


function closeOnEscape(f, evt)
if string(evt.Key) == "escape"; delete(f); end
end
