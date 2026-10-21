function B = latencyBoxStats(v)
%latencyBoxStats  A box plot's statistics of latencies: quartiles, median, Tukey's whiskers and the outliers.
%   B = latencyBoxStats(V) for the latencies V (s, any shape; NaN, the
%   epochs with no first spike, left out) has
%     n         the values counted
%     q         [q1 median q3] = prctile(V, [25 50 75]) (MATLAB's prctile:
%               the k-th sorted value at the (k - 0.5) / n point, linear
%               between them)
%     iqr       q3 - q1
%     fences    [q1 - 1.5 iqr, q3 + 1.5 iqr] (Tukey)
%     whiskers  [lo hi]: the smallest and the largest value inside the
%               fences (a value on a fence is inside)
%     outliers  the values outside the fences, ascending (a column)
%   With no value, n is 0 and the rest NaN (outliers empty). Pure: drawn
%   by a PSTH panel's latency box plot (drawPsthPanel).
%
%   See also firstSpikeLatency, drawPsthPanel, prctile.
v = sort(double(v(isfinite(v))));
v = v(:);
n = numel(v);
B = struct('n', n, 'q', NaN(1, 3), 'iqr', NaN, 'fences', NaN(1, 2), 'whiskers', NaN(1, 2), 'outliers', zeros(0, 1));
if n == 0; return; end
q = reshape(prctile(v, [25 50 75]), 1, 3);
iq = q(3) - q(1);
fences = [q(1) - 1.5 * iq, q(3) + 1.5 * iq];
in = v >= fences(1) & v <= fences(2);
B.q = q;
B.iqr = iq;
B.fences = fences;
B.whiskers = q([1 3]);
if any(in); B.whiskers = [min(v(in)) max(v(in))]; end
B.outliers = v(~in);
end
