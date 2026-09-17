function [T, skipped] = findNasSessions(subjID, dateSpec, opts)
%findNasSessions  Pair ePsych behavior files with Intan RHX recordings on the NAS by name.
%   T = findNasSessions(subjID, dateSpec) lists one subject's sessions on the
%   NAS for a day (or a range of days) and pairs each Intan recording folder
%   with its ePsych behavior file from the timestamps in their names. Nothing
%   is written to either tree; of the files, only headers are read: the
%   Intan headers of every folder taking part in the pairing (for
%   MinIntanDuration and the IntanDuration column) and the ePsych files of
%   the listed sessions (for the EpsychTrials column).
%
%   Names are matched with strict regular expressions anchored to the whole
%   name, and the subject ID must match exactly (SUBJ-ID-125 never matches
%   SUBJ-ID-1255_...):
%     ePsych  <EpsychRoot>/<SUBJ>/<SUBJ>_<yyMMdd>T<HHmmss>.mat     (file)
%     Intan   <IntanRoot>/<SUBJ>/<SUBJ>_<yyMMdd>_<HHmmss>          (folder)
%   Anything else in the two subject folders is logged and skipped (never
%   guessed at); it is also returned in SKIPPED.
%
%   Pairing. An ePsych file is a candidate for an Intan folder when its time
%   lies in [IntanTime - MaxLeadTime, IntanTime + MaxLagTime] (ePsych usually
%   starts 1-3 min before Intan; the lag allows for clock skew). Candidates
%   are grouped into connected sets; within a set every candidate pair is
%   sorted by |DeltaT| and assigned greedily one-to-one, so a conflict is
%   resolved globally rather than by whichever file comes first. When, at an
%   assignment, the Intan folder or the ePsych file has another unassigned
%   candidate whose |DeltaT| is within AmbiguityMargin, the whole set is
%   marked ambiguous: none of its files are paired, and copyNasSessions never
%   copies them.
%
%   An Intan recording shorter than MinIntanDuration (from its headers) takes
%   no part in the pairing: it is never a candidate, so it can neither claim
%   an ePsych file nor make a set ambiguous. It is listed as intan_only with
%   a Note. A recording whose headers cannot be read has no known duration
%   and is paired as usual.
%
%   dateSpec
%     datetime                one day (the time of day is ignored)
%     [datetime datetime]     an inclusive range of days
%     "yyMMdd"                one day, e.g. "260916"
%     ["yyMMdd" "yyMMdd"]     an inclusive range of days
%   A row is listed when its Intan or its ePsych time falls on one of those
%   days, so a session that crosses midnight appears under either day.
%   Files up to MaxLeadTime + MaxLagTime outside the range take part in the
%   pairing so that edge sessions pair the same way whatever range is asked.
%
%   Options
%     EpsychRoot       (default "S:/RIG3_Backup_2025/epsych_files/Data")
%     IntanRoot        (default "S:/RIG3_Backup_2025/intan_files/Data")
%     DestRoot         (default "D:/EPHYS") only fills the DestDir column
%     MaxLeadTime      duration, how long ePsych may start before Intan (default minutes(10))
%     MaxLagTime       duration, how long ePsych may start after Intan (default minutes(2))
%     AmbiguityMargin  duration (default seconds(30))
%     MinIntanDuration duration, shorter recordings are not paired (default
%                      minutes(2); 0 pairs every recording)
%     LogFcn          function handle taking one string (default: print it)
%
%   T has one row per Intan folder plus one per ePsych file left unpaired,
%   sorted by time:
%     Subject     string
%     IntanDir    string, full path ("" for an ePsych-only row)
%     IntanTime   datetime (NaT for an ePsych-only row)
%     EpsychFile  string, full path ("" when not paired)
%     EpsychTime  datetime (NaT when not paired)
%     DeltaT      duration EpsychTime - IntanTime (negative: ePsych started first)
%     Status      "paired" | "intan_only" | "epsych_only" | "ambiguous"
%     DestDir     string, <DestRoot>/<SUBJ>/<Intan folder name>; an unpaired
%                 ePsych row uses the ePsych file name without .mat
%     Note        string, why a row is ambiguous (its candidates) or unpaired
%                 (including a recording shorter than MinIntanDuration)
%     IntanDuration  duration of the recording from its Intan headers
%                 (IntanReader metadata; NaN without a folder or when the
%                 headers cannot be read)
%     EpsychTrials   double, trials in the ePsych file (epsychSessionMeta;
%                 NaN without a file or when it cannot be read)
%     StitchFiles    cell, strings(0, 1) on every row: stitchNasSessions
%                 merges rows picked by hand into a "stitched" row that lists
%                 its ePsych files here
%   A header that cannot be read is logged and leaves NaN.
%   For an ambiguous ePsych file the row carries EpsychFile / EpsychTime and
%   no Intan folder.
%
%   SKIPPED is a table (Path, Reason) of names that did not parse.
%
%   Errors with findNasSessions:RootNotFound when EpsychRoot or IntanRoot
%   is not a folder (e.g. the NAS drive is not mounted). A missing subject
%   folder under an existing root is logged and treated as empty.
%
%   Examples
%     T = findNasSessions("SUBJ-ID-1255", "260916");
%     T = findNasSessions("SUBJ-ID-1255", datetime(2026,9,14) + [0 3], ...
%             MaxLeadTime=minutes(5));
%     R = copyNasSessions(T(T.Status == "paired", :), DryRun=true);
%
%   See also copyNasSessions, stitchNasSessions, findEpsychSessions,
%   matchEpsychSession.

