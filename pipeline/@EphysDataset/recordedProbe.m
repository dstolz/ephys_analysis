function [P, info] = recordedProbe(obj, P)
%recordedProbe  The probe as this recording's channels sit on it: sites matched by hardware number.
%   [P, INFO] = ds.recordedProbe(P) is EphysDataset.probeOnChannels(P,
%   ds.ChannelNumbers): P (a Kilosort4 probe, decoded or its file) with its
%   chanMap in this recording's .bin rows. A full recording gets P as it
%   is; a recording with channels disabled at acquisition gets the sites
%   of the channels it recorded, at their rows, the others left out. When
%   the hardware numbers are not known (none, or not one per channel),
%   P is returned as it is and INFO.probeChannel is 0..NumChannels-1.
%
%   channelLayout, the Local reference window, the probe assignment's
%   channel-count check and the sorters (runKilosort, runSpikeInterface: a
%   derived <probe>_recorded.json in the run folder) use it.
%
%   See also EphysDataset.probeOnChannels, EphysDataset.channelLayout.

arguments
    obj (1,1) EphysDataset
    P
end

n = obj.NumChannels;
if ~isfinite(n); n = numel(obj.ChannelNumbers); end
hw = obj.ChannelNumbers;
if numel(hw) ~= n
    hw = 0:n - 1;   % numbers not known: rows are chanMap values
end
[P, info] = EphysDataset.probeOnChannels(P, hw);
end
