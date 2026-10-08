function M = designColormap(style, fields, default, n)
%designColormap  N colours of the plot design's colormap, else of a default one.
%   M = designColormap(STYLE, FIELDS, DEFAULT, N) is N x 3 (N default 256):
%   the first of the design's colormaps FIELDS ("sequential", "heat",
%   "diverging"; STYLE.Design, renderStyle) that it gives, else the
%   colormap function DEFAULT ("parula", "blueWhiteRed").
if nargin < 4; n = 256; end
if isfield(style, 'Design')
    for f = string(fields)
        if ~isempty(style.Design.(f))
            M = PlotDesign.colormap(style.Design.(f), n);
            return
        end
    end
end
M = feval(char(default), n);
end
