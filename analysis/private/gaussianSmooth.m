function Y = gaussianSmooth(X, sigmaBins)
%gaussianSmooth  Gaussian smoothing down the rows, renormalized at the edges.
%   Y = gaussianSmooth(X, SIGMABINS) convolves every column of X with a
%   Gaussian of standard deviation SIGMABINS rows (cut at +/- 3 SD). Near
%   the ends and next to NaN rows the kernel is renormalized over the rows
%   that exist, so a constant stays constant and nothing leaks in from
%   outside. NaN rows stay NaN. SIGMABINS <= 0 returns X.

if ~(sigmaBins > 0) || isempty(X)
    Y = X;
    return
end
sz = size(X);
X = reshape(double(X), sz(1), []);
h = max(1, ceil(3 * sigmaBins));
k = exp(-((-h:h).' .^ 2) / (2 * sigmaBins ^ 2));
k = k / sum(k);
bad = isnan(X);
X0 = X;
X0(bad) = 0;
num = conv2(X0, k, 'same');
w = conv2(double(~bad), k, 'same');
Y = num ./ w;
Y(bad) = NaN;
Y = reshape(Y, sz);
end
