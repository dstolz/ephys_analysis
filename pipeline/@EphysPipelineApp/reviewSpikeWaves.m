function C = reviewSpikeWaves(obj, chans, u)
%reviewSpikeWaves  A unit's spikes on CHANS, the selected unit's read once and kept.
%   C = reviewSpikeWaves(OBJ, CHANS) reads the selected unit's
%   (ReviewSelectedUnit); C = reviewSpikeWaves(OBJ, CHANS, U) unit U's, a row
%   of ReviewData. C is the cache (ReviewSpikeWaves): .key (folder, unit,
%   count), .W [samples x channels x spikes] and .info from
%   EphysDataset.readPhyWaveforms, and .err / .errId when the read failed
%   (the .bin is gone; a failed read is tried again). Only the selected
%   unit's spikes are kept, so another unit's read (Plot in new figure)
%   leaves the shank plot's in place. The count is the Review tab's spike
%   spinner, so the shank plot, the waveform insets on the timing plots and
%   the new figure draw the same spikes.
%
%   See also EphysPipelineApp.renderReviewUnitShank, EphysPipelineApp.renderReviewPlots,
%   EphysPipelineApp.onReviewUnitsFigure.

R = obj.ReviewData;
if nargin < 3; u = obj.ReviewSelectedUnit; end
n = obj.ReviewShankCountSpinner.Value;
key = struct('folder', string(R.folder), 'unit', R.clusterID(u), 'n', n);
C = obj.ReviewSpikeWaves;
if ~isempty(C) && isequal(C.key, key) && C.err == ""
    return
end
C = struct('key', key, 'W', [], 'info', [], 'err', "", 'errId', "");
pointer = obj.Fig.Pointer;
obj.Fig.Pointer = 'watch';
drawnow;
try
    [C.W, C.info] = EphysDataset.readPhyWaveforms(R.folder, R.units.samples{u}, ...
        Channels=chans, MaxSpikes=n);
catch ME
    C.err = string(ME.message);
    C.errId = string(ME.identifier);
end
obj.Fig.Pointer = pointer;
if u == obj.ReviewSelectedUnit
    obj.ReviewSpikeWaves = C;
end
end
