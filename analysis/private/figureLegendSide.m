function side = figureLegendSide(style)
%figureLegendSide  The side of the panels the figure's legend takes a band on: "north", "south", "east" (auto) or "west"; "" in a panel (inside).
%
%   See also renderFigure, renderProbeFigure.
side = string(style.LegendLocation);
if side == "auto"; side = "east"; end
if ~ismember(side, ["north" "south" "east" "west"]); side = ""; end
end
