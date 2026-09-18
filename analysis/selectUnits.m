function [st, meta] = selectUnits(src, usel)
%selectUnits  Spike trains of the chosen sorted units or detection channels.
%   [ST, META] = selectUnits(SRC, USEL) loads spike times for the dataset SRC
%   (loadAnalysisSource) through SRC.outputs (cached when it has CacheData)
%   and returns
%     ST     {nUnits x 1} spike times, s (recording-relative, the clock of
%            the digital events)
%     META   table, one row per unit: label, unitId, class, channel (1-based
%            recording channel), channelName, shank, x, y (probe position,
%            um; NaN when unknown), nSpikes
%   Sorted units ("units") and threshold detections ("detected", one
%   "unit" per channel, class "det") share every later step.
%
%   USEL fields (EphysAnalysisConfig.defaults("UnitSelection"); a struct or
%   [] for the defaults)
%     source    "units": the sorted units -- the spikes file's units when
%               it has them, else the sorting folder (DatasetOutputs.
%               readUnits); "detected": the spikes file's detections
%     classes   sorted-unit classes kept, e.g. ["su" "mua"] ([] = all)
%     groups    phy groups kept ([] = all)
%     ids       unit ids (units) or channels (detected) kept ([] = all)
%     channels  1-based recording channels kept ([] = all)
%     shanks    shanks kept ([] = all; detected: from the probe map)
%     maxUnits  at most this many, in order
%
%   Errors: selectUnits:NoUnits, selectUnits:NoDetected, selectUnits:NoneLeft,
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
            error('selectUnits:NoUnits', '%s has no sorted units (no spikes file with units, no sorting folder).', src.name);
        end
        if src.unitsFrom == "spikes"
            S = out.load("spikes", "units");
            U = S.units;
        else
            U = out.readUnits();
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
        groups = string(col(U, 'group', strings(nU, 1)));
        st = cellfun(@(x) double(x(:)), U.times(:), 'UniformOutput', false);
        keep = true(nU, 1);
        if ~isempty(usel.classes); keep = keep & ismember(meta.class, usel.classes); end
        if ~isempty(usel.groups);  keep = keep & ismember(groups, usel.groups); end
        if ~isempty(usel.ids);     keep = keep & ismember(meta.unitId, usel.ids); end
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
    error('selectUnits:NoneLeft', '%s: no %s is left after the unit selection.', src.name, ...
        replace(usel.source, ["units" "detected"], ["sorted unit" "detection channel"]));
end
st = st(idx);
meta = meta(idx, :);
end


function v = col(U, f, default)
%col  Column-shaped field of a units struct, or the default.
v = default;
if isfield(U, f) && numel(U.(f)) == numel(default)
    v = reshape(U.(f), [], 1);
end
end
