function s = rectText(rect, units, pageCm, dpi)
%rectText  A panel's rect in words, in the Layout section's units: "10.2 x 6.0 cm at 0, 0".
%   S = rectText(RECT, UNITS, PAGECM, DPI): RECT is [x y width height],
%   0-1 of the page (a panel's rect), shown in UNITS
%   (EphysAnalysisConfig.RectUnits) on the page PAGECM ([width height] cm)
%   at DPI: the width x height, then the place of its bottom-left corner
%   from the page's ("10.2 x 6.0 cm at 0, 6", "50.0 x 50.0 % at 0, 50",
%   "0.50 x 0.50 of the page at 0, 0.5", "602 x 354 px at 0, 354"). The
%   size has one decimal in cm and %, two in inches and normalized, none
%   in px; the place as few as it needs.
%
%   See also showPanelPlace, unitsShown, figureRectConvert.
r = figureRectConvert(double(reshape(rect, 1, 4)), "normalized", units, pageCm, dpi, "rect");
switch units
    case "normalized", d = 2; tail = " of the page";
    case "%",          d = 1; tail = " %";
    case "px",         d = 0; tail = " px";
    case "in",         d = 2; tail = " in";
    otherwise,         d = 1; tail = " cm";
end
at = round(r(1:2), d);
at(at == 0) = 0;
s = sprintf("%.*f x %.*f%s at %g, %g", d, r(3), d, r(4), tail, at(1), at(2));
end
