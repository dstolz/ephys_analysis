function test_DatasetOutputs()
%test_DatasetOutputs  Verification suite for DatasetOutputs.
%   Builds the files the pipeline writes for a dataset -- per-type and
%   combined extracts, spikes, Chronux, FieldTrip and behavior files, a phy
%   results folder, a manifest -- with plain save() calls, plus decoys that
%   belong to other datasets, and checks discovery, pinning and on-demand
%   loading, both for a folder alone and for an EphysDataset (a tiny
%   universal-format recording, so no Intan files or toolboxes are needed).
%   Then: two recordings with one name whose outputs share a folder (the
%   recorded source folder decides, also after the project moved), a
%   hand-picked sort that is not there, and a combined extract that changes.
%   Last, an EphysProject over a copy of an output root, without the
%   recordings: its output folders are the datasets.
%
%   Usage:  test_DatasetOutputs
%
%   The fixtures live in a temp folder which is deleted on completion.
%
%   See also DATASETOUTPUTS.

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('DSOutputs_test_%s', ...
    datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
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
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end

%% ---- fixtures -------------------------------------------------------------
name = "rec1";
out = fullfile(root, 'out', name);
mkdir(out);
conv = @(ds) struct('tool', "test", 'dataset', ds);
ev = struct('din0', [1 2; 3 4]);

% Per-type extracts (older) and a combined extract (newer, LFP + MUA).
S = struct();
S.Y = struct('LFP', single(ones(10, 2)), 'MUA', single([]), 'SPIKE', single([]));
S.info = struct('LFP', struct('Fs', 1000), 'labels', ["a" "b"]);
S.events = ev; S.conversion = conv(name);
save(fullfile(out, 'rec1_extract_LFP.mat'), '-struct', 'S');
S.Y = struct('LFP', single([]), 'MUA', single([]), 'SPIKE', single(2 * ones(20, 2)));
S.info = struct('SPIKE', struct('Fs', 2000), 'labels', ["a" "b"]);
save(fullfile(out, 'rec1_extract_SPIKE.mat'), '-struct', 'S');
pause(1.1);   % distinct modification times (newest wins)
S.Y = struct('LFP', single(3 * ones(10, 2)), 'MUA', single(4 * ones(10, 2)), 'SPIKE', single([]));
S.info = struct('LFP', struct('Fs', 1000), 'MUA', struct('Fs', 1000), 'labels', ["a" "b"]);
save(fullfile(out, 'rec1_custom.mat'), '-struct', 'S');     % suffix need not be "_extract"

% Spikes, exports and behavior, classified by their variables.
Sp = struct('detected', struct('ts', {{1, 2}}), 'conversion', conv(name));
save(fullfile(out, 'rec1_spikes.mat'), '-struct', 'Sp');
C = struct('LFP', struct('data', 1), 'sp', struct('times', {1}), 'spDetected', [], ...
    'events', ev, 'export', conv(name));
save(fullfile(out, 'rec1_chronux.mat'), '-struct', 'C');
ftDir = fullfile(root, 'ft_elsewhere');
mkdir(ftDir);
F = struct('data_LFP', struct('fsample', 1000), 'spike', [], 'event', struct('sample', 1), ...
    'export', conv(name));
save(fullfile(ftDir, 'rec1_fieldtrip.mat'), '-struct', 'F');
B = struct('behavior', struct('nTrials', 7, 'subject', "mouseA"), 'conversion', conv(name));
save(fullfile(out, 'rec1_behavior.mat'), '-struct', 'B');

% Decoys: another dataset whose name starts with "rec1", another dataset's
% provenance under a matching name, a partial file and an unrelated .mat.
save(fullfile(out, 'rec10_fieldtrip.mat'), '-struct', 'F');
Fo = F; Fo.export = conv("rec1_other");
save(fullfile(out, 'rec1_other_fieldtrip.mat'), '-struct', 'Fo');
save(fullfile(out, '~rec1_chronux.partial.mat'), '-struct', 'C');
junk = 1; %#ok<NASGU>
save(fullfile(out, 'rec1_notes.mat'), 'junk');

% Sorted output + manifest.
makePhyFixture(fullfile(out, 'kilosort4'), 30000);
writeJsonFile(fullfile(out, 'rec1_manifest.json'), struct('schema', "intan-dataset-manifest/2", ...
    'name', name, 'sorting', struct('results_dir', "", 'source', "auto")));
writeJsonFile(fullfile(out, 'rec1_artifacts.json'), struct('schema', "ephys-artifacts/2", 'intervals', [0 1]));

%% ---- 1. folder mode: discovery -------------------------------------------
fprintf('\n== 1. discovery from a folder ==\n');
o = DatasetOutputs(out);
check(o.Name == name && o.Roots == string(out), 'name from the folder leaf; the folder is the root');
C0 = o.Candidates;
check(sum(C0.Kind == "extract") == 3 && sum(C0.Kind == "spikes") == 1 && sum(C0.Kind == "chronux") == 1 ...
    && sum(C0.Kind == "behavior") == 1 && sum(C0.Kind == "manifest") == 1 && sum(C0.Kind == "artifacts") == 1, ...
    'files classified by their variables');
check(~any(contains(C0.File, ["rec10" "rec1_other" "partial" "notes"])), ...
    'other datasets, partial files and unrelated .mat files are ignored');
check(sum(C0.Kind == "fieldtrip") == 0 && ~o.has("fieldtrip"), 'nothing outside the roots');
check(isequal(o.ExtractFiles(1), string(fullfile(out, 'rec1_custom.mat'))) && numel(o.ExtractFiles) == 3, ...
    'ExtractFiles: newest combined + newest per type, newest first');
check(o.SortingDir == string(fullfile(out, 'kilosort4')) && o.pathSource("sorting") == "discovered", ...
    'sorting found in the kilosort4 layout');
check(o.pathSource("fieldtrip") == "" && o.pathSource("spikes") == "discovered", 'pathSource');
errId = '';
try
    o.FieldTrip; %#ok<VUNUS>
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'DatasetOutputs:Missing'), 'reading a missing kind errors clearly');

