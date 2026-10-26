function C = figureKeep(C, kind, key, v)
%figureKeep  Note in a figure compute's C.K what it made now: its KIND, KEY and value V (and its size), for figureReuse.
%   See also figureReuse, figureCompute.
w = whos('v');
C.K(end+1) = struct('kind', kind, 'dataset', C.dataset, 'key', {key}, 'value', {v}, 'bytes', w.bytes, 'from', 0);
end
