function renderReviewUnitShank(obj)
%renderReviewUnitShank  Draw the selected unit's spikes on the shank it was detected on.
%   Every sorted channel on the unit's shank (the peak channel's, as the
%   Shank column gives it) is drawn at its site on the probe
%   (channel_positions.npy; without it, in a column in channel order),
%   labeled with its name or recording channel:
%     - the unit's spikes as thin lines (Spikes; at most the number beside
%       it, picked at random, the same ones each time),
%     - their mean with an error band (Mean +/-; SD, SEM or none).
%   The peak channel is drawn in red. The spikes are cut from the sorted
%   .bin by EphysDataset.readPhyWaveforms, prepared as Kilosort4 saw them
%   (referenced and high-passed, not whitened), in the templates' units; a
%   scale bar gives the amplitude and time. The last unit's spikes are kept
%   (ReviewSpikeWaves), so changing what is drawn does not read them again.
%   When they cannot be read (the .bin is gone), the unit's template is
%   drawn instead, the subtitle says so and the status bar says why. With no
%   unit selected the axes asks for one. The drawing is drawUnitOnShank's,
%   which Plot in new figure (onReviewUnitsFigure) shares.
%
%   See also EphysPipelineApp.renderReviewPlots, EphysDataset.readPhyWaveforms.

ax = obj.ReviewUnitShankAxes;
cla(ax, 'reset');
R = obj.ReviewData;
u = obj.ReviewSelectedUnit;
chans = unitShankChannels(R, u);
C = struct([]);
if ~isempty(chans)
    C = obj.reviewSpikeWaves(chans);         % read once per unit and count
end
opts = struct('spikes', obj.ReviewShankSpikesCheckBox.Value, 'mean', obj.ReviewShankMeanCheckBox.Value, ...
    'band', string(obj.ReviewShankBandDropDown.Value));
note = drawUnitOnShank(ax, R, u, chans, C, opts);
if note.text ~= ""
    obj.setStatus(note.text, note.hint);
end
end
