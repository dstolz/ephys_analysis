function n = gridItems(R, spec)
%gridItems  How many tiles a plot's grid has over all its pages (0: not a grid).
%   N = gridItems(R, SPEC) for SPEC from plotSpecFor: the units of a psth
%   "grid", a raster and a tuning "grid", the channels of an evoked "grid".
%   Every other plot is one panel or a few fixed ones (N = 0).
n = 0;
switch spec.kind
    case "psth"
        if spec.layout == "grid"; n = size(R.rate, 2); end
    case "raster"
        n = numel(R.raster);
    case "tuning"
        if spec.layout == "grid"; n = size(R.mean, 2); end
    case "evoked"
        if spec.layout == "grid"; n = size(R.mean, 2); end
end
end
