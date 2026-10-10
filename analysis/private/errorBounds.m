function [lo, hi] = errorBounds(X, dim, type, nBoot)
%errorBounds  The edges of an error band around the mean of X along DIM.
%   [LO, HI] = errorBounds(X, DIM, TYPE, NBOOT) ignores NaN. TYPE:
%     "sem"   the mean +/- its standard error (std / sqrt(n)), as semOf
%     "std"   the mean +/- the standard deviation of the values
%     "ci95"  the 95% confidence interval of the mean: NBOOT (default 1000)
%             bootstrap resamples of the slices of X along DIM, percentile
%             method (bootci, Statistics and Machine Learning Toolbox; the
%             mean of each resample ignores NaN). The resamples come from a
%             stream of their own (mt19937ar, seed 0), so the same data give
%             the same band every time; the global stream is left as it was
%   LO and HI have X's size with DIM collapsed to 1. Where fewer than 2
%   values are not NaN they are NaN (no band), as semOf's SEM is.
%
%   See also semOf, errorPatch, plotErrorType.

if nargin < 4 || isempty(nBoot); nBoot = 1000; end
type = string(type);
n = sum(~isnan(X), dim);
switch type
    case "sem"
        m = mean(X, dim, 'omitnan');
        d = std(X, 0, dim, 'omitnan') ./ sqrt(n);
        lo = m - d;
        hi = m + d;
    case "std"
        m = mean(X, dim, 'omitnan');
        d = std(X, 0, dim, 'omitnan');
        lo = m - d;
        hi = m + d;
    case "ci95"
        [lo, hi] = bootBounds(X, dim, round(nBoot));
    otherwise
        error('errorBounds:BadType', 'The error type is sem, std or ci95, not "%s".', type);
end
bad = n < 2;
lo(bad) = NaN;
hi(bad) = NaN;
end


function [lo, hi] = bootBounds(X, dim, nBoot)
%bootBounds  bootci's percentile 95% CI of the mean along DIM, for every slice at once.
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
prev = RandStream.setGlobalStream(RandStream('mt19937ar', 'Seed', 0));
restore = onCleanup(@() RandStream.setGlobalStream(prev));
ci = bootci(nBoot, {@(y) mean(y, 1, 'omitnan'), Y}, 'Type', 'per', 'Alpha', 0.05);   % [2 x nSlices]
clear restore
shape = [1 sz(order(2:end))];
lo = ipermute(reshape(ci(1, :), shape), order);
hi = ipermute(reshape(ci(2, :), shape), order);
end
