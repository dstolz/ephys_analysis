function S = sessionTable(names, keys, opts)
%sessionTable  One row per dataset of a session figure: who, when, and the label it is drawn with.
%   S = sessionTable(NAMES, KEYS, NamePattern=, AcqDates=, Folders=, Tags=) has one
%   row per dataset (NAMES and KEYS: string vectors of one length), in the
%   order given:
%     index     Index= (default 1..n): the runner passes its dataset indices
%     key       the dataset key (the Data tab's Key column)
%     name      the dataset name
%     folder    its output folder (Folders=; "" when not given)
%     starred   the dataset is starred: its folder's favorites file
%               (DatasetFavorites); false without a folder
%     tags      the dataset's tags as text (Tags=; TagSet.toText with the
%               export delimiter ";", "" when none)
%     subject   the SubjectID token of NamePattern (subjectAndDate), "" when
%               unknown
%     date      datetime: AcqDates (the recording's own start) where given,
%               else the Date and Time tokens of the name
%               (EphysDataset.nameIdentity); NaT when unknown
%     dateText  "yyyy-MM-dd" ("" when unknown)
%     label     "<subject> <dateText>", else the name; made unique with
%               " (2)", " (3)" in table order
%   Sort=true orders the rows by date (NaT last), then name, before the
%   labels are made unique (EphysAnalysisRunner.sessionTable does). The only
%   I/O is each folder's favorites file (a dataset's star). AcqDates and
%   Folders may be one value for every row. Tags= is the text of each row's
%   tags (a string vector, "" for none; one value or one per row), as the
%   runner reads them from the manifests (loadAnalysisSource).
%
%   See also combineSessions, figureSessionCompute, subjectAndDate,
%   EphysAnalysisRunner.sessionTable.

arguments
    names (:,1) string
    keys (:,1) string
    opts.NamePattern (1,1) string = EphysDataset.DefaultNamePattern
    opts.AcqDates (:,1) datetime = NaT
    opts.Folders (:,1) string = ""
    opts.Tags (:,1) string = ""
    opts.Index (:,1) double = []
    opts.Sort (1,1) logical = false
end

n = numel(names);
if numel(keys) ~= n
    error('sessionTable:Size', 'NAMES has %d entries and KEYS %d.', n, numel(keys));
end
acq = expand(opts.AcqDates, n, NaT, "AcqDates");
folder = expand(opts.Folders, n, "", "Folders");
tags = expand(opts.Tags, n, "", "Tags");
index = opts.Index;
if isempty(index); index = (1:n).'; end
if numel(index) ~= n
    error('sessionTable:Size', 'Index has %d entries for %d datasets.', numel(index), n);
end
[subject, dateText] = subjectAndDate(names, opts.NamePattern, acq);
date = NaT(n, 1);
for k = 1:n
    if ~isnat(acq(k))
        date(k) = acq(k);
    else
        id = EphysDataset.nameIdentity(names(k), opts.NamePattern);
        if id.ok && isdatetime(id.recordingStart) && ~isnat(id.recordingStart)
            date(k) = id.recordingStart;
        end
    end
end
date.Format = 'yyyy-MM-dd HH:mm:ss';
key = keys;
name = names;
starred = false(n, 1);
for k = reshape(find(folder ~= "" & isfolder(folder)), 1, [])
    try
        fav = DatasetFavorites(folder(k), Name=names(k));
        starred(k) = fav.Dataset;
    catch   % unreadable: no star
    end
end
S = table(index, key, name, folder, starred, tags, subject, date, dateText);
if opts.Sort && n > 1
    [~, order] = sortrows(table(S.date, S.name), [1 2], 'ascend', 'MissingPlacement', 'last');
    S = S(order, :);
end
label = S.name;
known = S.subject ~= "" & S.dateText ~= "";
label(known) = S.subject(known) + " " + S.dateText(known);
S.label = uniqueLabels(label);
end


function v = expand(v, n, fill, what)
%expand  One value per row: a scalar repeated, [] filled.
if isempty(v)
    v = repmat(fill, n, 1);
elseif isscalar(v)
    v = repmat(v, n, 1);
elseif numel(v) ~= n
    error('sessionTable:Size', '%s has %d entries for %d datasets.', what, numel(v), n);
end
v = v(:);
end


function L = uniqueLabels(L)
%uniqueLabels  Repeated labels get " (2)", " (3)", ... in order (the first keeps its own).
for k = 2:numel(L)
    base = L(k);
    n = 1;
    while any(L(1:k-1) == L(k))
        n = n + 1;
        L(k) = base + " (" + n + ")";
    end
end
end
