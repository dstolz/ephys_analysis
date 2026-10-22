function B = figureBatchYLim(E)
%figureBatchYLim  The y range every observation of a run shares on each "batch" panel: the union of their extents.
%   B = figureBatchYLim(E) for E, the observations' figureYExtents results
%   (a cell array of struct rows, or one struct array of id / lim), is a
%   struct row (id, lim, n), one per panel id met: lim [lo hi] the
%   smallest lo and largest hi of the finite extents (a flat union widened
%   by +/-0.5), n how many observations gave a finite extent (lim [NaN
%   NaN], n 0: none did). renderFigure(..., BatchYLim=B) draws each such
%   panel at its lim, so every observation of the run is on the one scale;
%   figureCaption(..., YShared=n) says so. The scope is what E covers: a
%   run's every observation on every dataset of one figure
%   (EphysAnalysisRunner.run), a session figure's matched observations
%   (runSessionFigure), or the datasets of a standalone script.
%
%   See also figureYExtents, figureBatchPanels, renderFigure, figureCaption.
if iscell(E)
    parts = E(~cellfun(@isempty, E));
    if isempty(parts)
        E = struct('id', cell(1, 0), 'lim', cell(1, 0));
    else
        E = [parts{:}];
    end
end
B = struct('id', cell(1, 0), 'lim', cell(1, 0), 'n', cell(1, 0));
if isempty(E); return; end
ids = unique([E.id], 'stable');
for id = ids
    L = reshape([E([E.id] == id).lim], 2, []).';
    ok = all(isfinite(L), 2);
    lim = [NaN NaN];
    if any(ok)
        lim = [min(L(ok, 1)) max(L(ok, 2))];
        if ~(lim(2) > lim(1)); lim = lim + [-0.5 0.5]; end
    end
    B(end+1) = struct('id', id, 'lim', lim, 'n', nnz(ok)); %#ok<AGROW>
end
end
