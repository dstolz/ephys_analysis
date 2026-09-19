function c = countBelow(s, x)
%countBelow  Number of elements of sorted S strictly below each X.
%   C = countBelow(S, X) for a sorted column S. One stable sort of [X; S]:
%   on ties X comes first, so a spike equal to X is not counted as below.
%   Non-finite X give NaN.
x = x(:);
nX = numel(x);
[~, ord] = sort([x; s(:)]);
pos = zeros(numel(ord), 1);
pos(ord) = 1:numel(ord);
[~, xo] = sort(x);
rx = zeros(nX, 1);
rx(xo) = 1:nX;
c = pos(1:nX) - rx;
c(~isfinite(x)) = NaN;
end
