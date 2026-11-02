function b = emptyStateCard(obj, panel)
%emptyStateCard  The Figures tab's preview while there is no figure: what to do first, with a starter figure one click away.
%   B = emptyStateCard(OBJ, PANEL) fills the preview container PANEL with a
%   short text and the button "Add Raster + PSTH" (tag "starterCard": a
%   unit's raster over its PSTH, onAddFigure("rasterPsth")), and returns
%   the button. newFigureView makes it for the container shown while no
%   figure is selected, and the preview makes it again when it clears that
%   container (refreshFigurePreview).
%
%   See also newFigureView, onAddFigure.
g = uigridlayout(panel, [3 3], "RowHeight", {'1x', 40, '1x'}, "ColumnWidth", {'1x', 260, '1x'}, "RowSpacing", 10);
l = uilabel(g, "Text", "No figure yet. Start from a ready-made figure, or press Add under the figure list for a blank one. " + ...
    "Then scan the datasets (Data tab) and pick one to preview.", "WordWrap", "on", "HorizontalAlignment", "center", ...
    "VerticalAlignment", "bottom", "FontColor", [0.4 0.4 0.4]);
l.Layout.Row = 1; l.Layout.Column = [1 3];
b = uibutton(g, "Text", "Add Raster + PSTH", "Tag", "starterCard", "ButtonPushedFcn", @(~, ~) obj.onAddFigure("rasterPsth"), ...
    "Tooltip", "Add a ready-made figure: a unit's raster flush above its PSTH, both following the observed unit.");
b.Layout.Row = 2; b.Layout.Column = 2;
styleButton(b, "confirm");
end