%% ---- 2. loading -----------------------------------------------------------
fprintf('\n== 2. loading on demand ==\n');
X = o.Extract;
check(isequal(X.Y.LFP, single(3 * ones(10, 2))) && isequal(X.Y.MUA, single(4 * ones(10, 2))) ...
    && isequal(X.Y.SPIKE, single(2 * ones(20, 2))) && isfield(X.info, 'SPIKE') && isequal(X.events, ev), ...
    'Extract merges every file; the newer file wins for LFP');
L = o.LFP;
check(isequal(fieldnames(L.Y), {'LFP'}) && isequal(L.Y.LFP, X.Y.LFP) && ~isfield(L.info, 'MUA') ...
    && isfield(L.info, 'labels'), 'LFP holds only that signal (from the newest file holding it)');
check(o.signalFile("SPIKE") == string(fullfile(out, 'rec1_extract_SPIKE.mat')) && isequal(o.SPIKE.Y.SPIKE, X.Y.SPIKE), ...
    'SPIKE from its per-type file');
check(~o.has("AUX"), 'has("AUX") false when no file holds AUX');
check(isequal(o.Spikes.detected.ts, {1, 2}) && isequal(o.Chronux.sp.times, 1), 'Spikes and Chronux load the files');
check(o.Behavior.nTrials == 7 && o.pathSource("behavior") == "discovered", 'Behavior from <Name>_behavior.mat');
U = o.Units;
check(isequal(U.unitId, [0; 1]) && U.fs == 30000, 'Units read from the sorting folder');
[Ug, ~] = o.readUnits(Groups="good");
check(isequal(Ug.unitId, 0), 'readUnits forwards reader options');
check(o.Artifacts.intervals(2) == 1 && o.Manifest.name == name, 'Manifest and Artifacts decode the JSON');
P = o.load("chronux", "events");
check(isequal(fieldnames(P), {'events'}), 'load(kind, vars) reads only those variables');
T = o.inventory();
check(height(T) == numel(DatasetOutputs.Kinds) && T.Exists(T.Kind == "extract") && ~T.Exists(T.Kind == "fieldtrip") ...
    && T.NumCandidates(T.Kind == "extract") == 3, 'inventory table');

