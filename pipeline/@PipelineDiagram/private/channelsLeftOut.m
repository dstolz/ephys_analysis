function L = channelsLeftOut(cfg, d)
%channelsLeftOut  The channels every step leaves out, for the diagrams.
%   L = channelsLeftOut(CFG, D) mirrors EphysDataset.excludedChannels for
%   the pipeline config CFG and the dataset D (an EphysDataset, or [] for
%   none), but reads Leave out bad channels (Artifacts.ExcludeBadChannels)
%   from CFG, as the pipeline will run it, rather than from D's
%   ArtifactConfig, which the pipeline sets from CFG only when it runs.
%     on      Artifacts.ExcludeBadChannels
%     probe   D's ExcludeChannels (the Probe tab)
%     marked  D's BadChannels, whether or not the box is ticked
%     bad     the BadChannels in force (none while the box is off)
%     source  D's BadChannelsSource: "suggested", "manual", or "" (never
%             set: the first read works them out, prepareBadChannels)
%     all     probe and bad, sorted
%     text    a short label for the bad channels: "3, 7 (set by hand)",
%             "none (suggested)", "worked out at the first read", "each
%             dataset's own" (no D), or "" while the box is off
%
%   See also EphysDataset.excludedChannels, EphysDataset.prepareBadChannels.

L = struct('on', logical(cfg.Artifacts.ExcludeBadChannels), ...
    'probe', double.empty(1, 0), 'marked', double.empty(1, 0), 'bad', double.empty(1, 0), ...
    'source', "", 'all', double.empty(1, 0), 'text', "");
if ~isempty(d)
    L.probe = unique(d.ExcludeChannels);
    L.marked = unique(d.BadChannels);
    L.source = string(d.BadChannelsSource);
end
if isempty(L.probe); L.probe = double.empty(1, 0); end
if isempty(L.marked); L.marked = double.empty(1, 0); end
if L.on
    L.bad = L.marked;
end
L.all = unique([L.probe, L.bad]);
if isempty(L.all); L.all = double.empty(1, 0); end

if ~L.on
    return
end
if isempty(d)
    L.text = "each dataset's own";
elseif L.source == ""
    L.text = "worked out at the first read";
else
    list = "none";
    if ~isempty(L.bad); list = EphysDataset.formatChannelList(L.bad); end
    L.text = list + " (" + ternary(L.source == "manual", "set by hand", L.source) + ")";
end
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
