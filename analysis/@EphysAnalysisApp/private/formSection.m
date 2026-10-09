function S = formSection(parent, row, name, title, body)
%formSection  A section of labelled rows that collapses under its header.
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
%   S = formSection(..., Color=RGB) sets the colour of the title. It is
%   darkened, keeping its hue, until it reads on the header bar (a contrast
%   ratio of 4.5 against it); S.Color is the colour used. The default is
%   black. S.Key, which the caller may set, is the key that goes to the
%   section; formLayout names it in the header.
%
%   See also formRow, formLayout.
arguments
    parent
    row (1,1) double
    name (1,1) string
    title (1,1) string
    body (1,1) string {mustBeMember(body, ["form" "panel"])} = "form"
    opts.Color (1,3) double {mustBeInRange(opts.Color, 0, 1)} = [0 0 0]
end
bar = [0.88 0.91 0.95];
S = struct('Name', name, 'Title', title, 'Grid', [], 'HeaderGrid', [], 'Toggle', [], 'Body', [], ...
    'Keys', {{}}, 'Heights', zeros(1, 0), 'Shown', true(1, 0), 'Items', {{}}, 'BodyHeight', 0, ...
    'Visible', true, 'Expanded', true, 'Color', readable(opts.Color, bar), 'Key', "");
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
        "FontWeight", "bold", "FontSize", 13, "FontColor", S.Color, "BackgroundColor", bar, "Tag", "formSectionToggle", ...
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


function c = readable(c, ground)
%readable  C darkened, keeping its hue, until its contrast with GROUND is at least 4.5 (WCAG AA).
while wcagRatio(c, ground) < 4.5
    c = 0.95 * c;
end
end


function r = wcagRatio(a, b)
%wcagRatio  The contrast ratio of two RGB colours: 1 (alike) to 21 (black on white).
la = relLuminance(a);
lb = relLuminance(b);
r = (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
end


function l = relLuminance(c)
%relLuminance  The relative luminance of the sRGB colour C.
lin = (c <= 0.04045) .* (c / 12.92) + (c > 0.04045) .* (((c + 0.055) / 1.055) .^ 2.4);
l = lin(:).' * [0.2126; 0.7152; 0.0722];
end
