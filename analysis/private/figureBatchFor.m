function lim = figureBatchFor(B, id)
%figureBatchFor  The run's shared y range for panel ID (BatchYLim: id, lim), [] when it has none.
%
%   See also renderFigure, renderProbeFigure.
lim = [];
if isempty(B) || ~isstruct(B) || ~isfield(B, 'id'); return; end
k = find([B.id] == id, 1);
if ~isempty(k); lim = B(k).lim; end
end
