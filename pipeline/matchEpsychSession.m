function match = matchEpsychSession(T, ds, opts)
%matchEpsychSession  Pick the Epsych2 session that belongs to a recording.
%   MATCH = matchEpsychSession(T, ds) where T is a findEpsychSessions table
%   and DS an EphysDataset (or any struct/object with Name, Files and
%   AcqDate). Two strategies:
%     "prefix"  the recording folder name or one of its files starts with the
%               session file stem. That is how Epsych2 names Intan RHX
%               recordings (after the session data file), so it is exact when
%               Epsych2 controlled the recorder. The longest matching stem
%               wins; several sessions with the same longest stem are
%               ambiguous.
%     "time"    the session whose StartTime is nearest to the recording's
%               AcqDate within MaxStartOffsetMin minutes. A session with a
%               Subject (T.Subject, when it is not empty) that is not
%               contained, ignoring case, in the recording's name or file
%               names is vetoed: a time match alone ignores whose session it
%               is. Two remaining sessions within a minute of each other are
%               ambiguous.
%   Match="prefix-then-time" (default) tries prefix first.
%
%   MATCH is a struct: file ("" when nothing matched), method ("prefix" |
%   "time" | ""), candidates (rows of T considered), ambiguous (logical),
%   reason (text).
%
%   See also findEpsychSessions, readEpsychSession, EphysDataset.BehaviorFile.

arguments
    T table
    ds
    opts.Match (1,1) string {mustBeMember(opts.Match, ["prefix","time","prefix-then-time"])} = "prefix-then-time"
    opts.MaxStartOffsetMin (1,1) double {mustBePositive} = 30
end

match = struct('file', "", 'method', "", 'candidates', T([], :), ...
    'ambiguous', false, 'reason', "no sessions");
if height(T) == 0; return; end

name = string(getField(ds, 'Name', ""));
files = string(getField(ds, 'Files', string.empty(1,0)));
acq = getField(ds, 'AcqDate', NaT);
targets = [name, files(:).'];
targets = targets(targets ~= "");

if opts.Match ~= "time"
    hit = false(height(T), 1);
    for i = 1:height(T)
        stem = T.Stem(i);
        if stem == ""; continue; end
        hit(i) = any(startsWith(targets, stem, 'IgnoreCase', true));
    end
    if any(hit)
        C = T(hit, :);
        len = strlength(C.Stem);
        best = C(len == max(len), :);
        match.candidates = best;
        if height(best) == 1
            match.file = best.File(1);
            match.method = "prefix";
            match.reason = "recording name starts with the session stem " + best.Stem(1);
        else
            match.ambiguous = true;
            match.reason = sprintf("%d sessions share the stem %s", height(best), best.Stem(1));
        end
        return
    end
    if opts.Match == "prefix"
        match.reason = "no session stem prefixes the recording name";
        return
    end
end

% --- time ---------------------------------------------------------------------
if ~isdatetime(acq) || isnat(acq)
    match.reason = "recording has no acquisition date";
    return
end
dt = abs(minutes(T.StartTime - acq));
ok = isfinite(dt) & dt <= opts.MaxStartOffsetMin;
% Two animals recorded at the same time (two rigs, or a shared clock) start
% sessions within minutes of each other: a session whose subject is not in
% the recording's name or file names belongs to someone else's recording.
vetoed = false(height(T), 1);
if ismember("Subject", string(T.Properties.VariableNames)) && ~isempty(targets)
    subj = string(T.Subject);
    for i = find(ok & strlength(subj) > 0).'
        vetoed(i) = ~any(contains(targets, subj(i), 'IgnoreCase', true));
    end
end
nVetoed = nnz(vetoed);
ok = ok & ~vetoed;
if ~any(ok)
    match.reason = sprintf("no session starts within %g min of the recording", opts.MaxStartOffsetMin);
    if nVetoed > 0
        match.reason = sprintf("no session of this recording's subject starts within %g min of it (%d session(s) there belong to another subject)", ...
            opts.MaxStartOffsetMin, nVetoed);
    end
    return
end
C = T(ok, :);
dtc = dt(ok);
[~, order] = sort(dtc);
C = C(order, :);
match.candidates = C;
match.file = C.File(1);
match.method = "time";
match.reason = sprintf("session starts %.1f min from the recording", dtc(order(1)));
if height(C) > 1 && abs(dtc(order(2)) - dtc(order(1))) < 1
    match.ambiguous = true;
    match.file = "";
    match.reason = "two sessions start within a minute of each other";
end
end


function v = getField(ds, name, default)
v = default;
try
    if isstruct(ds)
        if isfield(ds, name); v = ds.(name); end
    elseif isprop(ds, name)
        v = ds.(name);
    end
catch
end
end
