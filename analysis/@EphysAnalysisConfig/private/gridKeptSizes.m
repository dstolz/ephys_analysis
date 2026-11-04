function s = gridKeptSizes(s, was)
%gridKeptSizes  The relative sizes S, [] (equal) when they are all equal and the grid had none of its own (WAS []).
if isempty(was) && all(abs(s - s(1)) <= 1e-12 * max(abs(s(1)), 1)); s = []; end
end
