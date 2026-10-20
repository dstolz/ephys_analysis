function c = wcarCopies(obj, plan)
%wcarCopies  The extra copies of one chunk a weighted-CAR read holds.
%   C = wcarCopies(DS, PLAN) is 0 unless ArtifactConfig.Reference is
%   "wcar". Then a read of a PLAN chunk holds the chunk padded by the
%   high-pass's padding on both sides and run from its checkpoint
%   (wcarRows), and the gains: C counts those in chunks, for
%   parallelChunkPool's memory cap. Call it after prepareWCAR.
%
%   See also parallelChunkPool, EphysDataset.prepareWCAR.

c = 0;
st = obj.WCARState;
if obj.referenceMode() ~= "wcar" || ~isstruct(st) || isempty(plan)
    return
end
n = max([plan.nSamples]);
if ~(isfinite(n) && n > 0)
    return
end
c = (n + 2 * st.pad + st.grid) / n + 1;
end
