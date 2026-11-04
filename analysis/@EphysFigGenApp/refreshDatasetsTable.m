function refreshDatasetsTable(obj)
%refreshDatasetsTable  One row per dataset: Run tick, star and what it holds.
%   Signals, units, detections and behavior come from which files exist;
%   trials, pairing and duration once the dataset's source has been loaded
%   (making it active loads it). Subject and Date (the day recorded) come
%   from the name pattern and, in a project, the recording's own start.
%   Star (the ★ column, a check box) is the dataset's star (Favorites);
%   ticking it stars the dataset (onDatasetsTableEdited). Note (the ✎
%   column) shows "✎" when the dataset has a note (Notes); a click on it
%   opens the notepad (onDatasetNoteClicked). Tags (after Key, read only)
%   are the dataset's tags, ", "-joined: its source's once loaded, else the
%   manifest's (outputTags, read once per dataset, not a whole source).
%
%   The rows are in the order of the last header click (DatasetsSort), put
%   there each time the table is filled, so the sort survives a tick or a
%   new active dataset. The last column, Idx (hidden), is the dataset's
%   place in the Runner: ticks, clicks and the active row go through it,
%   never through the row, so any order is safe.
%
%   The filter above the table is the DatasetBrowser's and shows only some
%   rows: Subject keeps the datasets whose subject is one of those picked or
%   typed (comma-separated, * and ? wildcards, case ignored) and "not" drops
%   those of the subjects given there; Tags keeps those holding any (or all)
%   of the tags picked or typed (a term that is no valid tag matches
%   nothing) and its "not" drops those holding any of the tags given there;
%   Search keeps those whose name, key, subject and tags hold every word
%   typed. Every filter that is set must pass (datasetFilter). The lists are
%   the subjects and tags in use. A hidden row keeps its Run tick (Ticked is
%   per dataset), and FilterLabel says "showing k of n (m ticked hidden)".
%
%   Nothing happens while HoldDatasetViews is set (onScan, which fills
%   the table once): every dataset's files are checked on each fill, a
%   network round trip each over a share.
if obj.HoldDatasetViews; return; end
r = obj.Runner;
if isempty(r) || isempty(r.Keys)
    obj.DatasetsTable.Data = table();
    obj.FilterLabel.Text = "";
    return
end
n = numel(r.Keys);
mark = @(tf) ternary(tf, "✓", "");
Run = reshape(obj.Ticked, [], 1);
Star = false(n, 1);
if numel(obj.Favorites) == n; Star = reshape([obj.Favorites.Dataset], [], 1); end
Note = strings(n, 1);
if numel(obj.Notes) == n; Note(arrayfun(@(d) d.hasNote("dataset"), obj.Notes)) = "✎"; end
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
Tags = strings(n, 1);
sets = cell(1, n);   % each dataset's tag set, for the filter
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
        sets{k} = src.tags;
    else
        Units(k) = mark(out.has("sorting"));   % the spikes file holds detections only
        Detected(k) = mark(out.has("spikes"));
        sets{k} = outputTags(out);   % the manifest, read once (CacheData)
    end
    Tags(k) = TagSet.toText(sets{k}, TagSet.DisplayDelimiter);
end
Idx = (1:n).';
T = table(Run, Star, Note, Name, Subject, Date, Key, Tags, LFP, MUA, SPIKE, AUX, Units, Detected, Behavior, Trials, Pairing, Duration, Idx);
keep = applyFilter(obj, Subject, sets, Name + " " + Key + " " + Subject + " " + Tags);
T = T(keep, :);
T = TableSort.apply(T, obj.DatasetsSort);
obj.DatasetsTable.Data = T;
obj.DatasetsTable.ColumnEditable = [true true false(1, width(T) - 2)];
removeStyle(obj.DatasetsTable);
row = find(T.Idx == obj.ActiveIdx, 1);
if ~isempty(row)
    addStyle(obj.DatasetsTable, uistyle("BackgroundColor", [0.86 0.93 1]), "row", row);
end
end


function keep = applyFilter(obj, subject, sets, text)
%applyFilter  Which datasets (SUBJECT, a column, SETS, a tag set each, and TEXT, what Search looks in) the filters keep.
%   Subject, "not" subject, Tags (any / all of), "not" tags and Search, as
%   the DatasetBrowser's (datasetFilter). Their lists are set to '(any)' and
%   the subjects and tags in use first (a typed value is kept by the
%   editable drop-down), and FilterLabel says how many rows show while any
%   filter is on.
n = numel(subject);
inUse = cellstr(unique(subject(subject ~= ""))).';
voc = TagSet.vocabulary(sets);
syncItems(obj.SubjectFilterDropDown, inUse);
syncItems(obj.NotSubjectFilterDropDown, inUse);
syncItems(obj.TagFilterDropDown, voc);
syncItems(obj.NotTagFilterDropDown, voc);
[keep, active] = datasetFilter(subject, sets, Subjects=obj.SubjectFilterDropDown.Value, ...
    ExcludeSubjects=obj.NotSubjectFilterDropDown.Value, Tags=obj.TagFilterDropDown.Value, ...
    TagMode=obj.TagFilterModeDropDown.Value, ExcludeTags=obj.NotTagFilterDropDown.Value, ...
    Search=obj.SearchFilterField.Value, Text=text);
if ~active
    obj.FilterLabel.Text = "";
else
    msg = sprintf("showing %d of %d", nnz(keep), n);
    nHidden = nnz(~keep & reshape(obj.Ticked, [], 1));
    if nHidden > 0; msg = msg + sprintf(" (%d ticked hidden)", nHidden); end
    obj.FilterLabel.Text = msg;
end
end


function syncItems(dd, inUse)
%syncItems  A filter drop-down lists '(any)' and the values IN USE; its value (picked or typed) stays.
v = dd.Value;
dd.Items = [{'(any)'}, reshape(inUse, 1, [])];
dd.Value = v;
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
