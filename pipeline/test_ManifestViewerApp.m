function test_ManifestViewerApp()
%test_ManifestViewerApp  Headless checks of the dataset manifest viewer.
%   Builds ManifestViewerApp windows in the current session (uifigure; no
%   display interaction) and checks: the Summary rows of a hand-written
%   manifest (path checks against the recorded "exists", channel-count and
%   range warnings, the tags, the reference exclusions, the pairing status, how each
%   output was made, unknown fields kept), a pairing record the dataset
%   would ignore, opening from a
%   file, a folder (the newest of two manifests) and an EphysDataset of a
%   synthetic recording, the timeline and probe plots, the tree, a schema
%   /1 manifest without a probe (with and without the config's default
%   probe), a file that is not JSON, Rewrite, a Rewrite that writeManifest
%   refuses, and the Flow chart: PipelineDiagram.manifest at its four levels
%   of detail (what each shows, no box over another and no arrow through one,
%   the steps not run hidden) and its tab (drawn when shown, the level kept,
%   saved as a file).
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
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
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
m.tags = {'pilot', 'draft'};
m.reference_exclude = struct('channels', "7,30", 'source', "manual");
m.manual_artifacts = [1 2; 10 12; 95 130];
m.artifact_adjustments = [20 21 19.5 21.25];   % one row: jsondecode gives it back as a vector
m.artifacts = struct('file', string(fullfile(rec, 'subjA_260101_120000_artifacts.json')), 'exists', true, ...
    'created', "2026-01-01 12:30:00", 'detected', 12, 'detected_s', 4, 'manual', 3, 'adjusted', 1, ...
    'handling', struct('auto_detection', true, ...
    'sorting', struct('periods', "manual + automatic", 'treatment', "noise fill"), ...
    'spikes', struct('periods', "manual only", 'treatment', "events rejected"), ...
    'signals', struct('periods', "", 'treatment', "none"), 'noise_band_hz', 0, 'noise_seed', NaN));
m.bin = struct('file', string(fullfile(rec, 'missing.bin')), 'exists', true);
m.kilosort = struct('has_results', false, 'results_dir', "", 'num_units', NaN, 'state', "");
m.sorting = struct('results_dir', string(fullfile(root, 'nowhere')), 'source', "manual", 'exists', true, ...
    'curated', false, 'num_units', NaN, 'updated', "");
m.behavior = struct('file', "", 'exists', false, 'subject', "subjA", 'start_time', "2026-01-01 11:58:55", 'n_trials', 12, ...
    'pairing', struct('status', "unreviewed", 'auto_approved', false, 'cut_trials', [0 1], ...
    'cut_intervals', [0 0], 'fingerprint', "x", 'trial_line', "InTrial", 'summary', "12 trials", ...
    'updated', "2026-01-01 13:00:00"));
m.processing = struct( ...
    'artifacts', [], ...
    'bin', struct('file', string(fullfile(rec, 'missing.bin')), 'created', "2026-01-01 12:40:00", ...
        'run_id', "20260101T124000000", 'options', struct('Dtype', "int16", 'Filter', false, 'Scale', 5.128), ...
        'reference', struct('mode', "wcar", 'channels', "1-6,8-16", 'wcar', struct('Order', 2, 'Q', 12.5, 'QAuto', true)), ...
        'filter', "none", 'artifacts', struct('listed', 3, 'detected', 0, 'erased_s', 1.5, 'fill', "noise"), 'exists', true), ...
    'sorting', struct('results_dir', string(fullfile(root, 'nowhere')), 'created', "2026-01-01 12:41:00", 'run_id', "", ...
        'options', struct('do_CAR', true, 'Th_universal', 9), 'sorter', "kilosort4", 'probe_file', probeFile, ...
        'bin_file', string(fullfile(rec, 'missing.bin')), 'bin_reference', "car", 'own_reference', true, ...
        'exclude_channels', "2,5", 'exists', false), ...
    'signals', struct('files', {{fullfile(rec, 'x_extract.mat')}}, 'created', "2026-01-01 12:42:00", 'run_id', "", ...
        'options', struct('LFP_Fs', 1000, 'LFP_bpLoHi', {{0, "Inf"}}, 'MUA_bpLoHi', [300 5000]), ...
        'types', {{'LFP', 'MUA'}}, 'reference', struct('mode', "cmr", 'channels', "1-16", 'signals', {{'MUA'}}), ...
        'exists', false), ...
    'spikes', []);
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
check(T.Value(T.Section == "General" & T.Field == "Tags") == "draft, pilot" && ~any(T.Section == "Other" & T.Field == "tags"), ...
    'Tags row: the dataset''s tags sorted and ", "-joined, not listed under Other');
