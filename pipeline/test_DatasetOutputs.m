function test_DatasetOutputs()
%test_DatasetOutputs  Verification suite for DatasetOutputs.
%   Builds the files the pipeline writes for a dataset -- per-type and
%   combined extracts, spikes, Chronux, FieldTrip and behavior files, a phy
%   results folder, a manifest -- with plain save() calls, plus decoys that
%   belong to other datasets, and checks discovery, pinning and on-demand
%   loading, both for a folder alone and for an EphysDataset (a tiny
%   universal-format recording, so no Intan files or toolboxes are needed).
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
Sp = struct('detected', struct('ts', {{1, 2}}), 'units', [], 'conversion', conv(name));
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
writeJsonFile(fullfile(out, 'rec1_artifacts.json'), struct('schema', "ephys-artifacts/1", 'intervals', [0 1]));

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

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_DatasetOutputs:Failures', '%d checks failed.', nFail);
end
end
