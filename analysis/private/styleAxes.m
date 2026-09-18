function styleAxes(ax, style)
%styleAxes  Font size, box, grid and axis limits from a Style struct.
ax.FontSize = style.FontSize;
box(ax, 'on');
if style.Grid
    grid(ax, 'on');
else
    grid(ax, 'off');
end
if numel(style.XLim) == 2 && style.XLim(2) > style.XLim(1)
    xlim(ax, style.XLim);
end
if numel(style.YLim) == 2 && style.YLim(2) > style.YLim(1)
    ylim(ax, style.YLim);
end
end
