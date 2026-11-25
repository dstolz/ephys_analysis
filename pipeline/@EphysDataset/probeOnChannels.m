function [P, info] = probeOnChannels(P, channelNumbers)
%probeOnChannels  A probe with its sites matched to a recording's channels by hardware number.
%   [P, INFO] = EphysDataset.probeOnChannels(P, CHANNELNUMBERS) takes a
%   Kilosort4 probe (the decoded .json, or its file) and the recording's
%   0-based hardware channel numbers, one per channel in recording order
%   (EphysDataset.ChannelNumbers), and returns the probe with its chanMap
%   in the recording's .bin rows (0-based). A probe's chanMap values are
%   the hardware channel numbers of a full recording, which, for a full
%   recording, are its rows too: such a probe is returned as it is.
%
%   A recording with channels disabled at acquisition (RHX lets a channel
%   be switched off) holds fewer channels than the probe has sites, and its
%   rows no longer match the chanMap values. When every hardware number is
%   a chanMap value and they are not just 0..n-1, each site is matched to
%   the row recording its hardware number: the sites of channels not
%   recorded are left out, as excluded channels are (every per-site field:
%   chanMap, xc, yc, kcoords and any other field with one value per site),
%   and n_chan is the recording's channel count. Otherwise (hardware
%   numbers outside the probe, or none) P is returned as it is.
%
%   INFO has:
%     remapped      true when the sites were matched by hardware number
%     missing       [1 x m] the chanMap values (hardware numbers) of the
%                   sites left out, ascending; empty when not remapped
%     probeChannel  [1 x n] each recording channel's chanMap value in the
%                   probe as given: its hardware number when remapped,
%                   else its row - 1. Two recordings on one probe share a
%                   channel where these agree
%                   (EphysPipelineApp.saveLocalReference uses it).
%
%   EphysDataset.recordedProbe calls it with a dataset's channels;
%   loadAnalysisSource with the manifest's (metadata.channel_numbers).
%
%   See also EphysDataset.recordedProbe, EphysDataset.channelLayout, writeProbeMap.

if isstring(P) || ischar(P)
    P = readJsonFile(string(P), ErrorOnFail=false);
end
hw = reshape(double(channelNumbers), 1, []);
n = numel(hw);
info = struct('remapped', false, 'missing', zeros(1, 0), 'probeChannel', 0:n - 1);
if n == 0 || isequal(hw, 0:n - 1) || ~isstruct(P) || ~isscalar(P) || ~isfield(P, 'chanMap')
    return   % no numbers, a full recording (rows are chanMap values), or no map
end
try
    cm = double(P.chanMap(:));
catch
    return
end
if ~all(ismember(hw, cm))
    return   % hardware numbers the probe does not have: its chanMap values are rows, as before
end

[rec, row] = ismember(cm, hw);
nSite = numel(cm);
for f = string(fieldnames(P)).'
    v = P.(f);
    if f ~= "n_chan" && (isnumeric(v) || islogical(v)) && numel(v) == nSite && nSite > 1
        P.(f) = v(rec);
    end
end
P.chanMap = reshape(row(rec) - 1, size(P.chanMap));
P.n_chan = n;
info.remapped = true;
info.missing = reshape(sort(cm(~rec)), 1, []);
info.probeChannel = hw;
end
