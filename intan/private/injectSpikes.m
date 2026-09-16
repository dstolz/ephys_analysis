function X = injectSpikes(X, idx, chan, tmpl, peakPos)
%injectSpikes  Add tmpl to column chan of X, tmpl(peakPos) landing on each idx.
%   Samples of the template that fall outside X are clipped. Test fixture.
n = size(X, 1);
m = numel(tmpl);
for k = 1:numel(idx)
    rows = idx(k) - peakPos + (1:m).';
    ok = rows >= 1 & rows <= n;
    X(rows(ok), chan) = X(rows(ok), chan) + tmpl(ok);
end
end
