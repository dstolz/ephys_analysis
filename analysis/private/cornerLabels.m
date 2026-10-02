function cornerLabels(axs, nr, nc, style)
%cornerLabels  With Style.CornerLabelsOnly, keep axis labels on the bottom-left tile only.
%   cornerLabels(AXS, NR, NC, STYLE): AXS are the tiles of an NR x NC grid in
%   row-major order. Every tile but the bottom-left one loses its x and y
%   axis labels (both sides of a yyaxis); titles, ticks and colorbars stay.
if ~style.CornerLabelsOnly || numel(axs) < 2; return; end
keep = min((nr - 1) * nc + 1, numel(axs));
for j = 1:numel(axs)
    if j == keep || ~isgraphics(axs(j)); continue; end
    axs(j).XAxis(1).Label.String = '';
    for k = 1:numel(axs(j).YAxis)
        axs(j).YAxis(k).Label.String = '';
    end
end
end
