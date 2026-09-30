function [iv, adjusted, row] = adjustArtifacts(obj, iv)
%adjustArtifacts  Detected artifacts with the bounds moved by hand.
%   [IV, ADJUSTED, ROW] = ds.adjustArtifacts(IV) takes detected artifacts IV
%   ([k x 2] [tStart tEnd) in recording-relative seconds, one row per
%   detection as the detector gives them: analyzeArtifacts' intervals,
%   artifactIntervals' automatic part) and returns the same rows with the
%   bounds of those listed in ds.ArtifactAdjustments moved to where they
%   were set (setArtifactAdjustment). A row is matched by its detected
%   bounds, to a quarter of a sample. The rows keep their order and
%   nothing is merged, so row k is still the preview's artifact k.
%   ADJUSTED [k x 1] flags the rows moved, and ROW [k x 1] is the row of
%   ArtifactAdjustments each came from (0 = none).
%
%   An adjustment whose artifact the detector no longer finds (other
%   detection settings, another common reference) is not applied; it stays
%   in the list, and applies again if those settings come back.
%
%   See also EphysDataset.setArtifactAdjustment, EphysDataset.artifactIntervals,
%   EphysDataset.ArtifactAdjustments.

arguments
    obj (1,1) EphysDataset
    iv (:,2) double
end

n = size(iv, 1);
adjusted = false(n, 1);
row = zeros(n, 1);
A = obj.ArtifactAdjustments;
if isempty(A) || n == 0
    return
end
tol = 0.25 / obj.Fs;            % detections sit on the sample grid
if ~(isfinite(tol) && tol > 0)
    tol = 1e-7;
end
det = iv;                       % matched as detected, never as moved
for j = 1:size(A, 1)
    hit = abs(det(:, 1) - A(j, 1)) <= tol & abs(det(:, 2) - A(j, 2)) <= tol;
    iv(hit, 1) = A(j, 3);
    iv(hit, 2) = A(j, 4);
    row(hit) = j;
end
adjusted = row > 0;
end