arguments
    subjID (1,1) string {mustBeNonzeroLengthText}
    dateSpec {mustBeDateSpec}
    opts.EpsychRoot (1,1) string = "S:/RIG3_Backup_2025/epsych_files/Data"
    opts.IntanRoot (1,1) string = "S:/RIG3_Backup_2025/intan_files/Data"
    opts.DestRoot (1,1) string = "D:/EPHYS"
    opts.MaxLeadTime (1,1) duration {mustBeNonnegativeDuration} = minutes(10)
    opts.MaxLagTime (1,1) duration {mustBeNonnegativeDuration} = minutes(2)
    opts.AmbiguityMargin (1,1) duration {mustBeNonnegativeDuration} = seconds(30)
    opts.MinIntanDuration (1,1) duration {mustBeNonnegativeDuration} = minutes(2)
    opts.LogFcn = []
end

logFcn = opts.LogFcn;
if isempty(logFcn)
    logFcn = @(msg) fprintf('%s\n', msg);
end
subjID = strtrim(subjID);
[day0, day1] = parseDateSpec(dateSpec);

for r = [opts.EpsychRoot, opts.IntanRoot]
    if ~isfolder(r)
        error('findNasSessions:RootNotFound', ...
            'Folder not found: %s (is the NAS drive mounted?)', r);
    end
end

skipped = table(strings(0, 1), strings(0, 1), 'VariableNames', {'Path', 'Reason'});
    function skip(path, reason)
        skipped(end+1, :) = {string(path), string(reason)};
        logFcn(sprintf("Skipped %s: %s", path, reason));
    end

subj = regexptranslate('escape', char(subjID));
epsychExpr = ['^' subj '_(\d{6})T(\d{6})\.mat$'];
intanExpr  = ['^' subj '_(\d{6})_(\d{6})$'];

% --- ePsych files --------------------------------------------------------------
eFile = strings(0, 1); eTime = NaT(0, 1);
eDir = fullfile(opts.EpsychRoot, subjID);
if ~isfolder(eDir)
    logFcn(sprintf("No ePsych folder for %s: %s", subjID, eDir));
else
    D = dir(eDir);
    for k = 1:numel(D)
        name = D(k).name;
        if any(strcmp(name, {'.', '..'})); continue; end
        path = string(fullfile(eDir, name));   % spelled from the root as given
        tok = regexp(name, epsychExpr, 'tokens', 'once');
        if isempty(tok)
            skip(path, "name is not " + subjID + "_yyMMddTHHmmss.mat");
        elseif D(k).isdir
            skip(path, "a folder, not an ePsych .mat file");
        else
            t = nameTime(tok);
            if isnat(t)
                skip(path, "the name holds an invalid date or time");
            else
                eFile(end+1, 1) = path; %#ok<AGROW>
                eTime(end+1, 1) = t;    %#ok<AGROW>
            end
        end
    end
end

