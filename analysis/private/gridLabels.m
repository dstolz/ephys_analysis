function gridLabels(tl, axs, x, y, style)
%gridLabels  A grid's x and y labels, once for all its tiles: on its tiled layout.
%   gridLabels(TL, AXS, X, Y, STYLE) names the x axis X and the y axis Y of
%   every tile AXS of the grid in the tiled layout TL as TL's own labels, at
%   Style.FontSize, and clears the tiles' x labels and left y labels (the
%   right y axis of a yyaxis keeps its label: a layout has none on that
%   side). Drawn into one axes (TL = []), AXS(1) takes them. "" leaves a
%   label out. Labels are plain text (no TeX).
if isempty(tl) || ~isgraphics(tl)
    if isempty(axs) || ~isgraphics(axs(1)); return; end
    xlabel(axs(1), x, 'Interpreter', 'none');
    ylabel(axs(1), y, 'Interpreter', 'none');
    return
end
for ax = reshape(axs, 1, [])
    if ~isgraphics(ax); continue; end
    ax.XAxis(1).Label.String = '';
    ax.YAxis(1).Label.String = '';
end
xlabel(tl, x, 'Interpreter', 'none', 'FontSize', style.FontSize);
ylabel(tl, y, 'Interpreter', 'none', 'FontSize', style.FontSize);
end
