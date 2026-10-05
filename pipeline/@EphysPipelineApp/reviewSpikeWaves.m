function C = reviewSpikeWaves(obj, chans)
%reviewSpikeWaves  The selected unit's spikes on CHANS, read once and kept.
%   C is the cache (ReviewSpikeWaves): .key (folder, unit, count), .W
%   [samples x channels x spikes] and .info from EphysDataset.readPhyWaveforms,
%   and .err / .errId when the read failed (the .bin is gone; a failed read is
%   tried again). The count is the Review tab's spike spinner, so the shank
%   plot and the waveform insets on the timing plots draw the same spikes.
%
%   See also EphysPreprocessingApp.renderReviewUnitShank, EphysPreprocessingApp.renderReviewPlots.

R = obj.ReviewData;
u = obj.ReviewSelectedUnit;
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
obj.ReviewSpikeWaves = C;
end
