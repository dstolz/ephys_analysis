function [v, digits] = unitsShown(v, from, units, pageCm, dpi, axis)
%unitsShown  Values as the Panels section shows them in UNITS: converted, and rounded to its fields' precision.
%   V = unitsShown(V, FROM, UNITS, PAGECM, DPI, AXIS) converts V from the
%   units FROM to UNITS (EphysAnalysisConfig.RectUnits) on the page PAGECM
%   ([width height] cm) at DPI, along AXIS ("x", "y" or "rect":
%   figureRectConvert), and rounds it to the decimals the fields show in
%   UNITS: 4 for normalized, 2 for % and cm, 3 for in, none for px. Two
%   values that round alike show alike, so gatherFigureEditor writes a
%   field back only when it differs from what showPanelPlace showed (a
%   rect in px would otherwise move by a fraction of a pixel at each
%   edit).
%   [V, DIGITS] = unitsShown(...) also gives that number of decimals;
%   [~, DIGITS] = unitsShown([], "", UNITS) gives it alone.
%
%   See also figureRectConvert, showPanelPlace, rectText.
arguments
    v double
    from (1,1) string
    units (1,1) string {mustBeMember(units, ["normalized" "%" "cm" "in" "px"])}
    pageCm double = []
    dpi double = 150
    axis (1,1) string = "rect"
end
switch units
    case "normalized", digits = 4;
    case "in",         digits = 3;
    case "px",         digits = 0;
    otherwise,         digits = 2;   % % and cm
end
if isempty(v); return; end
v = round(figureRectConvert(v, from, units, pageCm, dpi, axis), digits);
v(v == 0) = 0;   % no -0
end
