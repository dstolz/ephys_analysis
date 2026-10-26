function [hit, v, C] = figureReuse(C, kind, key)
%figureReuse  The value a figure's compute keeps for this KIND and KEY, made earlier in this compute or in an earlier one (Reuse).
%   [HIT, V, C] = figureReuse(C, KIND, KEY) looks in C.K (what this
%   compute found or made so far: two panels on the same data) and then in
%   C.pool (an earlier compute's K, or many of them joined:
%   EphysAnalysisRunner.computeFigure keeps them for the app's preview),
%   entries of KIND for this dataset (C.dataset) whose key equals KEY
%   (isequaln). HIT false and V [] when none; a value found in the pool is
%   noted in C.K with the index it came from (from). C is figureCompute's
%   struct (on, pool, dataset, K).
%
%   See also figureKeep, figureCompute, figureLatencies.
hit = false;
v = [];
for i = 1:numel(C.K)
    if C.K(i).kind == kind && isequaln(C.K(i).key, key)
        hit = true;
        v = C.K(i).value;
        return
    end
end
P = C.pool;
for i = 1:numel(P)
    if P(i).kind ~= kind || P(i).dataset ~= C.dataset || ~isequaln(P(i).key, key); continue; end
    hit = true;
    v = P(i).value;
    C.K(end+1) = struct('kind', kind, 'dataset', C.dataset, 'key', {key}, 'value', {v}, 'bytes', P(i).bytes, 'from', i);
    return
end
end
