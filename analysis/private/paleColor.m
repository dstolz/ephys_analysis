function c = paleColor(c, k, style)
%paleColor  Color C taken share K of the way to the plot's ground.
%   The ground is white, or the plot design's background (STYLE.Design,
%   renderStyle), so a band or fill paled from a group color sits quietly
%   on a dark ground too.
g = [1 1 1];
if nargin > 2 && isfield(style, 'Design') && numel(style.Design.background) == 3
    g = style.Design.background;
end
c = c + (g - c) * k;
end