mTg = m;
mTg.tags = {};
Tt = ManifestViewerApp.summaryRows(mTg);
check(Tt.Value(Tt.Field == "Tags") == "(none)" && rowIs(Tt, "Tags", ""), 'Tags row: (none) for an empty array');
mTg = rmfield(m, 'tags');
Tt = ManifestViewerApp.summaryRows(mTg);
check(Tt.Value(Tt.Field == "Tags") == "(none)", 'Tags row: (none) for a manifest without the field');
mTg.tags = {'Pilot', 'bad tag!', 'ok'};
Tt = ManifestViewerApp.summaryRows(mTg);
check(Tt.Value(Tt.Field == "Tags") == "ok, pilot" && rowIs(Tt, "Tags", "warn") ...
    && contains(Tt.Check(Tt.Field == "Tags"), "bad tag!"), 'Tags row: an invalid tag is named in a warning (applyManifest drops it)');
r = T(T.Field == "Reference exclude", :);
check(rowIs(T, "Reference exclude", "warn") && contains(r.Check, "set by hand") && contains(r.Check, "2 left out"), ...
    'reference exclusion: counted, source named, beyond the channel count: warning');
check(rowIs(T, "Out of range", "warn"), 'artifact period past the end: warning');
aS = T.Section == "Detected artifacts moved by hand";
check(any(aS & T.Field == "Artifacts" & T.Value == "1") && any(aS & T.Field == "Change" & startsWith(T.Value, "0.75 s")) ...
    && ~any(aS & T.Field == "Out of range") && ~any(T.Section == "Other" & startsWith(T.Field, "artifact_adjustments")), ...
    'a moved detected artifact: counted in a section of its own, a single row read back from the vector');
aR = T.Section == "Artifacts";
check(rowIs(T(aR, :), "Interval file", "missing") && any(aR & T.Field == "Detected" & T.Value == "12") ...
    && any(aR & T.Field == "Detected total" & startsWith(T.Value, "4 s")) ...
    && any(aR & T.Field == "Manual" & T.Value == "3") && any(aR & T.Field == "Moved by hand" & T.Value == "1") ...
    && any(aR & T.Field == "Handling: sorting" & T.Value == "noise fill (manual + automatic)") ...
    && any(aR & T.Field == "Handling: spikes" & T.Value == "events rejected (manual only)") ...
    && any(aR & T.Field == "Handling: signals" & T.Value == "none") && ~any(T.Section == "Other" & startsWith(T.Field, "artifacts")), ...
    'artifacts block: interval file checked live, counts and per-step handling listed');
check(rowIs(T, "Pairing", "warn"), 'unreviewed pairing: warning');
r = T(T.Section == "Behavior" & T.Field == "Start", :);
check(contains(r.Check, "-1.1 min"), 'behavior start relative to the recording');
check(any(T.Section == "Other" & T.Field == "extra_field" & T.Value == "7") ...
    && any(T.Section == "Other" & T.Field == "extra_block.b.c" & T.Value == "x"), 'unknown fields listed, blocks flattened');
check(~any(T.Field == "Default probe"), 'no default probe row for a dataset with its own probe');
pS = T.Section == "Processing";
pv = @(field) T.Value(pS & T.Field == field);
check(rowIs(T(pS, :), "Sorting .bin file", "missing") && contains(pv("Sorting .bin reference"), "weighted CAR over channels 1-6,8-16") ...
    && contains(pv("Sorting .bin reference"), "Q 12.5") && contains(pv("Sorting .bin reference"), "automatic") ...
    && pv("Sorting .bin options.Dtype") == "int16" && pv("Sorting .bin artifacts.erased_s") == "1.5", ...
    'processing: the .bin''s weighted CAR (channels, order, Q), every option and its artifacts, the file checked live');
check(rowIs(T(pS, :), "Sort reference", "warn") && contains(T.Check(pS & T.Field == "Sort reference"), "referenced twice") ...
    && contains(pv("Sort reference"), "CAR in the .bin") && contains(pv("Sort reference"), "do_CAR") ...
    && pv("Sort options.Th_universal") == "9" && pv("Sort probe_file") == probeFile, ...
    'processing: a CAR .bin sorted with Kilosort4''s do_CAR on is a warning; the sorter''s settings listed');
