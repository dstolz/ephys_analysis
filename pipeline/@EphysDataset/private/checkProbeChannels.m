function checkProbeChannels(probeFile, nChanBin, who)
%checkProbeChannels  Warn when the probe's channel count differs from n_chan_bin.
%   The probe has passed probeMapProblems. n_chan, but never fewer than the
%   mapped sites: an n_chan written from a 0-based map's max index is one
%   short of numel(chanMap); prefer the map. WHO names the caller in the
%   warning identifier.
probe = readJsonFile(probeFile);
nProbe = max(double(probe.n_chan), numel(probe.chanMap));
if nProbe ~= nChanBin
    warning(['EphysDataset:' char(who) ':ProbeChannelMismatch'], ...
        'Probe channel count (%d) differs from n_chan_bin (%d).', nProbe, nChanBin);
end
end