%% ---- 3. manual paths ------------------------------------------------------
fprintf('\n== 3. pinning paths ==\n');
o.FieldTripFile = fullfile(ftDir, 'rec1_fieldtrip.mat');
FT = o.FieldTrip;
check(o.pathSource("fieldtrip") == "manual" && FT.data_LFP.fsample == 1000, 'a pinned file loads');
o.ExtractFiles = fullfile(out, 'rec1_extract_LFP.mat');
check(isequal(o.Extract.Y.LFP, single(ones(10, 2))) && ~o.has("SPIKE"), 'pinned ExtractFiles replace discovery');
o.ExtractFiles = "";
o.FieldTripFile = "";
check(numel(o.ExtractFiles) == 3 && o.pathSource("fieldtrip") == "", 'assigning "" returns to discovery');
o2 = DatasetOutputs(out, SearchDirs=ftDir);
check(o2.has("fieldtrip") && o2.pathSource("fieldtrip") == "discovered", 'SearchDirs extend discovery');

o2.CacheData = true;
a = o2.Chronux;
delete(fullfile(out, 'rec1_chronux.mat'));
check(isequal(o2.Chronux, a), 'CacheData serves the loaded data again');
o2.clearCache();
check(~o2.has("chronux"), 'clearCache + a deleted file');
o2.refresh();
check(~any(o2.Candidates.Kind == "chronux"), 'refresh forgets deleted files');
save(fullfile(out, 'rec1_chronux.mat'), '-struct', 'C');

%% ---- 4. dataset mode ------------------------------------------------------
fprintf('\n== 4. from an EphysDataset ==\n');
recDir = fullfile(root, 'raw', name);
mkdir(recDir);
fid = fopen(fullfile(recDir, 'data.bin'), 'w');
fwrite(fid, zeros(2, 100, 'int16'), 'int16');
fclose(fid);
BinaryReader.writeDescriptor(recDir, struct('data_file', "data.bin", 'dtype', "int16", ...
    'n_chan', 2, 'fs', 1000, 'gain_to_uV', 0.195, 'offset', 0));
ds = EphysDataset(recDir);
ds.OutputDir = out;
behFile = fullfile(root, 'mouseA_session.mat');
Data = struct('TrialIndex', {1, 2}); Info = struct('Subject', 'mouseA'); %#ok<NASGU>
save(behFile, 'Data', 'Info');
ds.BehaviorFile = behFile;
od = ds.outputs();
check(od.Dataset == ds && isequal(od.Roots, [string(out), string(recDir)]), 'roots: outputFolder and Folder');
check(od.SortingDir == string(ds.sortingResultsDir()) && od.pathSource("sorting") == "dataset", ...
    'sorting follows the dataset association');
check(od.Behavior.nTrials == 7, 'the written behavior file wins over the session');
delete(fullfile(out, 'rec1_behavior.mat'));
od.refresh();
bh = od.Behavior;
check(od.pathSource("behavior") == "dataset" && bh.nTrials == 2 && height(bh.trials) == 2, ...
    'without <Name>_behavior.mat, Behavior loads the associated Epsych2 session');
r = ds.behaviorToMat();
od.refresh();
check(od.BehaviorFile == r.file && od.Behavior.nTrials == 2, 'behaviorToMat output is discovered');

disp(od);   % must not load any data
check(true, 'display shows paths without loading data');

%% ---- 5. another recording, a sort that is not there, a changed extract ----
fprintf('\n== 5. provenance folders, offline sorts, changed extracts ==\n');
% m1/rec1 and m2/rec1: the same name, so under one output root one folder.
shared = fullfile(root, 'outShared', name);
mkdir(shared);
rA = fullfile(root, 'proj', 'm1', name);
rB = fullfile(root, 'proj', 'm2', name);
for r = string({rA, rB})
    mkdir(r);
    fid = fopen(fullfile(r, 'data.bin'), 'w'); fwrite(fid, zeros(2, 100, 'int16'), 'int16'); fclose(fid);
    BinaryReader.writeDescriptor(r, struct('data_file', "data.bin", 'dtype', "int16", 'n_chan', 2, 'fs', 1000, ...
        'gain_to_uV', 0.195, 'offset', 0));
end
dsA = EphysDataset(rA); dsA.DatasetKey = "m1/" + name; dsA.OutputDir = shared;
dsB = EphysDataset(rB); dsB.DatasetKey = "m2/" + name; dsB.OutputDir = shared;
S = struct('Y', struct('LFP', single(ones(10, 2))), 'info', struct('LFP', struct('Fs', 1000)), ...
    'conversion', struct('dataset', name, 'sourceFolder', rA));
