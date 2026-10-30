function [N, E] = gridHide(N, E)
%gridHide  Drop the disabled steps, the files not written, the arrows not
%   read and the inputs nothing reads any more, then close the empty rows up.
%   A disabled step stays while a file of it is still read (the manual
%   artifact periods); the arrows into it still go.
keep = true(size(N));
for k = 1:numel(N)
    n = N(k);
    if n.kind == "step" && n.dim
        keep(k) = any(arrayfun(@(p) ~isempty(p.dim) && ~p.dim, n.outs));
    end
    if ~isempty(N(k).outs); N(k).outs = N(k).outs([N(k).outs.kind] ~= "off"); end
end
N = N(keep);
live = [N.id];
E = E([E.on] & ~[E.dim] & ismember([E.from], live) & ismember([E.to], live));
% An input (not a step) is kept only while an arrow leaves it.
isIn = [N.kind] ~= "step";
N = N(~isIn | ismember([N.id], [string.empty(1, 0), E.from]));
% Close up the rows nothing is left in.
rows = unique([N.row]);
for k = 1:numel(N)
    N(k).row = find(rows == N(k).row) - 1;
end
end