check(pv("Signals reference") == "CMR over channels 1-16, subtracted from MUA" ...
    && pv("Signals options.LFP_Fs") == "1000" && pv("Signals options.MUA_bpLoHi") == "[300 5000]" ...
    && pv("Signals options.LFP_bpLoHi") == "[0, Inf]" && pv("Signals types") == "[LFP, MUA]", ...
    'processing: the signals'' reference and every option, a row each');
check(contains(pv("Not recorded"), "Artifact detection") && contains(pv("Not recorded"), "Spikes") ...
    && ~any(T.Section == "Other" & startsWith(T.Field, "processing")), ...
    'processing: the kinds without a record are named');

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

fprintf('\n== flow chart ==\n');
[html, summary, model] = PipelineDiagram.manifest(readJsonFile(f1));
html = string(html);
check(isequal([model.levels(1:4).name], ["steps" "outputs" "settings" "parameters"]) && numel(model.levels) == 8 ...
    && all([model.levels(5:8).direction] == "horizontal"), 'four levels of detail, from the steps to each parameter, in each direction');
check(count(html, "<svg class=""flow""") == 8 && count(html, "<button type=""button"" data-level=") == 4 ...
    && count(html, "<button type=""button"" data-dir=") == 2 ...
    && contains(html, "<div class=""lvl on"" data-level=""outputs"" data-dir=""vertical""") ...
    && contains(html, "<title>Processing flow: subjA_260101_120000</title>"), ...
    'the page holds every level in each direction and opens on Outputs, top to bottom, by default');
check(contains(summary, "5 of 7 steps run") && contains(summary, "with files gone"), ...
    'summary: the steps run (the artifacts by their manual periods, the behavior by its pairing), and the files gone');
pane = @(h, lv) extractBetween(h, "data-level=""" + lv + """ data-dir=""vertical"" data-initial", "</svg>");
check(~contains(pane(html, "steps"), "Th_universal") && ~contains(pane(html, "steps"), "written 2026") ...
    && ~contains(pane(html, "outputs"), "Th_universal") && contains(pane(html, "outputs"), "missing.bin") ...
    && contains(pane(html, "settings"), "Th_universal") && contains(pane(html, "settings"), "weighted CAR") ...
    && ~contains(pane(html, "settings"), "LFP_NotchBW") && contains(pane(html, "parameters"), "MUA_bpLoHi"), ...
    'each level adds to the last: steps; files; key settings in words; every parameter');
check(contains(pane(html, "outputs"), "reference: referenced twice") && ~contains(pane(html, "steps"), "referenced twice"), ...
    'a warning the Summary raises (a sort referenced twice) is on the box from Outputs on');
check(contains(pane(html, "steps"), "file gone") && contains(pane(html, "steps"), "not run") ...
    && count(pane(html, "steps"), "class=""badge bad""") >= 1, 'badges: a file gone now, a step not run');
mFull = m;
mFull.processing.artifacts = struct('created', "2026-01-01 12:30:00", 'run_id', "", 'detected', 12, 'detected_s', 4, ...
    'options', struct('Method', "rms", 'Threshold', 9), 'reference', struct('mode', "none", 'channels', ""), 'channels', "1-16");
