function refreshDatasetsTable(obj)
%refreshDatasetsTable  One row per dataset: Run tick and what it holds.
%   Signals, units, detections and behavior come from which files exist;
%   trials, pairing and duration once the dataset's source has been loaded
%   (making it active loads it).
r = obj.Runner;
if isempty(r) || isempty(r.Keys)
    obj.DatasetsTable.Data = table();
    return
end
n = numel(r.Keys);
mark = @(tf) ternary(tf, "✓", "");
Run = reshape(obj.Ticked, [], 1);
Name = reshape(r.Names, [], 1);
Key = reshape(r.Keys, [], 1);
[LFP, MUA, SPIKE, AUX, Units, Detected, Behavior, Trials, Pairing] = deal(strings(n, 1));
Duration = NaN(n, 1);
for k = 1:n
    out = r.Outputs(k);
    LFP(k) = mark(out.has("LFP")); MUA(k) = mark(out.has("MUA"));
    SPIKE(k) = mark(out.has("SPIKE")); AUX(k) = mark(out.has("AUX"));
    Behavior(k) = mark(out.has("behavior"));
    key = char(r.Keys(k));
    if isKey(r.Sources, key)
        src = r.Sources(key);
        Units(k) = mark(src.hasUnits);
        Detected(k) = mark(src.hasDetected);
        if src.hasBehavior; Trials(k) = string(src.nTrials); end
        if src.hasTrials
            Pairing(k) = "paired";
            if isstruct(src.pairing) && isfield(src.pairing, 'status'); Pairing(k) = string(src.pairing.status); end
        elseif src.hasBehavior
            Pairing(k) = "not paired";
        end
        Duration(k) = round(src.durationSec, 1);
    else
        Units(k) = mark(out.has("spikes") || out.has("sorting"));
        Detected(k) = mark(out.has("spikes"));
    end
end
T = table(Run, Name, Key, LFP, MUA, SPIKE, AUX, Units, Detected, Behavior, Trials, Pairing, Duration);
obj.DatasetsTable.Data = T;
obj.DatasetsTable.ColumnEditable = [true false(1, width(T) - 1)];
if obj.ActiveIdx >= 1 && obj.ActiveIdx <= n
    removeStyle(obj.DatasetsTable);
    addStyle(obj.DatasetsTable, uistyle("BackgroundColor", [0.86 0.93 1]), "row", obj.ActiveIdx);
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
