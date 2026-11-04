function S = formSection(parent, row, name, title, body, opts)
%formSection  A section of labeled rows that collapses under its header.
%   S = formSection(PARENT, ROW, NAME, TITLE) makes a section in row ROW of
%   the grid PARENT: a header bar -- the toggle button S.Toggle ("▼ TITLE";
%   the caller sets its ButtonPushedFcn), with room for one more control in
%   column 2 of S.HeaderGrid -- over the body S.Body, a two-column grid
%   (label, control) whose rows formRow adds. TITLE "" makes a section
%   without a header, always open.
%
%   S = formSection(..., "panel") makes the body a borderless panel for
%   another builder to fill; set S.BodyHeight to its height.
%
%   formLayout packs the rows S.Shown to the top and sizes the section; S.Visible
%   false hides it, S.Expanded false collapses it to its header.
%
%   S = formSection(..., Color=RGB) sets the color of the header bar: RGB
%   desaturated, keeping its hue, and lightened until black text reads on it
%   (a contrast ratio of 4.5); S.Color is the color used. The title is
%   black. The default is a pale gray-blue. S.Key, which the caller may set,
%   is the key that goes to the section; formLayout names it in the header.
%
%   See also formRow, formLayout.
arguments
    parent
    row (1,1) double
    name (1,1) string
    title (1,1) string
    body (1,1) string {mustBeMember(body, ["form" "panel"])} = "form"
    opts.Color (1,3) double {mustBeInRange(opts.Color, 0, 1)} = [0.88 0.91 0.95]
end
bar = pale(opts.Color);
S = struct('Name', name, 'Title', title, 'Grid', [], 'HeaderGrid', [], 'Toggle', [], 'Body', [], ...
    'Keys', {{}}, 'Heights', zeros(1, 0), 'Shown', true(1, 0), 'Items', {{}}, 'BodyHeight', 0, ...
    'Visible', true, 'Expanded', true, 'Color', bar, 'Key', "");
S.Grid = uigridlayout(parent, [2 1]);
S.Grid.Layout.Row = row;
S.Grid.Padding = [0 0 0 0];
S.Grid.RowSpacing = 4;
if title ~= ""
    S.HeaderGrid = uigridlayout(S.Grid, [1 2]);
    S.HeaderGrid.Layout.Row = 1;
    S.HeaderGrid.ColumnWidth = {'1x', 'fit'};
    S.HeaderGrid.Padding = [0 0 6 0];
    S.HeaderGrid.ColumnSpacing = 6;
    S.HeaderGrid.BackgroundColor = bar;
    S.Toggle = uibutton(S.HeaderGrid, "Text", "▼  " + title, "HorizontalAlignment", "left", ...
        "FontWeight", "bold", "FontSize", 13, "FontColor", [0 0 0], "BackgroundColor", bar, "Tag", "formSectionToggle", ...
        "Tooltip", "Show or hide this section.");
    S.Toggle.Layout.Column = 1;
end
if body == "form"
    S.Body = uigridlayout(S.Grid, [1 2]);
    S.Body.ColumnWidth = {110, '1x'};
    S.Body.RowSpacing = 4;
    S.Body.ColumnSpacing = 6;
    S.Body.Padding = [4 2 4 2];
else
    S.Body = uipanel(S.Grid, "BorderType", "none");
end
S.Body.Layout.Row = 2;
end


function c = pale(c)
%pale  C desaturated, keeping its hue, and lightened until black text on it has a contrast of at least 4.5 (WCAG AA).
hsv = rgb2hsv(c);
hsv(2) = 0.35 * hsv(2);
hsv(3) = 0.93;
c = hsv2rgb(hsv);
while wcagRatio(c, [0 0 0]) < 4.5
    c = 0.95 * c + 0.05;
end
end


function r = wcagRatio(a, b)
%wcagRatio  The contrast ratio of two RGB colors: 1 (alike) to 21 (black on white).
la = relLuminance(a);
lb = relLuminance(b);
r = (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
end


function l = relLuminance(c)
%relLuminance  The relative luminance of the sRGB color C.
lin = (c <= 0.04045) .* (c / 12.92) + (c > 0.04045) .* (((c + 0.055) / 1.055) .^ 2.4);
l = lin(:).' * [0.2126; 0.7152; 0.0722];
end
