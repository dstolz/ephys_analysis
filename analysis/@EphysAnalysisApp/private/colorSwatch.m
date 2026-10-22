function b = colorSwatch(field, opts)
%colorSwatch  A swatch button beside the color field FIELD that opens the color chooser (uisetcolor).
%   B = colorSwatch(FIELD) puts FIELD (an editable drop-down or a text
%   field holding a color: a name, #RRGGBB, or a word such as "groups",
%   "auto" or "none") in a one-row grid of its own where it was, in its
%   grid, with the swatch button B (Tag "colorSwatch", UserData FIELD) at
%   its right. The swatch shows the field's color (syncColorSwatches: a
%   word that names no one color shows "..." on a plain button) and is
%   enabled with the field. Pressing it opens the chooser on that color
%   (white for a word); a color picked is written to the field as #rrggbb
%   and the field's ValueChangedFcn runs as if it had been typed, so the
%   figure editor takes it as one edit, named after the field's row in the
%   undo history (onConfigChanged, figureEditLabel). Cancel, or the color
%   the field holds, changes nothing. The field still takes a name, a
%   code or a word typed; its ValueChangedFcn is wrapped so the swatch
%   follows what is typed.
%   Picker=FCN: the chooser, RGB = FCN(RGB0, TITLE), returning a 1x3 RGB
%   row, or 0 when canceled (default uisetcolor). The app passes its
%   ColorPicker property, read when the swatch is pressed: uisetcolor is
%   modal, so the tests put a function in its place.
%   Title=TEXT: the chooser's title (default "Pick a color").
%
%   See also syncColorSwatches, namedColor, uisetcolor, buildFiguresTab, latencyDialog.
arguments
    field (1,1)
    opts.Picker (1,1) function_handle = @uisetcolor
    opts.Title (1,1) string = "Pick a color"
end
parent = field.Parent;
heights = parent.RowHeight;    % a new child may grow the grid: put it back
widths = parent.ColumnWidth;
at = field.Layout;
g = uigridlayout(parent, [1 2], "ColumnWidth", {'1x', 24}, "RowHeight", {'1x'}, "Padding", [0 0 0 0], "ColumnSpacing", 4);
g.Layout.Row = at.Row;
g.Layout.Column = at.Column;
field.Parent = g;
field.Layout.Row = 1;
field.Layout.Column = 1;
parent.RowHeight = heights;
parent.ColumnWidth = widths;
b = uibutton(g, "Text", "", "Tag", "colorSwatch", "UserData", field, "ButtonPushedFcn", @(s, ~) pick(s, opts));
b.Layout.Row = 1;
b.Layout.Column = 2;
was = field.ValueChangedFcn;
field.ValueChangedFcn = @(s, e) typed(s, e, was, b);
syncColorSwatches(b);
end


function pick(b, opts)
%pick  The swatch pressed: the chooser on the field's color; a color picked goes to the field as typed.
f = b.UserData;
if ~isvalid(f) || f.Enable == "off"; return; end
rgb0 = [1 1 1];
try
    rgb0 = namedColor(f.Value);
catch
end
rgb = opts.Picker(rgb0, opts.Title);
if ~(isnumeric(rgb) && numel(rgb) == 3) || ~isvalid(f); return; end   % canceled (uisetcolor: 0)
hex = sprintf('#%02x%02x%02x', round(255 * min(max(double(rgb), 0), 1)));
before = f.Value;
if strcmpi(strtrim(string(before)), hex); return; end
f.Value = hex;
evt = struct('Value', hex, 'PreviousValue', before, 'Source', f, 'EventName', 'ValueChanged');
feval(f.ValueChangedFcn, f, evt);
end


function typed(f, evt, was, b)
%typed  The field's own callback, then the swatch follows its value.
if ~isempty(was); feval(was, f, evt); end
if isvalid(b); syncColorSwatches(b); end
end
