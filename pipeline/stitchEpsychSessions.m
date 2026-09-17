function [Data, Info] = stitchEpsychSessions(files, opts)
%stitchEpsychSessions  Join several Epsych2 session files into one session, in chronological order.
%   [DATA, INFO] = stitchEpsychSessions(files) loads every Epsych2 session
%   file in FILES (variables Data + Info, see readEpsychSession) and joins
%   them into one session, as if Epsych2 had run once: the trials of the
%   earliest session first, then those of the next, and so on. The order is
%   always chronological, whatever order FILES are given in: by
%   Info.StartTime, or by the first trial's computerTimestamp for a session
%   without a StartTime. The source files are only read.
%
%   DATA is one struct element per trial, as Epsych2 writes it, plus
%     StitchPart       the session the trial came from (1 = the earliest)
%     StitchPartTrial  the trial's position in that session's Data
%   TrialIndex, when present, is renumbered 1..N across the sessions. A
%   parameter that some sessions lack is added to their trials as []. TrialID
%   still indexes the TrialTable of the trial's own session
%   (INFO.Stitch.Parts(StitchPart).Info.TrialTable).
%
%   INFO is the earliest session's Info plus Info.Stitch:
%     Tool, Created
%     Parts   struct array, in stitched order: File, Name, Bytes, StartTime
%             (the time the order was taken from), NTrials, Info (that
%             session's own Info)
%
%   stitchEpsychSessions(files, OutFile=f) also saves Data and Info to F
%   (-v7, written to a temporary file and renamed into place).
%
%   Errors
%     stitchEpsychSessions:TooFew           fewer than two different files
%     stitchEpsychSessions:AlreadyStitched  a file is itself a stitched session
%     stitchEpsychSessions:Subject          the sessions name different subjects
%     stitchEpsychSessions:NoStartTime      a session has no StartTime and no trial timestamps
%     stitchEpsychSessions:Overlap          a session starts before the previous one's last trial
%   and readEpsychSession:NotFound / NotEpsych for a file that is not an
%   Epsych2 session.
%
%   See also readEpsychSession, epsychSessionMeta, stitchCopySessions,
%   copySessions.

arguments
    files string
    opts.OutFile (1,1) string = ""
end

files = unique(files(:), 'stable');
n = numel(files);
if n < 2
    error('stitchEpsychSessions:TooFew', 'Stitching needs at least two different session files (got %d).', n);
end

D = cell(n, 1);
start = NaT(n, 1);
subject = strings(n, 1);
parts = struct('File', cell(n, 1), 'Name', "", 'Bytes', 0, 'StartTime', NaT, 'NTrials', 0, 'Info', []);
for k = 1:n
    meta = epsychSessionMeta(files(k));   % errors unless the file holds Data and Info
    L = load(files(k), 'Data', 'Info');
    if ~isstruct(L.Info)
        error('readEpsychSession:NotEpsych', 'Info in %s is not a struct.', files(k));
    end
    d = L.Data;
    if isempty(d)
        d = struct([]);
    elseif ~isstruct(d)
        error('readEpsychSession:NotEpsych', 'Data in %s is not a struct array.', files(k));
    end
    if isfield(L.Info, 'Stitch') || isfield(d, 'StitchPart') || isfield(d, 'StitchPartTrial')
        error('stitchEpsychSessions:AlreadyStitched', '%s is already a stitched session.', files(k));
    end
    D{k} = reshape(d, 1, []);

    t = meta.startTime;
    if isnat(t) && ~isempty(d) && isfield(d, 'computerTimestamp') && isdatetime(d(1).computerTimestamp)
        t = d(1).computerTimestamp;
    end
    if isnat(t)
        error('stitchEpsychSessions:NoStartTime', ...
            '%s has no Info.StartTime and no trial timestamps, so its place in time is unknown.', files(k));
    end
    start(k) = unzoned(t);
    subject(k) = meta.subject;

    [~, name, ext] = fileparts(files(k));
    listing = dir(files(k));
    parts(k).File = files(k);
    parts(k).Name = name + ext;
    parts(k).Bytes = listing.bytes;
    parts(k).StartTime = start(k);
    parts(k).NTrials = numel(d);
    parts(k).Info = L.Info;
end

named = unique(subject(subject ~= ""));
if numel(named) > 1
    error('stitchEpsychSessions:Subject', 'The sessions belong to different subjects: %s.', strjoin(named, ", "));
end

[~, order] = sort(start);
for j = 2:n
    prev = D{order(j - 1)};
    if isempty(prev) || ~isfield(prev, 'computerTimestamp') || ~isdatetime(prev(end).computerTimestamp)
        continue
    end
    last = unzoned(prev(end).computerTimestamp);
    if ~isnat(last) && last > start(order(j))
        error('stitchEpsychSessions:Overlap', '%s starts (%s) before the last trial of %s ended (%s).', ...
            parts(order(j)).Name, string(start(order(j))), parts(order(j - 1)).Name, string(last));
    end
end

names = cell(0, 1);
for k = order.'
    f = fieldnames(D{k});
    names = [names; f(~ismember(f, names))]; %#ok<AGROW>
end
chunks = cell(1, n);
for j = 1:n
    d = D{order(j)};
    if isempty(d); continue; end
    for f = setdiff(names, fieldnames(d), 'stable').'
        [d.(f{1})] = deal([]);
    end
    d = orderfields(d, names);
    [d.StitchPart] = deal(j);
    c = num2cell(1:numel(d));
    [d.StitchPartTrial] = c{:};
    chunks{j} = d;
end
Data = [chunks{:}];
if isfield(Data, 'TrialIndex')
    c = num2cell(1:numel(Data));
    [Data.TrialIndex] = c{:};
end

Info = parts(order(1)).Info;
Info.Stitch = struct('Tool', "stitchEpsychSessions", ...
    'Created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'Parts', parts(order));

if opts.OutFile ~= ""
    S = struct();
    S.Data = Data;
    S.Info = Info;
    EphysDataset.saveAtomically(opts.OutFile, S, "-v7");
end
end


function t = unzoned(t)
if ~isempty(t.TimeZone)
    t.TimeZone = '';
end
end
