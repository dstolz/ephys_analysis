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
%   See also formRow, formLayout.
arguments
    parent
    row (1,1) double
    name (1,1) string
    title (1,1) string
    body (1,1) string {mustBeMember(body, ["form" "panel"])} = "form"
end
S = struct('Name', name, 'Title', title, 'Grid', [], 'HeaderGrid', [], 'Toggle', [], 'Body', [], ...
    'Keys', {{}}, 'Heights', zeros(1, 0), 'Shown', true(1, 0), 'Items', {{}}, 'BodyHeight', 0, ...
    'Visible', true, 'Expanded', true);
S.Grid = uigridlayout(parent, [2 1]);
S.Grid.Layout.Row = row;
S.Grid.Padding = [0 0 0 0];
S.Grid.RowSpacing = 4;
if title ~= ""
    bar = [0.88 0.91 0.95];
    S.HeaderGrid = uigridlayout(S.Grid, [1 2]);
    S.HeaderGrid.Layout.Row = 1;
    S.HeaderGrid.ColumnWidth = {'1x', 'fit'};
    S.HeaderGrid.Padding = [0 0 6 0];
    S.HeaderGrid.ColumnSpacing = 6;
    S.HeaderGrid.BackgroundColor = bar;
    S.Toggle = uibutton(S.HeaderGrid, "Text", "▼  " + title, "HorizontalAlignment", "left", ...
        "FontWeight", "bold", "FontSize", 13, "BackgroundColor", bar, "Tag", "formSectionToggle", ...
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
