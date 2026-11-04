function b = labelVariableButton(field, opts)
%labelVariableButton  A "{x}" button beside a label's text field that inserts a label variable ({Line}, {Response}, ...).
%   B = labelVariableButton(FIELD, Values=FCN, List=FCN2) puts FIELD (a
%   text field or text area whose text labels a figure: a title, an axis
%   label, a layer's name, a note) in a one-row grid of its own where it
%   was, in its grid, with the button B (Tag "labelVariables", UserData
%   FIELD) at its right, as colorSwatch does. Pressing it opens a menu of
%   the label variables (figureLabelVariables) by topic, each item "{Name}
%   what it means (now: its value)", the values from Values (FCN() returns
%   figureLabelVariables' table with its Value column: the figure
%   previewed), and a last item that opens the list of them all (List,
%   FCN2()). An item picked adds "{Name}" at the end of the text (after a
%   space) and runs the field's ValueChangedFcn as if it had been typed,
%   so the figure editor takes it as one edit (onConfigChanged). The menu
%   is kept on the button (appdata "LabelVariableMenu") until the next
%   press, so a test can pick an item.
%
%   See also figureLabelVariables, colorSwatch, EphysFigGenApp.onLabelVariables.
arguments
    field (1,1)
    opts.Values (1,1) function_handle = @() figureLabelVariables()
    opts.List = []
end
parent = field.Parent;
heights = parent.RowHeight;    % a new child may grow the grid: put it back
widths = parent.ColumnWidth;
at = field.Layout;
g = uigridlayout(parent, [1 2], "ColumnWidth", {'1x', 30}, "RowHeight", {'1x'}, "Padding", [0 0 0 0], "ColumnSpacing", 4);
if isa(field, 'matlab.ui.control.TextArea'); g.RowHeight = {24, '1x'}; end   % a text area: the button at its top
g.Layout.Row = at.Row;
g.Layout.Column = at.Column;
field.Parent = g;
field.Layout.Row = 1;
if numel(g.RowHeight) > 1; field.Layout.Row = [1 numel(g.RowHeight)]; end   % a text area spans the button's row and the one under it
field.Layout.Column = 1;
parent.RowHeight = heights;
parent.ColumnWidth = widths;
b = uibutton(g, "Text", "{x}", "Tag", "labelVariables", "UserData", field, "FontSize", 11, ...
    "ButtonPushedFcn", @(s, ~) openMenu(s, opts), ...
    "Tooltip", "Insert a variable, such as {Line}, {Response} or {Unit}: it is filled in for each figure drawn " + ...
    "(""Time (s) re {Line} {Edge}"", ""{Response} trials""). The menu's last item lists what each one means.");
b.Layout.Row = 1;
b.Layout.Column = 2;
end


function openMenu(b, opts)
%openMenu  The button pressed: the variables' menu, at the button.
f = b.UserData;
if ~isvalid(f) || f.Enable == "off"; return; end
fig = ancestor(b, 'figure');
if isappdata(b, 'LabelVariableMenu')
    old = getappdata(b, 'LabelVariableMenu');
    delete(old(isvalid(old)));
end
T = opts.Values();
if ~ismember("Value", string(T.Properties.VariableNames)); T.Value = strings(height(T), 1); end
cm = uicontextmenu(fig);
for topic = reshape(unique(T.Topic, 'stable'), 1, [])
    sub = uimenu(cm, 'Text', char(topic));
    for i = reshape(find(T.Topic == topic), 1, [])
        name = "{" + T.Name(i) + "}";
        txt = name + "   " + T.Meaning(i);
        if T.Value(i) ~= "" && ~startsWith(T.Value(i), "<"); txt = txt + "   (now: " + T.Value(i) + ")"; end
        uimenu(sub, 'Text', char(txt), 'Tag', char(T.Name(i)), 'MenuSelectedFcn', @(~, ~) insertVariable(f, name));
    end
end
if ~isempty(opts.List)
    uimenu(cm, 'Text', 'What each one means, with its value now...', 'Separator', 'on', 'Tag', 'list', ...
        'MenuSelectedFcn', @(~, ~) opts.List());
end
setappdata(b, 'LabelVariableMenu', cm);
p = getpixelposition(b, true);
try
    open(cm, p(1), p(2));
catch   % (no screen: the menu is built, a test picks from it)
end
end


function insertVariable(f, name)
%insertVariable  NAME ("{Line}") added at the end of the field's text, then its ValueChangedFcn as if typed.
if ~isvalid(f); return; end
before = f.Value;
if iscell(before) || isa(f, 'matlab.ui.control.TextArea')   % a text area: at the end of its last line
    L = string(before);
    if isempty(L); L = ""; end
    L = reshape(L, [], 1);
    if L(end) ~= "" && ~endsWith(L(end), " "); L(end) = L(end) + " "; end
    L(end) = L(end) + name;
    f.Value = cellstr(L);
else
    t = string(before);
    if t ~= "" && ~endsWith(t, " "); t = t + " "; end
    f.Value = char(t + name);
end
evt = struct('Value', f.Value, 'PreviousValue', before, 'Source', f, 'EventName', 'ValueChanged');
if ~isempty(f.ValueChangedFcn); feval(f.ValueChangedFcn, f, evt); end
try
    focus(f);
catch
end
end
