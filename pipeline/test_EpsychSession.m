function test_EpsychSession()
%test_EpsychSession  Verification suite for the Epsych2 session readers.
%   Builds synthetic Epsych2 session files (variables Data + Info, the shape
%   epsych2's ep_SaveDataFcn writes) in a temp folder and checks
%   epsychSessionMeta, readEpsychSession, findEpsychSessions,
%   matchEpsychSession and stitchEpsychSessions. No Epsych2 code is needed.
%
%   Usage:  test_EpsychSession

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('Epsych_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
        end
    end

% ---- fixtures ---------------------------------------------------------------
t0 = datetime(2026, 1, 1, 12, 0, 0);
Data = struct('ToneLevel', {60, 70, 80}, 'RespCode', {uint32(1), uint32(2), uint32(1)}, ...
    'TrialIndex', {1, 2, 3}, 'TrialID', {3, 1, 2}, ...
    'computerTimestamp', {t0 + seconds(5), t0 + seconds(10), t0 + seconds(15)}, ...
    'isTest', {false, false, false});
Info = struct('Subject', struct('Name', "subjA", 'ID', "A1"), 'StartTime', t0, ...
    'FormatVersion', 2, 'TrialTable', {{60, 70, 80}}, 'WriteParams', {{'ToneLevel'}}, ...
    'DataFilename', "subjA_260101T120000.mat");
fA = fullfile(root, 'subjA', 'subjA_260101T120000.mat');
mkdir(fileparts(fA));
save(fA, 'Data', 'Info');

Data = struct('AMdepth', {0.5, 1}, 'ResponseCode', {uint32(4), uint32(2)}, ...
    'TrialIndex', {1, 2}, 'TrialID', {1, 2}, 'computerTimestamp', {t0 + days(1), t0 + days(1) + seconds(9)}, ...
    'isTest', {false, true});
Info = struct('Subject', 'subjB', 'StartTime', t0 + days(1) - minutes(21), 'FormatVersion', 2);
fB = fullfile(root, 'subjB', 'subjB_260102T090000.mat');
mkdir(fileparts(fB));
save(fB, 'Data', 'Info');

x = 1; %#ok<NASGU>
fD = fullfile(root, 'decoy.mat');
save(fD, 'x');

fprintf('\n== 1. epsychSessionMeta / readEpsychSession ==\n');
m = epsychSessionMeta(fA);
check(m.subject == "subjA" && m.startTime == t0 && m.nTrials == 3 && m.formatVersion == 2 ...
    && m.stem == "subjA_260101T120000" && m.hasTrialTable, 'meta from Info only (struct Subject)');
mB = epsychSessionMeta(fB);
check(mB.subject == "subjB" && mB.nTrials == 2 && ~mB.hasTrialTable, 'meta with a char Subject');
[T, info, meta] = readEpsychSession(fA);
check(height(T) == 3 && all(ismember(["ToneLevel" "RespCode" "TrialIndex" "TrialID" "computerTimestamp" "isTest"], ...
    string(T.Properties.VariableNames))), 'trials table: one row per trial, one column per field');
check(isequal(T.ToneLevel, [60; 70; 80]) && isequal(T.TrialID, [3; 1; 2]) && isa(T.RespCode, 'uint32'), ...
    'values are as saved (response codes left raw, TrialID is the schedule row)');
check(isequal(info.WriteParams, {'ToneLevel'}) && meta.responseCodeField == "RespCode" ...
    && meta.nTrials == 3 && any(meta.parameterNames == "ToneLevel"), 'Info returned as saved; meta extended');
[TB, ~, mB2] = readEpsychSession(fB);
check(height(TB) == 2 && mB2.responseCodeField == "ResponseCode" && islogical(TB.isTest), ...
    'ResponseCode spelling detected');
errId = '';
try
    readEpsychSession(fD);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'readEpsychSession:NotEpsych'), 'a .mat without Data/Info is refused');
errId = '';
try
    readEpsychSession(fullfile(root, 'nope.mat'));
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'readEpsychSession:NotFound'), 'a missing file is refused');

