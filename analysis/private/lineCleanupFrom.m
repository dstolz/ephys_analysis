function ref = lineCleanupFrom(ref, E, alignRef)
%lineCleanupFrom  An events layer's reference with its panel's stitching and refractory period for the same line.
%   REF = lineCleanupFrom(REF, E, ALIGNREF) takes an events layer's event
%   reference REF (eventMarkRef(L.event)) and the reference its panel's
%   epochs E are aligned to (E's own, epochTable's UserData.ref; else
%   ALIGNREF, the panel's ref) and, when REF sets neither stitchGapSec nor
%   refractorySec, gives it those the alignment uses for REF.line: the
%   alignment's own when it is on that line, else those of its first
%   sequence step on that line that sets one. So a panel aligned to
%   "Trial onset then Platform offset" with a refractory period on the
%   step draws its Platform row, marks and spans from the same cleaned
%   line the epochs were cut with. A layer that sets either keeps its own.
%
%   See also cleanIntervals, computeEventTracePanel, figurePointLayer.

if ref.stitchGapSec > 0 || ref.refractorySec > 0; return; end
if istable(E) && isstruct(E.Properties.UserData) && isfield(E.Properties.UserData, 'ref') && isstruct(E.Properties.UserData.ref)
    alignRef = E.Properties.UserData.ref;
end
if ~isstruct(alignRef) || ~isscalar(alignRef) || ~isfield(alignRef, 'line'); return; end
from = struct('line', {}, 'stitchGapSec', {}, 'refractorySec', {});
from(1) = pick(alignRef);
if isfield(alignRef, 'sequence')
    for k = 1:numel(alignRef.sequence)
        from(end+1) = pick(alignRef.sequence(k)); %#ok<AGROW>
    end
end
hit = find([from.line] == ref.line & ([from.stitchGapSec] > 0 | [from.refractorySec] > 0), 1);
if isempty(hit); return; end
ref.stitchGapSec = from(hit).stitchGapSec;
ref.refractorySec = from(hit).refractorySec;
end


function s = pick(r)
s = struct('line', string(r.line), 'stitchGapSec', 0, 'refractorySec', 0);
if isfield(r, 'stitchGapSec'); s.stitchGapSec = r.stitchGapSec; end
if isfield(r, 'refractorySec'); s.refractorySec = r.refractorySec; end
end
