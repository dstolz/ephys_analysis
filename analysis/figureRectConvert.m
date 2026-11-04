function v = figureRectConvert(v, from, to, pageCm, dpi, axis)
%figureRectConvert  Places on a figure's page from one unit to another: 0-1 of the page, %, cm, in or px.
%   V = figureRectConvert(V, FROM, TO, PAGECM, DPI, AXIS) converts the
%   values V from the units FROM to TO, each one of
%   EphysAnalysisConfig.RectUnits:
%     "normalized"  0-1 of the page (a panel's rect is stored so)
%     "%"           percent of the page (normalized x 100)
%     "cm", "in", "px"  a length on the page of PAGECM ([width height]
%                   cm, figureExportSize), from its bottom-left corner;
%                   a pixel is 1 / DPI inch (figureSizeConvert; DPI
%                   default 150, the Export section's)
%   AXIS says which side of the page a value is measured along:
%     "x"     every value along the width (an x or a width)
%     "y"     every value along the height (a y or a height)
%     "rect"  V holds rects, [x y width height] per row (n x 4): x and
%             width along the width, y and height along the height
%   "normalized" and "%" need no page (PAGECM may be []); a physical unit
%   does. Values are converted as they are, not clipped to the page:
%   converting there and back gives V again (to rounding).
%     figureRectConvert([0 0.5 1 0.5], "normalized", "cm", [18 12], 150, "rect")
%       = [0 6 18 6]
%
%   See also figureSizeConvert, figureExportSize, EphysAnalysisConfig.RectUnits.

arguments
    v double
    from (1,1) string {mustBeMember(from, ["normalized" "%" "cm" "in" "px"])}
    to (1,1) string {mustBeMember(to, ["normalized" "%" "cm" "in" "px"])}
    pageCm double = []
    dpi double = 150
    axis (1,1) string {mustBeMember(axis, ["x" "y" "rect"])} = "rect"
end
if from == to; return; end
if isempty(dpi); dpi = 150; end
physical = ["cm" "in" "px"];
if any(ismember([from to], physical)) && ~(numel(pageCm) == 2 && all(isfinite(pageCm) & pageCm > 0))
    error('figureRectConvert:NoPage', 'A conversion to or from %s needs the page''s [width height] in cm.', ...
        strjoin(intersect([from to], physical, 'stable'), " / "));
end
if axis == "rect" && size(v, 2) ~= 4
    if numel(v) == 4
        v = reshape(v, 1, 4);
    else
        error('figureRectConvert:BadRect', 'With axis "rect", V holds rects: [x y width height] per row.');
    end
end

% FROM -> 0-1 of the page
switch from
    case "normalized"
        n = v;
    case "%"
        n = v / 100;
    otherwise
        n = figureSizeConvert(v, from, "cm", dpi) ./ along(pageCm, axis, size(v));
end
% 0-1 of the page -> TO
switch to
    case "normalized"
        v = n;
    case "%"
        v = n * 100;
    otherwise
        v = figureSizeConvert(n .* along(pageCm, axis, size(n)), "cm", to, dpi);
end
end


function L = along(pageCm, axis, sz)
%along  The page's length each value is measured along: its width (x), its height (y), or per rect column.
switch axis
    case "x",    L = pageCm(1);
    case "y",    L = pageCm(2);
    case "rect", L = repmat(reshape(pageCm([1 2 1 2]), 1, 4), sz(1), 1);
end
end
