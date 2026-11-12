function b = emptyStateCard(obj, panel)
%emptyStateCard  The Figures tab's preview while there is no figure: what to do first, with Add one click away.
%   B = emptyStateCard(OBJ, PANEL) fills the preview container PANEL with a
%   short text and the button "Add figure" (tag "addFigureCard": what Add
%   under the figure list does, a blank figure and the New panel window,
%   onAddFigure), and returns the button. newFigureView makes it for the
%   container shown while no figure is selected, and the preview makes it
%   again when it clears that container (refreshFigurePreview).
%
%   See also newFigureView, onAddFigure.
g = uigridlayout(panel, [3 3], "RowHeight", {'1x', 40, '1x'}, "ColumnWidth", {'1x', 260, '1x'}, "RowSpacing", 10);
l = uilabel(g, "Text", "No figure yet. Add one and pick its first panel in the New panel window: a panel type, or a " + ...
    "saved figure such as Raster over PSTH. Then scan the datasets (Data tab) and pick one to preview.", "WordWrap", "on", ...
    "HorizontalAlignment", "center", "VerticalAlignment", "bottom", "FontColor", [0.4 0.4 0.4]);
l.Layout.Row = 1; l.Layout.Column = [1 3];
b = uibutton(g, "Text", "Add figure", "Icon", buttonIcon("add"), "Tag", "addFigureCard", "ButtonPushedFcn", @(~, ~) obj.onAddFigure(), ...
    "Tooltip", "Add a blank figure and pick its first panel in the New panel window (as Add under the figure list).");
b.Layout.Row = 2; b.Layout.Column = 2;
styleButton(b, "confirm");
end
