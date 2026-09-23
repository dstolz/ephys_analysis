function L = channelLayout(obj, opts)
%channelLayout  Where each recording channel sits on the assigned probe.
%   L = ds.channelLayout() reads ProbeFile (a Kilosort4 probe .json: chanMap,
%   xc, yc, kcoords) and places the amplifier channels, in recording order
%   (the columns readWindowUV and readChunkUV return).
%   L = ds.channelLayout(ProbeFile=F) reads F instead when it is not "": the
%   probe a dataset is used with when it has none of its own (the pipeline
%   config's default probe, EphysPipeline.probeFor). L has:
%     hasProbe  true when ProbeFile is readable and places at least one channel
%     shank     [1 x nChan] the channel's shank (kcoords; 1 when the probe
%               has none), NaN when the channel is not on the probe
%     x, y      [1 x nChan] the site's position (xc, yc) in um, NaN off the probe
%     order     [1 x nChan] the channels as they sit on the probe: by shank,
%               then from the top of the shank down (yc descending, as the
%               Probe tab draws it), then left to right; channels not on
%               the probe last, in recording order
%     shanks    [1 x k] the shanks holding at least one channel, ascending
%   Probe chanMap values are .bin rows, 0-based: channel c (in recording
%   order) sits at the site whose chanMap value is c - 1, as Kilosort4 and
%   readPhyUnits read the probe. The hardware numbers (ChannelNumbers) play
%   no part, so a recording with a channel disabled at acquisition needs a
%   probe that accounts for the gap, as for sorting. Without a usable probe
%   every channel is off it and ORDER is 1:nChan. The file is read on every
%   call.
%
%   See also EphysDataset.runKilosort, EphysDataset.readPhyUnits, EphysPipeline.probeFor.

arguments
    obj (1,1) EphysDataset
    opts.ProbeFile (1,1) string = ""
end
probeFile = opts.ProbeFile;
if probeFile == ""; probeFile = obj.ProbeFile; end

nChan = obj.NumChannels;
if ~isfinite(nChan); nChan = numel(obj.ChannelNumbers); end
L = struct('hasProbe', false, 'shank', NaN(1, nChan), 'x', NaN(1, nChan), ...
    'y', NaN(1, nChan), 'order', 1:nChan, 'shanks', zeros(1, 0));
if nChan == 0 || probeFile == ""; return; end
probe = readJsonFile(probeFile, ErrorOnFail=false);
if ~isstruct(probe) || ~isfield(probe, 'xc') || ~isfield(probe, 'yc'); return; end

try
    xc = double(probe.xc(:));
    yc = double(probe.yc(:));
    nSite = min(numel(xc), numel(yc));
    chanMap = (0:nSite - 1).';
    if isfield(probe, 'chanMap') && numel(probe.chanMap) >= nSite
        chanMap = double(probe.chanMap(1:nSite));
        chanMap = chanMap(:);
    end
    kc = ones(nSite, 1);
    if isfield(probe, 'kcoords') && numel(probe.kcoords) >= nSite
        kc = double(probe.kcoords(1:nSite));
        kc = kc(:);
    end
catch
    return      % fields of the wrong type: treat as no probe
end

[onProbe, site] = ismember(0:nChan - 1, chanMap);   % channel c <-> chanMap value c - 1
if ~any(onProbe); return; end
L.hasProbe = true;
L.shank(onProbe) = kc(site(onProbe));
L.x(onProbe) = xc(site(onProbe));
L.y(onProbe) = yc(site(onProbe));
L.shanks = unique(L.shank(onProbe));

% Off the probe sorts last (Inf shank), then top down, left to right.
key = [L.shank(:), -L.y(:), L.x(:), (1:nChan).'];
key(~onProbe, 1) = Inf;
key(~onProbe, 2:3) = 0;
[~, ord] = sortrows(key);
L.order = ord(:).';
end
