function mask = manualArtifactMask(obj, nSamp, sampleOffset, Fs, iv)
%manualArtifactMask  Logical mask of ManualArtifacts for one streamed block.
%   MASK = ds.manualArtifactMask(NSAMP, SAMPLEOFFSET, FS) returns an
%   [NSAMP x 1] logical flagging the samples of a block that fall within any
%   manually defined artifact period (ds.ManualArtifacts, recording-relative
%   seconds). SAMPLEOFFSET is the number of samples that precede this block in
%   the whole recording, so the absolute (0-based) sample index of row k is
%   SAMPLEOFFSET + k - 1 and its time is that divided by FS.
%
%   A period [a b] is half-open on that clock: it covers samples
%   round(a*FS) .. round(b*FS) - 1, the samples a detectArtifacts interval
%   came from (EphysDataset.artifactSamples). So every route (.bin blanking,
%   the derived signals, spike rejection) removes the same samples.
%
%   MASK = ds.manualArtifactMask(NSAMP, SAMPLEOFFSET, FS, IV) masks the
%   recording-relative [k x 2] second intervals IV instead of ManualArtifacts.
%
%   toBin streams one *.rhd file at a time and calls this per file (with the
%   running sample offset) to build the mask it passes to blankArtifacts.
%
%   See also EphysDataset.addArtifact, EphysDataset.blankArtifacts, EphysDataset.toBin.

arguments
    obj (1,1) EphysDataset
    nSamp (1,1) double {mustBeInteger, mustBeNonnegative}
    sampleOffset (1,1) double {mustBeInteger, mustBeNonnegative}
    Fs (1,1) double {mustBePositive}
    iv (:,2) double = obj.ManualArtifacts
end

mask = false(nSamp, 1);
if isempty(iv) || nSamp == 0
    return
end

% The periods' rows in the whole recording, mapped into this block.
rows = EphysDataset.artifactSamples(iv, Fs, Inf) - sampleOffset;
for k = 1:size(rows, 1)
    i0 = max(1, rows(k, 1));
    i1 = min(nSamp, rows(k, 2));
    if i1 >= i0
        mask(i0:i1) = true;
    end
end
end
