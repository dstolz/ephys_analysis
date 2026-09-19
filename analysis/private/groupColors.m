function C = groupColors(values, ordinal)
%groupColors  One RGB row per group.
%   C = groupColors(VALUES, ORDINAL) gives numel(VALUES) colours: sampled from
%   parula (dark to light, in the order given) when ORDINAL is true and there
%   are more than two groups -- a numeric parameter such as Depth -- and the
%   lines colours otherwise.

n = numel(values);
if n == 0
    C = zeros(0, 3);
elseif ordinal && n > 2
    P = parula(256);
    idx = round(linspace(1, 220, n));   % stop short of parula's pale yellow end
    C = P(idx, :);
else
    C = lines(n);
end
end
