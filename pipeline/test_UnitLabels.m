function test_UnitLabels()
%test_UnitLabels  Verification suite for unit labels, identity, location and notes.
%   Covers parseNameTokens formats, EphysDataset.nameIdentity, the label /
%   class / identity / location / notes columns of readPhyUnits and
%   readSortedUnits, writeUnitNotes / readUnitNotes, EphysProject's
%   NamePattern push and unitIdentities collisions, and unitTable. Uses phy
%   fixtures and tiny universal-format (recording.json) recordings, so no
%   Intan files or toolboxes are needed.
%
%   Usage:  test_UnitLabels
%
%   The fixtures live in a temp folder which is deleted on completion.
%
%   See also EphysDataset.nameIdentity, EphysDataset.readPhyUnits, unitTable.

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('UnitLabels_test_%s', ...
    datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
warnState = warning('off', 'EphysDataset:readPhyUnits:OtherGroup');
restoreWarn = onCleanup(@() warning(warnState)); %#ok<NASGU>

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
    function id = errorId(fn)
        id = '';
        try
            fn();
        catch ME
            id = ME.identifier;
        end
    end
    function d = makeRecording(folder)
        % A 2-channel universal-format recording with a legacy phy sort in kilosort4/.
        mkdir(folder);
        fid = fopen(fullfile(folder, 'data.bin'), 'w');
        fwrite(fid, zeros(2, 100, 'int16'), 'int16');
        fclose(fid);
        BinaryReader.writeDescriptor(folder, struct('data_file', "data.bin", 'dtype', "int16", ...
            'n_chan', 2, 'fs', 30000, 'gain_to_uV', 0.195, 'offset', 0));
        makePhyFixture(fullfile(folder, 'kilosort4'), 30000);
        d = string(folder);
    end

fs = 30000;
prefixPattern = "SUBJ-ID-{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}";

%% ---- 1. parseNameTokens formats ---------------------------------------------
fprintf('\n== 1. parseNameTokens formats ==\n');
[v, n, ok, f] = parseNameTokens("A1_260101_120000", EphysDataset.DefaultNamePattern);
check(ok && isequal(n, ["SubjectID" "Date" "Time"]) && isequal(f, ["" "yyMMdd" "HHmmss"]) ...
    && isequal(v, ["A1" "260101" "120000"]), 'formats: "" for free text, the datetime format otherwise');
[~, ~, ~, f] = parseNameTokens("", "{Letter:[A-Z]}{Num:\d+}_*");
check(isequal(f, ["" ""]), 'regex tokens have no format');

%% ---- 2. nameIdentity ------------------------------------------------------------
fprintf('\n== 2. nameIdentity ==\n');
id = EphysDataset.nameIdentity("SUBJ-ID-1255_260908_103949", prefixPattern);
check(id.ok && id.subject == "1255" && id.recordingStart == datetime(2026, 9, 8, 10, 39, 49) ...
    && id.labelSuffix == "1255_260908T1039" && id.reason == "", ...
    'a literal prefix is dropped; start to the second, label suffix to the minute');
check(EphysDataset.nameIdentity("recA", EphysDataset.DefaultNamePattern).reason == "nomatch", 'a name that does not match');
check(EphysDataset.nameIdentity("SUBJ-ID-1255_260908_103949", EphysDataset.DefaultNamePattern).subject == "SUBJ-ID-1255", ...
    'without the literal prefix the subject keeps it');
check(EphysDataset.nameIdentity("", "{SubjectID}_{Date:yyMMdd}").reason == "pattern", 'a pattern without Time cannot label units');
check(EphysDataset.nameIdentity("", "{SubjectID}_{Date}_{Time}").reason == "pattern", 'Date / Time need datetime formats');
check(EphysDataset.nameIdentity("", "{SubjectID}_{Date:yyMMdd}_{Time:HHss}").reason == "pattern", 'minutes are required');
check(EphysDataset.nameIdentity("", "{SubjectID").reason == "pattern", 'an invalid pattern is reported, not thrown');
check(EphysDataset.nameIdentity("", EphysDataset.DefaultNamePattern).reason == "nomatch", 'the default pattern can label units');
check(EphysDataset.nameIdentity("A_1_260101_120000", EphysDataset.DefaultNamePattern).reason == "subject", ...
    'a subject containing "_" is rejected');
check(EphysDataset.nameIdentity("A1_261301_120000", EphysDataset.DefaultNamePattern).reason == "datetime", 'month 13 is not a date');
check(EphysDataset.nameIdentity("A1_991231_235900", EphysDataset.DefaultNamePattern).recordingStart.Year == 2099, ...
    'two-digit years are 2000-2099');

%% ---- 3. readPhyUnits: class, padding, bare labels -------------------------------
fprintf('\n== 3. class and label ==\n');
d3 = fullfile(root, 'phy3');
makePhyFixture(d3, fs, ClusterIds=[7 1042 2]);
U = EphysDataset.readPhyUnits(d3, IncludeNoise=true);
check(isequal(U.unitId, [2; 7; 1042]) && isequal(U.class, ["noise"; "su"; "mua"]) ...
    && isequal(U.label, ["noise002"; "su007"; "mua1042"]), 'good->su, ids padded to 3 digits, longer ids kept');
fn = string(fieldnames(U)).';
check(isequal(fn(1:16), ["unitId" "label" "class" "group" "notes" "subject" "recordingStart" "datasetKey" ...
    "channel" "channelName" "ksChannel" "shank" "peakX" "peakY" "x" "y"]), 'identity and location fields come first');
check(all(U.subject == "") && all(isnat(U.recordingStart)) && all(U.datasetKey == "") && all(U.notes == ""), ...
    'a bare folder has no identity');
fid = fopen(fullfile(d3, 'cluster_group.tsv'), 'w');
fprintf(fid, 'cluster_id\tgroup\n7\tmaybe\n1042\tmua\n2\t\n');
fclose(fid);
warning('on', 'EphysDataset:readPhyUnits:OtherGroup');
lastwarn('');
U = EphysDataset.readPhyUnits(d3, IncludeNoise=true);
[~, wid] = lastwarn();
warning('off', 'EphysDataset:readPhyUnits:OtherGroup');
check(isequal(U.class, ["uns"; "other"; "mua"]) && isequal(U.label, ["uns002"; "other007"; "mua1042"]) ...
    && U.group(2) == "maybe" && strcmp(wid, 'EphysDataset:readPhyUnits:OtherGroup'), ...
    'blank -> uns; an unknown phy label -> other, with a warning; group keeps the raw label');
U = EphysDataset.readPhyUnits(d3, IncludeNoise=true, Identity=struct('subject', "A1", ...
    'recordingStart', datetime(2026, 1, 1, 12, 0, 0), 'labelSuffix', "A1_260101T1200", 'datasetKey', "a/b"));
check(isequal(U.label, ["uns002_A1_260101T1200"; "other007_A1_260101T1200"; "mua1042_A1_260101T1200"]) ...
    && all(U.subject == "A1") && all(U.datasetKey == "a/b") && all(U.recordingStart == datetime(2026, 1, 1, 12, 0, 0)), ...
    'an Identity gives full labels and the identity columns');
check(strcmp(errorId(@() EphysDataset.readPhyUnits(d3, Identity=struct('subject', "A1"))), ...
    'EphysDataset:readPhyUnits:BadIdentity'), 'an incomplete Identity is an error');

%% ---- 4. location ----------------------------------------------------------------
fprintf('\n== 4. location ==\n');
d4 = fullfile(root, 'phy4');
makePhyFixture(d4, fs, Shanks=[0 0 0 1], Positions=[0 0; 0 20; 0 40; 200 0]);
T = zeros(3, 8, 4);
T(1, 3, 2) = -50; T(1, 5, 2) = 20;     % cluster 0: p2p 70 on ch2 and ch3 (shank 0) ...
T(1, 3, 3) = -50; T(1, 5, 3) = 20;
T(1, 3, 4) = -60;                      % ... 60 on ch4 (shank 1, ignored) ...
T(1, 3, 1) = -10;                      % ... 10 on ch1 (under 25%, ignored)
T(2, 3, 4) = -80; T(2, 6, 4) = 30;     % cluster 1: ch4 only
T(3, 4, 1) = -10;                      % cluster 2: ch1 only
writeNPY(fullfile(d4, 'templates.npy'), single(T));
U = EphysDataset.readPhyUnits(d4, IncludeNoise=true, ChannelNames=["A-000" "A-001" "A-002" "A-003"]);
check(isequal(U.ksChannel, [2; 4; 1]) && isequal(U.shank, [0; 1; 0]) && isequal(U.channel, [2; 4; 1]) ...
    && isequal(U.channelName, ["A-001"; "A-003"; "A-000"]), 'peak channel, shank and channel name');
check(isequal([U.peakX U.peakY], [0 20; 200 0; 0 0]), 'peakX / peakY are the peak channel''s site');
check(abs(U.x(1)) < 1e-9 && abs(U.y(1) - 30) < 1e-9 && isequal([U.x(2:3) U.y(2:3)], [200 0; 0 0]), ...
    'template centre: weighted over same-shank channels with at least 25% of the peak');
U = EphysDataset.readPhyUnits(d4, IncludeNoise=true);
check(all(U.channelName == ""), 'no channel names without ChannelNames');
U = EphysDataset.readPhyUnits(d4, IncludeNoise=true, Templates=false);
check(all(isnan([U.x; U.y; U.peakX; U.peakY])), 'no position without templates');
delete(fullfile(d4, 'channel_positions.npy'));
U = EphysDataset.readPhyUnits(d4, IncludeNoise=true);
check(all(isnan([U.x; U.y; U.peakX; U.peakY])) && isequal(U.ksChannel, [2; 4; 1]), ...
    'no position without channel_positions.npy');

%% ---- 5. notes -------------------------------------------------------------------
fprintf('\n== 5. notes ==\n');
d5 = fullfile(root, 'phy5');
makePhyFixture(d5, fs);
file = EphysDataset.writeUnitNotes(d5, [1; 0], ["two" + sprintf('\t') + "cells?"; "clean refractory" + newline + "period"]);
txt = string(fileread(file));
check(startsWith(txt, "cluster_id" + sprintf('\t') + "notes") && contains(txt, "0" + sprintf('\t') + "clean refractory period") ...
    && contains(txt, "1" + sprintf('\t') + "two cells?"), 'phy-style TSV, tabs and line breaks become spaces');
EphysDataset.writeUnitNotes(d5, 2, "noise burst");
EphysDataset.writeUnitNotes(d5, 1, "");
[ids, notes] = EphysDataset.readUnitNotes(d5);
check(isequal(ids, [0; 2]) && isequal(notes, ["clean refractory period"; "noise burst"]), ...
    'writing one unit keeps the others; an empty note removes the row');
U = EphysDataset.readPhyUnits(d5, IncludeNoise=true);
check(isequal(U.notes, ["clean refractory period"; ""; "noise burst"]), 'readPhyUnits picks the notes up');
check(isempty(EphysDataset.readUnitNotes(fullfile(root, 'phy3'))), 'no notes file, no notes');
check(strcmp(errorId(@() EphysDataset.writeUnitNotes(d5, [1 2], "x")), 'EphysDataset:writeUnitNotes:Size'), ...
    'ids and notes must pair up');

%% ---- 6. dataset reads -------------------------------------------------------------
fprintf('\n== 6. readSortedUnits ==\n');
f6 = makeRecording(fullfile(root, 'single', 'A1_260101_120000'));
ds = EphysDataset(f6);
U = ds.readSortedUnits();
check(isequal(U.label, ["su000_A1_260101T1200"; "mua001_A1_260101T1200"]) && all(U.subject == "A1") ...
    && all(U.recordingStart == datetime(2026, 1, 1, 12, 0, 0)) && all(U.datasetKey == EphysProject.normalizeKey(f6)), ...
    'a dataset labels its units; outside a project the key is the folder');
ds.DatasetKey = "x/y";
U = ds.readSortedUnits();
check(all(U.datasetKey == "x/y"), 'DatasetKey is used when set');
id = ds.unitIdentity();
check(isequal(sort(string(fieldnames(id))).', sort(["subject" "recordingStart" "labelSuffix" "datasetKey"])), ...
    'unitIdentity returns what readPhyUnits needs');
ds.NamePattern = prefixPattern;
check(strcmp(errorId(@() ds.readSortedUnits()), 'EphysDataset:unitIdentity:NoMatch'), 'a name that does not match is an error');
rmdir(fullfile(f6, 'kilosort4'), 's');
check(strcmp(errorId(@() ds.readSortedUnits()), 'EphysDataset:unitIdentity:NoMatch'), ...
    'the identity is checked before the sorter output');
ds.NamePattern = "{SubjectID}";
check(strcmp(errorId(@() ds.unitIdentity()), 'EphysDataset:unitIdentity:Pattern'), 'a pattern that cannot label units');

%% ---- 7. project: pattern push and collisions ------------------------------------
fprintf('\n== 7. EphysProject ==\n');
proj = fullfile(root, 'proj');
makeRecording(fullfile(proj, 'SUBJ-ID-S1', 'SUBJ-ID-S1_260101_120000'));
makeRecording(fullfile(proj, 'SUBJ-ID-S1', 'SUBJ-ID-S1_260101_120030'));
makeRecording(fullfile(proj, 'SUBJ-ID-S2', 'SUBJ-ID-S2_260101_120000'));
makeRecording(fullfile(proj, 'misc', 'bench_test'));
P = EphysProject(proj, NamePattern=prefixPattern);
keys = P.datasetKeys();
iA = P.findByKey("SUBJ-ID-S1/SUBJ-ID-S1_260101_120000");
iB = P.findByKey("SUBJ-ID-S1/SUBJ-ID-S1_260101_120030");
iC = P.findByKey("SUBJ-ID-S2/SUBJ-ID-S2_260101_120000");
iD = P.findByKey("misc/bench_test");
check(all([P.Datasets.NamePattern] == prefixPattern) && isequal([P.Datasets.DatasetKey], keys), ...
    'pushConfig sets NamePattern and DatasetKey');
I = P.unitIdentities();
st = @(i) I.Status(I.Key == keys(i));
check(st(iA) == "collision" && st(iB) == "collision" && st(iC) == "ok" && st(iD) == "nomatch" ...
    && contains(I.Message(I.Key == keys(iA)), keys(iB)), ...
    'same subject + same minute collide and name each other; other names are ok or explain why not');
check(I.Subject(I.Key == keys(iC)) == "S2" && I.LabelSuffix(I.Key == keys(iC)) == "S2_260101T1200", ...
    'rows carry subject and label suffix');
I = P.unitIdentities(Among=[iA iC]);
check(height(I) == 2 && all(I.Status == "ok"), 'Among limits the collision scope');
I = P.unitIdentities(NamePattern=EphysDataset.DefaultNamePattern);
check(I.Subject(I.Key == keys(iC)) == "SUBJ-ID-S2", 'NamePattern overrides the datasets'' pattern');

%% ---- 8. unitTable -----------------------------------------------------------------
fprintf('\n== 8. unitTable ==\n');
UA = P.Datasets(iA).readSortedUnits();
UC = P.Datasets(iC).readSortedUnits(IncludeNoise=true);
T = unitTable({UA, UC});
check(isequal(string(T.Properties.VariableNames), ["label" "class" "subject" "recordingStart" "datasetKey" ...
    "unitId" "group" "channel" "channelName" "ksChannel" "shank" "peakX" "peakY" "x" "y" "notes" ...
    "nSpikes" "amplitude" "contamPct" "curated" "fs" "resultsDir" "times"]), 'column order');
check(height(T) == 5 && isstring(T.label) && isdatetime(T.recordingStart) && iscell(T.times) ...
    && isequal(T.times{1}, UA.times{1}), 'one row per unit, typed columns');
su = T(T.class == "su" & T.subject == "S1", :);
check(height(su) == 1 && su.label == "su000_S1_260101T1200" && su.datasetKey == keys(iA), 'filter by class and subject');
check(width(unitTable(UA, Times=false)) == 22, 'Times=false drops the times column');
check(height(unitTable([])) == 0 && width(unitTable([])) == 23, 'no units, an empty typed table');
check(strcmp(errorId(@() unitTable({UA, UA})), 'unitTable:DuplicateUnit'), 'the same unit twice is an error');
UB = P.Datasets(iB).readSortedUnits();
lastwarn('');
T = unitTable({UA, UB});
[~, wid] = lastwarn();
check(height(T) == 4 && strcmp(wid, 'unitTable:DuplicateLabel'), 'colliding recordings warn about shared labels');
spikesFile = fullfile(root, 'A_spikes.mat');
units = UA; detected = []; %#ok<NASGU>
save(spikesFile, 'units', 'detected');
emptyFile = fullfile(root, 'D_spikes.mat');
units = []; %#ok<NASGU>
save(emptyFile, 'units', 'detected');
EphysDataset.writeUnitNotes(UA.resultsDir, 1, "added after the spikes file");
T = unitTable([string(spikesFile) string(emptyFile)]);
check(height(T) == 2 && T.notes(T.unitId == 1) == "added after the spikes file", ...
    'files load; units = [] is skipped; notes are refreshed from the sort folder');
T = unitTable(spikesFile, RefreshNotes=false);
check(T.notes(T.unitId == 1) == "", 'RefreshNotes=false keeps the saved notes');
check(strcmp(errorId(@() unitTable(fullfile(root, 'nope.mat'))), 'unitTable:NoFile'), 'a missing file is an error');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_UnitLabels:Failures', '%d checks failed.', nFail);
end
end
