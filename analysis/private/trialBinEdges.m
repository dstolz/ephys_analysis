function edges = trialBinEdges(v, opts)
%trialBinEdges  One set of bin edges for a trial panel's values: histcounts' rule, a number of bins or a width; log-spaced on a log axis.
%   EDGES = trialBinEdges(V, Name=Value) for the values V (NaN left out)
%   gives the edges every series of a histogram (or a scatter's marginal
%   strip) is counted in, a row:
%     Mode "auto"   histcounts' automatic rule (default)
%          "count"  Count equal bins (default 20)
%          "width"  bins Width wide (default 10, in the values' unit); more
%                   than 1000 such bins: the automatic rule
%     Log true      the bins are equal on a log axis: the values over 0
%                   only, binned as log10 values (Mode "width" then takes
%                   the automatic rule), the edges 10 .^ those
%     Limits [lo hi]  the bins cover these only (histcounts' BinLimits;
%                   values outside are not counted); [] (default) the
%                   values' range
%   No value: ten bins over Limits, else [0 1] ([1 10] on a log axis).
%
%   See also drawTrialHistPanel, drawTrialScatterPanel, trialBins.

arguments
    v double
    opts.Mode (1,1) string = "auto"
    opts.Count (1,1) double = 20
    opts.Width (1,1) double = 10
    opts.Log (1,1) logical = false
    opts.Limits double = []
end
v = v(isfinite(v));
lim = double(opts.Limits);
okLim = numel(lim) == 2 && all(isfinite(lim)) && lim(2) > lim(1) && (~opts.Log || lim(1) > 0);
if opts.Log
    v = log10(v(v > 0));
    if okLim; lim = log10(lim); end
end
if okLim
    v = v(v >= lim(1) & v <= lim(2));
end
args = {};
if okLim; args = {'BinLimits', reshape(lim, 1, 2)}; end
if isempty(v)
    if okLim
        e = linspace(lim(1), lim(2), 11);
    else
        e = [0 1];
    end
else
    mode = opts.Mode;
    span = max(v) - min(v);
    if okLim; span = diff(lim); end
    if mode == "width" && (opts.Log || ~(opts.Width > 0) || span / opts.Width > 1000); mode = "auto"; end
    switch mode
        case "count"
            [~, e] = histcounts(v, max(1, round(opts.Count)), args{:});
        case "width"
            [~, e] = histcounts(v, 'BinWidth', opts.Width, args{:});
        otherwise
            [~, e] = histcounts(v, 'BinMethod', 'auto', args{:});
    end
end
if opts.Log; e = 10 .^ e; end
edges = reshape(double(e), 1, []);
end