fprintf('\n== 2. findEpsychSessions ==\n');
S = findEpsychSessions(root);
check(height(S) == 2 && isequal(S.Stem, ["subjA_260101T120000"; "subjB_260102T090000"]) ...
    && S.NTrials(1) == 3, 'two sessions found recursively, decoy ignored, sorted by StartTime');
S1 = findEpsychSessions(root, Recursive=false);
check(height(S1) == 0, 'Recursive=false only looks at the top level');
S2 = findEpsychSessions([fullfile(root, 'subjB'), "C:\no\such\dir"]);
check(height(S2) == 1 && S2.Subject(1) == "subjB", 'missing search dirs are skipped');

fprintf('\n== 3. matchEpsychSession ==\n');
dsA = struct('Name', "subjA_260101T120000_260101_120004", 'Files', ["subjA_260101T120000_260101_120004.rhd"], ...
    'AcqDate', t0 + seconds(4));
mA = matchEpsychSession(S, dsA);
check(mA.file == string(fA) && mA.method == "prefix" && ~mA.ambiguous, 'prefix match on the recording name');
dsT = struct('Name', "unrelated_rec", 'Files', "info.rhd", 'AcqDate', t0 + days(1) - minutes(15));
mT = matchEpsychSession(S, dsT);
check(mT.file == string(fB) && mT.method == "time", 'falls back to the nearest start time');
mN = matchEpsychSession(S, dsT, MaxStartOffsetMin=5);
check(mN.file == "" && mN.method == "" && contains(mN.reason, "within"), 'time match respects the tolerance');
mP = matchEpsychSession(S, dsT, Match="prefix");
check(mP.file == "" && contains(mP.reason, "prefix"), 'Match="prefix" does not fall back');
dsN = struct('Name', "x", 'Files', string.empty(1,0), 'AcqDate', NaT);
mX = matchEpsychSession(S, dsN);
check(mX.file == "" && contains(mX.reason, "acquisition date"), 'no AcqDate -> no time match');
% Ambiguity: the same stem in two folders.
fA2 = fullfile(root, 'copy', 'subjA_260101T120000.mat');
mkdir(fileparts(fA2));
copyfile(fA, fA2);
S3 = findEpsychSessions(root);
mAmb = matchEpsychSession(S3, dsA);
check(mAmb.file == "" && mAmb.ambiguous && height(mAmb.candidates) == 2, 'two sessions with the same stem are ambiguous');
% Longest stem wins.
fA3 = fullfile(root, 'subjA', 'subjA_2601.mat');
copyfile(fA, fA3);
delete(fA2);
S4 = findEpsychSessions(root);
mL = matchEpsychSession(S4, dsA);
check(mL.file == string(fA) && mL.method == "prefix", 'the longest matching stem wins');
check(matchEpsychSession(S4([], :), dsA).file == "", 'an empty table matches nothing');

fprintf('\n== 4. stitchEpsychSessions ==\n');
sdir = fullfile(root, 'stitch');
mkdir(sdir);
Data = struct('ToneLevel', {50, 55}, 'RespCode', {uint32(1), uint32(2)}, 'TrialIndex', {1, 2}, 'TrialID', {1, 2}, ...
    'computerTimestamp', {t0 + minutes(30) + seconds(5), t0 + minutes(30) + seconds(9)});
Info = struct('Subject', struct('Name', "subjA", 'ID', "A1"), 'StartTime', t0 + minutes(30), ...
    'TrialTable', {{50, 55}}, 'WriteParams', {{'ToneLevel'}});
fS2 = fullfile(sdir, 'subjA_260101T123000.mat');
save(fS2, 'Data', 'Info');
Data = struct('AMdepth', {0.25, 0.5, 1}, 'RespCode', {uint32(4), uint32(1), uint32(2)}, 'TrialIndex', {1, 2, 3}, ...
    'TrialID', {2, 1, 2}, 'computerTimestamp', {t0 + hours(1), t0 + hours(1) + seconds(4), t0 + hours(1) + seconds(8)});
