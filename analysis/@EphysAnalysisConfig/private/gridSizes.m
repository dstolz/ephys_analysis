function s = gridSizes(sizes, n)
%gridSizes  N relative sizes of a grid's rows (columns): SIZES when they are N positive numbers, else equal ones.
s = ones(1, n);
v = reshape(double(sizes), 1, []);
if numel(v) == n && all(isfinite(v) & v > 0); s = v; end
end
