function c = countBelow(s, x)
%countBelow  Number of elements of sorted S strictly below each X.
%   C = countBelow(S, X) for a sorted column S: a binary search for every X
%   at once, in about log2(numel(S)) vector steps, so a long spike train is
%   never sorted again. A spike equal to X is not counted as below it.
%   Non-finite X give NaN.
s = s(:);
x = x(:);
m = numel(s);
c = zeros(size(x));
step = 2 ^ floor(log2(max(m, 1)));
while step >= 1   % the largest C with S(C) < X, grown by halving steps
    k = c + step;
    ok = k <= m;
    ok(ok) = s(k(ok)) < x(ok);
    c(ok) = k(ok);
    step = step / 2;
end
c(~isfinite(x)) = NaN;
end
