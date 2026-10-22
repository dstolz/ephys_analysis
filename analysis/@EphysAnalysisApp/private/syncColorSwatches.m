function syncColorSwatches(B)
%syncColorSwatches  Each color swatch (colorSwatch) shows its field's color and is enabled with it.
%   syncColorSwatches(B) for the swatch buttons B: a gobjects array, a
%   cell array of them, or a struct of them (the figure editor's
%   E.swatch, by field name). A field whose value is a color (a name or
%   #RRGGBB: namedColor) gives its swatch that background; a word that
%   names no one color ("groups", "auto", "none", a colormap) a plain
%   button with "...". The tooltip says what the swatch does and the
%   color now. syncFigureEditor calls it after setting the editor's fields;
%   typing in a field calls it for its swatch (colorSwatch).
%
%   See also colorSwatch, namedColor.
if isstruct(B); B = struct2cell(B); end
if iscell(B)
    if isempty(B); return; end
    B = [B{:}];
end
for b = reshape(B, 1, [])
    if ~isvalid(b) || ~isvalid(b.UserData); continue; end
    f = b.UserData;
    tip = "Pick a color in the color chooser";
    try
        rgb = namedColor(f.Value);
        b.BackgroundColor = rgb;
        b.Text = "";
        tip = tip + " (now " + sprintf('#%02x%02x%02x', round(255 * rgb)) + ").";
    catch
        b.BackgroundColor = [0.96 0.96 0.96];
        b.Text = "...";
        tip = tip + "; it replaces """ + strtrim(string(f.Value)) + """ with one color.";
    end
    b.Tooltip = tip;
    b.Enable = f.Enable;
end
end
