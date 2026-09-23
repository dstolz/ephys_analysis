function test_ManifestViewerApp()
%test_ManifestViewerApp  Headless checks of the dataset manifest viewer.
%   Builds ManifestViewerApp windows in the current session (uifigure; no
%   display interaction) and checks: the Summary rows of a hand-written
%   manifest (path checks against the recorded "exists", channel-count and
%   range warnings, the reference exclusions, the pairing status, unknown
%   fields kept), a pairing record the dataset would ignore, opening from a
%   file, a folder (the newest of two manifests) and an EphysDataset of a
%   synthetic recording, the timeline and probe plots, the tree, a schema
%   /1 manifest without a probe (with and without the config's default
%   probe), a file that is not JSON, Rewrite, and a Rewrite that
%   writeManifest refuses.
%
%   Usage:  test_ManifestViewerApp

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('MVA_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() cleanupRoot(root)); %#ok<NASGU>

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
    function tf = rowIs(T, field, level)
        r = T(T.Field == field, :);
        tf = height(r) >= 1 && r.Level(1) == level;
    end

probeFile = string(fullfile(here, 'probes', 'linear16_example.json'));

% ---- a hand-written manifest ---------------------------------------------
rec = fullfile(root, 'subjA_260101_120000');
mkdir(rec);
m = struct();
m.schema = "intan-dataset-manifest/2";
m.name = "subjA_260101_120000";
m.folder = string(rec);
m.recording_format = "traditional";
m.reader = "intan";
m.updated = "2026-01-01 13:00:00";
m.metadata = struct('fs', 30000, 'num_channels', 16, 'duration_s', 100, 'num_files', 2, ...
    'acq_date', "2026-01-01 12:00:00", 'files', {{'a.rhd'; 'b.rhd'}});
m.probe = struct('file', probeFile, 'exists', true, 'num_channels', 16, 'num_shanks', 1, 'depth_um', 300, 'notes', "");
m.exclude_channels = "2,5,20";
m.reference_exclude = struct('channels', "7,30", 'source', "manual");
m.manual_artifacts = [1 2; 10 12; 95 130];
m.bin = struct('file', string(fullfile(rec, 'missing.bin')), 'exists', true);
m.kilosort = struct('has_results', false, 'results_dir', "", 'num_units', NaN, 'state', "");
m.sorting = struct('results_dir', string(fullfile(root, 'nowhere')), 'source', "manual", 'exists', true, ...
    'curated', false, 'num_units', NaN, 'updated', "");
m.behavior = struct('file', "", 'exists', false, 'subject', "subjA", 'start_time', "2026-01-01 11:58:55", 'n_trials', 12, ...
    'pairing', struct('status', "unreviewed", 'auto_approved', false, 'cut_trials', [0 1], ...
    'cut_intervals', [0 0], 'fingerprint', "x", 'trial_line', "InTrial", 'summary', "12 trials", ...
    'updated', "2026-01-01 13:00:00"));
m.extra_field = 7;
m.extra_block = struct('a', 1, 'b', struct('c', "x"));
f1 = fullfile(rec, 'subjA_260101_120000_manifest.json');
writeJsonFile(f1, m);

fprintf('\n== summaryRows ==\n');
T = ManifestViewerApp.summaryRows(readJsonFile(f1));
check(all(ismember(["Section" "Field" "Value" "Check" "Level"], string(T.Properties.VariableNames))), 'table columns');
check(rowIs(T, "Schema", "ok"), 'schema /2 accepted');
check(rowIs(T(T.Section == "General", :), "Folder", "ok"), 'recording folder found');
check(rowIs(T(T.Section == "Probe", :), "File", "ok"), 'probe file found');
check(rowIs(T(T.Section == "Binary (.bin)", :), "File", "warn"), '.bin present when written but gone now: warning');
check(rowIs(T(T.Section == "Sorting", :), "Results folder", "missing") ...
    && contains(T.Check(T.Section == "Sorting" & T.Field == "Results folder"), "there when written"), ...
    'sorting folder without params.py: missing, and there when written');
check(rowIs(T, "Excluded", "warn"), 'exclusion beyond the channel count: warning');
r = T(T.Field == "Reference exclude", :);
check(rowIs(T, "Reference exclude", "warn") && contains(r.Check, "set by hand") && contains(r.Check, "2 left out"), ...
    'reference exclusion: counted, source named, beyond the channel count: warning');
check(rowIs(T, "Out of range", "warn"), 'artifact period past the end: warning');
check(rowIs(T, "Pairing", "warn"), 'unreviewed pairing: warning');
r = T(T.Section == "Behavior" & T.Field == "Start", :);
check(contains(r.Check, "-1.1 min"), 'behavior start relative to the recording');
check(any(T.Section == "Other" & T.Field == "extra_field" & T.Value == "7") ...
    && any(T.Section == "Other" & T.Field == "extra_block.b.c" & T.Value == "x"), 'unknown fields listed, blocks flattened');
check(~any(T.Field == "Default probe"), 'no default probe row for a dataset with its own probe');

mBad = m;
mBad.behavior.pairing = rmfield(mBad.behavior.pairing, 'fingerprint');
Tb = ManifestViewerApp.summaryRows(mBad);
check(rowIs(Tb, "Pairing", "warn") && contains(Tb.Check(Tb.Field == "Pairing"), "not a usable pairing record"), ...
    'a pairing record the dataset would ignore: warning');
mOk = m;
mOk.behavior.pairing.status = "approved";
mOk.behavior.pairing.auto_approved = true;
To = ManifestViewerApp.summaryRows(mOk);
check(rowIs(To, "Pairing", "ok") && contains(To.Check(To.Field == "Pairing"), "automatically") ...
    && To.Value(To.Field == "Cut trials") == "[start end] [0 1]", 'approved pairing: ok, cut counts shown as a row');

fprintf('\n== open from a file ==\n');
v = ManifestViewerApp(f1);
check(v.File == string(f1), 'File set');
check(isstruct(v.Manifest) && v.Manifest.name == "subjA_260101_120000", 'manifest decoded');
check(height(v.SummaryTable.Data) == height(v.Rows) && height(v.Rows) > 20, 'summary table filled');
check(numel(v.SummaryTable.StyleConfigurations.Target) >= 3, 'rows styled by level');
check(numel(findobj(v.TimeAxes, 'Type', 'patch')) == 4, 'timeline: recording + 3 artifact periods');
check(isempty(findobj(v.TimeAxes, 'Type', 'constantline')) ...
    && contains(v.TimeAxes.Title.String, "65 s before the recording"), 'timeline: behavior start before the recording, in the title');
sc = findobj(v.ProbeAxes, 'Type', 'scatter');
nEx = 0; nRef = 0;
for k = 1:numel(sc)
    if sc(k).Marker == "x"; nEx = numel(sc(k).XData); end
    if sc(k).Marker == "o"; nRef = numel(sc(k).XData); end
end
check(numel(sc) == 3 && nEx == 2 && nRef == 1, 'probe: channels 2 and 5 marked excluded, 7 left out of the reference');
check(contains(v.ProbeAxes.Title.String, "2 listed channel(s) not on the probe"), ...
    'probe title notes channels 20 and 30 are not on the probe');
top = string({v.Tree.Children.Text});
check(any(startsWith(top, "metadata")) && any(startsWith(top, "schema: ")), 'tree top level');
check(any(contains(string(v.JsonArea.Value), "intan-dataset-manifest/2")), 'JSON text shown');
check(v.RewriteButton.Enable == "off" && ~v.rewrite(), 'Rewrite disabled without a dataset');

fprintf('\n== folder with two manifests ==\n');
m2 = m; m2.name = "subjA_b"; m2.updated = "2026-01-02 09:00:00";
f2 = fullfile(rec, 'subjA_b_manifest.json');
pause(1.1);
writeJsonFile(f2, m2);
v.load(rec);
check(v.File == string(f2), 'newest manifest chosen');
check(contains(v.StatusLabel.Text, "2 manifests"), 'status notes the other manifest');

fprintf('\n== schema /1 ==\n');
f3 = fullfile(root, 'old_manifest.json');
writeJsonFile(f3, struct('schema', "intan-dataset-manifest/1", 'name', "old", 'folder', string(root), ...
    'probe', struct('file', "", 'num_channels', NaN, 'num_shanks', NaN, 'depth_um', NaN, 'notes', ""), ...
    'exclude_channels', ""));
v.load(f3);
check(rowIs(v.Rows, "Schema", "ok") && ~any(v.Rows.Section == "Behavior"), 'only the sections present');
check(~isempty(findobj(v.ProbeAxes, 'Type', 'text')) && isempty(findobj(v.ProbeAxes, 'Type', 'scatter')), ...
    'probe: "no probe assigned" message');
v2 = ManifestViewerApp(f3, DefaultProbeFile=probeFile);
check(v2.DefaultProbeFile == probeFile && rowIs(v2.Rows, "Default probe", "ok") ...
    && contains(v2.Rows.Check(v2.Rows.Field == "File"), "default probe is used"), ...
    'no probe of its own: the Summary names the default probe, found');
check(numel(findobj(v2.ProbeAxes, 'Type', 'scatter')) == 1 && contains(v2.ProbeAxes.Title.String, "default probe"), ...
    'no probe of its own: the default probe is drawn');
delete(v2);

fprintf('\n== not JSON ==\n');
f4 = fullfile(root, 'bad_manifest.json');
fid = fopen(f4, 'w'); fprintf(fid, '{ not json'); fclose(fid);
v.load(f4);
check(isempty(v.Manifest) && contains(v.StatusLabel.Text, "Cannot parse"), 'parse error reported');
check(v.Tabs.SelectedTab.Title == "JSON", 'JSON tab shown');

threw = false;
try
    v.load(fullfile(root, 'no_such.json'));
catch ME
    threw = ME.identifier == "ManifestViewerApp:NotFound";
end
check(threw, 'missing file raises ManifestViewerApp:NotFound');
delete(v);

fprintf('\n== from an EphysDataset ==\n');
sr = makeSyntheticRecording(fullfile(root, 'SYNTH-01_260101_120000'), Fs=5000, NumChannels=16, ...
    NumTrials=4, FileSeconds=8, SortedOutput=false, Artifacts=false, ProbeFile=probeFile);
d = EphysDataset(sr.folder);
check(isfile(d.manifestFile()), 'synthetic recording wrote a manifest');
v = ManifestViewerApp(d);
check(v.Dataset == d && v.RewriteButton.Enable == "on", 'Rewrite enabled for a dataset');
check(rowIs(v.Rows(v.Rows.Section == "Probe", :), "File", "ok"), 'probe found');
d.ManualArtifacts = [0.5 1];
check(v.rewrite() && isequal(size(artifacts(v.Manifest)), [1 2]), 'Rewrite writes the dataset state and reloads');
fid = fopen(d.manifestFile(), 'w'); fprintf(fid, '{ broken'); fclose(fid);
v.reload();
ws = warning('off', 'EphysDataset:writeManifest:Kept');
tf = v.rewrite();
warning(ws);
check(~tf && contains(v.StatusLabel.Text, "Not rewritten") && strtrim(string(fileread(d.manifestFile()))) == "{ broken", ...
    'a manifest writeManifest cannot read is kept: Rewrite says so');
fig = v.Fig;
close(fig);
check(~isvalid(v) && ~isvalid(fig), 'closing the window deletes the viewer');

fprintf('\n%d passed, %d failed\n', nPass, nFail);
if nFail > 0
    error('test_ManifestViewerApp:Failed', '%d check(s) failed.', nFail);
end
end

function a = artifacts(m)
a = double(m.manual_artifacts);
if numel(a) == 2; a = a(:).'; end
end

function cleanupRoot(root)
delete(findall(groot, 'Type', 'figure', '-regexp', 'Name', '^Manifest'));
if isfolder(root)
    rmdir(root, 's');
end
end