% --- Intan folders ---------------------------------------------------------------
iDir = strings(0, 1); iTime = NaT(0, 1);
nDir = fullfile(opts.IntanRoot, subjID);
if ~isfolder(nDir)
    logFcn(sprintf("No Intan folder for %s: %s", subjID, nDir));
else
    D = dir(nDir);
    for k = 1:numel(D)
        name = D(k).name;
        if any(strcmp(name, {'.', '..'})); continue; end
        path = string(fullfile(nDir, name));
        tok = regexp(name, intanExpr, 'tokens', 'once');
        if isempty(tok)
            skip(path, "name is not " + subjID + "_yyMMdd_HHmmss");
        elseif ~D(k).isdir
            skip(path, "a file, not an Intan recording folder");
        else
            t = nameTime(tok);
            if isnat(t)
                skip(path, "the name holds an invalid date or time");
            else
                iDir(end+1, 1) = path; %#ok<AGROW>
                iTime(end+1, 1) = t;   %#ok<AGROW>
            end
        end
    end
end

% --- pair within a padded window so edge sessions pair consistently ------------
pad = opts.MaxLeadTime + opts.MaxLagTime;
lo = day0 - pad; hi = day1 + days(1) + pad;
keepE = eTime >= lo & eTime < hi;
keepI = iTime >= lo & iTime < hi;
eFile = eFile(keepE); eTime = eTime(keepE);
iDir = iDir(keepI); iTime = iTime(keepI);

% --- recording durations: a recording shorter than the minimum is not paired -------
iDur = duration(NaN(numel(iDir), 1), 0, 0, 'Format', 'hh:mm:ss');
for i = 1:numel(iDir)
    [iDur(i), msg] = intanDuration(iDir(i));
    if msg ~= ""; logFcn(sprintf("Could not read the Intan headers of %s: %s", iDir(i), msg)); end
end
short = iDur < opts.MinIntanDuration;   % false for NaN: an unknown duration pairs as usual

[pairOf, ambiguous, note] = pairSessions(iTime, eTime, ~short, opts, iDir, eFile);

% --- build rows ------------------------------------------------------------------
nI = numel(iDir); nE = numel(eFile);
usedE = false(nE, 1);
noDelta = duration(NaN, 0, 0);
rows = cell(0, 10);
for i = 1:nI
    [~, iName] = fileparts(iDir(i));
    dest = string(fullfile(opts.DestRoot, subjID, iName));
    if short(i)
        why = sprintf("recording is %s, shorter than the %s minimum; not paired", ...
            string(iDur(i), 'hh:mm:ss'), string(opts.MinIntanDuration, 'hh:mm:ss'));
        logFcn(sprintf("Not paired: %s (%s)", iDir(i), why));
        rows(end+1, :) = {subjID, iDir(i), iTime(i), "", NaT, noDelta, "intan_only", dest, why, iDur(i)}; %#ok<AGROW>
    elseif ambiguous.intan(i)
        rows(end+1, :) = {subjID, iDir(i), iTime(i), "", NaT, noDelta, "ambiguous", dest, note.intan(i), iDur(i)}; %#ok<AGROW>
    elseif pairOf(i) > 0
        j = pairOf(i);
        usedE(j) = true;
        rows(end+1, :) = {subjID, iDir(i), iTime(i), eFile(j), eTime(j), eTime(j) - iTime(i), "paired", dest, "", iDur(i)}; %#ok<AGROW>
    else
        rows(end+1, :) = {subjID, iDir(i), iTime(i), "", NaT, noDelta, "intan_only", dest, ...
            "no ePsych file within the pairing window", iDur(i)}; %#ok<AGROW>
    end
end
for j = find(~usedE).'
    [~, eName] = fileparts(eFile(j));
    dest = string(fullfile(opts.DestRoot, subjID, eName));
    if ambiguous.epsych(j)
        rows(end+1, :) = {subjID, "", NaT, eFile(j), eTime(j), noDelta, "ambiguous", dest, note.epsych(j), noDelta}; %#ok<AGROW>
    else
        dtShort = eTime(j) - iTime(short);
        if any(dtShort >= -opts.MaxLeadTime & dtShort <= opts.MaxLagTime)
            why = "no Intan recording of at least " + string(opts.MinIntanDuration, 'hh:mm:ss') + " within the pairing window";
        else
            why = "no Intan folder within the pairing window";
        end
        rows(end+1, :) = {subjID, "", NaT, eFile(j), eTime(j), noDelta, "epsych_only", dest, why, noDelta}; %#ok<AGROW>
    end