save(fullfile(shared, 'rec1_extract_LFP.mat'), '-struct', 'S');
oA = dsA.outputs(); oB = dsB.outputs();
check(oA.has("LFP") && isempty(oA.Foreign) && ~oB.has("LFP") ...
    && isequal(oB.Foreign, string(fullfile(shared, 'rec1_extract_LFP.mat'))), ...
    'a file whose provenance names another recording''s folder is not this dataset''s (it is listed in Foreign)');
Sp = struct('detected', struct('ts', {{1}}), ...
    'conversion', struct('dataset', name, 'sourceFolder', "Z:\old_drive\proj\m2\" + name));
save(fullfile(shared, 'rec1_spikes.mat'), '-struct', 'Sp');
oA.refresh(); oB.refresh();
check(oB.has("spikes") && ~oA.has("spikes") && dsB.isOwnSource(rB) && ~dsB.isOwnSource(rA), ...
    'after the project moved (another drive or root) the folder below the root still decides (DatasetKey)');
% A hand-picked sort recorded in the manifest stays the association while it is not there.
fm = fullfile(root, 'fm', name);
makePhyFixture(fullfile(fm, 'kilosort4'), 30000);
writeJsonFile(fullfile(fm, name + "_manifest.json"), struct('schema', "intan-dataset-manifest/2", 'name', name, ...
    'sorting', struct('results_dir', "Z:\unplugged\curated", 'source', "manual")));
of = DatasetOutputs(fm);
errId = ''; errMsg = '';
try
    of.Units;
catch ME
    errId = ME.identifier; errMsg = ME.message;
end
check(of.SortingDir == "Z:\unplugged\curated" && of.pathSource("sorting") == "manifest" && ~of.has("sorting") ...
    && strcmp(errId, 'DatasetOutputs:Missing') && contains(errMsg, "not found at Z:\unplugged\curated"), ...
    'a hand-picked sort that is not there is not replaced by the kilosort4 sort beside it; reading it names the folder');
% A combined extract is read for its signal list once, and again when it changes.
oc = DatasetOutputs(out);
comb = string(fullfile(out, 'rec1_custom.mat'));
check(oc.signalFile("MUA") == comb && oc.signalFile("LFP") == comb && oc.signalFile("MUA") == comb, ...
    'signalFile finds the signals of a combined extract');
C2 = load(comb);
C2.Y.MUA = single([]); C2.info = rmfield(C2.info, 'MUA');
save(comb, '-struct', 'C2');
check(isempty(oc.signalFile("MUA")) && oc.signalFile("LFP") == comb, 'a changed combined extract is read again');

%% ---- 6. an output root without its recordings (EphysProject) --------------
fprintf('\n== 6. an output root without its recordings ==\n');
% A copy of <OutputRoot>: n1 has an extract, a behavior file and a
% Kilosort4 sort; n2 only a SpikeInterface sort. A run record, an
% unrelated .mat and a hidden folder are no datasets.
n1 = "m1_260901_100658"; n2 = "m2_260902_102607";
bk = fullfile(root, 'backup');
b1Dir = fullfile(bk, n1);
b2Dir = fullfile(bk, n2);
mkdir(b1Dir); mkdir(fullfile(bk, 'pipeline_runs')); mkdir(fullfile(bk, 'notes')); mkdir(fullfile(bk, '.trash', 'm3_day1'));
S = struct('Y', struct('LFP', single(ones(10, 3))), ...
    'info', struct('origFs', 30000, 'labels', {{'a'; 'b'; 'c'}}, 'LFP', struct('Fs', 1000, 'nSamples', 5000)), ...
    'conversion', struct('dataset', n1, 'sourceFolder', "D:\proj\m1\" + n1));
save(fullfile(b1Dir, n1 + "_extract_LFP.mat"), '-struct', 'S');
B = struct('behavior', struct('nTrials', 3), 'conversion', struct('dataset', n1));
save(fullfile(b1Dir, n1 + "_behavior.mat"), '-struct', 'B');
makePhyFixture(fullfile(b1Dir, 'kilosort4'), 30000);
makePhyFixture(fullfile(b2Dir, 'si_spykingcircus2'), 30000);
writeJsonFile(fullfile(bk, 'pipeline_runs', '20261006T100000000_proj.json'), struct('schema', "ephys-pipeline-run/1"));
save(fullfile(bk, 'notes', 'readme.mat'), 'junk');
save(fullfile(bk, '.trash', 'm3_day1', 'm3_day1_spikes.mat'), '-struct', 'Sp');
lastwarn('');
ws = warning('off', 'EphysProject:OutputsOnly');
Pb = EphysProject(bk, OutputRoot=fullfile(root, 'elsewhere'));
warning(ws);
[~, wid] = lastwarn();
check(strcmp(wid, 'EphysProject:OutputsOnly') && isequal(sort(Pb.datasetKeys()), [n1 n2]), ...
    'a root of outputs alone gives one dataset per output folder, with a warning');
b1 = Pb.dataset(n1); b2 = Pb.dataset(n2);
check(~b1.hasRecording() && ~b2.hasRecording() && b1.OutputDir == "" && b1.outputFolder() == string(b1Dir), ...
    'they have no recording, and their outputs stay in their folders whatever the OutputRoot');
lastwarn('');
R = Pb.refresh();
[~, wid] = lastwarn();
check(all(R.Metadata) && all(R.Manifest) && all(R.Message == "") && isempty(wid), 'refresh reads them without a warning');
check(b1.Fs == 30000 && b1.NumChannels == 3 && isequal(b1.ChannelNames, ["a" "b" "c"]) && b1.Duration == 5 ...
    && isnan(b2.Fs), 'metadata from the info of the extract (none from a sort alone)');
check(~isfile(fullfile(b1Dir, n1 + "_manifest.json")) && ~isfile(fullfile(b2Dir, n2 + "_manifest.json")), ...
    'refresh writes no manifest into a folder of outputs');
ob = b1.outputs();
check(ob.has("LFP") && isempty(ob.Foreign) && ob.Behavior.nTrials == 3 && isequal(ob.Units.unitId, [0; 1]), ...
    'their outputs are read (a source folder on another drive is still this dataset''s)');
b2.Sorter = "spykingcircus2";
check(b2.outputs().has("sorting"), 'a SpikeInterface sort is read once Sorter names it');
ws = warning('off', 'EphysProject:OutputsOnly');
Pbf = EphysProject(bk, Recursive=false);
warning(ws);
check(isequal(sort(Pbf.datasetKeys()), [n1 n2]), 'Recursive=false finds the output folders directly in the root');
ws = warning('off', 'EphysProject:NoData');
check(EphysProject(fullfile(b1Dir, 'kilosort4')).NumDatasets == 0, ...
    'a sort folder as the root is no dataset (its dataset folder is above the root)');
warning(ws);
check(~any(contains(EphysProject(root).datasetKeys(), "backup")), ...
    'under a root that holds recordings, folders of outputs are no datasets');
% A copy laid out as the output transfer writes it, <subject>/<session>,
% with a second copy in a version folder <session>_v2 beside the first.
cp = fullfile(root, 'copies');
v1 = fullfile(cp, 'm1', n1);
v2 = fullfile(cp, 'm1', n1 + "_v2");
mkdir(v1); mkdir(v2);
copyfile(fullfile(b1Dir, n1 + "_extract_LFP.mat"), v1);
copyfile(fullfile(b1Dir, n1 + "_extract_LFP.mat"), v2);
copyfile(fullfile(b1Dir, 'kilosort4'), fullfile(v2, 'kilosort4'));
ws = warning('off', 'EphysProject:OutputsOnly');
Pv = EphysProject(cp);
warning(ws);
check(isequal(sort(Pv.datasetKeys()), ["m1/" + n1, "m1/" + n1 + "_v2"]) && all(string({Pv.Datasets.Name}) == n1), ...
    'a version folder <session>_v2 is the dataset <session> again, its key the folder''s');
dv = Pv.Datasets(Pv.findByKey("m1/" + n1 + "_v2"));
ov = dv.outputs();
check(ov.has("LFP") && isequal(ov.Units.unitId, [0; 1]) && startsWith(ov.ExtractFiles(1), string(v2)), ...
    'its outputs are found by the dataset''s name');
check(DatasetOutputs(v2).Name == n1 && DatasetOutputs(v2).has("LFP") && EphysProject.outputFolderName(v1) == n1, ...
    'DatasetOutputs(folder) names a version folder''s dataset the same way');
mkdir(fullfile(cp, 'm1', 'other_v3'));
save(fullfile(cp, 'm1', 'other_v3', "other_v3_spikes.mat"), '-struct', 'Sp');
check(EphysProject.outputFolderName(fullfile(cp, 'm1', 'other_v3')) == "other_v3", ...
    'a folder whose outputs carry its own _v<n> name keeps it');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_DatasetOutputs:Failures', '%d checks failed.', nFail);
end
end
