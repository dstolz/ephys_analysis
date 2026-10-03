function [st, meta] = selectUnits(src, usel)
%selectUnits  Spike trains of the chosen sorted units or detection channels.
%   [ST, META] = selectUnits(SRC, USEL) loads spike times for the dataset SRC
%   (loadAnalysisSource) through SRC.outputs (cached when it has CacheData)
%   and returns
%     ST     {nUnits x 1} spike times, s (recording-relative, on the
%            continuous clock of the signals: (sample-1)/Fs; see epochTable's
%            t0Continuous for the digital events on that clock)
%     META   table, one row per unit: label, unitId, class, channel (1-based
%            recording channel), channelName, shank, x, y (probe position,
%            um; NaN when unknown), nSpikes
%   Shanks are numbered as in the probe map (kcoords) for both sources: a
%   sorted unit on a mapped channel takes its channel's shank, because the
%   sorter's own shank numbers (channel_shanks.npy) need not match them.
%   Sorted units ("units") and threshold detections ("detected", one
%   "unit" per channel, class "det") share every later step.
%
%   USEL fields (EphysAnalysisConfig.defaults("UnitSelection"); a struct or
%   [] for the defaults)
%     source    "units": the sorted units in the sorting folder
%               (DatasetOutputs.load("sorting"), read once per dataset when
%               the outputs cache data); "detected": the spikes file's
%               threshold detections
%     classes   sorted-unit classes kept, e.g. ["su" "mua"] ([] = all)
%     groups    phy groups kept ([] = all)
%     ids       unit ids (units) or channels (detected) kept ([] = all)
%     channels  1-based recording channels kept ([] = all)
%     shanks    shanks kept ([] = all): the probe map's kcoords values
%     maxUnits  at most this many, in order
%     quality   good-unit criteria (unitQualityCriteria's fields) and
%               enabled: with enabled, the sorted units get their quality
%               metrics (EphysDataset.unitQuality with the dataset, else
%               unitQualityOf on the recording's length, without SNR; the
%               sort folder's cache when current), only those that meet the
%               criteria are kept (unitQualityPass), and META gains
%               firingRate, isiViolationsRatio, presenceRatio,
%               amplitudeCutoff, snr, driftPtp, qualityPass, qualityFails
%               and qualityUnknown
%
%   Errors: selectUnits:NoUnits, selectUnits:NoDetected, selectUnits:NoneLeft, selectUnits:NoQuality,
%   selectUnits:BadSource.
%
%   See also loadAnalysisSource, psth, firingRate, unitSummary.

arguments
    src (1,1) struct
    usel = []
end

if isempty(usel); usel = struct(); end
[usel, unknown] = EphysAnalysisConfig.normalizeSection("UnitSelection", usel);
if ~isempty(unknown)
    error('selectUnits:BadSource', 'Unknown unit-selection field(s): %s.', strjoin(unknown, ", "));
end
out = src.outputs;
switch usel.source
    case "units"
        if ~src.hasUnits
            error('selectUnits:NoUnits', '%s has no sorted units (no sorting folder).', src.name);
        end
        q = usel.quality;
        if q.enabled
            U = withQuality(src, q);
        else
            U = out.load("sorting");
        end
        nU = numel(U.unitId);
        meta = table(col(U, 'label', strings(nU, 1)), double(U.unitId(:)), col(U, 'class', strings(nU, 1)), ...
            double(col(U, 'channel', NaN(nU, 1))), col(U, 'channelName', strings(nU, 1)), ...
            double(col(U, 'shank', zeros(nU, 1))), double(col(U, 'x', NaN(nU, 1))), double(col(U, 'y', NaN(nU, 1))), ...
            double(col(U, 'nSpikes', NaN(nU, 1))), ...
            'VariableNames', {'label', 'unitId', 'class', 'channel', 'channelName', 'shank', 'x', 'y', 'nSpikes'});
        meta.label = string(meta.label);
        meta.class = string(meta.class);
        meta.channelName = string(meta.channelName);
        [pShank, pX] = probeSites(src.probe, meta.channel);
        onMap = ~isnan(pX);
        meta.shank(onMap) = pShank(onMap);
        groups = string(col(U, 'group', strings(nU, 1)));
        st = cellfun(@(x) double(x(:)), U.times(:), 'UniformOutput', false);
        keep = true(nU, 1);
        if ~isempty(usel.classes); keep = keep & ismember(meta.class, usel.classes); end
        if ~isempty(usel.groups);  keep = keep & ismember(groups, usel.groups); end
        if ~isempty(usel.ids);     keep = keep & ismember(meta.unitId, usel.ids); end
        if q.enabled
            [pass, why, unknown] = unitQualityPass(U, rmfield(q, 'enabled'));
            for m = ["firingRate" "isiViolationsRatio" "presenceRatio" "amplitudeCutoff" "snr" "driftPtp"]
                meta.(m) = double(U.(m)(:));
            end
            meta.qualityPass = pass;
            meta.qualityFails = why;
            meta.qualityUnknown = unknown;
            keep = keep & pass;
        end
    case "detected"
        if ~src.hasDetected
            error('selectUnits:NoDetected', '%s has no threshold detections (no spikes file with detected spikes).', src.name);
        end
        S = out.load("spikes", "detected");
        D = S.detected;
        ch = double(D.channels(:));
        nU = numel(ch);
        names = strings(nU, 1);
        if isfield(D, 'channelNames') && numel(D.channelNames) == nU
            names = reshape(string(D.channelNames), [], 1);
        end
        label = names;
        label(label == "") = "ch" + ch(label == "");
        [shank, x, y] = probeSites(src.probe, ch);
        st = cellfun(@(v) double(v(:)), reshape(D.ts, [], 1), 'UniformOutput', false);
        nSpikes = cellfun(@numel, st);
        meta = table(label, ch, repmat("det", nU, 1), ch, names, shank, x, y, nSpikes, ...
            'VariableNames', {'label', 'unitId', 'class', 'channel', 'channelName', 'shank', 'x', 'y', 'nSpikes'});
        keep = true(nU, 1);
        if ~isempty(usel.ids); keep = keep & ismember(meta.unitId, usel.ids); end
    otherwise
        error('selectUnits:BadSource', 'source must be "units" or "detected" (got "%s").', usel.source);
end
if ~isempty(usel.channels); keep = keep & ismember(meta.channel, usel.channels); end
if ~isempty(usel.shanks);   keep = keep & ismember(meta.shank, usel.shanks); end
idx = find(keep);
if isfinite(usel.maxUnits) && numel(idx) > usel.maxUnits
    idx = idx(1:usel.maxUnits);
end
if isempty(idx)
    msg = sprintf('%s: no %s is left after the unit selection.', src.name, ...
        replace(usel.source, ["units" "detected"], ["sorted unit" "detection channel"]));
    if ~isempty(usel.shanks)
        msg = [msg sprintf(' Its shanks are numbered %s.', strjoin(string(unique(meta.shank)).', ", "))];
    end
    error('selectUnits:NoneLeft', '%s', msg);
end
st = st(idx);
meta = meta(idx, :);
end


function U = withQuality(src, q)
%withQuality  The sorted units with their quality metrics.
%   With the dataset (its recording at hand), EphysDataset.unitQuality: the
%   sort's length and, when an SNR threshold is set, the recording's noise.
%   Without it, EphysDataset.unitQualityOf on the recording's length as
%   SRC knows it (fs x durationSec), and no SNR. Both use the sort
%   folder's quality_metrics.json when it is current.
out = src.outputs;
[U, info] = out.readUnits();
if ~isempty(out.Dataset)
    U = out.Dataset.unitQuality(U, info, Noise=isfinite(q.snrMin));
    return
end
n = round(src.fs * src.durationSec);
if ~(n > 0)
    error('selectUnits:NoQuality', ...
        '%s: the quality metrics need the recording''s length, and it is not known here.', src.name);
end
U = EphysDataset.unitQualityOf(U, info, NumSamples=n, NumSamplesSource="the dataset's metadata (fs x durationSec)");
end


function v = col(U, f, default)
%col  Column-shaped field of a units struct, or the default.
v = default;
if isfield(U, f) && numel(U.(f)) == numel(default)
    v = reshape(U.(f), [], 1);
end
end
