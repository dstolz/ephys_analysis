function s = semOf(X, dim)
%semOf  Standard error of the mean along DIM, ignoring NaN (NaN when n < 2).
n = sum(~isnan(X), dim);
s = std(X, 0, dim, 'omitnan') ./ sqrt(n);
s(n < 2) = NaN;
end
