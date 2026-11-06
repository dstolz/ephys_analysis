function G = arrangeGuides(ax)
%arrangeGuides  The smart guides' objects in Arrange's overlay AX, hidden: 8 alignment lines, 8 distance lines with their texts, the equal-size outline, the readout.
%   G = arrangeGuides(AX) makes them with the overlay (syncArrangeOverlay:
%   newOverlay), not at a drag's first step, so the first drag of a figure
%   costs no more than the next (26 objects take about half a second to
%   make and paint). arrangeCues sets their data and shows or hides them;
%   G.on notes which are shown, in the order arrangeCues lists them.
%
%   See also arrangeCues, EphysFigGenApp.syncArrangeOverlay.
magenta = [0.9 0.1 0.6];
common = {'Tag', 'arrangeGuide', 'Visible', 'off', 'HitTest', 'off', 'PickableParts', 'none', 'Clipping', 'off'};
G.lines = gobjects(1, 8);
for i = 1:8
    G.lines(i) = line(ax, [0 0], [0 0], 'Color', magenta, 'LineWidth', 1, common{:});
end
G.gapLines = gobjects(1, 8);
G.gapTexts = gobjects(1, 8);
for i = 1:8
    G.gapLines(i) = line(ax, [0 0], [0 0], 'Color', magenta, 'LineWidth', 1, 'Marker', '|', 'MarkerSize', 8, common{:});
    G.gapTexts(i) = text(ax, 0, 0, "", 'Color', magenta, 'FontSize', 9, 'FontWeight', 'bold', 'Interpreter', 'none', ...
        'BackgroundColor', [1 1 1], 'Margin', 1, common{:});
end
G.size = line(ax, [0 0], [0 0], 'Color', [0.95 0.55 0.8], 'LineWidth', 1.5, 'LineStyle', '--', common{:});
G.readout = text(ax, 0, 0, "", 'Color', [0.15 0.15 0.15], 'FontSize', 9, 'Interpreter', 'none', ...
    'BackgroundColor', [1 1 0.88], 'EdgeColor', [0.6 0.6 0.6], 'Margin', 2, common{:});
G.on = false(1, 8 + 2 * 8 + 2);   % which are shown, in the order arrangeCues lists them (none yet)
end
