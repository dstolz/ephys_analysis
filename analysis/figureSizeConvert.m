function v = figureSizeConvert(v, from, to, dpi)
%figureSizeConvert  Page lengths from one unit to another: "px", "in" or "cm".
%   V = figureSizeConvert(V, FROM, TO, DPI) converts the lengths V (an
%   array) from the units FROM to TO. A pixel is a pixel of the exported
%   PNG, 1 / DPI inch (the Export section's Dpi; default 150).
%
%   See also figureExportSize, figureSizeParse.
arguments
    v double
    from (1,1) string {mustBeMember(from, ["px" "in" "cm"])}
    to (1,1) string {mustBeMember(to, ["px" "in" "cm"])}
    dpi (1,1) double {mustBePositive} = 150
end
per = struct('px', 2.54 / dpi, 'in', 2.54, 'cm', 1);   % cm in one unit
v = v * per.(char(from)) / per.(char(to));
end