end

names = {'Subject', 'IntanDir', 'IntanTime', 'EpsychFile', 'EpsychTime', 'DeltaT', 'Status', 'DestDir', 'Note', ...
    'IntanDuration'};
if isempty(rows)
    T = table(strings(0, 1), strings(0, 1), NaT(0, 1), strings(0, 1), NaT(0, 1), duration.empty(0, 1), ...
        strings(0, 1), strings(0, 1), strings(0, 1), duration.empty(0, 1), 'VariableNames', names);
else
    T = cell2table(rows, 'VariableNames', names);
    T.DeltaT.Format = 'mm:ss';
end
T.IntanDuration.Format = 'hh:mm:ss';

% --- keep rows touching the requested days, sort by time ---------------------------
inRange = @(t) ~isnat(t) & t >= day0 & t < day1 + days(1);
T = T(inRange(T.IntanTime) | inRange(T.EpsychTime), :);
sortTime = T.IntanTime;
sortTime(isnat(sortTime)) = T.EpsychTime(isnat(sortTime));
[~, order] = sort(sortTime);
T = T(order, :);

% --- trial count, for the listed rows only ------------------------------------------
T.EpsychTrials = NaN(height(T), 1);
for k = 1:height(T)
    if T.EpsychFile(k) ~= ""
        [T.EpsychTrials(k), msg] = epsychTrials(T.EpsychFile(k));
        if msg ~= ""; logFcn(sprintf("Could not read the ePsych file %s: %s", T.EpsychFile(k), msg)); end
    end
end
T.StitchFiles = repmat({strings(0, 1)}, height(T), 1);

counts = arrayfun(@(s) nnz(T.Status == s), ["paired" "intan_only" "epsych_only" "ambiguous"]);
logFcn(sprintf("%s, %s to %s: %d paired, %d Intan only, %d ePsych only, %d ambiguous, %d name(s) skipped", ...
    subjID, string(day0, 'yyMMdd'), string(day1, 'yyMMdd'), counts, height(skipped)));
end


function [d, msg] = intanDuration(folder)
%intanDuration  Recording duration from the Intan headers (and .dat sizes); NaN and a message on failure.
d = duration(NaN, 0, 0); msg = "";
w = warning('off', 'all');
restore = onCleanup(@() warning(w));
try
    r = IntanReader(folder);
    r.discoverFiles();
    if r.RecordingFormat == "unknown"
        msg = "no Intan files";
        return
    end
    r.refreshMetadata();
    d = seconds(r.Duration);
catch ME
    msg = string(ME.message);
end
end


function [n, msg] = epsychTrials(file)
%epsychTrials  Trials in an ePsych session file (Data elements); NaN and a message on failure.
n = NaN; msg = "";
try
    meta = epsychSessionMeta(file);
    n = meta.nTrials;
catch ME
    msg = string(ME.message);
end
end


function [pairOf, ambiguous, note] = pairSessions(iTime, eTime, eligibleI, opts, iDir, eFile)
%pairSessions  One-to-one assignment by |DeltaT| within connected candidate sets.
%   Only the Intan folders flagged in eligibleI can be candidates.
nI = numel(iTime); nE = numel(eTime);
pairOf = zeros(nI, 1);
ambiguous = struct('intan', false(nI, 1), 'epsych', false(nE, 1));
note = struct('intan', strings(nI, 1), 'epsych', strings(nE, 1));
if nI == 0 || nE == 0; return; end

% Candidate pairs: ePsych in [I - lead, I + lag].
[I, E] = ndgrid(1:nI, 1:nE);
I = I(:); E = E(:);   % columns even when nI or nE is 1
dt = eTime(E) - iTime(I);
ok = dt >= -opts.MaxLeadTime & dt <= opts.MaxLagTime & eligibleI(I);
C = [I(ok), E(ok)];
absDt = abs(seconds(dt(ok)));
if isempty(C); return; end

% Connected sets (nodes 1..nI are Intan, nI+1..nI+nE are ePsych).
comp = 1:(nI + nE);
    function r = findRoot(x)
        r = x;
        while comp(r) ~= r; r = comp(r); end
        comp(x) = r;
    end
