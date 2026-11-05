function h = trialBins(ax, edges, counts, color, opacity, role, group, opts)
%trialBins  A histogram's bins drawn as bars: a bar of width 1 per bin on a linear axis, rectangles on a log one.
%   H = trialBins(AX, EDGES, COUNTS, COLOR, OPACITY, ROLE, GROUP, Name=Value)
%   draws COUNTS (one per bin of EDGES) in COLOR at OPACITY (0-1), no
%   edge, tagged ROLE and GROUP (tagPart): bar(centers, counts, 1) (barh
%   with Horizontal=true), so a data tip names the bin's center and its
%   count. On a log axis (Log=true), or for a single bin, a bar's width
%   would be linear: the bins are then one patch of rectangles from edge
%   to edge. No histogram object is made (it has no XData: data tips and
%   a design's colors would miss it).
%
%   Options
%     Horizontal  false (default) | true: the bins along y (a scatter's
%                 strip beside its y axis)
%     Log         false (default) | true: the bins' axis is logarithmic
%
%   See also drawTrialHistPanel, drawTrialScatterPanel, trialBinEdges.

arguments
    ax
    edges (1,:) double
    counts (1,:) double
    color (1,3) double
    opacity (1,1) double
    role (1,1) string
    group (1,1) string
    opts.Horizontal (1,1) logical = false
    opts.Log (1,1) logical = false
end
nb = numel(counts);
lo = edges(1:end-1);
hi = edges(2:end);
if ~opts.Log && nb > 1
    centers = (lo + hi) / 2;
    if opts.Horizontal
        h = barh(ax, centers, counts, 1, 'FaceColor', color, 'FaceAlpha', opacity, 'EdgeColor', 'none');
    else
        h = bar(ax, centers, counts, 1, 'FaceColor', color, 'FaceAlpha', opacity, 'EdgeColor', 'none');
    end
else
    X = [lo; hi; hi; lo];
    Y = [zeros(2, nb); counts; counts];
    if opts.Horizontal; [X, Y] = deal(Y, X); end
    h = patch(ax, X, Y, color, 'FaceAlpha', opacity, 'EdgeColor', 'none');
end
tagPart(h, role, group);
end
