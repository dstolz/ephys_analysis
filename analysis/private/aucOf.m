function a = aucOf(A, B)
%aucOf  Area under the ROC curve of A against B, per column: P(a > b) + P(a = b) / 2.
%   AUC = aucOf(A, B) with A [nA x m] and B [nB x m] (or B [nB x 1]: the
%   same B for every column) is, for each column, the Mann-Whitney U of
%   A's values against B's over nA x nB: 1 when every A value is above
%   every B value, 0 when every one is below, 0.5 when they overlap evenly
%   (a tie counts half). It is the area under the ROC curve that a
%   criterion swept from the smallest value to the largest draws (Cohen et
%   al. 2012), computed exactly from ranks (tiedrank, Statistics and
%   Machine Learning Toolbox). NaN values are left out of their column; a
%   column without an A or a B value is NaN. AUC is [1 x m].
%
%   See also aurocCurves, tiedrank.

m = size(A, 2);
if size(B, 2) == 1 && m > 1; B = repmat(B, 1, m); end
nA = size(A, 1);
nB = size(B, 1);
X = [A; B];
if ~anynan(X)
    if nA == 0 || nB == 0
        a = NaN(1, m);
        return
    end
    r = tiedrank(X);   % column by column
    a = (sum(r(1:nA, :), 1) - nA * (nA + 1) / 2) / (nA * nB);
    return
end
a = NaN(1, m);
for j = 1:m
    x = A(:, j); x = x(~isnan(x));
    y = B(:, j); y = y(~isnan(y));
    if isempty(x) || isempty(y); continue; end
    r = tiedrank([x; y]);
    k = numel(x);
    a(j) = (sum(r(1:k)) - k * (k + 1) / 2) / (k * numel(y));
end
end
