function order = probeOrder(meta, n, style)
%probeOrder  Row order of N units or channels from the probe: shank, then depth.
%   ORDER = probeOrder(META, N, STYLE) sorts by shank (ascending) when
%   STYLE.SortShank, then, within a shank, top of the probe first (y
%   descending) when STYLE.SortDepth, then by channel. With neither, or
%   without the column a key needs (shank, y), ORDER is 1..N as listed; so it
%   is when META is no table of N rows.
order = (1:n).';
if ~istable(meta) || height(meta) ~= n; return; end
vars = string(meta.Properties.VariableNames);
ch = (1:n).';
if ismember("channel", vars); ch = double(meta.channel); end
keys = zeros(n, 0);
if style.SortShank && ismember("shank", vars)
    keys = [keys double(meta.shank(:))];
end
if style.SortDepth && ismember("y", vars) && any(isfinite(meta.y))
    y = double(meta.y(:));
    y(~isfinite(y)) = -Inf;
    keys = [keys -y];
end
if isempty(keys); return; end
[~, order] = sortrows([keys ch (1:n).']);
end
