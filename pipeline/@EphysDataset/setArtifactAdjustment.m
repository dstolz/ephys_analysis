function setArtifactAdjustment(obj, detected, bounds)
%setArtifactAdjustment  Move a detected artifact's bounds by hand, or put them back.
%   ds.setArtifactAdjustment(DETECTED, BOUNDS) records that the detected
%   artifact DETECTED ([tStart tEnd) in recording-relative seconds, as the
%   detector found it: a row of analyzeArtifacts' intervals) is
%   [BOUNDS(1) BOUNDS(2)) instead, wherever the automatic detection applies
%   (adjustArtifacts). It replaces an earlier adjustment of that artifact.
%   The bounds are put on the sample grid and inside the recording, and
%   must keep at least one sample. BOUNDS on the same samples as DETECTED,
%   or [] (the default), puts the artifact back as detected.
%
%   The caller saves the manifest (writeManifest), as for ManualArtifacts.
%
%   See also EphysDataset.adjustArtifacts, EphysDataset.ArtifactAdjustments.

arguments
    obj (1,1) EphysDataset
    detected (1,2) double {mustBeFinite}
    bounds double {mustBeFinite} = []
end

A = obj.ArtifactAdjustments;
[~, ~, j] = obj.adjustArtifacts(detected);
if j > 0
    A(j, :) = [];
end
if ~isempty(bounds)
    if numel(bounds) ~= 2
        error('EphysDataset:setArtifactAdjustment:Bounds', 'BOUNDS must be [tStart tEnd] or [].');
    end
    bounds = reshape(bounds, 1, 2);
    Fs = obj.Fs;
    onGrid = isfinite(Fs) && Fs > 0;
    if onGrid
        bounds = round(bounds * Fs) / Fs;
    end
    bounds(1) = max(0, bounds(1));
    if onGrid && isfinite(obj.NumSamples) && obj.NumSamples > 0
        bounds(2) = min(bounds(2), obj.NumSamples / Fs);
    end
    if ~(bounds(2) > bounds(1))
        error('EphysDataset:setArtifactAdjustment:Empty', ...
            'An artifact keeps at least one sample: [%.6f %.6f) s is empty.', bounds(1), bounds(2));
    end
    if onGrid
        same = isequal(round(bounds * Fs), round(detected * Fs));
    else
        same = isequal(bounds, detected);
    end
    if ~same
        A = sortrows([A; detected, bounds], 1);
    end
end
obj.ArtifactAdjustments = A;
end