mFull.processing.spikes = struct('file', string(fullfile(rec, 's.mat')), 'created', "2026-01-01 12:43:00", 'run_id', "", ...
    'options', struct('ThresholdMethod', "mad", 'ChannelOrder', (1:64).'), 'threshold_input', 4, ...
    'artifacts', struct('mode', "reject", 'periods', 2, 'rejected', 7, 'erased_s', 0), ...
    'coincidence', struct('mode', "remove", 'probe', probeFile));
mFull.processing.behavior = struct('file', string(fullfile(rec, 'b.mat')), 'created', "2026-01-01 12:44:00", 'run_id', "", ...
    'options', struct('Overwrite', true), 'n_trials', 12, 'extract_files', {{'x'}}, 'derived_events', {{'Hit'}}, 'derived_failed', {{}});
mFull.processing.nwb = struct('file', string(fullfile(rec, 'n.nwb')), 'created', "2026-01-01 12:45:00", 'run_id', "", ...
    'options', struct('Trials', true, 'Events', true), 'probe_file', probeFile, ...
    'sources', struct('extractFile', "x", 'sortingDir', "y"), 'versions', struct('pynwb', "3.0"));
mFull.behavior.file = string(f1);
[htmlF, ~, modelF] = PipelineDiagram.manifest(mFull);
check(contains(string(htmlF), "ChannelOrder") && contains(string(htmlF), "[1-64]"), 'a run of channels is shown in short');
check(contains(pane(string(htmlF), "parameters"), ">Overwrite</text><text class=""kv"" x=""")  ...
    && contains(extractAfter(pane(string(htmlF), "parameters"), ">Overwrite</text>"), ">true</text>"), 'a logical value reads as true / false');
ok = true; msg = "";
for mdl = [model, modelF]
    for L = mdl.levels
        [nBox, nThrough, nShared, nCross] = chartProblems(L);
        ok = ok && nBox == 0 && nThrough == 0 && nShared == 0 && nCross <= 6;
        msg = msg + sprintf(" %s:%d/%d/%d/%d", L.name, nBox, nThrough, nShared, nCross);
    end
end
for L = modelF.levels(5:8)
    % Left to right: each arrow leaves its source's right edge, enters its target's left edge, and runs forward.
    r = @(id) L.nodes([L.nodes.id] == id).rect;
    for e = L.edges
        a = r(e.from); b = r(e.to); p = e.points;
        ok = ok && abs(p(1, 1) - (a(1) + a(3))) < 0.5 && abs(p(end, 1) - b(1)) < 0.5 && b(1) > a(1) ...
            && p(end, 2) > b(2) && p(end, 2) < b(2) + b(4) && abs(p(end, 2) - p(end - 1, 2)) < 1e-6;
    end
end
check(ok, "no box over another, no arrow through a box, no stretch shared, few crossings (box/through/shared/crossings):" + msg);
stepsF = modelF.levels(1);
onEdges = stepsF.edges([stepsF.edges.on]);
readsOf = @(a, b) any([onEdges.from] == a & [onEdges.to] == b);
check(readsOf("behavior", "signals") && readsOf("probemap", "spikes") && readsOf("sorting", "export") && readsOf("rec", "signals") ...
    && readsOf("artifacts", "spikes"), 'the arrows say what each record read: derived events, sites, periods, units');
step1 = model.levels(1);
check(~any([step1.edges.on] & [step1.edges.from] == "artifacts" & [step1.edges.to] == "spikes") ...
    && any(~[step1.edges.on] & [step1.edges.to] == "export"), 'an arrow not read is off');
[~, ~, modelH] = PipelineDiagram.manifest(m, HideNotRun=true);
ids = [modelH.levels(1).nodes.id];
check(~any(ismember(ids, ["spikes" "export" "epsych"])) && all(ismember(["rec" "artifacts" "signals" "bin"], ids)) && all([modelH.levels(1).edges.on]), ...
    'HideNotRun leaves out the steps not run, the arrows not read and the inputs nothing reads');
mNone = struct('schema', "intan-dataset-manifest/1", 'name', "old", 'folder', string(root));
[~, sNone, modelN] = PipelineDiagram.manifest(mNone, HideNotRun=true);
check(contains(sNone, "0 of 7") && numel(modelN.levels(1).nodes) == 10, 'nothing run: the chart still draws, nothing hidden');
mSort = mNone;
mSort.sorting = struct('results_dir', string(rec), 'exists', true, 'num_units', 3, 'curated', true);
[hSort, ~, modelS] = PipelineDiagram.manifest(mSort, HideNotRun=true);
check(any([modelS.levels(1).nodes.id] == "sorting") && contains(string(hSort), "imported"), 'a sort with no record of how it was made: drawn as imported, without an arrow');
hf = PipelineDiagram.manifest(string(f1), Level="parameters", Direction="horizontal");
check(contains(string(hf), "<div class=""lvl on"" data-level=""parameters"" data-dir=""horizontal"""), 'from a file, opening on a level and direction');
hd = PipelineDiagram.manifest(string(rec), Level="steps");
check(contains(string(hd), "<div class=""lvl on"" data-level=""steps"""), 'from a folder');
threw = false;
try
    PipelineDiagram.manifest(fullfile(root, 'no_such.json'));
catch ME
    threw = ME.identifier == "ManifestViewerApp:NotFound";
end
check(threw, 'a missing file raises ManifestViewerApp:NotFound');

fprintf('\n== open from a file ==\n');
v = ManifestViewerApp(f1);
check(v.FlowStale && isempty(v.FlowHTML.HTMLSource), 'the Flow chart is not drawn until its tab is shown');
v.Tabs.SelectedTab = v.FlowTab;
v.Tabs.SelectionChangedFcn(v.Tabs, []);
src = string(v.FlowHTML.HTMLSource);
check(~v.FlowStale && contains(src, "Processing flow: subjA_260101_120000") && contains(v.FlowSummaryLabel.Text, "of 7 steps run"), ...
    'showing the tab draws the chart');
v.FlowHTML.HTMLEventReceivedFcn(v.FlowHTML, struct('HTMLEventName', 'level', 'HTMLEventData', 'settings'));
v.FlowHTML.HTMLEventReceivedFcn(v.FlowHTML, struct('HTMLEventName', 'direction', 'HTMLEventData', 'horizontal'));
v.FlowHideCheckBox.Value = true;
v.FlowHideCheckBox.ValueChangedFcn(v.FlowHideCheckBox, []);
src = string(v.FlowHTML.HTMLSource);
check(v.FlowLevel == "settings" && v.FlowDirection == "horizontal" && contains(src, "<div class=""lvl on"" data-level=""settings"" data-dir=""horizontal""") ...
    && contains(v.FlowSummaryLabel.Text, "hidden"), 'the level and direction picked are kept, and Hide steps not run draws it again');
v.reload();
check(contains(string(v.FlowHTML.HTMLSource), "<div class=""lvl on"" data-level=""settings"" data-dir=""horizontal"""), 'Reload redraws the tab shown, on the same level and direction');
fc = fullfile(root, 'chart.html');
v.saveFlowChart(fc);
check(isfile(fc) && count(string(fileread(fc)), "<svg class=""flow""") == 8 && contains(string(fileread(fc)), "flowZoom"), ...
    'saved as a standalone page with all its levels, in both directions');
v.FlowHideCheckBox.Value = false;
v.Tabs.SelectedTab = v.Tabs.Children(1);
v.Tabs.SelectionChangedFcn(v.Tabs, []);
v.reload();
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
check(v.FlowSaveButton.Enable == "off", 'no flow chart to save');

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

function [nBox, nThrough, nShared, nCross] = chartProblems(L)
%chartProblems  What a level of the chart draws over itself: boxes overlapping,
%   arrows through a box, stretches two sources share, and arrow crossings.
R = vertcat(L.nodes.rect);
nBox = 0;
for i = 1:height(R)
    for j = i + 1:height(R)
        if R(i, 1) < R(j, 1) + R(j, 3) && R(j, 1) < R(i, 1) + R(i, 3) ...
                && R(i, 2) < R(j, 2) + R(j, 4) && R(j, 2) < R(i, 2) + R(i, 4)
            nBox = nBox + 1;
        end
    end
end
nThrough = 0;
S = zeros(0, 5);
ids = unique([L.edges.from]);
for e = L.edges
    p = e.points;
    for k = 1:height(p) - 1
        lo = min(p(k, :), p(k + 1, :));
        hi = max(p(k, :), p(k + 1, :));
        S(end + 1, :) = [lo hi find(ids == e.from)]; %#ok<AGROW>
        nThrough = nThrough + nnz(lo(1) < R(:, 1) + R(:, 3) - 0.5 & hi(1) > R(:, 1) + 0.5 ...
            & lo(2) < R(:, 2) + R(:, 4) - 0.5 & hi(2) > R(:, 2) + 0.5);
    end
end
nShared = 0;
nCross = 0;
for a = 1:height(S)
    for b = a + 1:height(S)
        if S(a, 5) == S(b, 5); continue; end
        A = S(a, :); B = S(b, :);
        if A(1) == A(3) && B(1) == B(3) && abs(A(1) - B(1)) < 0.5 && min(A(4), B(4)) - max(A(2), B(2)) > 0.5
            nShared = nShared + 1;
        elseif A(2) == A(4) && B(2) == B(4) && abs(A(2) - B(2)) < 0.5 && min(A(3), B(3)) - max(A(1), B(1)) > 0.5
            nShared = nShared + 1;
        elseif A(1) == A(3) && B(2) == B(4) && A(1) > B(1) + 0.5 && A(1) < B(3) - 0.5 && B(2) > A(2) + 0.5 && B(2) < A(4) - 0.5
            nCross = nCross + 1;
        elseif A(2) == A(4) && B(1) == B(3) && B(1) > A(1) + 0.5 && B(1) < A(3) - 0.5 && A(2) > B(2) + 0.5 && A(2) < B(4) - 0.5
            nCross = nCross + 1;
        end
    end
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
