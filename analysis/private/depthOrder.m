function order = depthOrder(meta, n)
%depthOrder  Rows ordered top of the probe first: y descending, then channel.
%   Without a META table holding y (or with no finite y) the order is 1..N
%   by channel when META has one, else 1..N.
order = (1:n).';
if ~istable(meta) || height(meta) ~= n; return; end
vars = string(meta.Properties.VariableNames);
ch = (1:n).';
if ismember("channel", vars); ch = double(meta.channel); end
if ismember("y", vars) && any(isfinite(meta.y))
    y = double(meta.y);
    y(~isfinite(y)) = -Inf;
    [~, order] = sortrows([-y ch (1:n).']);
else
    [~, order] = sortrows([ch (1:n).']);
end
end
