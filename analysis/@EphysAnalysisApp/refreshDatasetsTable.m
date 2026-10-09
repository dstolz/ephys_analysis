function refreshDatasetsTable(obj)
%refreshDatasetsTable  One row per dataset: Run tick and what it holds.
%   Signals, units, detections and behavior come from which files exist;
%   trials, pairing and duration once the dataset's source has been loaded
%   (making it active loads it). Subject and Date (the day recorded) come
%   from the name pattern and, in a project, the recording's own start.
%
%   The rows are in the order of the last header click (DatasetsSort), put
%   there each time the table is filled, so the sort survives a tick or a
%   new active dataset. The last column, Idx (hidden), is the dataset's
%   place in the Runner: ticks, clicks and the active row go through it,
%   never through the row, so any order is safe.
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
acq = NaT(n, 1);
if ~isempty(r.Project)
    pk = r.Project.findByKey(r.Keys);
    for k = reshape(find(pk > 0), 1, [])
        acq(k) = r.Project.Datasets(pk(k)).AcqDate;
    end
end
[Subject, Date] = subjectAndDate(Name, string(r.Config.Source.NamePattern), acq);
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
        Units(k) = mark(out.has("sorting"));   % the spikes file holds detections only
        Detected(k) = mark(out.has("spikes"));
    end
end
Idx = (1:n).';
T = table(Run, Name, Subject, Date, Key, LFP, MUA, SPIKE, AUX, Units, Detected, Behavior, Trials, Pairing, Duration, Idx);
T = TableSort.apply(T, obj.DatasetsSort);
obj.DatasetsTable.Data = T;
obj.DatasetsTable.ColumnEditable = [true false(1, width(T) - 1)];
removeStyle(obj.DatasetsTable);
row = find(T.Idx == obj.ActiveIdx, 1);
if ~isempty(row)
    addStyle(obj.DatasetsTable, uistyle("BackgroundColor", [0.86 0.93 1]), "row", row);
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
