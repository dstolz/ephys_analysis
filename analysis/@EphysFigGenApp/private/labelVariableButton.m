function b = labelVariableButton(field, opts)
%labelVariableButton  A "{x}" button beside a text field that inserts a variable ({Line}, {Response}, ...) or a token ({Plot}, ...).
%   B = labelVariableButton(FIELD, Values=FCN, List=FCN2) puts FIELD (a
%   text field or text area whose text labels a figure: a title, an axis
%   label, a layer's name, a note) in a one-row grid of its own where it
%   was, in its grid, with the button B (Tag "labelVariables", UserData
%   FIELD) at its right, as colorSwatch does. Pressing it opens a menu of
%   the label variables (figureLabelVariables) by topic, the datasets'
%   variables last (Values' rows of Topic "Dataset variables"), each item
%   "{Name}   what it means   (now: its value)", the values from Values (FCN() returns
%   figureLabelVariables' table with its Value column: the figure
%   previewed), and a last item that opens the list of them all (List,
%   FCN2()). An item picked adds "{Name}" at the end of the text (after a
%   space) and runs the field's ValueChangedFcn as if it had been typed,
%   so the figure editor takes it as one edit (onConfigChanged). The menu
%   is kept on the button (appdata "LabelVariableMenu") until the next
%   press, so a test can pick an item.
%
%   Other lists (the Export tab's patterns: figureFileTokens):
%     Values=FCN    FCN() may return any table with Name and Meaning
%                   (Value optional); without a Topic column the items
%                   are in the menu itself, not under topics
%     List=[]       no last item
%     Insert=FCN3   FCN3(TEXT, "{Name}") returns the field's new text
%                   (default: added at the end after a space); a text
%                   area's goes at the end of its last line as ever
%     Tooltip=TXT   the button's tooltip
%
%   See also figureLabelVariables, figureFileTokens, colorSwatch, EphysFigGenApp.onLabelVariables.
arguments
    field (1,1)
    opts.Values (1,1) function_handle = @() figureLabelVariables()
    opts.List = []
    opts.Insert (1,1) function_handle = @appendSpaced
    opts.Tooltip (1,1) string = "Insert a variable, such as {Line}, {Response}, {Unit} or a dataset variable ({probeDepth}): " + ...
        "it is filled in for each figure drawn (""Time (s) re {Line} {Edge}"", ""{Response} trials"", " + ...
        """Depth {probeDepth} µm""). The menu's last item lists what each one means."
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
    "ButtonPushedFcn", @(s, ~) openMenu(s, opts), "Tooltip", opts.Tooltip);
b.Layout.Row = 1;
b.Layout.Column = 2;
end


function openMenu(b, opts)
%openMenu  The button pressed: the variables' menu, at the pointer (menuPoint).
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
if ismember("Topic", string(T.Properties.VariableNames))
    for topic = reshape(unique(T.Topic, 'stable'), 1, [])
        sub = uimenu(cm, 'Text', char(topic));
        for i = reshape(find(T.Topic == topic), 1, [])
            addItem(sub, T(i, :), f, opts.Insert);
        end
    end
else   % a short list: its items in the menu itself
    for i = 1:height(T)
        addItem(cm, T(i, :), f, opts.Insert);
    end
end
if ~isempty(opts.List)
    uimenu(cm, 'Text', 'What each one means, with its value now...', 'Separator', 'on', 'Tag', 'list', ...
        'MenuSelectedFcn', @(~, ~) opts.List());
end
setappdata(b, 'LabelVariableMenu', cm);
xy = menuPoint(fig, b);
% the new menu reaches the window first: R2025a's open, called in the turn that made the menu, shows nothing and
% raises no error (open's own "drawnow nocallbacks" is not enough; measured 2026-11-05)
drawnow;
try
    open(cm, xy(1), xy(2));
catch   % (no screen: the menu is built, a test picks from it)
end
end


function addItem(parent, row, f, insert)
%addItem  The menu item of one variable (ROW of the table): "{Name}   what it means   (now: its value)".
name = "{" + row.Name + "}";
txt = name + "   " + row.Meaning;
if row.Value ~= "" && ~startsWith(row.Value, "<"); txt = txt + "   (now: " + row.Value + ")"; end
uimenu(parent, 'Text', char(txt), 'Tag', char(row.Name), 'MenuSelectedFcn', @(~, ~) insertVariable(f, name, insert));
end


function xy = menuPoint(fig, b)
%menuPoint  Where the menu opens, in FIG's pixels from its lower-left: at the mouse pointer (the click on B).
%   Not at B's getpixelposition: the editor's column scrolls, and a scrolled
%   container's children are placed in its whole content, so B's position
%   lands outside the window (open then shows nothing, and raises no error).
%   A press from code, the pointer off the window: B's position, kept inside it.
fp = getpixelposition(fig);
xy = get(groot, 'PointerLocation') - fp(1:2);
if any(xy < 0) || any(xy > fp(3:4))
    p = getpixelposition(b, true);
    xy = p(1:2);
end
xy = min(max(xy, 1), fp(3:4) - 1);
end


function insertVariable(f, name, insert)
%insertVariable  NAME ("{Line}") put in the field's text (INSERT; a text area: at the end of its last line), then its ValueChangedFcn as if typed.
if ~isvalid(f); return; end
before = f.Value;
if iscell(before) || isa(f, 'matlab.ui.control.TextArea')   % a text area: at the end of its last line
    L = string(before);
    if isempty(L); L = ""; end
    L = reshape(L, [], 1);
    L(end) = appendSpaced(L(end), name);
    f.Value = cellstr(L);
else
    f.Value = char(insert(string(before), name));
end
evt = struct('Value', f.Value, 'PreviousValue', before, 'Source', f, 'EventName', 'ValueChanged');
if ~isempty(f.ValueChangedFcn); feval(f.ValueChangedFcn, f, evt); end
try
    focus(f);
catch
end
end


function t = appendSpaced(t, name)
%appendSpaced  NAME added at the end of the text T, after a space.
if t ~= "" && ~endsWith(t, " "); t = t + " "; end
t = t + name;
end
