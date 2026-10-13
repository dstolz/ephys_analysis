function [lo, hi] = errorBounds(X, dim, type, nBoot, stat)
%errorBounds  The edges of an error band around the mean (or median) of X along DIM.
%   [LO, HI] = errorBounds(X, DIM, TYPE, NBOOT, STAT) ignores NaN. TYPE:
%     "sem"   the mean +/- its standard error (std / sqrt(n)), as semOf
%     "std"   the mean +/- the standard deviation of the values
%     "ci95"  the 95% confidence interval of the mean: NBOOT (default 1000)
%             bootstrap resamples of the slices of X along DIM, percentile
%             method (bootci, Statistics and Machine Learning Toolbox; the
%             mean of each resample ignores NaN). The resamples come from a
%             stream of their own (mt19937ar, seed 0), so the same data give
%             the same band every time; the global stream is left as it was
%     "iqr"   the interquartile range: the 25th to the 75th percentile of
%             the values (prctile)
%   STAT ("mean", default; or "median") is the statistic the band belongs
%   to: "median" centers "sem" and "std" on the median, and makes "ci95"
%   the bootstrap CI of the median (a resample's median ignores NaN). "iqr"
%   is the same either way.
%   LO and HI have X's size with DIM collapsed to 1. Where fewer than 2
%   values are not NaN they are NaN (no band), as semOf's SEM is.
%
%   See also semOf, errorPatch, plotErrorType.

if nargin < 4 || isempty(nBoot); nBoot = 1000; end
if nargin < 5 || isempty(stat); stat = "mean"; end
type = string(type);
stat = string(stat);
if ~ismember(stat, ["mean" "median"])
    error('errorBounds:BadStatistic', 'The statistic is mean or median, not "%s".', stat);
end
n = sum(~isnan(X), dim);
switch type
    case {"sem", "std"}
        if stat == "median"
            m = median(X, dim, 'omitnan');
        else
            m = mean(X, dim, 'omitnan');
        end
        d = std(X, 0, dim, 'omitnan');
        if type == "sem"; d = d ./ sqrt(n); end
        lo = m - d;
        hi = m + d;
    case "ci95"
        [lo, hi] = bootBounds(X, dim, round(nBoot), stat);
    case "iqr"
        q = prctile(X, [25 75], dim);
        at = repmat({':'}, 1, ndims(q));
        at{dim} = 1;
        lo = q(at{:});
        at{dim} = 2;
        hi = q(at{:});
    otherwise
        error('errorBounds:BadType', 'The error type is sem, std, ci95 or iqr, not "%s".', type);
end
bad = n < 2;
lo(bad) = NaN;
hi(bad) = NaN;
end


function [lo, hi] = bootBounds(X, dim, nBoot, stat)
%bootBounds  bootci's percentile 95% CI of the mean (or median) along DIM, for every slice at once.
sz = size(X);
sz(end+1:dim) = 1;
order = [dim setdiff(1:numel(sz), dim)];
out = sz;
out(dim) = 1;
lo = NaN(out);
hi = NaN(out);
n = sz(dim);
if n < 2 || prod(out) == 0; return; end
Y = reshape(double(permute(X, order)), n, []);   % a row per observation, a column per slice
if stat == "median"
    fcn = @(y) median(y, 1, 'omitnan');
else
    fcn = @(y) mean(y, 1, 'omitnan');
end
prev = RandStream.setGlobalStream(RandStream('mt19937ar', 'Seed', 0));
restore = onCleanup(@() RandStream.setGlobalStream(prev));
ci = bootci(nBoot, {fcn, Y}, 'Type', 'per', 'Alpha', 0.05);   % [2 x nSlices]
clear restore
shape = [1 sz(order(2:end))];
lo = ipermute(reshape(ci(1, :), shape), order);
hi = ipermute(reshape(ci(2, :), shape), order);
end
