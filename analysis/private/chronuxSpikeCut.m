function [data, counts] = chronuxSpikeCut(train, onsets, twin, timeBase)
%chronuxSpikeCut  One spike train cut into Chronux trials (ChronuxDataset.spikeTrials).
%   [DATA, COUNTS] = chronuxSpikeCut(TRAIN, ONSETS, TWIN, TIMEBASE): TRAIN
%   a struct with field times (s on the continuous clock), ONSETS each
%   trial's time 0, TWIN [a b] s from it. Trial i keeps the spikes with
%   t > ONSETS(i)+a and t <= ONSETS(i)+b (createdatamatpt's half-open
%   rule), stamped from the window's start (TIMEBASE "window") or from the
%   onset ("onset"). DATA is a 1 x nTrials struct array with field times,
%   one per onset (the time base already kept the trials inside the
%   recording); COUNTS the spikes in each.
%
%   See also ChronuxDataset.spikeTrials, chronuxSpikeSpectrum.
if isempty(onsets)
    data = struct('times', cell(1, 0));
    counts = zeros(1, 0);
    return
end
[data, ~, ~, info] = ChronuxDataset().spikeTrials(onsets, twin, Spikes=train, TimeBase=timeBase, Incomplete="keep");
counts = info.counts;
end