for c = 1:size(C, 1)
    a = findRoot(C(c, 1)); b = findRoot(nI + C(c, 2));
    if a ~= b; comp(max(a, b)) = min(a, b); end
end
root = arrayfun(@findRoot, C(:, 1));

margin = seconds(opts.AmbiguityMargin);
for r = unique(root).'
    inSet = find(root == r);
    [~, order] = sort(absDt(inSet));
    inSet = inSet(order);
    takenI = false(nI, 1); takenE = false(nE, 1);
    tie = false;
    pairs = zeros(0, 2);
    for c = inSet.'
        i = C(c, 1); j = C(c, 2);
        if takenI(i) || takenE(j); continue; end
        rivals = inSet(inSet ~= c & (C(inSet, 1) == i | C(inSet, 2) == j));
        rivals = rivals(~takenI(C(rivals, 1)) & ~takenE(C(rivals, 2)));
        if any(absDt(rivals) - absDt(c) < margin)
            tie = true;
            break
        end
        takenI(i) = true; takenE(j) = true;
        pairs(end+1, :) = [i j]; %#ok<AGROW>
    end
    setI = unique(C(inSet, 1)); setE = unique(C(inSet, 2));
    if tie
        ambiguous.intan(setI) = true;
        ambiguous.epsych(setE) = true;
        for i = setI.'
            cand = C(inSet(C(inSet, 1) == i), 2);
            note.intan(i) = "ambiguous: candidate ePsych files " + candidateList(eFile(cand), eTime(cand) - iTime(i));
        end
        for j = setE.'
            cand = C(inSet(C(inSet, 2) == j), 1);
            note.epsych(j) = "ambiguous: candidate Intan folders " + candidateList(iDir(cand), eTime(j) - iTime(cand));
        end
    else
        pairOf(pairs(:, 1)) = pairs(:, 2);
    end
end
end


function s = candidateList(paths, dts)
parts = strings(numel(paths), 1);
for k = 1:numel(paths)
    [~, n, x] = fileparts(paths(k));
    parts(k) = sprintf("%s (%+.0f s)", n + x, seconds(dts(k)));
end
s = strjoin(parts, "; ");
end


function t = nameTime(tok)
%nameTime  datetime from the yyMMdd and HHmmss name tokens (NaT when invalid).
t = NaT;
d = tok{1}; h = tok{2};
v = sscanf([d h], '%2d');   % yy MM dd HH mm ss
if numel(v) ~= 6 || v(2) < 1 || v(2) > 12 || v(3) < 1 || v(4) > 23 || v(5) > 59 || v(6) > 59
    return
end
c = datetime(2000 + v(1), v(2), v(3), v(4), v(5), v(6));
if day(c) ~= v(3)   % e.g. 31 February rolls over
    return
end
t = c;
end


function [day0, day1] = parseDateSpec(spec)
if isdatetime(spec)
    d = dateshift(spec(:), 'start', 'day');
else
    s = string(spec(:));
    d = NaT(numel(s), 1);
    for k = 1:numel(s)
        tok = regexp(s(k), '^(\d{6})$', 'tokens', 'once');
        t = NaT;
        if ~isempty(tok); t = nameTime({char(tok), '000000'}); end
        if isnat(t)
            error('findNasSessions:BadDate', 'Invalid date "%s": expected yyMMdd.', s(k));
        end
        d(k) = t;
    end
end
d.TimeZone = '';
day0 = d(1); day1 = d(end);
if any(isnat([day0 day1]))
    error('findNasSessions:BadDate', 'The date must not be NaT.');
end
if day1 < day0
    error('findNasSessions:BadDate', 'The date range ends (%s) before it starts (%s).', ...
        string(day1, 'yyMMdd'), string(day0, 'yyMMdd'));
end
end


function mustBeDateSpec(x)
ok = (isdatetime(x) && any(numel(x) == [1 2])) ...
    || ((isstring(x) || ischar(x) || iscellstr(x)) && any(numel(string(x)) == [1 2]));
if ~ok
    error('findNasSessions:BadDate', ...
        'dateSpec must be a datetime, two datetimes, a "yyMMdd" string or two of them.');
end
end


function mustBeNonnegativeDuration(x)
if x < 0
    error('findNasSessions:BadOption', 'Durations must not be negative.');
end
end