Info = struct('Subject', struct('Name', "subjA", 'ID', "A1"), 'StartTime', t0 + minutes(59), 'Protocol', "second");
fS3 = fullfile(sdir, 'subjA_260101T125900.mat');
save(fS3, 'Data', 'Info');

[SD, SI] = stitchEpsychSessions(string({fS3, fA, fS2}));   % given out of order
check(numel(SD) == 8 && isequal([SD.StitchPart], [1 1 1 2 2 3 3 3]) ...
    && isequal([SD.StitchPartTrial], [1 2 3 1 2 1 2 3]), 'trials joined in chronological order, whatever the input order');
check(isequal([SD.TrialIndex], 1:8) && isequal([SD.TrialID], [3 1 2 1 2 2 1 2]), ...
    'TrialIndex renumbered across the sessions; TrialID kept');
check(isempty(SD(4).AMdepth) && SD(6).AMdepth == 0.25 && isempty(SD(6).ToneLevel) && SD(4).ToneLevel == 50, ...
    'parameters a session lacks are []');
check(isequal(SI.StartTime, t0) && isequal(SI.WriteParams, {'ToneLevel'}) && ~isfield(SI, 'Protocol') ...
    && isequal(string({SI.Stitch.Parts.Name}), ["subjA_260101T120000.mat" "subjA_260101T123000.mat" "subjA_260101T125900.mat"]) ...
    && isequal([SI.Stitch.Parts.NTrials], [3 2 3]) && SI.Stitch.Parts(3).Info.Protocol == "second", ...
    'Info is the earliest session''s, with every part (and its own Info) under Stitch');
fOut = fullfile(sdir, 'out', 'subjA_260101T120000_stitched.mat');
[SD2, SI2] = stitchEpsychSessions(string({fS2, fA}), OutFile=fOut);
[TS, ~, mS] = readEpsychSession(fOut);
check(height(TS) == 5 && isequal(TS.StitchPart, [1; 1; 1; 2; 2]) && mS.startTime == t0 && mS.subject == "subjA" ...
    && numel(SD2) == 5 && numel(SI2.Stitch.Parts) == 2, 'OutFile writes a session readEpsychSession reads');
check(height(findEpsychSessions(fullfile(sdir, 'out'))) == 1 && ...
    ~isfile(fullfile(sdir, 'out', '~subjA_260101T120000_stitched.partial.mat')), 'no partial file left behind');

    function id = stitchError(varargin)
        id = '';
        try
            stitchEpsychSessions(varargin{:});
        catch ME
            id = ME.identifier;
        end
    end
check(strcmp(stitchError(string({fA, fA})), 'stitchEpsychSessions:TooFew'), 'one file (even listed twice) is refused');
check(strcmp(stitchError(string({fA, fB})), 'stitchEpsychSessions:Subject'), 'sessions of different subjects are refused');
check(strcmp(stitchError(string({fA, fOut})), 'stitchEpsychSessions:AlreadyStitched'), 'a stitched session is not stitched again');
Data = struct('ToneLevel', {40}, 'TrialIndex', {1}, 'computerTimestamp', {t0 + seconds(20)});
Info = struct('Subject', "subjA", 'StartTime', t0 + seconds(10));
fOver = fullfile(sdir, 'subjA_260101T120010.mat');
save(fOver, 'Data', 'Info');
check(strcmp(stitchError(string({fA, fOver})), 'stitchEpsychSessions:Overlap'), 'a session starting during the previous one is refused');
Data = struct('ToneLevel', {40}); Info = struct('Subject', "subjA");
fNoT = fullfile(sdir, 'subjA_notime.mat');
save(fNoT, 'Data', 'Info');
check(strcmp(stitchError(string({fA, fNoT})), 'stitchEpsychSessions:NoStartTime'), 'a session with no time is refused');
check(strcmp(stitchError(string({fA, fD})), 'readEpsychSession:NotEpsych'), 'a file that is not a session is refused');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EpsychSession:Failures', '%d checks failed.', nFail);
end
end
