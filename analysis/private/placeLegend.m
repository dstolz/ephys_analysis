function lgd = placeLegend(ax, handles, labels, style, tl, auto)
%placeLegend  A plot's legend, placed and dressed by Style.
%   LGD = placeLegend(AX, HANDLES, LABELS, STYLE, TL, AUTO) lists HANDLES as
%   LABELS in a legend of the axes AX that sit in the tiled layout TL ([]
%   when the plot is one axes). STYLE.LegendLocation:
%     "auto"                   AUTO, the location the plot picks itself:
%                              a legend Location ('best', 'bestoutside'),
%                              or a side ("east": a grid's legend goes
%                              outside the grid, as the grid's labels)
%     "inside"                 'best', in the axes
%     "north" "south" "east" "west"
%                              outside the whole grid of plots, on that side
%                              (beside the axes when the plot is one axes)
%   STYLE.LegendOrientation is "vertical" or "horizontal"; "auto" lays a
%   legend north or south of the grid out horizontally, any other vertically.
%   STYLE.LegendBox draws its outline and background. A legend outside the
%   grid of a layout whose axes are nested (a PSTH's raster and rate panels)
%   is hosted by a hidden axes of TL, tagged "legendHost" (PlotAesthetics
%   leaves it out of the tiles), that lists the handles of AX.
%
%   See also renderPlot, PlotAesthetics.

loc = string(style.LegendLocation);
sides = ["north" "south" "east" "west"];
if loc == "auto" && ismember(string(auto), sides); loc = string(auto); end
side = ismember(loc, sides);
hosted = side && ~isempty(tl) && isgraphics(tl);
host = ax;
if hosted && ax.Parent ~= tl
    host = axes(tl, 'Visible', 'off', 'HitTest', 'off', 'PickableParts', 'none', 'Tag', 'legendHost');
    host.Layout.Tile = 1;
end
lgd = legend(host, handles, cellstr(labels), 'Interpreter', 'none', 'FontSize', max(6, style.FontSize - 1));
lgd.Box = matlab.lang.OnOffSwitchState(style.LegendBox);
if hosted
    lgd.Layout.Tile = char(loc);
elseif side
    lgd.Location = char(loc + "outside");
elseif loc == "inside"
    lgd.Location = 'best';
else
    lgd.Location = char(auto);
end
orient = string(style.LegendOrientation);
if orient == "auto"
    orient = "vertical";
    if ismember(loc, ["north" "south"]); orient = "horizontal"; end
end
lgd.Orientation = char(orient);
end
