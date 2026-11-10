function w = onLabelVariables(obj)
%onLabelVariables  A window listing the label variables ({Line}, {Response}, ...): what each means and its value on the figure previewed.
%   W is the window, "Label variables": a table of every variable of
%   figureLabelVariables -- its name in braces, what it means, an example
%   and its value now (labelVariableValues: the Figures tab's selected
%   figure and panel, as previewed) -- under a line saying where they go.
%   A click on a row copies its variable ("{Line}") to the clipboard, to
%   paste into a label. Help > Label variables opens it, and so does the
%   last item of every "{x}" button's menu (labelVariableButton). One
%   window at a time: a second call brings the open one to the front with
%   its values made again. Escape, Close or closing the app closes it.
%
%   See also figureLabelVariables, labelVariableValues.
T = obj.labelVariableValues();
D = table("{" + T.Name + "}", T.Meaning, T.Example, T.Value, 'VariableNames', ["Variable" "Means" "Example" "Now"]);
old = findall(groot, 'Type', 'figure', 'Tag', 'EphysLabelVariables');
if ~isempty(old)
    w = old(1);
    t = findobj(w, 'Tag', 'variablesTable');
    if ~isempty(t); t(1).Data = D; end
    figure(w);
    return
end
w = uifigure('Name', 'Label variables', 'Tag', 'EphysLabelVariables', 'Position', [obj.Fig.Position(1:2) + [80 80] 820 600], ...
    'WindowStyle', 'alwaysontop');
g = uigridlayout(w, [4 1], 'RowHeight', {'fit', '1x', 'fit', 30});
what = "the figure previewed";
if obj.SelectedPanel > 0; what = "the figure previewed, at its selected panel"; end
uilabel(g, 'WordWrap', 'on', 'Text', "Type a variable, braces and all, in a figure's Title, a panel's Title, X axis or " + ...
    "Y axis label, a layer's Name or a Text note (or pick it from the {x} button beside them). It is filled in for " + ...
    "each figure drawn, so one label serves every unit, channel, trial group and dataset: ""Time (s) re {Line} " + ...
    "{Edge}"" shows ""Time (s) re Stim onset"", ""{Response} trials"" shows ""Hit trials"". Each panel's alignment " + ...
    "and trial selection give its own values. Names are case-sensitive; a name not listed here stays as typed. " + ...
    "Now: the value on " + what + " (<Name> until it is previewed). Special characters: type \mu, \pm, \Delta or " + ...
    "^\circ for µ, ±, Δ or ° (any TeX name, e.g. \alpha, \leq, \rightarrow).");
t = uitable(g, 'Data', D, 'ColumnWidth', {110, 'auto', 150, 150}, 'RowName', {}, 'ColumnEditable', false, ...
    'Tag', 'variablesTable', 'SelectionType', 'row', 'Multiselect', 'off', ...
    'Tooltip', 'Click a row to copy its variable to the clipboard.');
t.Layout.Row = 2;
note = uilabel(g, 'Text', "Click a row to copy its variable, then paste it into a label (Ctrl+V).", ...
    'FontColor', [0.35 0.35 0.35], 'Tag', 'copyNote');
note.Layout.Row = 3;
t.SelectionChangedFcn = @(s, ~) copyRow(s, note);
b = uibutton(g, 'Text', 'Close', 'ButtonPushedFcn', @(~, ~) delete(w));
b.Layout.Row = 4;
styleButton(b, "primary");
w.WindowKeyPressFcn = @(f, evt) closeOnEscape(f, evt);
addlistener(obj.Fig, 'ObjectBeingDestroyed', @(~, ~) delete(w(isvalid(w))));   % it closes with the app
end


function copyRow(t, note)
%copyRow  The row clicked: its variable to the clipboard.
r = t.Selection;
if isempty(r); return; end
v = string(t.Data.Variable(r(1)));
try
    clipboard('copy', char(v));
    note.Text = char("Copied " + v + ": paste it into a label (Ctrl+V).");
catch
    note.Text = char("Type " + v + " into a label.");
end
end


function closeOnEscape(f, evt)
if string(evt.Key) == "escape"; delete(f); end
end
