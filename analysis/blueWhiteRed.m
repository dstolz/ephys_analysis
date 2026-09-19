function c = blueWhiteRed(n)
%blueWhiteRed  Diverging colormap: blue through white to red.
%   C = blueWhiteRed(N) is an N x 3 colormap (default: the current figure's
%   colormap length, else 256) for values centred on zero, such as
%   correlations on [-1 1]: the default colours of renderCorrMap.
%
%   See also renderCorrMap, colormap.

if nargin < 1
    f = get(groot, 'CurrentFigure');
    if isempty(f); n = 256; else; n = size(f.Colormap, 1); end
end
anchors = [0.019 0.188 0.380; 0.263 0.576 0.765; 0.969 0.969 0.969; 0.839 0.376 0.302; 0.404 0.000 0.122];
x = linspace(0, 1, size(anchors, 1));
c = interp1(x, anchors, linspace(0, 1, n));
end
