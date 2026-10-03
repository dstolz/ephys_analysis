function q = pAdjust(p, method)
%pAdjust  P values adjusted for multiple comparisons, as R's p.adjust.
%   Q = pAdjust(P, METHOD) over the finite values of P (NaN stays NaN and
%   does not count as a test):
%     "bh"          Benjamini-Hochberg false discovery rate (default):
%                   q(i) = min over j >= i of m p(j) / j, sorted ascending
%     "holm"        Holm's step-down family-wise error rate:
%                   q(i) = max over j <= i of (m - j + 1) p(j)
%     "bonferroni"  m p
%     "none"        P
%   capped at 1, in the order of P. The same as statsmodels' multipletests
%   (fdr_bh, holm, bonferroni); test_ResponseStats checks them against it
%   (pipeline/testdata/padjust_golden.json, from
%   tools/golden/padjust_golden.py).
%
%   See also responseStats.

arguments
    p double
    method (1,1) string {mustBeMember(method, ["bh" "holm" "bonferroni" "none"])} = "bh"
end
q = nan(size(p));
ok = isfinite(p);
v = p(ok);
v = v(:);
m = numel(v);
if m == 0
    return
end
switch method
    case "none"
        a = v;
    case "bonferroni"
        a = min(1, m * v);
    case "bh"
        [s, order] = sort(v, 'descend');
        i = (m:-1:1).';
        a = zeros(m, 1);
        a(order) = min(1, cummin(m ./ i .* s));
    case "holm"
        [s, order] = sort(v);
        i = (1:m).';
        a = zeros(m, 1);
        a(order) = min(1, cummax((m - i + 1) .* s));
end
q(ok) = a;
end
