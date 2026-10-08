function tf = isOrdinalGroups(G)
%isOrdinalGroups  True when groups G have groupColors' ordered colours.
%   selectTrials (and tuningCurve, behaviorValues) colour more than two
%   values of a numeric parameter in order (groupColors); a plot design
%   then gives them its sequential colours instead of its palette.
n = height(G);
tf = n > 2 && isequal(size(G.color), [n 3]) && ...
    max(abs(double(G.color) - groupColors(zeros(n, 1), true)), [], 'all') < 1e-9;
end
