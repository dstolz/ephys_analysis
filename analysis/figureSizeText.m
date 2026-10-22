function txt = figureSizeText(width, height, units)
%figureSizeText  A page size as the Size drop-down shows it: "7 x 4.5 in".
%   TXT = figureSizeText(WIDTH, HEIGHT, UNITS) is a figureSizePresets label
%   when an own size matches one (a row with a size), else the numbers to
%   four significant digits and the units ("px", "in" or "cm").
%   figureSizeParse reads it back.
%
%   See also figureSizeParse, figureSizePresets.
arguments
    width (1,1) double
    height (1,1) double
    units (1,1) string
end
T = figureSizePresets();
i = find(T.Width == width & T.Height == height & T.Units == units, 1);
if ~isempty(i)
    txt = T.Label(i);
else
    txt = string(sprintf('%.4g x %.4g %s', width, height, units));
end
end
