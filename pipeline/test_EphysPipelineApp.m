function test_EphysPipelineApp()
%test_EphysPipelineApp  Headless checks of the GUI's config model.
%   Builds the app in the current session (uifigure; no display interaction),
%   opens a config over a synthetic project, and checks: config -> controls ->
%   config round trip, the unsaved-changes marker, scan + selection ticks,
%   plan, the Sorting tab's Optimize for probe / Reset to defaults, running
%   one step through EphysPipeline, save, a config for another project
%   root, a rescan that keeps the active dataset, the Visualize tab (a
%   recording read across its files, keys, wheel and shading), the
%   results table filling as a run goes, the Kilosort4 monitor and queue
%   (kept at close: the queue offered back per project root, the runs
%   going followed again at the next launch), the phy launch, a figure
%   deleted without Close, and that the app's
%   preferences are restored afterwards. Dialogs that would block (uiconfirm)
%   are never triggered because the config is kept clean before New / Close.
%
%   Usage:  test_EphysPipelineApp

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));
addpath(genpath(fullfile(fileparts(here), 'vendor')));

root = fullfile(tempdir, sprintf('App_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);

% The app's preferences go to a temporary file for this suite (AppPrefs),
% which starts empty; the user's own preferences are never read or written.
g = EphysPipelineApp.PrefGroup;
restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU>
cleanup = onCleanup(@() removeRoot(root)); %#ok<NASGU>

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

% ---- fixture ---------------------------------------------------------------
Fs = 30000; numAmp = 4; spb = 128; nSamp = 4 * spb;
rng(5);
ampRaw = uint16(randi([0 65535], numAmp, nSamp));
digRaw = zeros(1, nSamp); digRaw(50:70) = 1;
proj = fullfile(root, 'proj');
f1 = fullfile(proj, 'recA_260101_120000'); mkdir(f1);   % <SubjectID>_<yyMMdd>_<HHmmss>
writeSyntheticRHD(fullfile(f1, 'recA.rhd'), ampRaw, digRaw, Fs, spb);
phyDir = fullfile(root, 'phy');
makePhyFixture(phyDir, Fs, ChannelMap=[0 1 2 3], SettingsJson=true);
d = EphysDataset(f1);
d.SortingDir = phyDir;
d.ManualArtifacts = [0.001 0.002];
behFile = fullfile(root, 'recA_session.mat');
Data = struct('ToneLevel', {60}, 'TrialIndex', {1}, 'computerTimestamp', {datetime(2026,1,1,12,0,1)}, ...
    'isTest', {false}); %#ok<NASGU>
Info = struct('Subject', "mouseA", 'StartTime', datetime(2026,1,1,12,0,0), 'FormatVersion', 2); %#ok<NASGU>
save(behFile, 'Data', 'Info');
d.BehaviorFile = behFile;
d.writeManifest();
outRoot = fullfile(root, 'out');
cfg = EphysPipelineConfig();
cfg.Name = "gui test";
cfg.Project.Root = proj;
cfg.Project.OutputRoot = outRoot;
cfg.Spikes.Enabled = true; cfg.Spikes.Filter = false; cfg.Spikes.ThresholdMethod = "absolute"; cfg.Spikes.Threshold = 2000;
cfg.Export.Formats = "chronux";
cfg.Sorting.KS4.nblocks = 3; cfg.Sorting.KS4.dmin = 12;
cfg.Parallel.Enabled = true; cfg.Parallel.MaxWorkers = 3;
cfgFile = fullfile(root, 'gui_test.json');
cfg = cfg.save(cfgFile);

fprintf('\n== 1. build + open ==\n');
app = EphysPipelineApp;
appCleanup = onCleanup(@() closeApp(app));
check(isvalid(app.Fig) && numel(app.Tabs.Children) == 15 && app.Tabs.Children(1) == app.TabCopy ...
    && app.Tabs.Children(3) == app.TabTrials && app.Tabs.Children(end - 1) == app.TabSynthetic ...
    && app.Tabs.Children(end) == app.TabCleanup && app.Tabs.SelectedTab == app.TabProject, ...
    'app builds with 15 tabs (Copy first, Trials third, Synthetic then Clean up last) and opens on Project');
check(startsWith(app.Fig.Name, "Ephys preprocessing") && ~startsWith(app.Fig.Name, "*"), 'fresh app is clean');
ok = app.openConfigFile(cfgFile);
check(ok && app.Config.Name == "gui test" && app.Config.File == string(cfgFile), 'openConfigFile loads the config');
check(strcmp(app.RootPathField.Value, proj) && app.SpkEnableCheckBox.Value && strcmp(app.SpkThresholdField.Value, '2000') ...
    && app.ExpChronuxCheckBox.Value && ~app.ExpFieldTripCheckBox.Value && app.ParamControls.nblocks.Value == 3 ...
    && strcmp(app.ParamControls.dmin.Value, '12'), 'controls reflect the config');
check(app.RunParallelCheckBox.Value && strcmp(app.RunMaxWorkersField.Value, '3') && strcmp(app.RunMaxWorkersField.Enable, 'on') ...
    && ~isprop(app, 'SpkParallelCheckBox'), 'the Run tab shows the Parallel section; the Spikes tab has no parallel box');
check(tabTip(app, app.TabSpikes) ~= "Step disabled." && tabTip(app, app.TabSignals) == "Step disabled." && app.RunSpikesCheckBox.Value, ...
    'tab strip states and the Run checklist follow the enabled steps');
app.selectTab(app.TabFlow);
ovDefault = string(app.FlowHTML.HTMLSource);
check(app.FlowViewDropDown.Value == "overview" && contains(ovDefault, "Preprocessing data flow: gui test") ...
    && contains(ovDefault, "<div class=""zoomview"" data-key=""overview"" data-initial=""fit"">") ...
    && count(ovDefault, "<button type=""button"" data-z=") == 4 && contains(ovDefault, "flowZoom.restore(htmlComponent.Data)") ...
    && app.FlowLayoutDropDown.Enable == "off", ...
    'the Diagram opens on the data-flow overview, fitted in a viewport with zoom out / 100% / in / fit buttons');
app.onFlowNavigate(struct('HTMLEventName', 'zoom', 'HTMLEventData', ...
    struct('key', 'overview', 'auto', [], 'scale', 1.5, 'x', -40, 'y', 12)));
app.onFlowNavigate(struct('HTMLEventName', 'zoom', 'HTMLEventData', ...
    struct('key', 'nosuchview', 'auto', [], 'scale', 2, 'x', 0, 'y', 0)));
app.refreshFlowChart();
z = app.FlowHTML.Data;
check(isstruct(z) && z.key == "overview" && z.scale == 1.5 && z.x == -40 && z.y == 12 && z.auto == "" ...
    && isequal(fieldnames(app.FlowZoom), {'overview'}), ...
    'a zoom the page reports is kept for its view (others ignored) and handed back to the page on a redraw');
app.FlowViewDropDown.Value = "detail";
app.onFlowViewChanged();
html = string(app.FlowHTML.HTMLSource);
check(isempty(app.FlowHTML.Data) && contains(html, "<div class=""zoomview"" data-key=""detail_tree"" data-initial=""actual"">"), ...
    'the detail view opens at 100% (no zoom kept for it yet)');
check(contains(html, "Preprocessing diagram: gui test") ...
    && contains(html, "thr = 2000 &micro;V") && contains(html, "Bandpass filter</div><div class=""d"">off (raw trace)") ...
    && contains(html, "nblocks 3") && contains(html, "Chronux file") && ~contains(html, "FieldTrip file") ...
    && ~contains(html, "sorted units (under Sorting)") && ~contains(html, "Spikes: sorted units") ...
    && startsWith(app.FlowSummaryLabel.Text, "1 of 4"), ...
    'the Diagram tab charts the loaded config (spike threshold, filter off, KS4 drift, export formats; Spikes reads no sorted units)');
app.SpkThresholdField.Value = '2500';
app.onSpikesControlsChanged();
check(contains(string(app.FlowHTML.HTMLSource), "thr = 2500 &micro;V"), 'the Diagram follows config edits while shown');
app.SpkThresholdField.Value = '2000';
app.onSpikesControlsChanged();

fprintf('\n== 1a. Diagram: boxes open their settings ==\n');
loaded = app.Config;                       % put back after the every-branch chart below
allOn = loaded;
allOn.Artifacts.Enabled = true; allOn.Sorting.Enabled = true; allOn.Signals.Enabled = true;
allOn.Signals.LFP = true; allOn.Signals.MUA = true; allOn.Signals.SPIKE = true; allOn.Signals.AUX = true;
allOn.Export.Enabled = true; allOn.Export.Formats = ["chronux" "fieldtrip" "epochs" "kcsd"];
allOn.Artifacts.Reference = "cmr";
app.applyConfig(allOn);
full = string(app.FlowHTML.HTMLSource);
targets = unique(strip(split(join(string(regexp(full, '(?<=data-nav=")[^"]+', 'match')), ","), ",")));
missing = targets(arrayfun(@(t) isempty(app.flowNavControls(t)), targets));
msg = sprintf('every one of the %d controls the Diagram boxes point at exists', numel(targets));
if ~isempty(missing); msg = msg + " (missing: " + join(missing, ", ") + ")"; end
check(numel(targets) > 50 && isempty(missing) && contains(full, "sendEventToMATLAB('navigate'") ...
    && ~isempty(app.FlowHTML.HTMLEventReceivedFcn), msg);
check(isempty(regexp(full, '<div class="n k-[a-z]+( dim)?">', 'once')) ...
    && numel(regexp(full, '<div class="n k-step( dim)?" data-nav=')) == 5 && count(full, "<div class=""n k-src") == 1, ...
    'one tree from one recording box; no box is left without a target, and each of the 5 step boxes has one too');
refAt = strfind(full, "data-nav=""ArtRefDropDown,");   % once: every step subtracts it once from its read
check(isscalar(refAt) && strfind(full, "<div class=""n k-src") < refAt && refAt < strfind(full, "<li class=""c-artifacts"">") ...
    && contains(full, "median of the good channels, subtracted once from each<br>as each step reads the recording<br>not Signals") ...
    && contains(full, ">LFP</div><div class=""d"">amplifier<br>as recorded (no common reference)</div>") ...
    && contains(full, ">MUA</div><div class=""d"">amplifier<br>common CMR referenced</div>") ...
    && contains(full, ">KS4 CAR</div><div class=""d"">off (do_CAR = false): the .bin<br>already carries the common reference</div>"), ...
    ['the common reference is drawn once, between the recording and the steps; the LFP says it is taken as recorded, ' ...
     'the MUA that it is referenced, and Kilosort4''s own CAR is off']);
sortAt = [strfind(full, "<li class=""c-sorting"">"), ...
    strfind(full, ">Blank artifact periods</div>"), strfind(full, ">Write .bin</div>")];
check(~isempty(regexp(full, ['>Artifact periods</div><div class="d">[^<]*(<br>[^<]*)*</div></div>' ...
    '<span class="stem"></span><ul><li class="c-sorting">'], 'once')) ...
    && numel(sortAt) == 3 && issorted(sortAt), ...
    'Sorting hangs from the artifact periods, and writes its .bin after the blanking');
sigAt = [strfind(full, ">Artifact periods</div>"), strfind(full, "<li class=""c-signals"">"), ...
    strfind(full, ">Channel selection</div>"), ...
    strfind(full, ">Erase artifact periods</div>"), strfind(full, ">LFP</div>"), strfind(full, ">MUA</div>"), ...
    strfind(full, ">SPIKE</div>"), strfind(full, ">AUX</div>"), strfind(full, ">Reject in Spikes</div>")];
check(numel(sigAt) == 9 && issorted(sigAt) && contains(full, "a line across each, before any filter") ...
    && contains(full, "touching an artifact period: dropped"), ...
    ['Signals hangs from the artifact periods too: the channel selection, then the periods ' ...
     'erased before LFP / MUA / SPIKE (AUX after); its epochs drop the ones that touch a period']);
noErase = allOn;
noErase.Signals.BlankArtifacts = false;
app.applyConfig(noErase);
raw = string(app.FlowHTML.HTMLSource);
at = [strfind(raw, ">Reject in Spikes</div>"), strfind(raw, "<li class=""c-signals"">")];
check(numel(at) == 2 && issorted(at) && contains(raw, "Erase artifact periods</div><div class=""d"">off (as recorded)") ...
    && startsWith(app.FlowSummaryLabel.Text, "4 of 4"), ...
    'with the Signals erase switch off, Signals hangs from the recording (its reference) again and its erase box is drawn off');
app.applyConfig(allOn);
app.FlowLayoutDropDown.Value = "steps";
app.onFlowLayoutChanged();
per = string(app.FlowHTML.HTMLSource);
check(count(per, "<div class=""n k-src") == 2 && contains(per, "Downstream (reads step outputs)") ...
    && numel(regexp(per, '<div class="n k-step( dim)?" data-nav=')) == 5 ...
    && contains(per, ">Artifact periods</div><div class=""d"">from Artifacts</div></div><span class=""stem""></span><ul><li class=""c-sorting"">") ...
    && contains(per, ">Artifact periods</div><div class=""d"">from Artifacts</div></div><span class=""stem""></span><ul><li class=""c-signals"">") ...
    && ~contains(per, "from Sorting") && contains(per, "from Signals") && string(AppPrefs.getpref(g, 'DiagramLayout')) == "steps", ...
    'Layout "Tree per step": a tree from the recording for Artifacts and Spikes; Sorting and Signals (under the artifact periods) and Export downstream; saved as a preference');
spkErase = allOn;
spkErase.Spikes.ArtifactMode = "erase";
app.applyConfig(spkErase);
perE = string(app.FlowHTML.HTMLSource);
spE = strfind(perE, "<li class=""c-spikes"">");
eE = strfind(perE, "NaN: out of the thresholds,");
fE = sort([strfind(perE, ">Butterworth bandpass</div>"), strfind(perE, ">Bandpass filter</div>")]);
eraseFirst = isscalar(eE) && any(spE < eE) && any(fE > eE) && ~any(fE > max(spE(spE < eE)) & fE < eE);
check(count(perE, "<div class=""n k-src") == 1 && eraseFirst ...
    && contains(perE, ">Artifact periods</div><div class=""d"">from Artifacts</div></div><span class=""stem""></span><ul><li class=""c-spikes"">") ...
    && ~contains(perE, ">Reject in Spikes</div>") && contains(perE, "NaN: out of the thresholds,"), ...
    'Spikes.ArtifactMode "erase": Spikes hangs from the artifact periods too, erasing them before its filter');
app.FlowLayoutDropDown.Value = "tree";
app.onFlowLayoutChanged();
app.applyConfig(loaded);
drift = struct('nav', 'ks4.nblocks,ks4.sig_interp,ks4.binning_depth,ks4.dmin,ks4.dminx', 'title', 'Drift correction');
app.onFlowNavigate(struct('HTMLEventName', 'navigate', 'HTMLEventData', drift));
check(app.Tabs.SelectedTab == app.TabSorting && numel(app.FlowHighlight) == 5 ...
    && isequal(app.ParamControls.nblocks.FontColor, [0.15 0.45 0.80]) && app.ParamControls.dmin.FontWeight == "bold" ...
    && contains(app.StatusBar.Text, "Drift correction is set on the Sorting tab"), ...
    'a click in the Diagram opens the first control''s tab, marks every control of the box and says where it went');
app.selectTab(app.TabFlow);
check(isempty(app.FlowHighlight) && app.ParamControls.nblocks.FontWeight == "normal" ...
    && isequal(app.ParamControls.nblocks.FontColor, app.ParamControls.nt.FontColor), ...
    'the marks come off when the tab changes');
app.onFlowNavigate(struct('HTMLEventName', 'navigate', ...
    'HTMLEventData', struct('nav', 'NoSuchField', 'title', 'Gone')));
check(app.Tabs.SelectedTab == app.TabFlow && contains(app.StatusBar.Text, "no setting to open"), ...
    'a box pointing at a control that no longer exists says so instead of navigating');

fprintf('\n== 1a. Diagram: the data-flow overview ==\n');
flowOn = allOn;
flowOn.Behavior.Enabled = true;
flowOn.Export.IncludeDetected = true; flowOn.Export.EpochSource = "behavior";
app.applyConfig(flowOn);
app.FlowViewDropDown.Value = "overview";
app.onFlowViewChanged();
ov = string(app.FlowHTML.HTMLSource);
check(contains(ov, "Preprocessing data flow: gui test") && contains(ov, "<svg class=""flow""") ...
    && count(ov, "<g class=""node c-") == 10 && count(ov, "<g class=""edge ") == 16 ...
    && app.FlowLayoutDropDown.Enable == "off" && startsWith(app.FlowSummaryLabel.Text, "7 of 7 steps enabled") ...
    && string(AppPrefs.getpref(g, 'DiagramView')) == "overview", ...
    'View "Data-flow overview": a box per input and step, 16 arrows between them, Layout off, all 7 steps counted; saved as a preference');
[~, ~, M] = app.flowOverviewHTML();
[nCross, nOverlap, nThrough, nBadEnd] = flowGeometry(M);
check(nThrough == 0 && nOverlap == 0 && nBadEnd == 0 && nCross <= 2, sprintf(['the overview''s arrows never run ' ...
    'through a box or share a stretch between sources and each ends on its target''s top (%d crossing(s), at most 2)'], nCross));
targets = unique(strip(split(join(string(regexp(ov, '(?<=data-nav=")[^"]+', 'match')), ","), ",")));
missing = targets(arrayfun(@(t) isempty(app.flowNavControls(t)), targets));
msg = sprintf('every one of the %d controls the overview''s boxes point at exists', numel(targets));
if ~isempty(missing); msg = msg + " (missing: " + join(missing, ", ") + ")"; end
check(numel(targets) > 30 && isempty(missing) && contains(ov, "sendEventToMATLAB('navigate'"), msg);
reads = @(M, a, b) M.edges([M.edges.from] == a & [M.edges.to] == b).on;
check(reads(M, "artifacts", "signals") && reads(M, "artifacts", "spikes") && reads(M, "behavior", "export") ...
    && reads(M, "spikes", "export") && ~any([M.edges.dim]) && ~any([M.edges.from] == "sorting" & [M.edges.to] == "spikes"), ...
    'with every step on, Signals and Spikes read the artifact periods, Export the behavior and spikes files; Spikes never reads the sort');
flowOff = flowOn;
flowOff.Signals.BlankArtifacts = false; flowOff.Sorting.Enabled = false; flowOff.Spikes.ArtifactMode = "none";
flowOff.Export.Formats = strings(1, 0);
app.applyConfig(flowOff);
[ovOff, sumOff, M] = app.flowOverviewHTML();
check(~reads(M, "artifacts", "signals") && ~reads(M, "artifacts", "spikes") && ~reads(M, "behavior", "export") ...
    && all([M.edges([M.edges.to] == "sorting").dim]) && ~any([M.edges([M.edges.to] ~= "sorting").dim]) ...
    && contains(ovOff, "<g class=""edge c-artifacts off"" data-from=""artifacts"" data-to=""signals"">") ...
    && contains(ovOff, ">No format ticked</text>") && startsWith(sumOff, "6 of 7") ...
    && contains(string(app.FlowHTML.HTMLSource), ">No format ticked</text>"), ...
    'the reads a config leaves off are dashed, the arrows into a disabled step fade with it, and the shown chart follows edits');
flowNS = flowOn; flowNS.Behavior.Search = false;
app.applyConfig(flowNS);
[ovNS, ~, M] = app.flowOverviewHTML();
check(contains(ovNS, "associated by hand; no search") && contains(ovNS, "associated session") ...
    && ~contains(ovNS, "matched by name") && reads(M, "epsych", "behavior") ...
    && app.BehSearchDirsField.Enable == "off" && app.BehOverwriteCheckBox.Enable == "off" ...
    && app.BehFindButton.Text == "Write behavior for selected" && ~app.gatherConfig().Behavior.Search, ...
    'Behavior.Search off: the overview draws the associated sessions with no search, the search controls grey out and the step button writes');
app.FlowViewDropDown.Value = "detail";
app.onFlowViewChanged();
check(app.FlowLayoutDropDown.Enable == "on" && contains(string(app.FlowHTML.HTMLSource), "Preprocessing diagram: gui test") ...
    && string(AppPrefs.getpref(g, 'DiagramView')) == "detail", 'back on "Every parameter": the detail chart, with Layout on again');
app.applyConfig(loaded);
app.selectTab(app.TabProject);
g2 = app.gatherConfig();
check(g2.isequalConfig(app.Config) && isequaln(g2.toStruct(), cfg.toStruct()), 'gatherConfig reproduces the loaded config exactly');
check(~startsWith(app.Fig.Name, "*") && contains(app.Fig.Name, "gui_test.json"), 'title shows the file and no unsaved marker');

% the Export tab's event-epoch settings, both ways
app.ExpEpochsCheckBox.Value = true;
app.ExpEpochSourceDropDown.Value = 'behavior';
app.ExpEpochPreField.Value = -0.35;
app.ExpEpochPostField.Value = 0.8;
app.ExpEpochSpikeBaseDropDown.Value = 'window';
app.ExpEpochIncompleteDropDown.Value = 'drop';
app.ExpEpochArtifactsDropDown.Value = 'keep';
gE = app.gatherExportSection();
check(any(gE.Formats == "epochs") && gE.EpochSource == "behavior" && isequal(gE.EpochWindow, [-0.35 0.8]) ...
    && gE.EpochSpikeTimeBase == "window" && gE.EpochIncomplete == "drop" && gE.EpochArtifacts == "keep", ...
    'the Export tab''s epoch settings reach the Export section');
app.applyExportSection(app.Config.Export);
check(~app.ExpEpochsCheckBox.Value && strcmp(app.ExpEpochSourceDropDown.Value, 'line') ...
    && app.ExpEpochPreField.Value == -0.2 && strcmp(app.ExpEpochIncompleteDropDown.Value, 'nan') ...
    && strcmp(app.ExpEpochArtifactsDropDown.Value, 'drop'), ...
    'applyExportSection puts the epoch settings back');
app.ExpKCSDCheckBox.Value = true;
gK = app.gatherExportSection();
check(any(gK.Formats == "kcsd"), 'the kCSD box adds the kcsd format');
kc = app.Config.Export; kc.Formats = "kcsd";
app.applyExportSection(kc);
check(app.ExpKCSDCheckBox.Value && ~app.ExpChronuxCheckBox.Value, 'applyExportSection ticks the kCSD box for the kcsd format');
app.applyExportSection(app.Config.Export);

% the artifact periods in the signals: the Signals tab's switch and the Artifacts tab's use
app.SigBlankArtifactsCheckBox.Value = false;
app.ArtApplySignalsCheckBox.Value = false;
check(~app.gatherConvertConfig().BlankArtifacts && ~app.gatherArtifactsSection().ApplyToSignals, ...
    'the Signals erase switch and the Artifacts tab''s signals use reach their sections');
app.applyConvertConfig(app.Config.Signals);
app.applyArtifactsSection(app.Config.Artifacts);
check(app.SigBlankArtifactsCheckBox.Value && app.ArtApplySignalsCheckBox.Value, ...
    'applying the sections puts both back on (the defaults)');

fprintf('\n== 1b. Help menu: wiki pages ==\n');
items = flip(string({app.HelpMenu.Children.Text}));
check(isequal(items(1:2), ["Help for this tab" "Documentation home"]) && numel(items) == 12 ...
    && isequal(items(10:12), ["Report an issue on GitHub..." "Request a feature on GitHub..." "About EphysPipelineApp"]) ...
    && app.helpURL("") == app.WikiURL && app.helpURL("Quick-Start") == app.WikiURL + "/Quick-Start", ...
    'the Help menu opens the tab''s page, the wiki home, the guides, the two GitHub issue items and About');
v = ephysVersion();
check(~isempty(regexp(v.Version, '^\d+\.\d+\.\d+$', 'once')) && startsWith(v.Text, v.Version) ...
    && (v.Commit == "" || contains(v.Text, "commit " + v.Commit)) && isfolder(v.Folder + "/pipeline"), ...
    'ephysVersion gives the release number, the git commit and the repository folder');
tabPages = strings(1, numel(app.TabList));
for k = 1:numel(app.TabList)
    app.Tabs.SelectedTab = app.TabList(k);   % helpURL reads only the selection; no tab-change refresh needed
    tabPages(k) = app.helpURL("tab");
end
app.Tabs.SelectedTab = app.TabProject;
check(numel(tabPages) == 15 && numel(unique(tabPages)) == 15 && all(startsWith(tabPages, app.WikiURL + "/")) ...
    && ~any(endsWith(tabPages, "/App-Overview")), 'every tab has its own wiki page');

fprintf('\n== 1c. Help menu: GitHub issue and feature request ==\n');
bug = app.issueReport("bug", Description="the Spikes step stops here");
check(contains(bug, "### What happened") && contains(bug, "the Spikes step stops here") ...
    && contains(bug, "### Steps to reproduce") && contains(bug, "<summary>System</summary>") ...
    && contains(bug, "MATLAB") && contains(bug, "<summary>Pipeline options</summary>") ...
    && contains(bug, "gui test") && contains(bug, "<summary>Config JSON</summary>") ...
    && contains(bug, """schema""") && contains(bug, "<summary>Logs</summary>"), ...
    'a bug report carries the description, the system, the config and the logs');
feat = app.issueReport("feature", Description="a button that stitches", System=false, Config=false, Logs=false);
check(contains(feat, "### What would you like to be able to do") && contains(feat, "a button that stitches") ...
    && ~contains(feat, "<details>") && ~contains(feat, "### What happened") ...
    && ~contains(feat, string(proj)), 'a feature request keeps only what is ticked: no system, config or logs');
app.LastError = MException("EphysPipelineApp:test", "synthetic failure");
app.LastErrorTime = datetime('now');
err = app.issueReport("bug", System=false, Config=false);
check(contains(err, "**Last run error**") && contains(err, "synthetic failure") ...
    && ~contains(app.issueReport("bug", System=false, Config=false, Logs=false), "synthetic failure"), ...
    'the last run error and its stack go with the report, unless the logs are unticked');
app.LastError = MException.empty(0, 1);
app.LastErrorTime = NaT;
[url, cut] = app.issueURL("bug", "a title", "line one" + newline + "line two");
check(startsWith(url, app.RepoURL + "/issues/new?") && contains(url, "title=a%20title") ...
    && contains(url, "body=line%20one%0Aline%20two") && contains(url, "labels=bug") ...
    && ~cut && ~contains(url, " ") && ~contains(url, newline), ...
    'the issue address is the prefilled form, percent-encoded');
check(contains(app.issueURL("feature", "t", "b"), "labels=enhancement"), ...
    'a feature request is filed as an enhancement');
[long, cut] = app.issueURL("bug", "t", join(repmat("0123456789", 1, 2000), newline));
check(cut && strlength(long) <= 7000 && contains(long, "was%20too%20long%20for%20the%20address"), ...
    'a report too long for the address is cut and says so in the body');

fprintf('\n== 1d. a config with values the controls cannot show ==\n');
bad = cfg;
bad.Name = "cannot show";
bad.Artifacts.Threshold = NaN;            % detection is off: validate lets it pass
bad.Behavior.MaxStartOffsetMin = 0;       % Behavior is off; the field wants more than 0
bad.Spikes.Polarity = "nonsense";
badFile = fullfile(root, 'cannot_show.json');
bad.save(badFile);
ok = app.openConfigFile(badFile);
check(ok && app.Config.Name == "cannot show" && numel(app.ApplyRejected) == 3 ...
    && contains(join(app.ApplyRejected), "Artifacts.Threshold = NaN") && contains(join(app.ApplyRejected), "Behavior.MaxStartOffsetMin = 0") ...
    && contains(join(app.ApplyRejected), "Spikes.Polarity") && app.Config.Artifacts.Threshold == app.ArtThresholdField.Value ...
    && app.Config.Behavior.MaxStartOffsetMin == app.BehMaxOffsetField.Value && startsWith(app.Fig.Name, "*"), ...
    'a config with values its fields cannot show opens: those are listed, the config holds what the fields show and is marked unsaved');
ok = app.openConfigFile(cfgFile);
check(ok && isempty(app.ApplyRejected) && ~startsWith(app.Fig.Name, "*") && app.Config.Spikes.Polarity == "negative", ...
    'the good config opens clean again');

fprintf('\n== 2. edits and the unsaved marker ==\n');
app.SpkThresholdField.Value = '1500';
app.onSpikesControlsChanged();
check(app.Config.Spikes.Threshold == 1500 && startsWith(app.Fig.Name, "*"), 'a control edit updates the config and marks it unsaved');
app.RunSignalsCheckBox.Value = true;
app.RunSignalsCheckBox.ValueChangedFcn(app.RunSignalsCheckBox, []);   % as a click would
check(app.Config.Signals.Enabled && app.SigEnableCheckBox.Value && tabTip(app, app.TabSignals) ~= "Step disabled.", ...
    'the Run checklist and the step tab stay in sync');
app.SigEnableCheckBox.Value = false;
app.onConvertControlsChanged();
check(~app.Config.Signals.Enabled && ~app.RunSignalsCheckBox.Value, 'and back');
app.SortEnableCheckBox.Value = true;
app.SortSkipExistingCheckBox.Value = true;
app.SortEnableCheckBox.ValueChangedFcn(app.SortEnableCheckBox, []);   % as a click would
check(app.Config.Sorting.Enabled && app.Config.Sorting.SkipExisting && app.SortEnableCheckBox.Value ...
    && app.RunSortingCheckBox.Value, 'ticking Enable on the Sorting tab sticks');
app.SortEnableCheckBox.Value = false;
app.SortSkipExistingCheckBox.Value = false;
app.SortEnableCheckBox.ValueChangedFcn(app.SortEnableCheckBox, []);
app.RunMaxWorkersField.Value = '';
app.onParallelControlsChanged();
check(isnan(app.Config.Parallel.MaxWorkers) && app.Config.Parallel.Enabled, 'a blank worker cap means automatic');
app.RunParallelCheckBox.Value = false;
app.onParallelControlsChanged();
check(~app.Config.Parallel.Enabled && strcmp(app.RunMaxWorkersField.Enable, 'off'), 'unticking Parallel disables the worker cap');
app.RunParallelCheckBox.Value = true;
app.onParallelControlsChanged();
[html, ~] = app.flowChartHTML();
check(contains(html, "Write .bin") && contains(html, "run_kilosort") && ~contains(html, "SpikeInterface"), ...
    'the Sorting diagram shows Kilosort4 on a .bin');
app.ParamControls.tmax.Value = 'abc';
[~, msg] = app.gatherSortingSection();
check(msg ~= "", 'an unparseable KS4 field is reported');
app.ParamControls.tmax.Value = 'Infinity';
app.ParamControls.drift_smoothing.Value = '1, 2, 3';
app.onConfigChanged();
app.ParamControls.drift_smoothing.Value = 'x, 2, 3';
app.onConfigChanged();
[S, msg] = app.gatherSortingSection();
check(isequal(app.Config.Sorting.KS4.drift_smoothing, [1 2 3]) && isequal(S.KS4.drift_smoothing, [1 2 3]) ...
    && contains(msg, "drift_smoothing") && contains(app.StatusBar.Text, "drift_smoothing") && ~app.onSaveConfig(), ...
    'a Kilosort4 field that does not parse keeps the value in force (not the default), is reported, and Save refuses');
app.ParamControls.drift_smoothing.Value = '0.5, 0.5, 0.5';
app.onConfigChanged();
K0 = app.Config.Spikes;
K = K0; K.Threshold = 0.1953125; K.MaxAmplitudeUV = 123.456789; K.EdgePadMs = 0.1;
app.applySpikesSection(K);
gK = app.gatherSpikesSection();
check(strcmp(app.SpkThresholdField.Value, '0.1953125') && gK.Threshold == 0.1953125 ...
    && gK.MaxAmplitudeUV == 123.456789 && gK.EdgePadMs == 0.1, ...
    'numbers in the Spikes text fields are written in full and read back unchanged (0.1953125, not 0.19531)');
app.applySpikesSection(K0);
app.ArtMethodDropDown.Value = 'microvolts';
app.onArtifactControlsChanged();
check(app.ArtThresholdField.Value == 1500 && app.Config.Artifacts.Threshold == 1500, ...
    'switching Method to Absolute microvolts takes its own default threshold (1500 uV), not the running-RMS 9');
app.ArtThresholdField.Value = 800;
app.onArtifactControlsChanged();
app.ArtMethodDropDown.Value = 'commonmode';
app.onArtifactControlsChanged();
check(app.ArtThresholdField.Value == 800, 'a threshold typed for the previous method is kept');
app.ArtMethodDropDown.Value = 'rms';
app.ArtThresholdField.Value = 1500;
app.onArtifactControlsChanged();
check(app.ArtThresholdField.Value == 9 && app.Config.Artifacts.Method == "rms", ...
    'back to running RMS from the common-mode default: 9 robust SDs again');
A0 = app.Config.Artifacts;
A2 = A0; A2.Filter = true; A2.FilterType = "bandpass"; A2.FilterCutoff = [300 3000]; A2.FilterOrder = 2;
app.applyArtifactsSection(A2);
app.Config.Artifacts = A2;   % as applyConfig leaves it
app.ArtHighpassField.Value = 400;
app.onArtifactControlsChanged();
gA = app.Config.Artifacts;
check(gA.FilterType == "bandpass" && gA.FilterOrder == 2 && isequal(gA.FilterCutoff, [400 3000]), ...
    'the filter type, order and upper band edge (no control) are kept; the High-pass field sets the band''s lower edge');
A3 = A0; A3.Filter = true; A3.FilterType = "lowpass"; A3.FilterCutoff = 250;
app.applyArtifactsSection(A3);
app.Config.Artifacts = A3;
app.onArtifactControlsChanged();
check(app.Config.Artifacts.FilterType == "lowpass" && app.Config.Artifacts.FilterCutoff == 250 ...
    && strcmp(app.ArtHighpassField.Enable, 'off'), 'a low-pass filter keeps its cut-off, and the High-pass field is off');
app.applyArtifactsSection(A0);
app.Config.Artifacts = A0;
app.onArtifactControlsChanged();

fprintf('\n== 3. scan, selection, plan ==\n');
app.onScan();
T = app.DatasetsTable.Data;
check(~isempty(app.Project) && app.Project.NumDatasets == 1 && height(T) == 1 && T.Key(1) == "recA_260101_120000" ...
    && contains(T.Sorting(1), "manual"), 'scan fills the table with keys and the sorting association');
check(~T.Select(1) && app.Config.Project.Selection == "all", 'no ticks = every dataset');
check(numel(app.DatasetTickedItems) == 1 && string(app.DatasetTickedItems.Text) == "(no datasets ticked)" ...
    && numel(app.DatasetMenuItems) == 1 && isequal(app.DatasetMenu.Children(1:2), [app.DatasetManifestItem; app.DatasetAllMenu]), ...
    'the Dataset menu lists no datasets while none is ticked; All datasets lists every one; View manifest at the bottom');
app.onSelectDatasets("all");
check(app.Config.Project.Selection == "list" && isequal(app.Config.Project.Datasets, "recA_260101_120000"), 'ticking rows selects by key');
check(numel(app.DatasetTickedItems) == 1 && isequal(app.DatasetTickedItems.UserData, 1) && app.DatasetTickedItems.Checked ...
    && isequal(app.DatasetMenu.Children(1:2), [app.DatasetManifestItem; app.DatasetAllMenu]), ...
    'a ticked dataset is listed above All datasets, checked when active');
check(all(arrayfun(@(dd) isequal(dd.ItemsData, {1}) && isequal(dd.Value, 1), app.DatasetPickers)), ...
    'every tab''s Dataset box lists the ticked datasets');
app.onSelectDatasets("none");
check(app.SelectedDatasetIdx == 1 && app.DatasetMenuItems(1).Checked && numel(app.DatasetPickers) == 8 ...
    && all(arrayfun(@(dd) isequal(dd.Value, 1), app.DatasetPickers)) && height(app.DatasetsTable.StyleConfigurations) == 1, ...
    'the scan makes the dataset active: menu item checked, every tab''s Dataset box set, table row highlighted');
app.onDatasetCellSelection(struct('Indices', [1 1]));
check(contains(app.SortResultsLabel.Text, "manual") && size(app.ArtManualTable.Data, 1) == 1, ...
    'selecting a row shows its sorting association and manual periods');
app.onViewManifest();
mv = findall(groot, 'Type', 'figure', 'Name', "Manifest - recA_260101_120000_manifest.json");
mvT = findall(mv, 'Type', 'uitable');
check(isscalar(mv) && isscalar(mvT) && any(mvT.Data.Field == "Periods" & mvT.Data.Value == "1") ...
    && contains(app.StatusBar.Text, "Opened the manifest of recA_260101_120000"), ...
    'Dataset > View manifest opens the active dataset''s manifest in a viewer');
close(mv);
check(~any(isvalid(mv)), 'closing the viewer window closes it');
check(app.ToolsTargetLabel.Text == "recA_260101_120000" && app.ToolsManifestButton.Enable == "on" ...
    && app.ToolsAnalysisButton.Enable == "on" && app.ToolsFolderButton.Enable == "on" ...
    && app.ToolsPhyButton.Enable == matlab.lang.OnOffSwitchState(app.currentDataset().hasPhyOutput()), ...
    'the Tools panel names the active dataset; phy only with sorted output');
app.ToolsScopeDropDown.Value = 'ticked';
app.syncToolsPanel();
check(app.ToolsTargetLabel.Text == "recA_260101_120000 (none ticked: every dataset)", ...
    'Tools on the ticked datasets with none ticked: every dataset, as a run takes them');
app.onSelectDatasets("all");
check(app.ToolsTargetLabel.Text == "1 ticked: recA_260101_120000", 'ticking a row names it in the Tools panel');
app.onOpenTool("manifest");
mv = findall(groot, 'Type', 'figure', 'Name', "Manifest - recA_260101_120000_manifest.json");
check(isscalar(mv) && contains(app.StatusBar.Text, "Opened the manifest of recA_260101_120000"), ...
    'Tools > Manifest viewer opens the ticked dataset''s manifest');
close(mv);
if exist('EphysAnalysisApp', 'class')
    an = app.onOpenAnalysisApp(app.toolTargets());
    anS = an.Config.Source;
    check(isvalid(an.Fig) && anS.Mode == "project" && anS.Root == app.Project.Root && anS.Selection == "all" ...
        && height(an.DatasetsTable.Data) == 1 && contains(app.StatusBar.Text, "Opened the analysis app on"), ...
        'Tools > Analysis app on every dataset opens the analysis app on the whole project');
    delete(an.Fig);   % not onClose: that saves the analysis app's preferences
else
    fprintf('  (analysis folder not on the path: Tools > Analysis app not checked)\n');
end
app.onSelectDatasets("none");
app.ToolsScopeDropDown.Value = 'active';
app.syncToolsPanel();
check(~isempty(app.EpsychMetaCache) && isKey(app.EpsychMetaCache, char(behFile)) ...
    && contains(app.DatasetsTable.Data.Behavior(1), "(1 trials)"), ...
    'the Behavior column reads the session summary once and keeps it until the file changes');
app.ExcludeChannelsField.Value = '1,5,32-40,4O';
app.onApplyExclude("selected");
app.ArtRefExcludeField.Value = '2,x';
app.onReferenceExcludeEdited();
check(isempty(app.currentDataset().ExcludeChannels) && strcmp(app.ExcludeChannelsField.Value, '') ...
    && isempty(app.currentDataset().ReferenceExclude) && app.ArtRefExcludeField.Value == "", ...
    'a channel list that does not parse ("4O", "x") changes nothing and the fields show the lists in force');
app.onPlan();
P = app.RunResultsTable.Data;
check(istable(P) && any(P.Step == "spikes" & P.Status == "ready"), 'plan lists the spikes step as ready');
app.onValidate();
check(iscell(app.RunIssuesTable.Data) || istable(app.RunIssuesTable.Data), 'validate fills the issues table');

fprintf('\n== 3a0. Artifacts tab: the artifact viewer ==\n');
art0 = app.Config.Artifacts;
ax = app.ArtViewAxes;
check(~app.ArtView.previewed && strcmp(app.ArtViewSpinner.Enable, 'off') && app.ArtViewCountLabel.Text == "of 0" ...
    && any(contains(string(get(findobj(ax, 'Type', 'text'), 'String')), "Detect / Preview")), ...
    'the viewer asks for a preview until one has run');
app.ArtMethodDropDown.Value = 'microvolts';
app.ArtThresholdField.Value = 6300;
app.ArtMinChannelsField.Value = 1;
app.onArtifactControlsChanged();
app.onDetectArtifacts();
dA = app.Project.Datasets(1);
sm = dA.analyzeArtifacts();
nArt = size(app.ArtView.intervals, 1);
check(nArt > 1 && isequal(app.ArtView.intervals, sm.intervals) && app.ArtViewCountLabel.Text == "of " + nArt ...
    && isequal(app.ArtViewSpinner.Limits, [1 nArt]) && strcmp(app.ArtViewPrevButton.Enable, 'off') ...
    && strcmp(app.ArtViewNextButton.Enable, 'on') && startsWith(ax.Title.String, "Artifact 1 of " + nArt), ...
    'a preview loads the detected artifacts into the viewer and shows the first');
% Auto context (25 ms) spans the whole 512-sample recording; all 4 channels drawn.
nPts  = @(name) sum(arrayfun(@(h) nnz(~isnan(h.YData)), findobj(ax, 'Type', 'line', 'DisplayName', name)));
nKept = @() nPts('Kept');                 % one line per lane
nRem  = @() nPts('Removed (replaced)');
manMask = dA.manualArtifactMask(nSamp, 0, Fs);
allMask = manMask | dA.manualArtifactMask(nSamp, 0, Fs, sm.intervals);
check(numel(ax.YTick) == numAmp && nKept() == numAmp * (nSamp - nnz(manMask)) && nRem() > 0 ...
    && startsWith(app.ArtViewNoteLabel.Text, "Automatic detection is off") ...
    && numel(findobj(ax, 'Type', 'constantregion')) == nArt + 1, ...
    'detection off: only the manual period is removed (red), the detected artifacts shaded but kept');
app.ArtEnableCheckBox.Value = true;
app.onArtifactControlsChanged();
check(nKept() == numAmp * (nSamp - nnz(allMask)) && startsWith(app.ArtViewNoteLabel.Text, "Red is what a run removes: replaced"), ...
    'detection on: the detected artifacts are removed too');
app.ArtApplySortingCheckBox.Value = false; app.ArtApplySpikesCheckBox.Value = false;
app.onArtifactControlsChanged();
check(nKept() == numAmp * (nSamp - nnz(allMask)) ...
    && contains(app.ArtViewNoteLabel.Text, "removes: erased in the signals (LFP / MUA / SPIKE)."), ...
    'with the signals the one use ticked, a run still removes the detected artifacts');
app.SigBlankArtifactsCheckBox.Value = false;
app.onArtifactControlsChanged();
check(nKept() == numAmp * (nSamp - nnz(manMask)) && contains(app.ArtViewNoteLabel.Text, "No step takes the detected artifacts"), ...
    'the signals use ticked but the Signals tab not erasing the periods: a run keeps the detected artifacts');
app.SigBlankArtifactsCheckBox.Value = true;
app.ArtApplySignalsCheckBox.Value = false;
app.onArtifactControlsChanged();
check(nKept() == numAmp * (nSamp - nnz(manMask)) && contains(app.ArtViewNoteLabel.Text, "No step takes the detected artifacts"), ...
    'with no use ticked a run keeps the detected artifacts');
app.ArtApplySortingCheckBox.Value = true; app.ArtApplySpikesCheckBox.Value = true;
app.ArtApplySignalsCheckBox.Value = true;
app.ArtThresholdField.Value = 6000;
app.onArtifactControlsChanged();
check(startsWith(app.ArtViewNoteLabel.Text, "Detection settings changed"), 'a changed detection setting marks the preview stale');
app.ArtThresholdField.Value = 6300;
app.onArtifactControlsChanged();
check(startsWith(app.ArtViewNoteLabel.Text, "Red is what"), 'setting it back clears the mark');

% Moving a bound: Ctrl arms it (the pointer shows which bound), Ctrl+drag
% moves the nearer one on the sample grid, the release keeps it for the dataset.
% An artifact with a few samples clear of every other period either side
% (allMask: row g + 1 is sample g).
kMove = 0;
for kc = 1:nArt
    sOn = round(sm.intervals(kc, 1) * Fs); sOff = round(sm.intervals(kc, 2) * Fs);
    if sOn >= 4 && sOff + 4 <= nSamp && ~any(allMask(sOn - 2:sOn)) && ~any(allMask(sOff + 1:sOff + 4))
        kMove = kc;
        break
    end
end
check(kMove > 0, 'the fixture has an artifact with room to move its bounds');
det1 = sm.intervals(kMove, :);
app.ArtViewSpinner.Value = kMove;
app.showArtifactView();
app.selectTab(app.TabArtifacts);
drawnow;
pp = getpixelposition(ax, true);
box = [pp(1:2) + ax.InnerPosition(1:2) - ax.OuterPosition(1:2), ax.InnerPosition(3:4)];
at = @(xms) [box(1) + (det1(1) + xms / 1e3 - ax.XLim(1)) / diff(ax.XLim) * box(3), box(2) + box(4) / 2];   % ms from the onset -> pixel
samp = 1e3 / Fs;                          % one sample, in ms
kEvt = @(k, mods) struct('Key', k, 'Modifier', {mods});
pan0 = ax.Interactions;
app.Fig.CurrentPoint = at(-samp);         % just before the onset
app.Fig.WindowKeyPressFcn(app.Fig, kEvt('control', {'control'}));
check(app.ArtView.edit.armed && strcmp(app.Fig.Pointer, 'left') && isempty(ax.Interactions), ...
    'Ctrl over the plot: a resize pointer for the nearer bound, the axes'' own pan off');
app.Fig.CurrentPoint = at(1e3 * diff(det1) + samp);
app.Fig.WindowButtonMotionFcn(app.Fig, []);
check(strcmp(app.Fig.Pointer, 'right'), 'past the offset the pointer shows the offset');
app.Fig.CurrentPoint = at(-samp);
app.Fig.SelectionType = 'alt';            % Ctrl+press
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.CurrentPoint = at(-2.2 * samp);
app.Fig.WindowButtonMotionFcn(app.Fig, []);
onLine = findobj(ax, 'Tag', 'artOnset');
check(app.ArtView.edit.bound == "on" && abs(onLine.Value - (det1(1) - 2 / Fs)) < 1e-9, ...
    'Ctrl+drag moves the dashed onset with the pointer, on the sample grid');
app.Fig.WindowButtonUpFcn(app.Fig, []);
dA = app.Project.Datasets(1);
moved1 = [det1(1) - 2 / Fs, det1(2)];
mA = readJsonFile(dA.manifestFile());
check(size(dA.ArtifactAdjustments, 1) == 1 && max(abs(dA.ArtifactAdjustments - [det1 moved1])) < 1e-12 ...
    && numel(mA.artifact_adjustments) == 4 && contains(ax.Title.String, "moved by hand") ...
    && contains(app.ArtViewCountLabel.Text, "1 moved") && strcmp(app.ArtViewRestoreButton.Enable, 'on') ...
    && numel(findobj(ax, 'Tag', 'artDetected')) == 2 && contains(app.StatusBar.Text, "onset moved"), ...
    'the release moves the onset two samples earlier for the dataset (its manifest); the detected bounds stay dotted');
movedMask = manMask | dA.manualArtifactMask(nSamp, 0, Fs, dA.adjustArtifacts(sm.intervals));
check(nKept() == numAmp * (nSamp - nnz(movedMask)) && nnz(movedMask) == nnz(allMask) + 2, ...
    'a run removes the moved span: two more samples red');
app.Fig.CurrentPoint = at(1e3 * diff(det1) + 0.4 * samp);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.CurrentPoint = at(1e3 * diff(det1) + 3 * samp);
app.Fig.WindowButtonMotionFcn(app.Fig, []);
app.Fig.WindowButtonUpFcn(app.Fig, []);
check(size(dA.ArtifactAdjustments, 1) == 1 && max(abs(dA.ArtifactAdjustments(3:4) - (moved1 + [0 3 / Fs]))) < 1e-12, ...
    'a second drag moves the offset of the same artifact (one adjustment, both bounds)');
app.Fig.WindowKeyReleaseFcn(app.Fig, kEvt('control', {}));
check(~app.ArtView.edit.armed && strcmp(app.Fig.Pointer, 'arrow') && isequal(ax.Interactions, pan0) ...
    && isempty(app.Fig.WindowButtonMotionFcn), 'letting go of Ctrl puts the pointer and the pan back');
app.Fig.SelectionType = 'normal';
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.WindowButtonUpFcn(app.Fig, []);
check(size(dA.ArtifactAdjustments, 1) == 1 && max(abs(dA.ArtifactAdjustments(3:4) - (moved1 + [0 3 / Fs]))) < 1e-12, ...
    'a press without Ctrl moves nothing');
% Stepping keys, pointer over the plot: N / PgDn next, P / PgUp previous, Home / End first / last.
app.Fig.CurrentPoint = at(0);
kAll = @(k, mods) app.onArtViewInput("key", struct('Key', k, 'Modifier', {mods}));
kAll('home', {});
check(app.ArtViewSpinner.Value == 1, 'Home shows the first artifact');
kAll('pagedown', {});
check(app.ArtViewSpinner.Value == min(2, nArt) && startsWith(ax.Title.String, "Artifact " + min(2, nArt) + " of"), 'PgDn steps to the next artifact');
kAll('p', {});
check(app.ArtViewSpinner.Value == 1, 'P steps back');
kAll('pageup', {});
check(app.ArtViewSpinner.Value == 1, 'stepping back from the first stays on it');
kAll('end', {});
check(app.ArtViewSpinner.Value == nArt, 'End shows the last artifact');
kAll('n', {});
check(app.ArtViewSpinner.Value == nArt, 'stepping on from the last stays on it');
kAll('pageup', {'shift'});
check(app.ArtViewSpinner.Value == max(nArt - 10, 1), 'Shift+PgUp steps ten back, to the first at most');
app.ArtViewSpinner.Value = kMove;
app.showArtifactView();
% Shading: S over the plot and the button toggle it; the chosen bounds stay.
nReg = numel(findobj(ax, 'Type', 'constantregion'));
app.Fig.CurrentPoint = at(0);
app.Fig.WindowKeyPressFcn(app.Fig, kEvt('s', {}));
check(~app.ArtViewShadeButton.Value && isempty(findobj(ax, 'Type', 'constantregion')) && nReg > 0 ...
    && isscalar(findobj(ax, 'Tag', 'artOnset')) && isscalar(findobj(ax, 'Tag', 'artOffset')), ...
    'S turns the shading off; the chosen artifact''s bounds stay drawn');
app.ArtViewShadeButton.Value = true;
app.ArtViewShadeButton.ValueChangedFcn(app.ArtViewShadeButton, []);
check(numel(findobj(ax, 'Type', 'constantregion')) == nReg && isequal(app.ArtViewShadeButton.BackgroundColor, [1 0.8 0.3]), ...
    'Shade artifacts turns it back on (amber while on)');
app.ArtViewRestoreButton.ButtonPushedFcn(app.ArtViewRestoreButton, []);
mA = readJsonFile(dA.manifestFile());
check(isempty(dA.ArtifactAdjustments) && ~contains(ax.Title.String, "moved") && app.ArtViewCountLabel.Text == "of " + nArt ...
    && strcmp(app.ArtViewRestoreButton.Enable, 'off') && isempty(findobj(ax, 'Tag', 'artDetected')) ...
    && nKept() == numAmp * (nSamp - nnz(allMask)) && isempty(mA.artifact_adjustments), ...
    'Restore bounds puts the artifact back as detected (and in the manifest)');
app.selectTab(app.TabProject);
app.ArtViewSpinner.Value = 1;
app.showArtifactView();
app.ArtViewNextButton.ButtonPushedFcn(app.ArtViewNextButton, []);
check(app.ArtViewSpinner.Value == 2 && startsWith(ax.Title.String, "Artifact 2 of") ...
    && strcmp(app.ArtViewPrevButton.Enable, 'on'), 'Next steps to the second artifact');
app.ArtViewContextField.Value = 1;
app.ArtViewContextField.ValueChangedFcn(app.ArtViewContextField, []);
iv2 = sm.intervals(2, :);
check(diff(ax.XLim) <= diff(iv2) + 2e-3 + 2 / Fs, 'Context sets the signal shown around it (ms)');
check(ax.XLim(1) > iv2(1) - 1 && ax.XLim(2) < iv2(2) + 1 && strcmp(ax.XLabel.String, 'Recording time (s)'), ...
    'the x axis is recording time (s), not time from the artifact');
app.ArtViewChannelsField.Value = 2;
app.drawArtifactView();
fitAll = diff(ax.YLim);
check(numel(ax.YTick) == 2 && isequal(string(ax.Subtitle.String), ["the 2 of 4 channels it is largest on"; "broadband, as detected"]) ...
    && ~contains(ax.YLabel.String, "clipped"), ...
    'Channels picks the channels it is largest on (a long subtitle on two lines); fitting the artifact never clips');
app.ArtViewScaleDropDown.Value = 'kept';
app.drawArtifactView();
check(diff(ax.YLim) <= fitAll && numel(ax.YTick) == 2, 'fitting the kept signal gives lanes no wider');
check(abs(app.ArtViewLanesField.Value - diff(ax.YLim) / 2) < 1e-6 * diff(ax.YLim), 'Lanes shows the spacing drawn');
app.ArtViewLanesField.Value = 123;
app.ArtViewLanesField.ValueChangedFcn(app.ArtViewLanesField, []);
check(app.ArtViewScaleDropDown.Value == "manual" && abs(ax.YTick(2) - ax.YTick(1) - 123) < 1e-9 ...
    && contains(ax.YLabel.String, "123 uV"), 'typing a lane spacing sets the scale by hand');
app.drawArtifactView();
check(abs(ax.YTick(2) - ax.YTick(1) - 123) < 1e-9, 'a manual spacing survives a redraw');
app.ArtViewLanesField.Value = 0;
app.ArtViewLanesField.ValueChangedFcn(app.ArtViewLanesField, []);
check(app.ArtViewScaleDropDown.Value == "artifact" && abs(diff(ax.YLim) - fitAll) < 1e-6 * fitAll, ...
    'a spacing of 0 goes back to fitting the artifact');
app.ArtViewContextField.Value = 0; app.ArtViewChannelsField.Value = 8; app.ArtViewScaleDropDown.Value = 'artifact';
app.ArtThresholdField.Value = 1e6;
app.onArtifactControlsChanged();
app.onDetectArtifacts();
check(app.ArtView.previewed && isempty(app.ArtView.intervals) && strcmp(app.ArtViewNextButton.Enable, 'off') ...
    && any(contains(string(get(findobj(ax, 'Type', 'text'), 'String')), "No artifacts detected")), ...
    'a preview that detects nothing says so');
app.applyArtifactsSection(art0);
app.onArtifactControlsChanged();
app.selectDataset(1, Reset=true);
check(~app.ArtView.previewed && isempty(app.ArtView.win) && isequaln(app.Config.Artifacts, art0), ...
    'a dataset change clears the viewer; the settings are back as loaded');

fprintf('\n== 3a0b. Artifacts tab: probe layout, shanks, voltage and time scale ==\n');
check(~app.ArtProbeOrderCheckBox.Value && strcmp(app.ArtProbeOrderCheckBox.Enable, 'off') ...
    && isequal(app.ArtViewShankDropDown.ItemsData, {'all'}) && app.ArtViewShankColorCheckBox.Value ...
    && numel(app.ArtChannelTable.ColumnName) == 4, ...
    'without a probe: no probe order or shanks to pick, colour by shank on by default, no Shank column');
% Two shanks, the recording's channels crossing between them: 1 and 3 on
% shank 2, 2 and 4 on shank 1; 3 and 4 above 1 and 2.
probe2 = fullfile(root, 'twoShank.json');
writeJsonFile(probe2, struct('chanMap', (0:3).', 'xc', zeros(4, 1), 'yc', [0; 0; 20; 20], 'kcoords', [2; 1; 2; 1]));
dA = app.Project.Datasets(1);
dA.ProbeFile = probe2;
L = dA.channelLayout();
check(L.hasProbe && isequal(L.order, [4 2 3 1]) && isequal(L.shank, [2 1 2 1]) && isequal(L.shanks, [1 2]), ...
    'channelLayout places the channels: by shank, the top of each shank first');
app.syncArtProbeControls();
check(app.ArtProbeOrderCheckBox.Value && strcmp(app.ArtProbeOrderCheckBox.Enable, 'on') ...
    && isequal(app.ArtViewShankDropDown.ItemsData, {'all', '1', '2'}), ...
    'with a probe: probe order is on by default and its shanks are offered');
app.ArtMethodDropDown.Value = 'microvolts';
app.ArtThresholdField.Value = 6300;
app.ArtMinChannelsField.Value = 1;
app.onArtifactControlsChanged();
app.onDetectArtifacts();
w = app.ArtView.win;
lanes = @() string(ax.YTickLabel(:)).';   % bottom lane first
artT = app.ArtChannelTable.Data;
check(isequal(lanes(), w.names([1 3 2 4])) && isscalar(findall(ax, 'Type', 'constantline', 'InterceptAxis', 'y')) ...
    && isequal(cell2mat(artT(:, 1)).', [4 2 3 1]) && isequal(cell2mat(artT(:, 3)).', [1 1 2 2]), ...
    'the lanes and the table follow the probe (a dotted line between the shanks, a Shank column)');
k1 = findobj(ax, 'Type', 'line', 'DisplayName', 'Shank 1');
k2 = findobj(ax, 'Type', 'line', 'DisplayName', 'Shank 2');
check(~isempty(k1) && ~isempty(k2) && ~isequal(k1(1).Color, k2(1).Color) ...
    && isempty(findobj(ax, 'Type', 'line', 'DisplayName', 'Kept')), 'colour by shank: each shank in its own colour');
app.ArtProbeOrderCheckBox.Value = false;
app.ArtProbeOrderCheckBox.ValueChangedFcn(app.ArtProbeOrderCheckBox, []);
check(isequal(lanes(), w.names(4:-1:1)) && isempty(findall(ax, 'Type', 'constantline', 'InterceptAxis', 'y')) ...
    && isequal(cell2mat(app.ArtChannelTable.Data(:, 1)).', 1:4), 'unticked: recording order again, plot and table');
app.ArtViewShankDropDown.Value = '2';
app.drawArtifactView();
check(numel(ax.YTick) == 2 && all(ismember(lanes(), w.names([1 3]))) && contains(join(string(ax.Subtitle.String)), "on shank 2"), ...
    'Shank draws that shank''s channels only');
app.ArtViewShankColorCheckBox.Value = false;
app.drawArtifactView();
check(~isempty(findobj(ax, 'Type', 'line', 'DisplayName', 'Kept')), 'colour by shank off: the kept signal is black again');
app.ArtViewShankDropDown.Value = 'all';
app.ArtViewShankColorCheckBox.Value = true;
app.drawArtifactView();

% Scale: the plot's keys and wheel, with the pointer over it.
pp = getpixelposition(ax, true);
app.Fig.CurrentPoint = pp(1:2) + pp(3:4) / 2;
keyEvt = @(k, mods) struct('Key', k, 'Modifier', {mods});
xFull = ax.XLim; yFull = diff(ax.YLim);
check(app.onArtViewInput("key", keyEvt('uparrow', {})) && app.ArtView.gain > 1 && diff(ax.YLim) < yFull ...
    && contains(ax.YLabel.String, "clipped"), 'up arrow scales the voltage up (the lanes fewer microvolts apart)');
check(app.onArtViewInput("key", keyEvt('rightarrow', {'shift'})) && diff(ax.XLim) < diff(xFull), 'Shift+right zooms time in');
xz = ax.XLim;
app.onArtViewInput("key", keyEvt('rightarrow', {}));
check(ax.XLim(1) > xz(1) && abs(diff(ax.XLim) - diff(xz)) < 1e-9, 'right arrow pans later in time');
xz = ax.XLim;
app.drawArtifactView();
check(max(abs(ax.XLim - xz)) < 1e-9, 'a redraw of the same artifact keeps the time zoom');
app.ArtView.mods = strings(1, 0);
app.onArtViewInput("scroll", struct('VerticalScrollCount', -1));
check(diff(ax.XLim) < diff(xz), 'the wheel zooms time');
g0 = app.ArtView.gain;
app.ArtView.mods = "control";
app.onArtViewInput("scroll", struct('VerticalScrollCount', 1));
app.ArtView.mods = strings(1, 0);
check(app.ArtView.gain < g0, 'Ctrl+wheel scales the voltage');
app.Fig.CurrentPoint = [1 1];
check(~app.onArtViewInput("key", keyEvt('uparrow', {})) && app.ArtView.gain < g0, ...
    'with the pointer off the plot the keys are left alone');
app.Fig.CurrentPoint = pp(1:2) + pp(3:4) / 2;
app.ArtViewResetButton.ButtonPushedFcn(app.ArtViewResetButton, []);
check(app.ArtView.gain == 1 && max(abs(ax.XLim - xFull)) < 1e-9 && abs(diff(ax.YLim) - yFull) < 1e-9, ...
    'Reset view: the whole window at the Scale fit');
app.onArtViewInput("key", keyEvt('equal', {}));
app.onArtViewInput("key", keyEvt('rightarrow', {'shift'}));
app.ArtViewNextButton.ButtonPushedFcn(app.ArtViewNextButton, []);
check(app.ArtView.gain > 1 && max(abs(ax.XLim - app.ArtView.drawn.span)) < 1e-9, ...
    'the next artifact keeps the voltage scale but shows its whole window');
app.ArtViewScaleDropDown.Value = 'manual';
app.ArtViewLanesField.Value = 200;
g0 = app.ArtView.gain;
app.onArtViewInput("key", keyEvt('uparrow', {}));
check(abs(app.ArtViewLanesField.Value - 160) < 1e-9 && app.ArtView.gain == g0 ...
    && abs(ax.YTick(2) - ax.YTick(1) - 160) < 1e-9, 'with Scale: Manual the voltage keys change Lanes');
app.ArtViewScaleDropDown.Value = 'artifact';
app.selectTab(app.TabArtifacts);
g0 = app.ArtView.gain;
app.Fig.WindowKeyPressFcn(app.Fig, keyEvt('uparrow', {}));
check(app.ArtView.gain > g0, 'on the Artifacts tab the figure''s keys reach the plot');
app.selectTab(app.TabProject);
g0 = app.ArtView.gain;
app.Fig.WindowKeyPressFcn(app.Fig, keyEvt('uparrow', {}));
check(app.ArtView.gain == g0, 'on another tab they do not');
dA.ProbeFile = "";
app.applyArtifactsSection(art0);
app.onArtifactControlsChanged();
app.selectDataset(1, Reset=true);
check(~app.ArtProbeOrderCheckBox.Value && isequal(app.ArtViewShankDropDown.ItemsData, {'all'}), ...
    'without the probe again the probe controls go back off');
app.ProbeDefaultField.Value = char(probe2);
app.onConfigChanged();
check(app.ArtProbeOrderCheckBox.Value && isequal(app.ArtViewShankDropDown.ItemsData, {'all', '1', '2'}), ...
    'a dataset without a probe of its own is laid out on the default probe (as the pipeline uses it)');
app.ProbeDefaultField.Value = '';
app.onConfigChanged();
check(~app.ArtProbeOrderCheckBox.Value && isequal(app.ArtViewShankDropDown.ItemsData, {'all'}), ...
    'and without a default probe the probe controls go back off');

fprintf('\n== 3a0c. Artifacts tab: marking manual periods on the plot ==\n');
app.selectTab(app.TabArtifacts);
manual0 = dA.ManualArtifacts;
colAuto = [0.95 0.6 0.1];
colManual = [0.5 0.25 0.85];
nOf = @(c) nnz(arrayfun(@(h) isequal(h.FaceColor, c), findobj(ax, 'Type', 'constantregion')));
check(isempty(app.ArtView.win) && strcmp(app.ArtMarkButton.Enable, 'off') && strcmp(app.ArtViewGotoField.Enable, 'on') ...
    && ~isprop(app, 'ArtViewTabs') && ~isprop(app, 'VizArtButton') ...
    && any(contains(string(get(findobj(ax, 'Type', 'text'), 'String')), "Go to (s)")), ...
    'one plot: before a preview nothing is drawn to mark on, and the plot points to Go to (s)');
dur = nSamp / Fs;
app.ArtViewGotoField.Value = 0.004;
app.ArtViewGotoField.ValueChangedFcn(app.ArtViewGotoField, []);
w = app.ArtView.win;
check(isstruct(w) && w.k == 0 && isequal(app.ArtView.free, [0, (nSamp - 1) / Fs]) && startsWith(ax.Title.String, "Recording from") ...
    && isempty(findobj(ax, 'Tag', 'artOnset')) && strcmp(app.ArtMarkButton.Enable, 'on') && strcmp(app.ArtViewContextField.Enable, 'off') ...
    && nOf(colManual) == 1 && nOf(colAuto) == 0 && nKept() == numAmp * (nSamp - nnz(manMask)) ...
    && startsWith(app.ArtViewNoteLabel.Text, "Red is what a run removes: the manual periods (purple)"), ...
    'Go to (s) shows a stretch of the recording (2 s, kept inside it), no artifact chosen; the manual period purple, removed (red)');

% Marking: the pointer is placed through the figure, as in the bound editing above.
pxAt = @(t) markPixel(ax, t);
app.ArtMarkButton.Value = true;
app.ArtMarkButton.ValueChangedFcn(app.ArtMarkButton, []);
check(app.ArtView.mark.on && contains(app.ArtMarkButton.Text, "ON") && strcmp(app.Fig.Pointer, 'crosshair') ...
    && isempty(ax.Interactions), 'Mark artifacts on: a crosshair, and the axes'' own pan gives way');
drawnow;
app.Fig.SelectionType = 'normal';
app.Fig.CurrentPoint = pxAt(0.005);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.CurrentPoint = pxAt(0.009);
app.Fig.WindowButtonMotionFcn(app.Fig, []);
band = findobj(ax, 'Tag', 'artMarkBand');
inFlight = isscalar(band) && isequal(band.FaceColor, colManual) && max(abs(band.Value - [0.005 0.009])) < 1e-9;
app.Fig.WindowButtonUpFcn(app.Fig, []);
mA = readJsonFile(dA.manifestFile());
check(inFlight && size(dA.ManualArtifacts, 1) == 2 && max(abs(dA.ManualArtifacts(2, :) - [0.005 0.009])) < 1e-9 ...
    && isequal(dA.ManualArtifacts(1, :), manual0) && size(app.ArtManualTable.Data, 1) == 2 ...
    && isequal(size(mA.manual_artifacts), [2 2]) && isempty(findobj(ax, 'Tag', 'artMarkBand')) ...
    && isempty(app.Fig.WindowButtonMotionFcn) && nOf(colManual) == 2 && app.ArtView.mark.on, ...
    'a drag over the plot marks a period (a purple band while dragging): saved in the manifest, listed, shaded purple');
app.Fig.CurrentPoint = pxAt(0.007);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.WindowButtonUpFcn(app.Fig, []);
check(isequal(dA.ManualArtifacts, manual0) && size(app.ArtManualTable.Data, 1) == 1 && nOf(colManual) == 1 ...
    && max(abs(reshape(readJsonFile(dA.manifestFile()).manual_artifacts, 1, []) - manual0)) < 1e-12, ...
    'a click on a purple period removes it');
app.Fig.CurrentPoint = pxAt(0.0101);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.WindowButtonUpFcn(app.Fig, []);
check(isequal(dA.ManualArtifacts, manual0), 'a click where nothing is marked changes nothing');
app.Fig.CurrentPoint = pxAt(0.012);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.CurrentPoint = pxAt(dur + 0.01);   % released past the end of the plot
app.Fig.WindowButtonUpFcn(app.Fig, []);
check(size(dA.ManualArtifacts, 1) == 2 && abs(dA.ManualArtifacts(2, 1) - 0.012) < 1e-9 ...
    && abs(dA.ManualArtifacts(2, 2) - (nSamp - 1) / Fs) < 1e-12, 'a drag past the window is kept inside it');
app.onClearManualArtifacts();
check(isempty(dA.ManualArtifacts) && nOf(colManual) == 0 && isempty(app.ArtManualTable.Data), ...
    'Clear removes the periods, and the plot follows');
app.RunActive = true;
app.Fig.CurrentPoint = pxAt(0.005);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.CurrentPoint = pxAt(0.009);
app.Fig.WindowButtonUpFcn(app.Fig, []);
app.RunActive = false;
check(isempty(dA.ManualArtifacts), 'while a run is under way a mark is refused');
app.Fig.WindowKeyPressFcn(app.Fig, kEvt('escape', {}));
check(~app.ArtView.mark.on && ~app.ArtMarkButton.Value && strcmp(app.Fig.Pointer, 'arrow') ...
    && contains(app.ArtMarkButton.Text, "off") && isequal(ax.Interactions, pan0), ...
    'Escape turns marking off: the pointer and the pan come back');

% A stretch pages through the recording with the stepping keys.
app.showArtifactView([0.002 0.006]);
app.Fig.CurrentPoint = pxAt(0.004);
app.Fig.WindowKeyPressFcn(app.Fig, kEvt('pagedown', {}));
f = app.ArtView.free;
check(abs(f(1) - 0.006) < 1.5 / Fs && abs(diff(f) - 0.004) < 2 / Fs && app.ArtViewGotoField.Value == f(1), ...
    'on a stretch PgDn shows the next one as wide, and Go to (s) shows its start');
app.Fig.WindowKeyPressFcn(app.Fig, kEvt('end', {}));
check(abs(app.ArtView.free(2) - (nSamp - 1) / Fs) < 1e-12, 'End: the end of the recording');
app.Fig.WindowKeyPressFcn(app.Fig, kEvt('home', {}));
check(app.ArtView.free(1) == 0, 'Home: its start');

% Measure: a drag selects a stretch and scores it with every method.
colSel = [0.15 0.45 0.9];
app.showArtifactView([0 0.012]);
check(strcmp(app.ArtMeasureButton.Enable, 'on') && size(app.ArtSelectionMethodTable.Data, 1) == 0 ...
    && contains(app.ArtSelectionLabel.Text, "Measure"), 'Measure is on offer once a window is drawn; no selection yet');
app.ArtMeasureButton.Value = true;
app.ArtMeasureButton.ValueChangedFcn(app.ArtMeasureButton, []);
check(app.ArtView.mark.on && app.ArtView.mark.kind == "measure" && contains(app.ArtMeasureButton.Text, "ON") ...
    && ~app.ArtMarkButton.Value && strcmp(app.Fig.Pointer, 'crosshair') && isempty(ax.Interactions), ...
    'Measure on: the same crosshair drag, Mark artifacts off');
drawnow;
nMan0 = size(dA.ManualArtifacts, 1);
app.Fig.SelectionType = 'normal';
app.Fig.CurrentPoint = pxAt(0.005);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.CurrentPoint = pxAt(0.009);
app.Fig.WindowButtonMotionFcn(app.Fig, []);
band = findobj(ax, 'Tag', 'artMarkBand');
inFlight = isscalar(band) && isequal(band.FaceColor, colSel);
app.Fig.WindowButtonUpFcn(app.Fig, []);
S = app.ArtView.sel;
mt = app.ArtSelectionMethodTable.Data;
check(inFlight && isstruct(S) && max(abs(S.span - [0.005 0.009])) < 1e-9 && size(dA.ManualArtifacts, 1) == nMan0 ...
    && isscalar(findobj(ax, 'Tag', 'artSelection')) && nOf(colSel) == 1 ...
    && app.ArtResultTabs.SelectedTab == app.ArtSelectionTab ...
    && height(mt) == 4 && all(startsWith(string(mt.Method), ["Running RMS", "MAD", "Absolute", "Common mode"])) ...
    && height(app.ArtSelectionTable.Data) == numAmp && startsWith(app.ArtSelectionLabel.Text, "0.0050 to 0.0090 s"), ...
    'a Measure drag selects the stretch (blue), marks nothing, and scores it per method and per channel');
wM = app.ArtView.win;
rowsM = ((wM.s0 + (0:size(wM.X, 1) - 1)') / wM.Fs) >= 0.005 & ((wM.s0 + (0:size(wM.X, 1) - 1)') / wM.Fs) < 0.009;
Mref = dA.measureArtifacts(wM.X, rowsM, Fs=wM.Fs);
check(strcmp(mt.Peak{3}, sprintf('%.0f uV', Mref.methods(3).peak)) || strcmp(mt.Peak{3}, sprintf('%.3g uV', Mref.methods(3).peak)), ...
    'the table shows measureArtifacts on the rows selected');
app.ArtThresholdField.Value = 1;
app.onArtifactControlsChanged();
check(contains(app.ArtSelectionMethodTable.Data.Threshold{string(app.ArtMethodDropDown.Value) == ["rms" "mad" "microvolts" "commonmode"]}, "(set)") ...
    && startsWith(app.ArtSelectionMethodTable.Data.Threshold{string(app.ArtMethodDropDown.Value) == ["rms" "mad" "microvolts" "commonmode"]}, "1 "), ...
    'a new threshold on the left re-scores the selection');
app.applyArtifactsSection(art0);
app.onArtifactControlsChanged();
app.ArtMarkButton.Value = true;
app.ArtMarkButton.ValueChangedFcn(app.ArtMarkButton, []);
check(app.ArtView.mark.on && app.ArtView.mark.kind == "mark" && ~app.ArtMeasureButton.Value && isstruct(app.ArtView.sel), ...
    'Mark artifacts on switches Measure off; the selection stays');
app.Fig.WindowKeyPressFcn(app.Fig, kEvt('m', {}));
check(app.ArtView.mark.kind == "measure" && app.ArtMeasureButton.Value && ~app.ArtMarkButton.Value, 'M over the plot: Measure');
app.Fig.CurrentPoint = pxAt(0.007);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.WindowButtonUpFcn(app.Fig, []);
check(isempty(app.ArtView.sel) && nOf(colSel) == 0 && height(app.ArtSelectionMethodTable.Data) == 0, ...
    'a click clears the selection');
app.Fig.CurrentPoint = pxAt(0.005);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.CurrentPoint = pxAt(0.009);
app.Fig.WindowButtonUpFcn(app.Fig, []);
app.Fig.WindowKeyPressFcn(app.Fig, kEvt('pagedown', {}));
check(isempty(app.ArtView.sel) && height(app.ArtSelectionMethodTable.Data) == 0, 'another window drops the selection');
app.Fig.WindowKeyPressFcn(app.Fig, kEvt('escape', {}));
check(~app.ArtView.mark.on && ~app.ArtMeasureButton.Value && isequal(ax.Interactions, pan0), ...
    'Escape turns Measure off: the pan comes back');
app.ArtResultTabs.SelectedTab = app.ArtResultTabs.Children(1);

% With a preview: the detected artifacts orange beside the manual periods
% purple, marking on an artifact's window, and back from a stretch to them.
dA.ManualArtifacts = manual0;
app.refreshManualArtifactsTable();
app.ArtMethodDropDown.Value = 'microvolts';
app.ArtThresholdField.Value = 6300;
app.ArtMinChannelsField.Value = 1;
app.onArtifactControlsChanged();
app.onDetectArtifacts();
check(isempty(app.ArtView.free) && app.ArtView.win.k == 1 && strcmp(app.ArtMarkButton.Enable, 'on') ...
    && nOf(colAuto) > 0 && nOf(colManual) == 1 ...
    && ~isempty(findobj(ax, 'Type', 'constantregion', 'DisplayName', 'Detected (automatic)')), ...
    'a preview shows its first artifact: detected (automatic) orange, manual purple, on one plot');
app.ArtMarkButton.Value = true;
app.ArtMarkButton.ValueChangedFcn(app.ArtMarkButton, []);
drawnow;
xl = ax.XLim;
tA = xl(1) + 0.6 * diff(xl);
tB = xl(1) + 0.8 * diff(xl);
app.Fig.CurrentPoint = pxAt(tA);
app.Fig.WindowButtonDownFcn(app.Fig, []);
app.Fig.CurrentPoint = pxAt(tB);
app.Fig.WindowButtonUpFcn(app.Fig, []);
iv = dA.ManualArtifacts;
check(any(iv(:, 1) <= tA + 1e-9 & iv(:, 2) >= tB - 1e-9) && app.ArtView.win.k == 1, ...
    'marking works on an artifact''s window too');
dA.ManualArtifacts = manual0;
app.saveManifests(dA);
app.refreshManualArtifactsTable();
app.ArtViewGotoField.Value = 0;
app.ArtViewGotoField.ValueChangedFcn(app.ArtViewGotoField, []);
check(app.ArtView.win.k == 0 && nOf(colAuto) == size(app.ArtView.intervals, 1) && app.ArtView.mark.on, ...
    'Go to (s) after a preview: the stretch shades every detected artifact in it; marking stays on');
app.ArtViewNextButton.ButtonPushedFcn(app.ArtViewNextButton, []);
check(isempty(app.ArtView.free) && app.ArtView.win.k == 1 && app.ArtViewSpinner.Value == 1, ...
    'Next from a stretch: the first artifact after its start');

% Marking stops on leaving the tab or the dataset, and is refused during a run.
app.selectTab(app.TabProject);
check(~app.ArtView.mark.on && ~app.ArtMarkButton.Value && isequal(ax.Interactions, pan0), ...
    'leaving the Artifacts tab stops marking');
app.selectTab(app.TabArtifacts);
app.ArtMarkButton.Value = true;
app.ArtMarkButton.ValueChangedFcn(app.ArtMarkButton, []);
app.applyArtifactsSection(art0);
app.onArtifactControlsChanged();
app.selectDataset(1, Reset=true);
check(~app.ArtView.mark.on && isempty(app.ArtView.win) && isempty(app.ArtView.free) && strcmp(app.ArtMarkButton.Enable, 'off'), ...
    'a dataset change clears the plot, and with it marking');
app.ArtViewGotoField.Value = 0;
app.ArtViewGotoField.ValueChangedFcn(app.ArtViewGotoField, []);
app.RunActive = true;
app.ArtMarkButton.Value = true;
app.ArtMarkButton.ValueChangedFcn(app.ArtMarkButton, []);
app.RunActive = false;
check(~app.ArtView.mark.on && ~app.ArtMarkButton.Value, 'while a run is under way marking cannot be turned on');
app.selectDataset(1, Reset=true);
dA.ManualArtifacts = manual0; dA.writeManifest();   % as the fixture had it
app.refreshManualArtifactsTable();
app.selectTab(app.TabProject);

fprintf('\n== 2z. probe rules ==\n');
app.ProbeRulesTable.Data = {'rec*', char(probe2); 'zz', char(probe2)};
app.onConfigChanged();
check(isequal(app.Config.Probe.RuleSubjects, ["rec*" "zz"]) && isequal(app.Config.Probe.RuleProbes, [string(probe2) string(probe2)]) ...
    && ~app.Config.Probe.AutoAssign, 'the rules table is the config''s probe rules');
dA.ProbeFile = "";
app.onApplyProbeRules();
mA = readJsonFile(dA.manifestFile());
check(dA.ProbeFile == string(probe2) && string(mA.probe.file) == string(probe2), ...
    'Apply rules now assigns the matching rule''s probe to a dataset without one and saves the manifest');
app.ProbeRulesTable.UserData = 2;
app.onRemoveProbeRule();
check(isequal(app.Config.Probe.RuleSubjects, "rec*") && dA.ProbeFile == string(probe2), ...
    'Remove rule drops the selected rule; datasets keep the probe they got');
app.ProbeAutoAssignCheckBox.Value = true;
app.onConfigChanged();
S = app.gatherProbeSection();
app.applyProbeSection(S);
check(app.Config.Probe.AutoAssign && height(app.ProbeRulesTable.Data) == 1 && app.ProbeAutoAssignCheckBox.Value, ...
    'the auto-assign option and the rules round-trip through the config');
app.ProbeAutoAssignCheckBox.Value = false;
app.ProbeRulesTable.Data = cell(0, 2);
app.onConfigChanged();
dA.ProbeFile = "";
dA.writeManifest();
check(isempty(app.Config.Probe.RuleSubjects) && isempty(app.Config.Probe.RuleProbes), 'an empty rules table is an empty rule list');

fprintf('\n== 3a. name tokens ==\n');
check(isequal(string({app.NameTokenChecks.Text}), ["SubjectID" "Date" "Time"]) && isequal([app.NameTokenChecks.Value], [true false false]) ...
    && T.Token_SubjectID(1) == "recA" && string(app.DatasetsTable.ColumnName{3}) == "SubjectID" ...
    && app.NameTokenStatusLabel.Text == "1 of 1 names match", ...
    'default pattern: one checkbox per token, SubjectID shown, the name matches');
app.NamePatternField.Value = '{Stem}{Letter:[A-Z]}_*';
app.onNameTokensChanged();
check(isequal(string({app.NameTokenChecks.Text}), ["Stem" "Letter"]) && ~any([app.NameTokenChecks.Value]) ...
    && ~any(startsWith(app.DatasetsTable.Data.Properties.VariableNames, 'Token_')) ...
    && app.NameTokenStatusLabel.Text == "1 of 1 names match", 'a new pattern rebuilds the checkboxes');
app.NameTokenChecks(2).Value = true; app.NameTokenChecks(1).Value = true;
app.onNameTokensChanged();
T = app.DatasetsTable.Data;
check(T.Token_Stem(1) == "rec" && T.Token_Letter(1) == "A" && isequal(reshape(string(app.DatasetsTable.ColumnName(3:4)), 1, []), ["Stem" "Letter"]) ...
    && app.Config.Project.NamePattern == "{Stem}{Letter:[A-Z]}_*" && app.Config.Project.TokenColumns == "Stem, Letter" ...
    && numel(app.DatasetsTable.ColumnWidth) == width(T) && startsWith(app.Fig.Name, "*"), ...
    'ticked tokens become columns in pattern order and are saved in the config');
check(numel(app.NameTokenFilters) == 2 && isequal(string(app.NameTokenFilters(2).Items), ["(any)" "A"]), ...
    'one filter dropdown per token, listing the parsed values');
app.onSelectDatasets("all");
app.NameTokenFilters(2).Value = 'B';
app.refreshDatasetsTable();
app.onConfigChanged();
check(height(app.DatasetsTable.Data) == 0 && app.HiddenSelectedKeys == "recA_260101_120000" && isequal(app.selectedDatasetIndices(), 1) ...
    && isequal(app.Config.Project.Datasets, "recA_260101_120000") && contains(app.NameTokenStatusLabel.Text, "showing 0 of 1 (1 ticked hidden)"), ...
    'a filter hides non-matching rows and keeps their ticks in the selection');
check(app.SelectedDatasetIdx == 1 && isempty(app.DatasetsTable.StyleConfigurations), ...
    'a hidden active dataset stays active, with no row highlighted');
app.NameTokenFilters(2).Value = 'b, a*';
app.refreshDatasetsTable();
check(height(app.DatasetsTable.Data) == 1 && app.DatasetsTable.Data.Select(1) && isempty(app.HiddenSelectedKeys) ...
    && height(app.DatasetsTable.StyleConfigurations) == 1, ...
    'wildcard / comma alternatives match case-insensitively; the tick and the highlight return');
app.NameTokenFilters(2).Value = '(any)';
app.onSelectDatasets("none");
nCol = width(app.DatasetsTable.Data);
app.DatasetsTable.DisplayColumnOrder = [5, 1:4, 6:nCol];   % as if Key were dragged to the front
app.refreshDatasetsTable();
T = app.DatasetsTable.Data;
check(string(T.Properties.VariableNames{1}) == "Key" && string(app.DatasetsTable.ColumnName{1}) == "Key" ...
    && isempty(app.DatasetsTable.DisplayColumnOrder) && ~app.DatasetsTable.ColumnSortable(end), ...
    'a rearranged column order is baked into the table on refresh');
app.NameTokenChecks(1).Value = false;
app.onNameTokensChanged();
T = app.DatasetsTable.Data;
check(isequal(string(T.Properties.VariableNames(1:4)), ["Key" "Select" "Name" "Token_Letter"]) ...
    && string(T.Properties.VariableNames{end}) == "DatasetIdx" && numel(app.DatasetsTable.ColumnWidth) == width(T), ...
    'the order survives a change of the token columns');
app.DatasetsColumnOrder = string.empty(1, 0);
app.NameTokenChecks(1).Value = true;
app.onNameTokensChanged();
app.NamePatternField.Value = '{Stem';
app.onNameTokensChanged();
check(numel(app.NameTokenChecks) == 2 && ~any(startsWith(app.DatasetsTable.Data.Properties.VariableNames, 'Token_')) ...
    && contains(app.NameTokenStatusLabel.Text, "unclosed"), 'an invalid pattern keeps the checkboxes and hides token columns');
app.applyProjectSection(cfg.Project);
app.onConfigChanged();
check(app.NameTokenChecks(1).Value && app.Config.Project.TokenColumns == "SubjectID" ...
    && app.Config.Project.NamePattern == cfg.Project.NamePattern, 'applying the section restores pattern and columns');

fprintf('\n== 3a2. recursive scan ==\n');
check(app.RecursiveCheckBox.Value && app.Project.Recursive, 'scans are recursive by default');
app.RecursiveCheckBox.Value = false;
app.onConfigChanged();
app.onScan();
check(~app.Config.Project.Recursive && ~app.Project.Recursive && app.Project.NumDatasets == 1, ...
    'unticking Recursive is saved in the config and scans only the root and the folders directly in it');
app.applyProjectSection(cfg.Project);
app.onConfigChanged();
app.onScan();
check(app.RecursiveCheckBox.Value && app.Config.Project.Recursive && app.Project.Recursive, ...
    'applying the section restores Recursive');

fprintf('\n== 3b1. Project tab: source settings (Open Ephys, TDT) ==\n');
app.selectDataset(1);
check(app.SourcePanel.Title == "Source settings: Intan" && app.SourceNoteLabel.Visible == "on" ...
    && app.SourceOEGrid.Visible == "off" && app.SourceTDTGrid.Visible == "off" ...
    && contains(app.SourceNoteLabel.Text, "no source settings"), ...
    'an Intan dataset is active: the Source settings panel says Intan has none');
check(app.Config.Acquisition.OpenEphys.Recordings == "concatenate" && string(app.OERecordingsDropDown.Value) == "concatenate", ...
    'Open Ephys sessions are joined by default');
app.OERecordingsDropDown.Value = 'separate';
app.OERecordNodeField.Value = '104';
app.OEStreamField.Value = 'Rhythm Data';
app.onAcquisitionChanged();
A = app.Config.Acquisition.OpenEphys;
check(A.Recordings == "separate" && A.RecordNode == "104" && A.Stream == "Rhythm Data" ...
    && isequaln(app.Project.ReaderOptions, app.Config.Acquisition) && isequaln(app.Project.Datasets(1).ReaderOptions, app.Config.Acquisition), ...
    'the Open Ephys options are saved in Acquisition and a rescan pushes them to the project and datasets');
app.applyAcquisitionSection(cfg.Acquisition);
app.onAcquisitionChanged();
check(app.Config.Acquisition.OpenEphys.Recordings == "concatenate" && app.OERecordNodeField.Value == "" ...
    && isequaln(app.Project.ReaderOptions, cfg.Acquisition), 'applying the section restores the defaults');
app.Config.Acquisition.OpenEphys.RecordNode = "node";
app.syncTabStrip();
check(contains(tabTip(app, app.TabProject), "RecordNode"), 'an invalid Open Ephys option shows on the Project tab''s button');
app.Config.Acquisition = cfg.Acquisition;
app.syncTabStrip();
check(string(app.TDTStreamDropDown.Value) == "automatic" && app.TDTGainField.Value == "", ...
    'the TDT options are automatic by default');
app.TDTStreamDropDown.Value = 'Wav1';
app.TDTGainField.Value = '0.5';
app.onAcquisitionChanged();
check(app.Config.Acquisition.TDT.Stream == "Wav1" && app.Config.Acquisition.TDT.GainToMicrovolts == 0.5 ...
    && isequaln(app.Project.Datasets(1).ReaderOptions, app.Config.Acquisition), ...
    'the TDT stream and gain are saved in Acquisition.TDT and pushed to the datasets');
app.TDTGainField.Value = 'abc';
app.onAcquisitionChanged();
check(app.Config.Acquisition.TDT.GainToMicrovolts == 0.5, 'a TDT gain that is not a number is refused');
app.applyAcquisitionSection(cfg.Acquisition);
app.onAcquisitionChanged();
check(app.Config.Acquisition.TDT.Stream == "" && isnan(app.Config.Acquisition.TDT.GainToMicrovolts) ...
    && string(app.TDTStreamDropDown.Value) == "automatic" && app.TDTGainField.Value == "", ...
    'applying the section restores the TDT defaults');

fprintf('\n== 3b. Trials tab: load, cut, approve, polarity ==\n');
app.selectDataset(1);
app.setTrialsLineItems("din0", "din0");
app.onTrialsSettingsChanged();
check(app.Config.Behavior.TrialLine == "din0" && startsWith(app.Fig.Name, "*"), 'the trial line is a config setting');
app.onTrialsLoad("recorded");
dT = app.currentDataset();
TT = app.TrialsTable.Data;
check(~isempty(app.TrialsPairing) && height(TT) == 1 && TT{1, 3} == 1 && TT{1, 6} == 50 ...
    && height(app.TrialsLinesTable.Data) == 1 && strcmp(app.TrialsApproveButton.Enable, 'on'), ...
    'Load pairs the single trial with the din0 interval (onset row 50)');
check(isequal(app.TrialsCutSpinners(1, 1).Limits, [0 1]) && strcmp(app.TrialsCutSpinners(2, 2).Enable, 'on') ...
    && app.TrialsCutIntervalsLabel.Text == "din0 intervals", 'the cut spinners are limited to the trial / interval counts');
check(app.TrialsAxes.InteractionOptions.LimitsDimensions == "x", 'the lines plot zooms and pans horizontally only');
check(all(app.TrialsTable.ColumnSortable) && app.TrialsTable.ColumnRearrangeable == "on", 'the trials table sorts and rearranges');
cm = app.TrialsTable.ContextMenu;
app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', [])));
sub = findobj(cm.Children, 'flat', 'Text', 'Parameter columns');
check(isscalar(sub) && isequal(flip(string({sub.Children.Text})), ["computerTimestamp" "isTest" "ToneLevel"]) ...
    && ~any(logical([sub.Children.Checked])) && isscalar(findobj(cm.Children, 'flat', 'Text', 'Reset column order')), ...
    'the table menu lists the session parameters (not TrialIndex) alphabetically, ignoring case, unticked');
item = findobj(cm.Children, 'flat', '-regexp', 'Text', '^Clear sort');
check(isscalar(item) && item.Enable == "off" && item.Separator == "off" && isequal(cm.Children(1), item), ...
    'the menu ends with Clear sort, beside Reset column order, off while the table keeps no sort');
for p = ["ToneLevel" "isTest"]
    item = findobj(sub, 'Text', p);
    item.MenuSelectedFcn(item, []);
    app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', [])));   % as the next right-click would
    sub = findobj(cm.Children, 'flat', 'Text', 'Parameter columns');
end
TT = app.TrialsTable.Data;
vars = string(TT.Properties.VariableNames);
check(isequal(app.TrialsParamColumns, ["ToneLevel" "isTest"]) && isequal(vars(8:11), ["Flag" "Param_ToneLevel" "Param_isTest" "OtherLines"]) ...
    && isequal(reshape(string(app.TrialsTable.ColumnName(9:10)), 1, []), ["ToneLevel" "isTest"]) && TT.Param_ToneLevel == 60 && TT.Param_isTest == false ...
    && all(logical(findobj(sub, 'Text', 'ToneLevel').Checked)), 'ticked parameters become columns after Flag, in the order added');
app.TrialsTable.DisplayColumnOrder = [10, 1:9, 11];   % as if isTest were dragged to the front
check(isequal(app.trialsColumnOrder(), vars([10, 1:9, 11])), 'the dragged order is read back before a refresh');
kTone = find(vars == "Param_ToneLevel");
app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', kTone)));
item = findobj(cm.Children, 'flat', 'Text', 'Remove "ToneLevel"');
check(isscalar(item), 'right-clicking a parameter column offers to remove it');
item.MenuSelectedFcn(item, []);
TT = app.TrialsTable.Data;
check(isequal(app.TrialsParamColumns, "isTest") && string(TT.Properties.VariableNames{1}) == "Param_isTest" ...
    && ~ismember("Param_ToneLevel", TT.Properties.VariableNames) && isempty(app.TrialsTable.DisplayColumnOrder) ...
    && isequal(app.TrialsColumnOrder, ["Param_isTest", vars(1:8), "Param_ToneLevel", "OtherLines"]), ...
    'removing a column keeps the dragged order and remembers where the removed column was');
app.TrialsParamColumns = ["isTest" "ToneLevel" "Response"];   % Response: chosen for another dataset
app.refreshTrialsTable();
TT = app.TrialsTable.Data;
app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', [])));
sub = findobj(cm.Children, 'flat', 'Text', 'Parameter columns');
item = findobj(sub, 'Text', 'Response (not in these trials)');
check(isequal(string(TT.Properties.VariableNames), ["Param_isTest", vars(1:8), "Param_ToneLevel", "OtherLines"]) ...
    && isscalar(item) && logical(item.Checked), 'a re-added column returns to its place; a parameter the session lacks is listed, not shown');
item.MenuSelectedFcn(item, []);
check(isequal(app.TrialsParamColumns, ["isTest" "ToneLevel"]), 'and can be unticked');
app.TrialsSession.Pos = [1 2];
app.TrialsSession.Note = {'abc'};
app.TrialsSession.Maybe = {[]};
app.TrialsParamColumns = ["Pos" "Note" "Maybe"];
app.refreshTrialsTable();
TT = app.TrialsTable.Data;
check(TT.Param_Pos == "1 2" && TT.Param_Note == "abc" && isnan(TT.Param_Maybe), ...
    'multi-column and cell parameters are shown as text, empty numbers as NaN');
app.savePreferences();
check(isequal(string(AppPrefs.getpref(g, 'TrialsParamColumns')), ["Pos" "Note" "Maybe"]) ...
    && isequal(string(AppPrefs.getpref(g, 'TrialsColumnOrder')), app.TrialsColumnOrder), 'the columns and their order are preferences');
app.TrialsTable.DisplayColumnOrder = [2 1 3:width(TT)];
app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', [])));
item = findobj(cm.Children, 'flat', 'Text', 'Reset column order');
item.MenuSelectedFcn(item, []);
TT = app.TrialsTable.Data;
check(string(TT.Properties.VariableNames{1}) == "Trial" && isempty(app.TrialsTable.DisplayColumnOrder) ...
    && isequal(app.TrialsColumnOrder, string(TT.Properties.VariableNames)), 'Reset column order restores the natural order');
app.TrialsParamColumns = string.empty(1, 0);
app.refreshTrialsTable();
app.TrialsCutSpinners(1, 1).Value = 1;
app.onTrialsCutsChanged();
check(isequal(app.TrialsPairing.cutTrials, [1 0]) && isnan(app.TrialsPairing.interval(1)) && app.TrialsPairing.countMismatch ...
    && contains(app.TrialsSummaryLabel.Text, "WARNING"), 'cutting the only trial leaves the interval unpaired and warns about the mismatch');
app.TrialsCutSpinners(1, 2).Value = 1;
app.onTrialsCutsChanged();
check(isequal(app.TrialsPairing.cutTrials, [1 0]) && app.TrialsCutSpinners(1, 2).Value == 0, ...
    'cuts beyond the trial count are refused and the spinners put back');
app.onTrialsLoad("none");
check(isequal(app.TrialsPairing.cutTrials, [0 0]) && app.TrialsCutSpinners(1, 1).Value == 0 && ~app.TrialsPairing.countMismatch, ...
    'Reset cuts pairs everything in order again');
app.onTrialsApprove("approved");
mT = readJsonFile(dT.manifestFile());
check(strcmp(mT.behavior.pairing.status, 'approved') && contains(app.DatasetsTable.Data.Behavior(1), "pairing approved"), ...
    'Approve saves the pairing in the manifest and the table shows it');
app.TrialsLinesTable.Data.Inverted(1) = true;
app.onTrialsSettingsChanged();
check(isequal(app.Config.Signals.InvertedLines, "din0") && app.TrialsPairing.stale ...
    && app.TrialsPairing.status == "unreviewed" && app.TrialsPairing.onsetSample(1) == 1, ...
    'inverting the line makes the approved pairing stale (onset = falling edge)');
FsT = app.TrialsEvents.Fs;
hBars = findall(app.TrialsAxes, "Tag", "events:din0");
xBars = [hBars.XData];
barRows = sortrows(round(reshape(xBars(~isnan(xBars)), 2, []).' * FsT));
hiRows = round(app.namedTrialsEvents().events.din0 * FsT);
check(isequal(barRows, round(app.TrialsPairing.events.din0 * FsT)) && all(ismember(hiRows(:, 2) + 1, barRows(:, 1))) ...
    && all(ismember(hiRows(:, 1) - 1, barRows(:, 2))) && all(strcmp({hBars.Marker}, 'none')) ...
    && any(contains(string(app.TrialsAxes.YTickLabel), "din0 (inverted)")), ...
    'inverted, the plot draws din0 as unmarked bars from each falling edge to the next rising edge');
hEdges = findall(app.TrialsAxes, "Tag", "trialEdges");
check(isscalar(hEdges) && hEdges.Visible == "on" && isequal(unique(round(hEdges.XData(~isnan(hEdges.XData)) * FsT)), ...
    unique(round(app.TrialsPairing.intervals(:) * FsT)).'), ...
    'dotted lines mark every trial-line onset and offset, and a refresh replaces the previous plot (hidden objects too)');
app.TrialsEdgesMenu.MenuSelectedFcn(app.TrialsEdgesMenu, []);
app.onTrialsSettingsChanged();
hEdges = findall(app.TrialsAxes, "Tag", "trialEdges");
check(isscalar(hEdges) && hEdges.Visible == "off" && app.TrialsEdgesMenu.Checked == "off", ...
    'the plot''s context menu hides the onset / offset lines, and they stay hidden when the plot is redrawn');
app.TrialsEdgesMenu.MenuSelectedFcn(app.TrialsEdgesMenu, []);
check(app.TrialsAxes.XGrid == "off", 'no grid lines by default');
app.TrialsGridMenu.MenuSelectedFcn(app.TrialsGridMenu, []);
check(hEdges.Visible == "on" && app.TrialsAxes.XGrid == "on" && app.TrialsAxes.YGrid == "on" && app.TrialsGridMenu.Checked == "on", ...
    'the context menu shows the onset / offset lines again and toggles the grid lines');
app.TrialsGridMenu.MenuSelectedFcn(app.TrialsGridMenu, []);
app.onTrialsPlotMenu();
labelItems = flip(string({app.TrialsLabelsMenu.Children.Text}));
sessionVars = string(app.TrialsSession.Properties.VariableNames);
[~, iAlpha] = sort(lower(sessionVars));
check(isequal(labelItems, sessionVars(iAlpha)) && ismember("TrialIndex", labelItems) ...
    && ~any(logical([app.TrialsLabelsMenu.Children.Checked])) && isempty(findall(app.TrialsAxes, "Tag", "trialLabels")), ...
    'the plot menu lists every session parameter for trial labels (TrialIndex too), none shown by default');
item = findobj(app.TrialsLabelsMenu, 'Text', 'ToneLevel');
item.MenuSelectedFcn(item, []);
hLab = findall(app.TrialsAxes, "Tag", "trialLabels");
check(isequal(app.TrialsLabelParams, "ToneLevel") && isscalar(hLab) && string(hLab.String) == "60" ...
    && hLab.Position(1) == app.TrialsPairing.onset(1) && hLab.Position(2) > 1 && app.TrialsAxes.YLim(2) > hLab.Position(2) ...
    && isscalar(findall(app.TrialsAxes, "Tag", "trialEdges")), ...
    'ticking a parameter writes each paired trial''s value above the trial line at its onset');
app.onTrialsPlotMenu();
item = findobj(app.TrialsLabelsMenu, 'Text', 'isTest');
item.MenuSelectedFcn(item, []);
hLab = findall(app.TrialsAxes, "Tag", "trialLabels");
check(isscalar(hLab) && string(hLab.String) == "ToneLevel=60, isTest=false" && contains(string(app.TrialsAxes.Title.String), "labels: ToneLevel, isTest"), ...
    'several parameters are written name=value in the order ticked, and the title names them');
app.TrialsLabelParams = ["ToneLevel" "Response"];   % Response: chosen for another dataset
app.refreshTrialsPlot();
app.onTrialsPlotMenu();
item = findobj(app.TrialsLabelsMenu, 'Text', 'Response (not in these trials)');
hLab = findall(app.TrialsAxes, "Tag", "trialLabels");
check(isscalar(item) && logical(item.Checked) && string(hLab.String) == "60", ...
    'a label parameter the session lacks is listed, not written');
app.savePreferences();
check(isequal(string(AppPrefs.getpref(g, 'TrialsLabelParams')), ["ToneLevel" "Response"]), 'the label parameters are a preference');
item = findobj(app.TrialsLabelsMenu, 'Text', 'No labels');
item.MenuSelectedFcn(item, []);
check(isempty(app.TrialsLabelParams) && isempty(findall(app.TrialsAxes, "Tag", "trialLabels")) && app.TrialsAxes.YLim(2) == 1.6, ...
    'No labels removes them and the head room');
g3 = app.gatherConfig();
check(isequal(g3.Signals.InvertedLines, "din0") && isequal(EphysPipelineConfig.signalOptions(g3.Signals).invertedLines, "din0"), ...
    'the polarity reaches the Signals options');
app.TrialsLinesTable.Data.Inverted(1) = false;
app.onTrialsSettingsChanged();
check(isempty(app.Config.Signals.InvertedLines) && app.TrialsPairing.recorded && app.TrialsPairing.status == "approved", ...
    'restoring the polarity brings the approved pairing back');
L0 = app.TrialsLinesTable.Data;
E0 = app.TrialsEvents;
check(isequal(string(L0.Properties.VariableNames), ["Native" "Name" "Intervals" "Inverted"]) && L0.Native(1) == "DIN-00" ...
    && L0.Name(1) == "din0", 'the lines table shows each line''s native name and its name');
app.TrialsLinesTable.Data.Name(1) = "Trial";
app.onTrialsLinesEdited(struct('Indices', [1 2], 'PreviousData', "din0", 'NewData', "Trial"));
check(isequal(app.Config.Signals.LineNames, "DIN-00=Trial") && app.Config.Behavior.TrialLine == "Trial" ...
    && string(app.TrialsLineDropDown.Value) == "Trial" && ~isempty(app.TrialsPairing) && app.TrialsPairing.nPaired == 1 ...
    && isequal(app.TrialsEvents, E0) && isfield(app.TrialsPairing.events, 'Trial'), ...
    'renaming a line writes Signals.LineNames, the trial line follows, and it re-pairs without reading the recording');
app.TrialsLinesTable.Data.Name(1) = "1bad";
app.onTrialsLinesEdited(struct('Indices', [1 2], 'PreviousData', "Trial", 'NewData', "1bad"));
check(app.TrialsLinesTable.Data.Name(1) == "Trial" && isequal(app.Config.Signals.LineNames, "DIN-00=Trial"), ...
    'an invalid name is refused and put back');
app.TrialsLinesTable.Data.Name(1) = "";
app.onTrialsLinesEdited(struct('Indices', [1 2], 'PreviousData', "Trial", 'NewData', ""));
check(isempty(app.Config.Signals.LineNames) && app.Config.Behavior.TrialLine == "din0" ...
    && app.TrialsLinesTable.Data.Name(1) == "din0", 'a blank name goes back to the default name and drops the entry');
app.ConvLabelFieldDropDown.Value = 'native';
app.onConvertControlsChanged();
check(isempty(app.Config.Signals.LineNames) && app.TrialsLinesTable.Data.Name(1) == "DIN-00", ...
    'switching Label field to native renames no line (no LineNames entry) and the lines table shows the native names');
app.ConvLabelFieldDropDown.Value = 'custom';
app.onConvertControlsChanged();
check(isempty(app.Config.Signals.LineNames) && app.TrialsLinesTable.Data.Name(1) == "din0", 'and back to the custom names');

vE = matlab.lang.makeValidName("epsych_" + dT.Name);
vB = matlab.lang.makeValidName("behavior_" + dT.Name);
evalin('base', "clear " + vE + " " + vB);
behT = fullfile(dT.outputFolder(), dT.Name + "_behavior.mat");
if ~isfile(behT)
    app.onTrialsToWorkspace("behavior");
    check(~evalin('base', "exist('" + vB + "', 'var')"), 'Behavior to workspace assigns nothing before <name>_behavior.mat exists');
end
app.onTrialsWriteBehavior();
BT = load(behT);
check(BT.behavior.trials.TrialOnsetSample(1) == 50 && BT.behavior.pairing.status == "approved", 'Write behavior .mat carries the pairing');
app.onTrialsToWorkspace("epsych");
E = evalin('base', vE);
check(isequal(E, load(dT.BehaviorFile)) && contains(app.StatusBar.Text, vE), ...
    'Trial source to workspace puts the Epsych2 session file as saved in the base workspace and names the variable');
app.onTrialsToWorkspace("behavior");
BW = evalin('base', vB);
check(isequal(BW, BT.behavior) && contains(app.StatusBar.Text, vB), ...
    'Behavior to workspace puts the behavior struct of <name>_behavior.mat in the base workspace and names the variable');
evalin('base', "clear " + vE + " " + vB);

fprintf('\n== 3b2. Trials tab: prefetch the ticked datasets, auto approve ==\n');
evFile = fullfile(dT.outputFolder(), dT.Name + "_events.mat");
check(isfile(evFile) && string(app.TrialsPrefetchButton.Text) == "Prefetch ticked" ...
    && ~app.TrialsAutoApproveCheckBox.Value && ~app.Config.Behavior.AutoApprove, ...
    'Load cached the lines; the Prefetch button is there and Auto approve is off by default');
delete(evFile);
dT.setTrialPairing([]);
app.clearTrialsView();
ticked0 = app.tickedDatasetIndices();
app.onSelectDatasets("all");
app.onTrialsPrefetch();
check(isfile(evFile) && contains(app.StatusBar.Text, "1 read, 0 already cached") && isempty(dT.TrialPairing), ...
    'Prefetch reads and caches the lines of the ticked dataset, and pairs nothing without Auto approve');
app.onTrialsPrefetch();
check(contains(app.StatusBar.Text, "0 read, 1 already cached"), 'a second Prefetch finds the lines cached');
app.onTrialsLoad("recorded");
check(app.TrialsEvents.source == "cache" && app.TrialsPairing.status == "unreviewed" && ~app.TrialsPairing.recorded, ...
    'Load takes the prefetched lines from the cache');
app.TrialsAutoApproveCheckBox.Value = true;
app.onTrialsSettingsChanged();
mT = readJsonFile(dT.manifestFile());
check(app.Config.Behavior.AutoApprove && app.TrialsPairing.status == "approved" && app.TrialsPairing.autoApproved ...
    && contains(app.TrialsSummaryLabel.Text, "APPROVED automatically") && mT.behavior.pairing.auto_approved ...
    && contains(app.DatasetsTable.Data.Behavior(1), "pairing approved (auto)"), ...
    'ticking Auto approve approves the shown pairing (its counts match) and marks it automatic');
BT = load(behT);
check(BT.behavior.pairing.status == "approved" && BT.behavior.pairing.autoApproved, ...
    'the automatic approval reaches the existing <name>_behavior.mat');
dT.setTrialPairing([]);
app.clearTrialsView();
app.onTrialsPrefetch();
check(dT.TrialPairing.status == "approved" && dT.TrialPairing.auto_approved ...
    && contains(app.StatusBar.Text, "1 approved automatically, 0 already approved, 0 need review"), ...
    'with Auto approve, Prefetch also approves each ticked pairing whose counts match');
app.onTrialsLoad("recorded");
app.onTrialsApprove("approved");
check(~dT.TrialPairing.auto_approved && app.TrialsPairing.status == "approved" && ~app.TrialsPairing.autoApproved ...
    && ~contains(app.TrialsSummaryLabel.Text, "automatically"), 'approving by hand replaces the automatic approval');
BT = load(behT);
check(BT.behavior.pairing.status == "approved" && ~BT.behavior.pairing.autoApproved && contains(app.StatusBar.Text, "rewrote"), ...
    'approving by hand rewrites <name>_behavior.mat and says so');
app.TrialsAutoApproveCheckBox.Value = false;
app.onTrialsSettingsChanged();
if isempty(ticked0); app.onSelectDatasets("none"); end

fprintf('\n== 3c. Sorting tab: optimize for probe, reset to defaults ==\n');
dS = app.currentDataset();
app.onOptimizeKS4ForProbe();
check(app.Config.Sorting.KS4.nblocks == 3 && strcmp(app.ParamControls.dmin.Value, '12'), ...
    'without a probe (the dataset''s or the default) nothing is loaded');
probeFile = fullfile(root, 'square4.json');
writeJsonFile(probeFile, struct('chanMap', (0:3).', 'xc', [0; 25; 0; 25], 'yc', [0; 0; 25; 25], 'kcoords', zeros(4, 1)));
paramsFile = EphysPipelineConfig.ks4ParamsFile(probeFile);
dS.ProbeFile = probeFile;
app.onOptimizeKS4ForProbe("cancel");
check(~isfile(paramsFile) && app.Config.Sorting.KS4.nblocks == 3, ...
    'a probe without a parameter file: cancelling the offer writes and changes nothing');
K0 = app.Config.Sorting.KS4;
app.onOptimizeKS4ForProbe("generate");
P = readJsonFile(paramsFile);
check(isfile(paramsFile) && isequal(string(fieldnames(P.KS4)).', EphysPipelineConfig.KS4ProbeParams) ...
    && P.KS4.nblocks == 3 && P.KS4.dmin == 12 && isequaln(app.Config.Sorting.KS4, K0) ...
    && any(contains(string(app.KSLogArea.Value), "square4.ks4.json")), ...
    'the current-parameters option saves the current probe-dependent values next to the probe map and logs it');
probeFolder = app.ProbeFolderField.Value;
app.ProbeFolderField.Value = char(root);
app.refreshProbeList();
row = find(app.ProbePaths == string(probeFile), 1);
check(~isempty(row) && ~any(endsWith(app.ProbePaths, ".ks4.json")), 'the probe list shows the probe map but not its parameter file');
app.selectProbeRow(row);
check(contains(app.ProbeInfoLabel.Text, "Kilosort4 parameters: square4.ks4.json"), ...
    'the Probe tab names the selected probe''s parameter file');
sidecar = ChannelMap.sidecarFile(probeFile);
writeJsonFile(sidecar, struct('schema', 'ephys-channel-map/1', 'probeFile', 'square4.json'));
app.refreshProbeList();
check(~any(endsWith(app.ProbePaths, ".chanmap.json")) && any(app.ProbePaths == string(probeFile)), ...
    'the probe list leaves out a probe''s .chanmap.json sidecar (ChannelMapperApp)');
delete(sidecar);
check(isa(app.ChannelMapperButton, 'matlab.ui.control.Button') && isvalid(app.ChannelMapperButton) && ...
    app.ChannelMapperButton.Text == "Map channels...", 'the Probe tab has the Map channels button');
mapper = app.onOpenChannelMapper();
check(isa(mapper, 'ChannelMapperApp') && mapper.App == app && isvalid(mapper.Fig) && ~isempty(mapper.Result), ...
    'Map channels opens a ChannelMapperApp with this app as its parent');
delete(mapper);
app.ProbeFolderField.Value = probeFolder;
app.refreshProbeList();
delete(paramsFile);
app.onOptimizeKS4ForProbe("derive");
P = readJsonFile(paramsFile);
K = app.Config.Sorting.KS4;
check(isfile(paramsFile) && P.KS4.dminx == 25 && isfield(P, 'reasons') && contains(string(P.description), "probe layout") ...
    && K.nblocks == 0 && K.dmin == 25 && K.dminx == 25 && K.nearest_chans == 4 && K.nearest_templates == 4 ...
    && K.x_centers == 1 && app.ParamControls.nearest_chans.Value == 4 && strcmp(app.ParamControls.dmin.Value, '25'), ...
    'the probe-layout option saves the layout defaults with their reasons and loads them into the controls and the config');
check(any(contains(string(app.KSLogArea.Value), "from the probe layout")) ...
    && any(contains(string(app.KSLogArea.Value), "x_centers: 4 -> 1 (a single shank")), ...
    'the generated file and each loaded value with its reason are logged');
noLayout = fullfile(root, 'nolayout.json');
writeJsonFile(noLayout, struct('chanMap', (0:3).'));
dS.ProbeFile = noLayout;
app.onOptimizeKS4ForProbe("derive");
check(~isfile(EphysPipelineConfig.ks4ParamsFile(noLayout)) && app.Config.Sorting.KS4.x_centers == 1, ...
    'a probe map without site positions gives no layout defaults: nothing is written or changed');
dS.ProbeFile = "";
app.ProbeDefaultField.Value = char(probeFile);
app.ParamControls.nearest_chans.Value = 9;
app.onConfigChanged();
app.onOptimizeKS4ForProbe();
check(app.Config.Sorting.KS4.nearest_chans == 4 && any(contains(string(app.KSLogArea.Value), "default probe")), ...
    'a dataset without a probe uses the default probe''s parameter file');
app.ProbeDefaultField.Value = '';
before = app.Config.Sorting;
app.ExtraSettingsArea.Value = {'{"nblocks": 2}'};
app.onConfigChanged();
app.onResetKS4Params();
S = app.Config.Sorting;
check(isequaln(S.KS4, EphysPipelineConfig.defaults("Sorting").KS4) && S.KS4ExtraJSON == "" ...
    && strcmp(app.ParamControls.dmin.Value, '') && isequal(app.ExtraSettingsArea.Value, {'{'; '}'}), ...
    'Reset to defaults restores every Kilosort4 parameter and clears the extra JSON');
check(S.PythonExe == before.PythonExe && S.Enabled == before.Enabled ...
    && app.Config.Probe.DefaultProbeFile == "", 'and leaves the other Sorting settings alone');

fprintf('\n== 4. run one step through the pipeline ==\n');
app.runPipeline(Steps="spikes");
R = app.RunResultsTable.Data;
spikesFile = fullfile(outRoot, 'recA_260101_120000', 'recA_260101_120000_spikes.mat');
check(istable(R) && any(R.Step == "spikes" & R.Status == "done") && isfile(spikesFile), 'the Spikes step ran and wrote its file');
scriptFile = EphysPipeline.scriptFileFor(app.Config.Project.Root, app.Config.Name);
check(app.SaveScriptCheckBox.Value && app.Config.Project.SaveScript && isfile(scriptFile) ...
    && contains(string(fileread(scriptFile)), "% That run ran spikes only;"), ...
    'the run saved the pipeline script in the project root (Save the pipeline script on each run, on by default)');
M = load(spikesFile);
check(~isempty(M.detected) && ~isfield(M, 'units') && M.detected.detection.options.Threshold == 1500, ...
    'the file reflects the edited threshold and holds the detections only');
check(~app.RunActive && strcmp(app.RunButton.Enable, 'on'), 'run state is reset afterwards');
app.runLog("the report reads this line");
runTail = string(app.RunLogArea.Value);
runTail = runTail(strlength(strip(runTail)) > 0);
rep = app.issueReport("bug", System=false, Config=false);
check(contains(rep, "**Run log**") && contains(rep, runTail(end)) && contains(rep, "the report reads this line") ...
    && isempty(app.LastError), 'the issue report carries the Run log as the tab shows it; the run recorded no error');

fprintf('\n== 4a. Review tab: unit labels, location, notes ==\n');
app.selectDataset(1);
app.syncReviewDataset();
R = app.ReviewData;
C = app.ReviewUnitsTable.Data;
check(~isempty(R) && isequal(string(app.ReviewUnitsTable.ColumnName(:)).', ...
    ["Unit" "Group" "Shank" "Ch" "X(um)" "Y(um)" "#Spk" "FR(Hz)" "Amp" "Cont%" "QC" "ISIv" "Pres" "Cutoff" "SNR" "Notes"]) ...
    && size(C, 2) == 16 && isequal(logical(app.ReviewUnitsTable.ColumnEditable), [false(1, 15) true]) ...
    && R.unitLabel(R.clusterID == 0) == "su000_recA_260101T1200" ...
    && any(contains(string(app.ReviewSummaryLabel.Text), "<class><id>_recA_260101T1200")), ...
    'the active dataset''s sort shows unit labels, location columns and an editable Notes column');
row = find(cellfun(@(v) isequal(v, 1), C(:, 1)), 1);
app.onReviewNoteEdited(struct('Indices', [row 16], 'NewData', 'two cells?', 'PreviousData', ''));
[ids, notes] = EphysDataset.readUnitNotes(phyDir);
check(isequal(ids, 1) && notes == "two cells?" && app.ReviewData.notes(app.ReviewData.clusterID == 1) == "two cells?" ...
    && string(app.ReviewUnitsTable.Data{row, 16}) == "two cells?", 'editing a Notes cell saves cluster_notes.tsv');
check(isfield(app.ReviewData.units, 'presenceRatio') && app.ReviewData.qc.has ...
    && all(ismember(string(app.ReviewUnitsTable.Data(:, 11)), ["yes" "no"])) ...
    && isfile(fullfile(phyDir, 'quality_metrics.json')), ...
    'the Review tab computes the units'' quality metrics (cached in the sort folder) and judges them in the QC column');
qcBefore = string(app.ReviewUnitsTable.Data(:, 11));
app.ReviewCriteriaFields.firingRateMin.Value = '1e9';
app.onReviewCriteriaChanged();
check(all(string(app.ReviewUnitsTable.Data(:, 11)) == "no") && app.Config.Sorting.Quality.firingRateMin == 1e9, ...
    'a stricter criterion goes into Sorting.Quality and fails every unit at once');
app.ReviewCriteriaFields.firingRateMin.Value = '';
app.onReviewCriteriaChanged();
check(isequal(string(app.ReviewUnitsTable.Data(:, 11)), qcBefore) && isnan(app.Config.Sorting.Quality.firingRateMin), ...
    'blank: the criterion is not applied again');
app.onReviewQCReport();
check(isfile(fullfile(phyDir, 'quality_report.html')) ...
    && contains(fileread(fullfile(phyDir, 'quality_report.html')), "Meet the criteria"), ...
    'QC report writes quality_report.html next to the sort');
app.syncReviewDataset();
check(app.ReviewData.notes(app.ReviewData.clusterID == 1) == "two cells?", 'the note is read back on reload');
settingsFile = fullfile(phyDir, 'settings.json');
S0 = readJsonFile(settingsFile);
S1 = S0; S1.tmin = 0.005;   % Kilosort4 sorted from 5 ms on
writeJsonFile(settingsFile, S1);
app.syncReviewDataset();
R = app.ReviewData;
dR = app.currentDataset();
check(abs(R.durSec - (dR.Duration - 0.005)) < 1e-9 && all(abs(R.firingRate - R.nSpikes / R.durSec) < 1e-9) ...
    && any(contains(string(app.ReviewSummaryLabel.Text), "Sorted")), ...
    'firing rates are over the sorted part of the recording: tmin (settings.json) to its end, not to the last spike');
writeJsonFile(settingsFile, S0);
app.syncReviewDataset();
ax = app.ReviewUnitShankAxes;
check(ax.Title.String == "Unit on its shank" && contains(string(findobj(ax, 'Type', 'text').String), "Pick a unit"), ...
    'with no unit selected the shank plot asks for one');
check(contains(string(findobj(app.ReviewISIAxes, 'Type', 'text').String), "Pick a unit") ...
    && contains(string(findobj(app.ReviewACGAxes, 'Type', 'text').String), "Pick a unit"), ...
    'with no unit selected the ISI and autocorrelogram plots ask for one');
check(app.ReviewShankAxes.Parent == app.ReviewUnitShankAxes.Parent && app.ReviewRateAxes.Parent == app.ReviewUnitShankAxes.Parent ...
    && isequal([app.ReviewUnitShankAxes.Layout.Row app.ReviewShankAxes.Layout.Row app.ReviewRateAxes.Layout.Row], [2 3 4]) ...
    && ~isprop(app, 'ReviewWaveAxes'), ...
    'units per shank and firing rates sit below the unit on its shank; there is no mean-waveforms plot');
binX = zeros(4, 46000, 'int16');                 % the sort's dat_path, x.bin: troughs at its spikes
binX(2, [300 600 30000] + 1) = -500;
binX(4, [900 1500] + 1) = -800;
fid = fopen(fullfile(phyDir, 'x.bin'), 'w', 'ieee-le'); fwrite(fid, binX, 'int16'); fclose(fid);
row = find(cellfun(@(v) isequal(v, 0), app.ReviewUnitsTable.Data(:, 1)), 1);
app.onReviewUnitSelected(struct('Indices', [row 1]));
nOf = @(type) numel(findobj(ax, 'Type', type));
check(contains(string(ax.Title.String), "su000_recA_260101T1200 on shank 0") ...
    && string(ax.Subtitle.String) == "3 of 3 spikes, mean " + char(177) + " SD" ...
    && isequal(size(app.ReviewSpikeWaves.W), [8 4 3]) && nOf('line') == 4 + 4 + 1 && nOf('patch') == 4 ...
    && any(string(get(findobj(ax, 'Type', 'text'), 'String')) == "A-001"), ...
    'selecting a unit draws its spikes, their mean and SD band on every site of its shank, labelled by channel, and a scale bar');
isiBar = findobj(app.ReviewISIAxes, 'Type', 'bar');     % su000: spikes at 10, 20 and 1000 ms
acgBar = findobj(app.ReviewACGAxes, 'Type', 'bar');
check(isscalar(isiBar) && sum(isiBar.YData) == 1 && abs(isiBar.XData(isiBar.YData > 0) - 10) < 0.5 ...
    && string(app.ReviewISIAxes.Subtitle.String) == "0.00% of 2 intervals < 1.5 ms" ...
    && isscalar(acgBar) && isequal(nnz(acgBar.YData), 2) && all(abs(abs(acgBar.XData(acgBar.YData > 0)) - 10) < 0.5) ...
    && all(abs(acgBar.YData(acgBar.YData > 0) - 1 / (3 * 0.0005)) < 1e-6) ...
    && isscalar(findobj(app.ReviewACGAxes, 'Type', 'constantline')), ...
    'selecting a unit draws its ISI histogram (intervals to 50 ms, the refractory share) and its autocorrelogram in Hz with its mean rate');
reads = app.ReviewSpikeWaves;
ia = app.ReviewISIAxes;
nIsi = @(type) numel(findobj(ia, 'Type', type));
check(app.ReviewWaveModeDropDown.Value == "off" && nIsi('patch') == 0 && nIsi('line') == 0, ...
    'the waveform overlay is off by default');
app.ReviewWaveModeDropDown.Value = 'both'; app.ReviewWaveLocDropDown.Value = 'NE'; app.ReviewWaveScaleSpinner.Value = 1;
app.renderReviewPlots();
p = findobj(ia, 'Type', 'patch'); xl = xlim(ia); yl = ylim(ia);
check(isscalar(p) && nIsi('line') == 2 && abs(range(p.XData) - diff(xl) / 3) < 1e-9 && abs(max(p.XData) - (xl(2) - 0.03 * diff(xl))) < 1e-9 ...
    && abs(max(p.YData) - (yl(2) - 0.03 * diff(yl))) < 1e-9 && isequal(app.ReviewSpikeWaves, reads) ...
    && nnz(contains(string(get(findobj(ia, 'Type', 'text'), 'String')), "A-001")) == 1, ...
    'both: the spikes and the mean in a third-size box at the north-east of the interval plot, captioned with the peak channel; no re-read');
app.ReviewWaveLocDropDown.Value = 'SW'; app.ReviewWaveScaleSpinner.Value = 2;
app.renderReviewPlots();
p = findobj(ia, 'Type', 'patch'); xl = xlim(ia); yl = ylim(ia);
check(abs(min(p.XData) - (xl(1) + 0.03 * diff(xl))) < 1e-9 && abs(min(p.YData) - (yl(1) + 0.03 * diff(yl))) < 1e-9 ...
    && abs(range(p.XData) - diff(xl) * 2 / 3) < 1e-9, 'south-west, scaled by 2: a box of two thirds of the plot in its lower left corner');
app.ReviewWaveModeDropDown.Value = 'mean';
app.renderReviewPlots();
check(nIsi('line') == 1 && numel(findobj(app.ReviewACGAxes, 'Type', 'line')) == 1 && numel(findobj(app.ReviewAmpAxes, 'Type', 'line')) == 1, ...
    'mean: one line in the box, on the autocorrelogram and amplitude plots too');
app.ReviewWaveModeDropDown.Value = 'off'; app.ReviewWaveLocDropDown.Value = 'NE'; app.ReviewWaveScaleSpinner.Value = 1;
app.renderReviewPlots();
app.ReviewShankBandDropDown.Value = 'none';
app.renderReviewUnitShank();
n1 = nOf('patch');
app.ReviewShankSpikesCheckBox.Value = false;
app.renderReviewUnitShank();
n2 = nOf('line');
app.ReviewShankSpikesCheckBox.Value = true; app.ReviewShankMeanCheckBox.Value = false;
app.renderReviewUnitShank();
check(n1 == 0 && n2 == 4 + 1 && nOf('line') == 4 + 1 && isequal(app.ReviewSpikeWaves, reads), ...
    'Spikes, Mean and the band each switch their part; the spikes are not read again');
app.ReviewShankMeanCheckBox.Value = true; app.ReviewShankBandDropDown.Value = 'SD';
app.onReviewAllUnits();
check(ax.Title.String == "Unit on its shank", '"Show all units" clears the shank plot');
delete(fullfile(phyDir, 'x.bin'));
app.syncReviewDataset();
app.onReviewUnitSelected(struct('Indices', [row 1]));
check(startsWith(string(ax.Subtitle.String), "Template: the sorted .bin is not there") && nOf('line') == 4 + 1 ...
    && contains(string(app.StatusBar.Text), "its template is shown"), ...
    'without the sorted .bin the unit''s template is drawn instead, and the status bar says why');

fprintf('\n== 4a2. Review tab: the units table keeps its sort ==\n');
app.syncReviewDataset();
app.TableSorts.Review = struct('column', "#Spk", 'direction', "ascend");   % as a click on #Spk leaves it
app.showReviewUnits();
C = app.ReviewUnitsTable.Data;
check(isequal(cell2mat(C(:, 1)), [2; 1; 0]) && isequal(cell2mat(C(:, 7)), [1; 2; 3]), ...
    'the units are shown in the remembered sort');
app.onReviewUnitSelected(struct('Indices', [3 1]));
check(app.ReviewData.clusterID(app.ReviewSelectedUnit) == 0, 'a row click reaches its unit through the cluster id');
app.onReviewNoteEdited(struct('Indices', [2 16], 'NewData', 'sorted', 'PreviousData', 'two cells?'));
[ids, notes] = EphysDataset.readUnitNotes(phyDir);
C = app.ReviewUnitsTable.Data;
check(isequal(ids, 1) && notes == "sorted" && isequal(cell2mat(C(:, 1)), [2; 1; 0]) && string(C{2, 16}) == "sorted" ...
    && isequal(app.ReviewUnitsTable.Selection, 3), ...
    'a note typed in the sorted table goes to its unit; the sort and the selected unit''s row stay');
app.onReviewNoteEdited(struct('Indices', [2 16], 'NewData', 'two cells?', 'PreviousData', 'sorted'));
app.syncReviewDataset();
check(isequal(cell2mat(app.ReviewUnitsTable.Data(:, 1)), [2; 1; 0]) ...
    && app.ReviewData.notes(app.ReviewData.clusterID == 1) == "two cells?", 'the sort holds when the sort is loaded again');
app.onTableSorted("Review", struct('Interaction', 'edit', 'InteractionColumn', 16));
check(isequal(app.tableSort("Review"), struct('column', "#Spk", 'direction', "ascend")), 'an edit is not a sort');
drawnow;
app.onTableSorted("Review", struct('Interaction', 'sort', 'InteractionColumn', 1));   % the Unit header, showing 2, 1, 0
p = AppPrefs.getpref(g, 'TableSorts');
check(isequal(app.tableSort("Review"), struct('column', "Unit", 'direction', "descend")) ...
    && string(p.Review.column) == "Unit" && string(p.Review.direction) == "descend", ...
    'a header click is remembered with the order it shows, and saved as a preference at once');
cm = app.ReviewUnitsTable.ContextMenu;
app.onTableSortMenu(cm, "Review");
item = cm.Children(1);
check(isscalar(cm.Children) && string(item.Text) == "Clear sort (Unit, descending)" && item.Enable == "on", ...
    'right-click offers to clear the sort, naming it');
item.MenuSelectedFcn(item, []);
p = AppPrefs.getpref(g, 'TableSorts');
check(~TableSort.isSorted(app.tableSort("Review")) && ~isfield(p, 'Review') ...
    && isequal(cell2mat(app.ReviewUnitsTable.Data(:, 1)), [0; 1; 2]), 'Clear sort: cluster order again, and the preference goes');
app.onTableSortMenu(cm, "Review");
check(string(cm.Children(1).Text) == "Clear sort" && cm.Children(1).Enable == "off", 'with no sort the item is off');
app.onReviewAllUnits();

fprintf('\n== 4b. Run tab: the run diagram ==\n');
check(app.RunDiagramPanel.Visible == "off" && isequal(app.RunSplitGrid.ColumnWidth, {'1x', 0}) ...
    && contains(string(app.RunDiagramHTML.HTMLSource), "function setup(htmlComponent)"), ...
    'the run diagram is off by default and its page is loaded');
app.RunDiagramCheckBox.Value = true;
app.onRunDiagramToggled();
D = app.RunDiagramHTML.Data;
st = [D.steps.state];
check(app.RunDiagramPanel.Visible == "on" && isequal(app.RunSplitGrid.ColumnWidth, {'3x', '1x'}) ...
    && isequal([D.steps.key], EphysPipelineConfig.StepNames) && D.phase == "done" ...
    && st(6) == "done" && D.steps(6).pct == 100 && D.steps(6).summary ~= "" && all(st([1:5 7]) == "off") ...
    && D.steps(1).label == "not in this run", ...
    'ticked, it takes a quarter of the right side and shows the last run (followed while hidden): Spikes done at 100%');
app.resetRunDiagram(["probe" "signals" "spikes"], false);
D = app.RunDiagramHTML.Data;
check(D.phase == "running" && all([D.steps([1 5 6]).state] == "queued") && D.steps(3).state == "off" ...
    && D.headline == "Starting...", 'a run starts with its steps waiting and the others not in it');
ev = @(step, ds, i, n, done, total, msg) struct('step', string(step), 'dataset', string(ds), 'index', i, ...
    'count', n, 'done', done, 'total', total, 'message', string(msg));
app.updateRunDiagram(ev("probe", "", 0, 4, 0, 1, "starting"));
app.updateRunDiagram(ev("signals", "", 0, 4, 0, 1, "starting"));
app.updateRunDiagram(ev("signals", "recB", 2, 4, 1, 2, "LFP"));
D = app.RunDiagramHTML.Data;
s = D.steps(5);
check(D.steps(1).state == "done" && D.steps(1).pct == 100 && s.state == "running" && s.pct == 37.5 ...
    && s.now == "Dataset 2 of 4: recB" && s.msg == "LFP" && D.steps(6).state == "queued" ...
    && D.headline == "Step 2 of 3: Signals", ...
    'an event makes its step the one underway at (index - 1 + done/total) / count, the steps before it done');
app.updateRunDiagram(ev("signals", "recA", 1, 4, 0, 1, "late"));
check(app.RunDiagramHTML.Data.steps(5).pct == 37.5, 'a step''s percentage never goes back');
Rd = EphysPipeline.emptyResults();
Rd(1:2, :) = {"signals", "recA", "done", "", "", 1; "signals", "recB", "cancelled", "", "", 1};
app.finishRunDiagram(Rd, "cancelled", "");
D = app.RunDiagramHTML.Data;
check(D.phase == "cancelled" && D.steps(5).state == "cancelled" && D.steps(5).pct == 37.5 ...
    && D.steps(6).state == "notrun" && D.steps(5).summary == "1 done, 1 cancelled" ...
    && startsWith(D.headline, "Cancelled during Signals"), ...
    'a cancel leaves its step at the percentage reached, with its counts, and the later steps not run');
app.resetRunDiagram();
app.RunSignalsCheckBox.Value = true;
app.RunSignalsCheckBox.ValueChangedFcn(app.RunSignalsCheckBox, []);   % as a click would
D = app.RunDiagramHTML.Data;
check(D.phase == "idle" && D.steps(1).label == "will run" && D.steps(5).label == "will run" ...
    && D.steps(3).label == "off" && startsWith(D.headline, "Ready: "), ...
    'before a run it previews the ticked steps and follows the checklist');
app.RunSignalsCheckBox.Value = false;
app.RunSignalsCheckBox.ValueChangedFcn(app.RunSignalsCheckBox, []);
check(app.RunDiagramHTML.Data.steps(5).label == "off", 'unticking a step takes it out of the preview');
app.savePreferences();
check(isequal(AppPrefs.getpref(g, 'ShowRunDiagram'), true), 'the switch is saved as a preference');
app.RunDiagramCheckBox.Value = false;
app.onRunDiagramToggled();
check(app.RunDiagramPanel.Visible == "off" && isequal(app.RunSplitGrid.ColumnWidth, {'1x', 0}), ...
    'unticked, the progress, results and log have the whole right side again');

fprintf('\n== 4b2. Run tab: the results table fills as the Run goes ==\n');
% As runPipeline leaves them: the pipeline running, the table showing its rows.
pipe = app.buildPipeline();
app.Pipe = pipe;
app.RunActive = true;
app.RunResultsTable.Data = EphysPipeline.emptyResults();
app.onPipelineProgress(ev("probe", "", 0, 1, 0, 1, "starting"));
pipe.addResult("probe", "recA_260101_120000", "ok", "");
app.onPipelineProgress(ev("behavior", "", 0, 1, 0, 1, "starting"));
R = app.RunResultsTable.Data;
check(height(R) == 1 && R.Step == "probe" && R.Status == "ok", ...
    'a row the pipeline records reaches the results table at the next progress event');
R.Message(1) = "left as it is";
app.RunResultsTable.Data = R;
app.onPipelineProgress(ev("behavior", "recA_260101_120000", 1, 1, 0.5, 1, "matching"));
check(app.RunResultsTable.Data.Message(1) == "left as it is", ...
    'an event that adds no row leaves the table alone (it is not rebuilt at every event)');
pipe.addResult("sorting", "recA_260101_120000", "launched", "background run", "X:/out/kilosort4", 1);
app.markKSResult("recA_260101_120000", "X:/out/kilosort4", "done", "Kilosort4 finished", 4);
R = app.RunResultsTable.Data;
check(height(R) == 2 && R.Status(2) == "done" && R.Seconds(2) == 5 && R.Message(1) == "" ...
    && pipe.Results.Status(2) == "done", ...
    'a row the monitor restates during the Run reaches the table at once, as the pipeline has it');
app.Pipe = [];
app.RunActive = false;

fprintf('\n== 4c. Run tab: resource monitoring ==\n');
check(app.RunMonitorPanel.Visible == "off" && isequal(app.RunLeftGrid.RowHeight, {'1x', 0}) ...
    && isempty(app.ResourceMonitorTimer) && app.ResourceMonitor.dir == "", ...
    'resource monitoring is off by default: no panel, no sampler, no timer');
S = struct('t', '2026-09-18T10:41:21', 'cpu', 37.2, 'memUsedGB', 12.3, 'memTotalGB', 31.7, ...
    'disk', 95, 'diskName', '1 D:', 'readMBs', 80.2, 'writeMBs', 12.5, ...
    'gpus', struct('index', {0 1}, 'name', {'A' 'B'}, 'util', {28 61}, 'memUsedMB', {869 1024}, 'memTotalMB', {4094 8192}), ...
    'gpuNote', '');
app.showResourceSample(S);
tx = string({app.RunMonitorTexts.Text});
check(isequal(tx, ["37%" "12.3 / 31.7 GB" "95%  93 MB/s" "61%  1.0/8.0 GB"]) ...
    && isequal(app.RunMonitorBars(3).Children(1).BackgroundColor, [0.9 0.45 0.1]) ...
    && isequal(app.RunMonitorBars(1).Children(1).BackgroundColor, [0.25 0.55 0.85]) ...
    && contains(app.RunMonitorTexts(3).Tooltip, "1 D:") && contains(app.RunMonitorTexts(4).Tooltip, "GPU 0 A"), ...
    'a sample shows each figure, the busiest GPU, and a bar at 90% or more in orange');
S.gpus = []; S.gpuNote = 'nvidia-smi not found'; S.cpu = [];
app.showResourceSample(S);
check(app.RunMonitorTexts(4).Text == "n/a" && contains(app.RunMonitorTexts(4).Tooltip, "not found") ...
    && app.RunMonitorTexts(1).Text == "n/a", 'a missing reading shows n/a and says why');
app.selectTab(app.TabRun);
app.RunMonitorCheckBox.Value = true;
app.onResourceMonitorToggled();
dirMon = app.ResourceMonitor.dir;
check(app.RunMonitorPanel.Visible == "on" && isequal(app.RunLeftGrid.RowHeight, {'1x', 'fit'}) ...
    && isfolder(dirMon) && strcmp(app.ResourceMonitorTimer.Running, 'on'), ...
    'ticked, the panel opens under the steps and the sampler and timer start');
t0 = tic;
while toc(t0) < 20 && ~startsWith(string(app.RunMonitorNote.Text), "Sampled every")
    pause(0.5);
end
tx = string({app.RunMonitorTexts.Text});
check(startsWith(string(app.RunMonitorNote.Text), "Sampled every") && endsWith(tx(1), "%") ...
    && endsWith(tx(2), " GB"), sprintf('live samples arrive within %.0f s', toc(t0)));
app.savePreferences();
check(isequal(AppPrefs.getpref(g, 'MonitorResources'), true), 'the switch is saved as a preference');
app.RunMonitorCheckBox.Value = false;
app.onResourceMonitorToggled();
t0 = tic;
while toc(t0) < 10 && isfolder(dirMon)
    pause(0.5);
end
check(app.RunMonitorPanel.Visible == "off" && isequal(app.RunLeftGrid.RowHeight, {'1x', 0}) ...
    && isempty(app.ResourceMonitorTimer) && ~isfolder(dirMon), ...
    'unticked, the panel closes, the timer stops and the sampler exits and removes its folder');

fprintf('\n== 4d. Clean up tab ==\n');
ksRoot = app.Project.Datasets(1).kilosortDir();   % under the OutputRoot
ksOut = ksRoot;
if ~isfolder(ksOut); mkdir(ksOut); end
fid = fopen(fullfile(ksOut, 'temp_wh.dat'), 'w'); fwrite(fid, zeros(1, 512, 'int16'), 'int16'); fclose(fid);
app.selectTab(app.TabCleanup);
check(contains(app.CleanupScopeLabel.Text, "1 dataset") && app.CleanupRunButton.Enable == "off" ...
    && isempty(app.CleanupPlan), 'the tab says which datasets it acts on; nothing can be removed before a Preview');
app.onCleanupPreview();
P = app.CleanupPlan;
rawRow = P(P.File == string(fullfile(f1, 'recA.rhd')), :);
check(height(P) > 2 && isequal(P.Action(P.File == string(fullfile(ksOut, 'temp_wh.dat'))), "remove") ...
    && rawRow.Action == "keep" && contains(rawRow.Reason, "no source copy") ...
    && app.CleanupRunButton.Enable == "on" && startsWith(app.CleanupSummaryLabel.Text, "Would remove 1 file(s)") ...
    && size(app.CleanupTable.Data, 1) == height(P) && isfile(fullfile(ksOut, 'temp_wh.dat')), ...
    'Preview lists every file as Remove or Keep (a raw recording without a copy record stays) and deletes nothing');
check(app.CleanupTable.ColumnSortable && isequal(P.Include, P.Action == "remove") ...
    && isequal(app.CleanupSubjectDropDown.Items, [{'All subjects'}; cellstr(unique(P.Subject))].'), ...
    'the columns sort, every Remove file starts ticked and the Subject ID list holds the plan''s subjects');
app.CleanupShowKeptCheckBox.Value = false;
app.refreshCleanupTable();
check(size(app.CleanupTable.Data, 1) == 1 && isequal(app.CleanupTable.Data(1, 1:2), {true, 'Remove'}), ...
    'unticking Show the files that remain leaves only the Remove rows');
app.CleanupShowKeptCheckBox.Value = true;
app.CleanupSearchField.Value = 'temp_wh\.dat$';
app.refreshCleanupTable();
check(size(app.CleanupTable.Data, 1) == 1 && startsWith(app.CleanupShownLabel.Text, "Showing 1 of"), ...
    'the regexp search shows only the matching files');
app.CleanupSearchField.Value = 'no-such-file';
app.refreshCleanupTable();
check(isempty(app.CleanupTable.Data) && isequal(app.CleanupSearchField.BackgroundColor, [1.00 0.85 0.85]), ...
    'a search matching no file empties the table and is flagged');
app.CleanupSearchField.Value = '';
app.CleanupSubjectDropDown.Value = app.CleanupSubjectDropDown.Items{end};
app.refreshCleanupTable();
check(size(app.CleanupTable.Data, 1) == nnz(P.Subject == string(app.CleanupSubjectDropDown.Value)), ...
    'the Subject ID list shows only that subject''s files');
app.CleanupSubjectDropDown.Value = 'All subjects';
app.refreshCleanupTable();
r = find(strcmp(app.CleanupTable.Data(:, 2), 'Remove'));
app.onCleanupFileTicked(struct('Indices', [r 1], 'NewData', false));
check(~app.CleanupPlan.Include(app.CleanupRowMap(r)) && app.CleanupRunButton.Enable == "off" ...
    && contains(app.CleanupSummaryLabel.Text, "Would remove 0 file(s)"), ...
    'unticking the only Remove file leaves nothing to remove');
k = find(strcmp(app.CleanupTable.Data(:, 2), 'Keep'), 1);
app.CleanupTable.Data{k, 1} = true;
app.onCleanupFileTicked(struct('Indices', [k 1], 'NewData', true));
check(~app.CleanupTable.Data{k, 1} && ~any(app.CleanupPlan.Include(app.CleanupPlan.Action == "keep")), ...
    'a Keep file cannot be ticked');
app.onCleanupSelect("all");
check(app.CleanupPlan.Include(app.CleanupRowMap(r)) && app.CleanupRunButton.Enable == "on", 'All visible ticks the Remove files shown');
app.onCleanupSelect("invert");
check(~any(app.CleanupPlan.Include), 'Invert visible flips them');
app.onCleanupSelect("all");
app.CleanupSearchField.Value = 'no-such-file';
app.refreshCleanupTable();
app.onCleanupSelect("only");
check(~any(app.CleanupPlan.Include), 'Only visible with nothing shown unticks every hidden file');
app.CleanupSearchField.Value = '';
app.refreshCleanupTable();
app.onCleanupSelect("all");
app.onCleanupSelect("none");
check(~any(app.CleanupPlan.Include) && app.CleanupRunButton.Enable == "off", 'None visible unticks what is shown');
app.onCleanupSelect("all");
app.TableSorts.Cleanup = struct('column', "File", 'direction', "descend");   % as a click on File leaves it
app.refreshCleanupTable();
D = app.CleanupTable.Data;
tempFile = string(fullfile(ksOut, 'temp_wh.dat'));
L = lower(string(D(:, 7)));
check(isequal(L, sort(L, 'descend')) && isequal(string(D(:, 7)), app.CleanupPlan.File(app.CleanupRowMap)), ...
    'a remembered sort orders the preview, and each row still maps to its own file in the plan');
r = find(string(D(:, 7)) == tempFile);
app.onCleanupFileTicked(struct('Indices', [r 1], 'NewData', false));
check(~app.CleanupPlan.Include(app.CleanupPlan.File == tempFile) && nnz(app.CleanupPlan.Include) == nnz(P.Action == "remove") - 1, ...
    'a tick in the sorted table reaches its own file and no other');
app.onCleanupSelect("all");
app.clearTableSort("Cleanup");
check(isequal(app.CleanupRowMap, (1:height(app.CleanupPlan)).'), 'Clear sort: the plan''s order again');
app.CleanupSorterCopyCheckBox.Value = false;
app.onCleanupSettingsChanged();
check(isempty(app.CleanupPlan) && app.CleanupRunButton.Enable == "off" && contains(app.CleanupSummaryLabel.Text, "Preview again"), ...
    'changing the kinds to remove discards the preview until Preview is pressed again');
check(numel(app.CleanupStepCheckBoxes) == 6 && isequal(string({app.CleanupStepCheckBoxes.Tag}), ...
    ["sorting" "signals" "spikes" "behavior" "artifacts" "export"]) && ~any([app.CleanupStepCheckBoxes.Value]) ...
    && string(app.CleanupMethodDropDown.Value) == "delete" && app.CleanupDestField.Enable == "off" ...
    && app.CleanupRunButton.Text == "Delete files...", ...
    'one box per step that writes files, none ticked; files are deleted by default and the folder field is off');
writelines('{"state": "done"}', fullfile(ksRoot, 'ks4_status.json'));
app.CleanupStepCheckBoxes(1).Value = true;   % Sorting (Kilosort4)
app.onCleanupSettingsChanged();
app.onCleanupPreview();
P = app.CleanupPlan;
inKs = startsWith(P.File, string(ksRoot) + filesep);
check(nnz(inKs) == 2 && all(P.Action(inKs) == "remove") && all(P.Step(inKs) == "sorting") ...
    && ~any(P.Action(~inKs & P.Step ~= "sorting") == "remove"), ...
    'ticking Sorting marks everything in the kilosort4 folder Remove, and nothing outside the step''s files');
app.CleanupMethodDropDown.Value = 'move';
app.onCleanupMethodChanged();
check(app.CleanupDestField.Enable == "on" && app.CleanupRunButton.Text == "Move files..." && ~isempty(app.CleanupPlan), ...
    'Move to a folder turns the folder field on and keeps the preview');
app.CleanupDestField.Value = fullfile(proj, 'moved');
app.onCleanupRun();   % refused with an alert, before any confirmation
check(all(isfile(P.File(inKs))) && ~isfolder(fullfile(proj, 'moved')), ...
    'a folder inside the project root is refused and nothing moves');
moveDest = fullfile(root, 'moved');
app.CleanupDestField.Value = moveDest;
R = app.runCleanup(app.CleanupPlan);
movedTo = string(fullfile(moveDest, R.Key, extractAfter(R.File, strlength(R.Root) + 1)));
check(height(R) == nnz(P.Action == "remove") && all(R.Status == "removed") && isequal(R.To, movedTo) ...
    && all(isfile(movedTo)) && ~isfolder(ksRoot) && ~any(startsWith(app.CleanupPlan.File, string(ksRoot))) ...
    && contains(string(app.CleanupLogArea.Value{end}), "Moved") ...
    && isfile(fullfile(f1, app.Project.Datasets(1).Name + "_cleanup.json")), ...
    'Move files moves them to <folder>\<dataset key>\..., removes the emptied kilosort4 folder, keeps a record and previews again');
app.savePreferences();
v = AppPrefs.getpref(g, 'CleanupOptions');
check(isequal(string(v.steps), "sorting") && string(v.method) == "move" && string(v.destination) == string(moveDest), ...
    'the ticked steps, the method and the folder are saved as preferences');
app.CleanupStepCheckBoxes(1).Value = false;
app.CleanupSorterCopyCheckBox.Value = true;
app.CleanupMethodDropDown.Value = 'delete';
app.CleanupDestField.Value = '';
app.onCleanupMethodChanged();
app.onCleanupSettingsChanged();
if isfolder(ksRoot); rmdir(ksRoot, 's'); end
app.selectTab(app.TabProject);

fprintf('\n== 4e. Run tab: background Kilosort4 runs, N at a time ==\n');
check(app.RunKSAtOnceSpinner.Value == 1 && strcmp(app.RunKSAtOnceSpinner.Enable, 'on') ...
    && app.Config.Sorting.MaxConcurrent == 1, 'one background Kilosort4 run at a time by default, set on the Run tab');
app.ExecModeDropDown.Value = true;   % Blocking (wait)
app.ExecModeDropDown.ValueChangedFcn(app.ExecModeDropDown, []);
check(app.Config.Sorting.Execution == "blocking" && strcmp(app.RunKSAtOnceSpinner.Enable, 'off'), ...
    'blocking execution greys out the runs-at-once spinner');
app.ExecModeDropDown.Value = false;
app.ExecModeDropDown.ValueChangedFcn(app.ExecModeDropDown, []);
app.RunKSAtOnceSpinner.Value = 2;
app.RunKSAtOnceSpinner.ValueChangedFcn(app.RunKSAtOnceSpinner, []);   % as a click would
check(app.Config.Sorting.MaxConcurrent == 2 && strcmp(app.RunKSAtOnceSpinner.Enable, 'on'), ...
    'the spinner sets Sorting.MaxConcurrent');
app.RunKSAtOnceSpinner.Value = 1;
app.RunKSAtOnceSpinner.ValueChangedFcn(app.RunKSAtOnceSpinner, []);
% A run from an earlier Run still holds the only slot: this Run waits for it
% (the sampler below ends that run once both labels have said so), and the
% monitor follows the new run from its start. A stand-in "python" sleeps
% ~4 s and writes ks4_status.json.
probe4 = fullfile(root, 'probe4.json');
writeJsonFile(probe4, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), 'yc', (0:numAmp-1) * 20, ...
    'kcoords', zeros(1, numAmp), 'n_chan', numAmp));
app.Project.Datasets(1).ProbeFile = probe4;
fakePython = fullfile(root, 'fake_python.cmd');
writelines(["@echo off"; "ping -n 5 127.0.0.1 > nul"; "echo sorted by the stand-in"
    "echo {""state"": ""done""}> ""%~dp1ks4_status.json"""], fakePython, LineEnding="\r\n");
app.PythonExeField.Value = fakePython;
app.onConfigChanged();
priorDir = fullfile(root, 'earlier_run'); mkdir(priorDir);
priorStatus = fullfile(priorDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("earlier", struct('statusFile', priorStatus, ...
    'resultsDir', priorDir, 'stdoutLog', "", 'device', ""));
app.startKSMonitor();
labelsSeen = strings(0, 1);
tSample = tic;
    function sampleLabels()
        labelsSeen(end+1, 1) = string(app.RunKSLabel.Text) + " | " + string(app.RunStepLabel.Text);
        both = any(contains(labelsSeen, "waiting to start")) && any(contains(labelsSeen, "waiting for a free"));
        if ~isfile(priorStatus) && (both || toc(tSample) > 60)
            writelines('{"state": "done"}', priorStatus);   % the earlier run finishes
        end
    end
sampler = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.5, 'BusyMode', 'drop', ...
    'TimerFcn', @(~,~) sampleLabels());
start(sampler);
app.runPipeline(Steps="sorting");
stop(sampler); delete(sampler);
R = app.RunResultsTable.Data;
check(any(R.Step == "sorting" & R.Status == "launched") && toc(tSample) < 60, ...
    'the Run waited for the earlier run''s slot, then launched');
check(any(contains(labelsSeen, "sorting: recA_260101_120000 - waiting for a free Kilosort4 slot (1 at a time): 1 running")) ...
    && any(contains(labelsSeen, "Background Kilosort4: 0 of 2 finished (1 running, 1 waiting to start).")), ...
    'while waiting, the step line and the Kilosort4 label say how many run and wait');
check(numel(app.KSRuns) == 2 && app.KSRuns(2).Name == "recA_260101_120000", ...
    'the new run joined the monitor as it started');
t0 = tic;
while toc(t0) < 30 && ~isempty(app.KSRuns)
    pause(0.5);
end
exitMarker = fullfile(app.Project.Datasets(1).kilosortDir(), EphysDataset.SortExitMarker);
while toc(t0) < 40 && ~isfile(exitMarker)
    pause(0.25);
end
ksLog = strjoin(string(app.KSLogArea.Value), newline);
check(contains(ksLog, "recA_260101_120000 | sorted by the stand-in"), ...
    'the monitor streamed the run''s log (CRLF lines, as Python on Windows writes them)');
check(isempty(app.KSRuns) && contains(ksLog, "[done] recA_260101_120000 - Kilosort4 complete") ...
    && contains(ksLog, "=== all 2 background run(s) complete ===") ...
    && startsWith(string(app.RunKSLabel.Text), "Background Kilosort4: 2 of 2 finished"), ...
    'the monitor logged it done and cleared the finished batch');
R = app.RunResultsTable.Data;
row = R(R.Step == "sorting", :);
check(height(row) == 1 && row.Status == "done" && row.Message == "Kilosort4 finished" && row.Seconds >= 3, ...
    'the monitor turned the run''s "launched" row into "done", adding the time it ran');
check(app.RunDiagram.results.Status(app.RunDiagram.results.Step == "sorting") == "done", ...
    'the run diagram counts it done too');

fprintf('\n== 4f. Run tab: GPUs, and queueing the waiting runs ==\n');
app.RunKSDevicesField.Value = 'cuda:0, cuda:1';
app.RunKSDevicesField.ValueChangedFcn(app.RunKSDevicesField, []);
check(isequal(app.Config.Sorting.Devices, ["cuda:0" "cuda:1"]), 'the GPUs field sets Sorting.Devices');
app.RunKSDevicesField.Value = '';
app.RunKSDevicesField.ValueChangedFcn(app.RunKSDevicesField, []);
check(isempty(app.Config.Sorting.Devices), 'a blank GPUs field lists no devices');
app.ExecModeDropDown.Value = true;
app.ExecModeDropDown.ValueChangedFcn(app.ExecModeDropDown, []);
check(strcmp(app.RunKSQueueCheckBox.Enable, 'off'), 'blocking execution greys out the queue box');
app.ExecModeDropDown.Value = false;
app.ExecModeDropDown.ValueChangedFcn(app.ExecModeDropDown, []);
app.RunKSQueueCheckBox.Value = true;
% An earlier run holds the only slot again: this time the Run queues the
% dataset and ends without waiting. A safety timer ends the earlier run
% after 60 s, so a Run that waited after all cannot hang the suite.
priorDir = fullfile(root, 'earlier_run2'); mkdir(priorDir);
priorStatus = fullfile(priorDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("earlier", struct('statusFile', priorStatus, ...
    'resultsDir', priorDir, 'stdoutLog', "", 'device', ""));
app.startKSMonitor();
safety = timer('StartDelay', 60, 'TimerFcn', @(~,~) writelines('{"state": "done"}', priorStatus));
start(safety);
t0 = tic;
app.runPipeline(Steps="sorting");
R = app.RunResultsTable.Data;
check(toc(t0) < 30 && ~app.RunActive && any(R.Step == "sorting" & R.Status == "queued") ...
    && numel(app.KSQueue) == 1 && numel(app.KSRuns) == 1, ...
    'with the earlier run holding the slot, the Run queued the dataset and ended at once');
t0 = tic;
while toc(t0) < 10 && ~contains(app.RunKSLabel.Text, "1 waiting to start"); pause(0.25); end
check(strcmp(app.RunKSStopQueueButton.Enable, 'on') && contains(app.RunKSLabel.Text, "(1 running, 1 waiting to start)"), ...
    'Stop queue is on and the Kilosort4 label counts the queued dataset');
writelines('{"state": "done"}', priorStatus);   % the earlier run finishes
t0 = tic;
while toc(t0) < 20 && ~isempty(app.KSQueue); pause(0.25); end
R = app.RunResultsTable.Data;
check(isempty(app.KSQueue) && any(R.Step == "sorting" & R.Status == "launched" & contains(R.Message, "started from the queue")) ...
    && strcmp(app.RunKSStopQueueButton.Enable, 'off'), ...
    'once the slot freed, the monitor started the queued run and its row says so');
t0 = tic;
while toc(t0) < 30 && ~isempty(app.KSRuns); pause(0.5); end
R = app.RunResultsTable.Data;
check(any(R.Step == "sorting" & R.Status == "done") && contains(strjoin(string(app.KSLogArea.Value), newline), ...
    "recA_260101_120000: launched from the queue"), 'the queued run ran to the end: its row says "done"');
while toc(t0) < 40 && ~isfile(exitMarker); pause(0.25); end
% Stop queue drops a queued run that has not started.
priorDir = fullfile(root, 'earlier_run3'); mkdir(priorDir);
priorStatus3 = fullfile(priorDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("earlier", struct('statusFile', priorStatus3, ...
    'resultsDir', priorDir, 'stdoutLog', "", 'device', ""));
app.startKSMonitor();
app.runPipeline(Steps="sorting");
check(numel(app.KSQueue) == 1, 'queued again behind a running earlier run');
app.RunKSStopQueueButton.ButtonPushedFcn(app.RunKSStopQueueButton, []);
R = app.RunResultsTable.Data;
check(isempty(app.KSQueue) && any(R.Status == "cancelled" & R.Message == "queue stopped before it started") ...
    && strcmp(app.RunKSStopQueueButton.Enable, 'off') && numel(app.KSRuns) == 1, ...
    'Stop queue drops the queued run, marks its row cancelled and leaves the running one');
writelines('{"state": "done"}', priorStatus3);
t0 = tic;
while toc(t0) < 20 && ~isempty(app.KSRuns); pause(0.25); end
stop(safety); delete(safety);
app.RunKSQueueCheckBox.Value = false;
% Stop runs... ends a run that is going: a stand-in that would take ~30 s.
slowPython = fullfile(root, 'slow_python.cmd');
writelines(["@echo off"; "ping -n 31 127.0.0.1 > nul"
    "echo {""state"": ""done""}> ""%~dp1ks4_status.json"""], slowPython, LineEnding="\r\n");
app.PythonExeField.Value = slowPython;
app.onConfigChanged();
check(strcmp(app.RunKSStopRunsButton.Enable, 'off'), 'Stop runs... is off with no run going');
app.runPipeline(Steps="sorting");
t0 = tic;
while toc(t0) < 10 && ~strcmp(app.RunKSStopRunsButton.Enable, 'on'); pause(0.25); end
check(strcmp(app.RunKSStopRunsButton.Enable, 'on') && numel(app.KSRuns) == 1, 'Stop runs... is on while a run is going');
app.stopKSRuns();   % what the button does once confirmed
t0 = tic;
while toc(t0) < 10 && ~isempty(app.KSRuns); pause(0.25); end
R = app.RunResultsTable.Data;
ksLog = strjoin(string(app.KSLogArea.Value), newline);
check(isempty(app.KSRuns) && any(R.Step == "sorting" & R.Status == "cancelled" & R.Message == "stopped before it finished") ...
    && contains(ksLog, "[stopped] recA_260101_120000 - Kilosort4 stopped by the user") ...
    && strcmp(app.RunKSStopRunsButton.Enable, 'off'), ...
    'stopKSRuns ended the run: logged, its row cancelled, the button off again');
app.PythonExeField.Value = '';
app.onConfigChanged();
app.Project.Datasets(1).ProbeFile = "";
app.Project.Datasets(1).writeManifest();
rmdir(app.Project.Datasets(1).kilosortDir(), 's');

fprintf('\n== 5. save and reopen ==\n');
ok = app.onSaveConfig();
check(ok && ~startsWith(app.Fig.Name, "*"), 'save clears the unsaved marker');
c2 = EphysPipelineConfig.load(cfgFile);
check(c2.Spikes.Threshold == 1500 && c2.Project.Root == string(proj), 'the saved file holds the edit');
app.onNewConfig();
check(app.Config.Name == "Untitled" && app.Config.File == "" && ~app.SpkEnableCheckBox.Value, 'New config resets to defaults');
ok = app.openConfigFile(cfgFile);
check(ok && app.Config.Spikes.Threshold == 1500 && any(app.RecentConfigs == string(cfgFile)), 'reopen + recent list');
check(AppPrefs.ispref(g, 'LastConfigFile') && strcmp(AppPrefs.getpref(g, 'LastConfigFile'), cfgFile), 'the last config file is remembered');

% the Artifacts tab's viewer options come back in a new window
app.ArtViewContextField.Value = 40;
app.ArtViewChannelsField.Value = 5;
app.ArtViewShankColorCheckBox.Value = false;
app.ArtViewShadeButton.Value = false;
app.ArtViewScaleDropDown.Value = 'manual';
app.ArtViewLanesField.Value = 150;
app.TableSorts.Trials = struct('column', "Onset", 'direction', "descend");
app.savePreferences();
app2 = EphysPipelineApp;
app2Cleanup = onCleanup(@() delete(app2.Fig));
check(app2.ArtViewContextField.Value == 40 && app2.ArtViewChannelsField.Value == 5 ...
    && ~app2.ArtViewShankColorCheckBox.Value && ~app2.ArtViewShadeButton.Value ...
    && app2.ArtViewScaleDropDown.Value == "manual" && app2.ArtViewLanesField.Value == 150, ...
    'the Artifacts viewer options are recalled by a new window (Shade artifacts drawn off)');
check(app2.ArtThresholdField.Value == app.ArtThresholdField.Value ...
    && strcmp(app2.ArtMethodDropDown.Value, app.ArtMethodDropDown.Value), ...
    'the detection settings come back with the config');
check(isequal(app2.tableSort("Trials"), struct('column', "Onset", 'direction', "descend")), ...
    'a table''s sort is recalled by a new window');
clear app2Cleanup
app.clearTableSort("Trials");
app.ArtViewContextField.Value = 0; app.ArtViewChannelsField.Value = 8; app.ArtViewShankColorCheckBox.Value = true;
app.ArtViewShadeButton.Value = true; app.ArtViewScaleDropDown.Value = 'artifact'; app.ArtViewLanesField.Value = 0;

fprintf('\n== 6. a config for another root; a rescan; the Visualize tab ==\n');
% A second project: recM002 (one file) and recM003, five files of 512
% samples with one spike at recording sample 2500 of channel 1 - a long
% recording in small, which Visualize reads across the file boundaries.
root2 = fullfile(root, 'proj2');
flatRaw = repmat(uint16(32768), numAmp, 4 * spb);
flatDig = zeros(1, 4 * spb);
fM2 = fullfile(root2, 'recM002_260102_120000'); mkdir(fM2);
writeSyntheticRHD(fullfile(fM2, 'recM002.rhd'), flatRaw, flatDig, Fs, spb);
fM3 = fullfile(root2, 'recM003_260103_120000'); mkdir(fM3);
tSpike = 2500;   % 0-based recording sample
for k = 1:5
    raw = flatRaw;
    s = tSpike - (k - 1) * 4 * spb;
    if s >= 0 && s < 4 * spb; raw(1, s + 1) = 32768 + 5000; end   % 975 uV
    fk = fullfile(fM3, sprintf('recM003_part%d.rhd', k));
    writeSyntheticRHD(fk, raw, flatDig, Fs, spb, FirstTimestamp=(k - 1) * 4 * spb);
    setFileModifiedTime(fk, datetime(2026, 1, 3, 12, 0, k));   % the files' order
end
cfgB = cfg;
cfgB.Name = "second project";
cfgB.Project.Root = root2;
cfgB.Project.OutputRoot = fullfile(root, 'out2');
cfgB.Project.Selection = "list";
cfgB.Project.Datasets = "recM003_260103_120000";
cfgBFile = fullfile(root, 'second_project.json');
cfgB = cfgB.save(cfgBFile);
app.onScan();   % gui_test.json's project
check(app.Project.NumDatasets == 1 && app.projectAtRoot(proj), 'the first project is scanned');
ok = app.openConfigFile(cfgBFile);
check(ok && isempty(app.Project) && height(app.DatasetsTable.Data) == 0 && app.Config.Project.Selection == "list" ...
    && isequal(app.Config.Project.Datasets, "recM003_260103_120000"), ...
    'opening a config for another root drops the scanned project and keeps the config''s selection');
id = "";
try
    app.buildPipeline();
catch ME
    id = string(ME.identifier);
end
check(id == "EphysPipelineApp:NoProject", 'before its Scan, a run or plan refuses');
app.onScan();
T = app.DatasetsTable.Data;
check(app.Project.NumDatasets == 2 && isequal(T.Select(T.Name == "recM003_260103_120000"), true) && nnz(T.Select) == 1 ...
    && app.Config.Project.Selection == "list" && isequal(app.Config.Project.Datasets, "recM003_260103_120000"), ...
    'Scan loads the config''s datasets and ticks its selection (not "all")');
app.TableSorts.Datasets = struct('column', "Name", 'direction', "descend");   % as a click on Name leaves it
app.refreshDatasetsTable();
active = app.SelectedDatasetIdx;
app.onDatasetCellSelection(struct('Indices', [2 2]));
T = app.DatasetsTable.Data;
S = app.DatasetsTable.StyleConfigurations;
check(isequal(T.Name, ["recM003_260103_120000"; "recM002_260102_120000"]) ...
    && app.Project.Datasets(app.SelectedDatasetIdx).Name == "recM002_260102_120000" ...
    && height(S) == 1 && isequal(S.TargetIndex{1}, 2) ...
    && isequal(app.Project.Datasets(app.tickedDatasetIndices()).Name, "recM003_260103_120000"), ...
    'the Project table keeps its sort on a refresh; a row click, the highlight and the ticks follow their datasets');
app.clearTableSort("Datasets");
if active >= 1; app.selectDataset(active); end
app.RootPathField.Value = char(proj);   % edited, not scanned
app.onConfigChanged();
id = "";
try
    app.buildPipeline();
catch ME
    id = string(ME.identifier);
end
check(id == "EphysPipelineApp:OtherProject" && isequal(app.Config.Project.Datasets, "recM003_260103_120000"), ...
    'with the root edited, a run or plan refuses the datasets scanned under the other root, and the selection is kept');
app.RootPathField.Value = char(root2);
app.onConfigChanged();
names = [app.Project.Datasets.Name];
dM2 = app.Project.Datasets(names == "recM002_260102_120000");
dM3 = app.Project.Datasets(names == "recM003_260103_120000");
dM2.ManualArtifacts = [0.001 0.002]; dM2.writeManifest();
dM3.ManualArtifacts = [0.03 0.031]; dM3.writeManifest();
app.selectDataset(find(names == "recM003_260103_120000"));
app.selectTab(app.TabVisualize);   % opening the tab loads the active dataset
app.Viewer.RenderDelay = 0;
check(app.VizDataset == dM3 && isequal(app.VizSourceDropDown.ItemsData, {'recording'}) ...
    && app.Viewer.Source.Kind == "recording" && app.Viewer.Source.Reference == "pipeline", ...
    'opening the tab loads the active dataset: its recording, the only signal it has, read as the pipeline reads it');
app.VizChannelsField.Value = '1';
app.VizHighpassField.Value = ''; app.VizLowpassField.Value = '';
app.VizRefDropDown.Value = 'none'; app.VizOffsetCheckBox.Value = false;
app.VizModeDropDown.Value = 'traces';
app.onVizControlsChanged("channels");
app.onVizControlsChanged("processing");
app.onVizControlsChanged("mode");
nTot = 5 * 4 * spb;
app.Viewer.setView(0, nTot / Fs);   % the whole recording: five files, read a chunk at a time
b = app.Viewer.LastRender.bin;
[x, y] = vizTrace(app.VizAxes);
[~, iPk] = max(y);
check(app.Viewer.Channels == 1 && app.Viewer.Source.Reference == "none" && b > 1 ...
    && x(iPk) <= tSpike / Fs && x(iPk) > (tSpike - b) / Fs && x(end) > (nTot - 2 * b) / Fs, ...
    'the whole recording in min / max bins across the files: the spike in the last file at its bin''s first sample, the last bin at the end');
app.Viewer.setView((tSpike - 5) / Fs, 10 / Fs);
[x, y] = vizTrace(app.VizAxes);
[~, iPk] = max(y);
check(app.Viewer.LastRender.bin == 1 && abs(x(iPk) - tSpike / Fs) < 1e-9 && app.VizStartField.Value == app.Viewer.TStart, ...
    'zoomed in, the spike is drawn at its own sample, (row-1)/Fs, and the Start field follows the view');
pp = getpixelposition(app.VizAxes, true);
app.Fig.CurrentPoint = pp(1:2) + pp(3:4) / 2;   % the pointer over the plot
t0 = app.Viewer.TStart;
w0 = app.Viewer.TWidth;   % 20 samples: no view is narrower
app.Fig.WindowKeyPressFcn(app.Fig, struct('Key', 'rightarrow', 'Modifier', {{}}, 'Character', ''));
t1 = app.Viewer.TStart;
app.Fig.WindowScrollWheelFcn(app.Fig, struct('VerticalScrollCount', 1));
w1 = app.Viewer.TWidth;
t2 = app.Viewer.TStart;
app.VizToolbarButtons(2).ButtonPushedFcn(app.VizToolbarButtons(2), []);   % Page >
check(abs(w0 - 20 / Fs) < 1e-12 && abs(t1 - t0 - w0 / 4) < 1e-9 && abs(w1 - 1.25 * w0) < 1e-9 ...
    && abs(app.Viewer.TStart - t2 - w1) < 1e-9, ...
    'with the pointer over the plot the right arrow pans, the wheel zooms time; Page > moves a window');
app.Fig.CurrentPoint = [1 1];
w2 = app.Viewer.TWidth;
app.Fig.WindowScrollWheelFcn(app.Fig, struct('VerticalScrollCount', 1));
check(app.Viewer.TWidth == w2, 'the wheel away from the plot leaves it alone');
tSeek = 0.6 * nTot / Fs;
% A click on the overview strip, as MATLAB delivers it: the figure's button
% down, the strip's own ButtonDownFcn (with the point clicked), the button up.
ov = app.VizOverviewAxes;
app.Fig.WindowButtonDownFcn(app.Fig, []);
ov.ButtonDownFcn(ov, struct('IntersectionPoint', [tSeek 0.5 0]));
app.Fig.WindowButtonUpFcn(app.Fig, []);
check(abs(app.Viewer.TStart + app.Viewer.TWidth / 2 - tSeek) < 1e-9 && app.VizGesture == "" ...
    && isempty(app.Fig.WindowButtonMotionFcn), 'a click on the overview strip centres the plot on that time, and the release ends the gesture');
app.VizHelpButton.ButtonPushedFcn(app.VizHelpButton, []);
hHelp = app.VizHelpFig;
app.VizHelpButton.ButtonPushedFcn(app.VizHelpButton, []);
helpTxt = string(get(findall(hHelp, 'Type', 'uilabel'), 'Text'));
check(isvalid(hHelp) && app.VizHelpFig == hHelp && contains(helpTxt, "Ctrl+wheel") && contains(helpTxt, "Overview strip") ...
    && string(app.VizHelpButton.Icon) == "question" && ~isprop(app, 'VizHelpLabel'), ...
    'the "?" button opens the mouse and keys window (once, pressed again it comes to the front); the panel no longer lists them');
delete(hHelp);
check(app.VizEventsReadButton.Enable == "on" && contains(app.VizEventsLabel.Text, "No events yet") ...
    && isempty(app.Viewer.Events), ...
    'no Signals extract and no events file: no events are loaded, and Read events is offered');
app.onVizReadEvents();
check(contains(app.VizEventsLabel.Text, "read from the recording") && app.VizEventsReadButton.Enable == "off" ...
    && isfile(fullfile(dM3.outputFolder(), dM3.Name + "_events.mat")), ...
    'Read events reads the digital inputs and keeps them in <Name>_events.mat');
app.VizData.events = EphysTraceViewer.eventLines(struct('TTL1', [(tSpike + 1) / Fs, (tSpike + 20) / Fs]), Fs);
app.VizEventLinesListBox.Items = {'TTL1'};
app.VizEventLinesListBox.Value = {'TTL1'};
app.VizEventsDropDown.Value = 'both';
app.onVizControlsChanged("events");
app.Viewer.setView((tSpike - 5) / Fs, 40 / Fs);
hOn = findall(app.VizAxes, 'Type', 'line', 'LineWidth', 1, 'LineStyle', '-', 'Visible', 'on');
xOn = cell2mat(get(hOn, {'XData'}).');
check(numel(hOn) == 2 && any(abs(xOn - tSpike / Fs) < 1e-12) && strcmp(app.VizAxes.YTickLabel{end}, 'TTL1') ...
    && app.VizAxes.YLim(2) > 0.5, ...
    'Events "Both": an onset marker on the sample the line turned on, and the line''s TTL row above the traces');
dd = app.VizEventJumpDropDown;
check(isequal(dd.ItemsData, {'TTL1'}) && isequal(dd.Items, {'TTL1 (1)'}) && strcmp(dd.Value, 'TTL1') ...
    && dd.Enable == "on" && app.VizEventNextButton.Enable == "on", ...
    'the toolbar''s event box lists every line with its onsets; without a trial line it starts on the first line with one');
app.Viewer.setView(0, 40 / Fs);
app.VizEventNextButton.ButtonPushedFcn(app.VizEventNextButton, []);
check(abs(app.Viewer.TStart - (tSpike - 10) / Fs) < 1e-9 && abs(app.Viewer.TWidth - 40 / Fs) < 1e-12 ...
    && contains(app.VizStatusLabel.Text, "TTL1 onset 1 of 1"), ...
    'the next-onset arrow puts the line''s onset a quarter into the window, and the status line names it');
app.VizEventNextButton.ButtonPushedFcn(app.VizEventNextButton, []);
tHeld = app.Viewer.TStart;
app.VizEventPrevButton.ButtonPushedFcn(app.VizEventPrevButton, []);
check(contains(app.VizStatusLabel.Text, "No earlier TTL1 onset") && app.Viewer.TStart == tHeld, ...
    'with no onset that way the view stays and the status line says so');
evKeep = app.VizData.events;
app.VizData.events = EphysTraceViewer.eventLines(struct('Stim', [1 2] / Fs, 'InTrial', [3 4] / Fs), Fs);
app.onVizControlsChanged("events");
check(dM3.TrialConfig.TrialLine == "InTrial" && strcmp(dd.Value, 'InTrial'), ...
    'new event lines: the box starts on the dataset''s trial line');
dd.Value = 'Stim';
app.onVizControlsChanged("events");
check(strcmp(dd.Value, 'Stim'), 'a line picked in the box stays while the lines are the same');
app.VizData.events = evKeep;
app.onVizControlsChanged("events");
app.VizEventsDropDown.Value = 'strip';
app.onVizControlsChanged("events");
app.Viewer.setView(0, nTot / Fs);
p = findall(app.VizAxes, 'Type', 'patch', 'Visible', 'on');
check(isempty(app.vizDetectedIntervals()) && contains(app.VizArtStatusLabel.Text, "Detect / Preview") ...
    && isscalar(p) && isequal(p.FaceColor, [0.5 0.25 0.85]), ...
    'before a Detect / Preview only the manual period is shaded (purple), and the tab says where detected periods come from');
app.selectTab(app.TabArtifacts);
app.ArtMethodDropDown.Value = 'microvolts';
app.onArtifactControlsChanged();
app.ArtThresholdField.Value = 500;
app.ArtMinChannelsField.Value = 1;
app.onArtifactControlsChanged();
app.onDetectArtifacts();
app.selectTab(app.TabVisualize);   % the overlay follows the preview
iv = app.vizDetectedIntervals();
tMid = (tSpike + 0.5) / Fs;   % inside the spike's sample, [tSpike tSpike+1) / Fs
p = findall(app.VizAxes, 'Type', 'patch', 'Visible', 'on');
check(size(iv, 1) == 1 && iv(1, 1) < tMid && iv(1, 2) > tMid ...
    && numel(p) == 2 && any(arrayfun(@(h) isequal(h.FaceColor, [0.95 0.6 0.1]), p)) ...
    && contains(app.VizArtStatusLabel.Text, "1 detected"), ...
    'after a Detect / Preview the plot shades the preview''s detection (orange) beside the manual period (purple)');
app.selectTab(app.TabArtifacts);
app.ArtThresholdField.Value = 600;
app.onArtifactControlsChanged();
app.selectTab(app.TabVisualize);
check(isempty(app.vizDetectedIntervals()) && contains(app.VizArtStatusLabel.Text, "changed") ...
    && isscalar(findall(app.VizAxes, 'Type', 'patch', 'Visible', 'on')), ...
    'a detection setting changed since the preview: nothing is shaded orange, and the tab says so');
fArt = fullfile(dM3.outputFolder(), dM3.Name + "_artifacts.json");
writeJsonFile(fArt, struct('schema', "ephys-artifacts/3", 'dataset', dM3.Name, 'fingerprint', "test", ...
    'intervals', [0.01 0.012], 'nIntervals', 1));
app.onPlotVisualization();                     % Reload data: finds the run's file
p = findall(app.VizAxes, 'Type', 'patch', 'Visible', 'on');
orange = p(arrayfun(@(h) isequal(h.FaceColor, [0.95 0.6 0.1]), p));
check(isscalar(orange) && abs(min(orange.XData, [], 'all') - 0.01) < 1e-12 ...
    && contains(app.VizArtStatusLabel.Text, "1 detected by the last run") && contains(app.VizArtStatusLabel.Text, "changed"), ...
    'with no current preview, the periods the last run detected (<Name>_artifacts.json) are shaded orange, and the tab says so');
delete(fArt);
app.onPlotVisualization();
app.Viewer.setView(0.002, 0.004);
app.VizArtEditButton.ButtonPushedFcn(app.VizArtEditButton, []);
wArt = app.ArtView.win;
check(app.Tabs.SelectedTab == app.TabArtifacts && isstruct(wArt) && wArt.k == 0 ...
    && abs(app.ArtView.free(1) - 0.002) < 1 / Fs && abs(diff(app.ArtView.free) - 0.004) < 2 / Fs ...
    && app.ArtView.mark.on && app.ArtMarkButton.Value, ...
    'Mark manual periods opens the Artifacts tab''s plot on the stretch shown here, with marking on');
app.selectTab(app.TabVisualize);
check(~app.ArtView.mark.on, 'and coming back to Visualize stops marking');
app.applyArtifactsSection(cfgB.Artifacts);
app.onArtifactControlsChanged();
fM1 = fullfile(root2, 'recM001_260101_120000'); mkdir(fM1);
writeSyntheticRHD(fullfile(fM1, 'recM001.rhd'), flatRaw, flatDig, Fs, spb);
app.onScan();
names = [app.Project.Datasets.Name];
dM2 = app.Project.Datasets(names == "recM002_260102_120000");
dM3 = app.Project.Datasets(names == "recM003_260103_120000");
iM3 = find(names == "recM003_260103_120000");
check(app.Project.NumDatasets == 3 && app.currentDataset() == dM3 && app.VizDataset == dM3 ...
    && ~contains(app.VizStatusLabel.Text, "The plot shows"), ...
    'a rescan that finds a dataset in front keeps recM003 active, and its plot current');
app.onClearManualArtifacts();
check(isempty(dM3.ManualArtifacts) && isequal(dM2.ManualArtifacts, [0.001 0.002]), ...
    'Clear clears the active recM003''s periods, not those of the dataset now in its old place');
dM3.SortingDir = phyDir;
app.refreshDatasetsTable(Datasets=iM3);
T = app.DatasetsTable.Data;
r = T.DatasetIdx == iM3;
check(startsWith(T.Sorting(r), "manual") && T.Select(r), 'refreshing one dataset''s row updates its cells and keeps its tick');
dM3.SortingDir = fullfile(root, 'not_there');
app.refreshDatasetsTable(Datasets=iM3);
app.selectTab(app.TabReview);
T = app.DatasetsTable.Data;
check(T.Sorting(r) == "missing: manual" && contains(string(app.ReviewSummaryLabel.Text), "not there now") ...
    && isempty(app.ReviewData), ...
    'a hand-picked sorted-output folder that is not there reads "missing", and the Review tab says so instead of showing another sort');
dM3.SortingDir = "";
app.ProbeDefaultField.Value = char(probe4);
app.onConfigChanged();
check(all(app.DatasetsTable.Data.Probe == "default: probe4.json"), 'datasets without a probe of their own show the default probe');
app.ProbeDefaultField.Value = '';
app.onConfigChanged();
app.RunActive = true;   % as while a blocking run is under way
P0 = app.Project;
ref0 = dM3.ArtifactConfig.Reference;
app.ArtRefDropDown.Value = 'car';
app.onArtifactControlsChanged();
app.onScan();
app.ExcludeChannelsField.Value = '1';
app.onApplyExclude("selected");
check(app.Config.Artifacts.Reference == "car" && dM3.ArtifactConfig.Reference == ref0 && app.Project == P0 ...
    && isempty(dM3.ExcludeChannels), ...
    'while a run is under way config edits wait for its end, and Scan and per-dataset edits are refused');
app.RunActive = false;
app.ArtRefDropDown.Value = 'none';
app.onArtifactControlsChanged();
app.selectTab(app.TabProject);
badManifest = fullfile(fM1, "recM001_260101_120000_manifest.json");
writelines("not json", badManifest);
app.onScan();
check(contains(app.StatusBar.Text, "1 with a problem") && strtrim(string(fileread(badManifest))) == "not json", ...
    'a manifest that cannot be read is reported after the scan and left as it is');
delete(badManifest);
app.onScan();
names = [app.Project.Datasets.Name];
dM2 = app.Project.Datasets(names == "recM002_260102_120000");
dM3 = app.Project.Datasets(names == "recM003_260103_120000");

fprintf('\n== 6b. a Plan while a background Kilosort4 run is going ==\n');
bgDir = fullfile(root, 'bg_run'); mkdir(bgDir);
bgStatus = fullfile(bgDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("recM003_260103_120000", struct('statusFile', bgStatus, ...
    'resultsDir', bgDir, 'stdoutLog', "", 'device', ""));
app.RunResults = EphysPipeline.emptyResults();
app.RunResults(1, :) = {"sorting", "recM003_260103_120000", "launched", "background run", string(bgDir), 1};
app.startKSMonitor();
app.onPlan();   % the results table now holds the plan
writelines('{"state": "done"}', bgStatus);
t0 = tic;
while toc(t0) < 20 && ~isempty(app.KSRuns); pause(0.25); end
T = app.RunResultsTable.Data;
check(isempty(app.KSRuns) && app.RunResults.Status(1) == "done" && ismember("Key", T.Properties.VariableNames) ...
    && contains(strjoin(string(app.KSLogArea.Value), newline), "[done] recM003_260103_120000"), ...
    'a run that ends while a Plan fills the results table is marked done in the Run''s results, and the monitor goes on');

fprintf('\n== 6c. the queue: each dataset once; a plan skips a queued one ==\n');
holdDir = fullfile(root, 'hold_run'); mkdir(holdDir);
holdStatus = fullfile(holdDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("hold", struct('statusFile', holdStatus, ...
    'resultsDir', holdDir, 'stdoutLog', "", 'device', ""));   % takes the only slot
prep = struct('statusFile', string(fullfile(dM3.kilosortDir(), 'ks4_status.json')), ...
    'resultsDir', string(dM3.kilosortDir()), 'stdoutLog', "", 'device', "", 'dryRun', false);
app.queueKSRun(dM3, prep);
app.queueKSRun(dM3, prep);
prepHold = prep;
prepHold.resultsDir = string(holdDir);   % the folder of the run going
app.queueKSRun(dM2, prepHold);
check(numel(app.KSQueue) == 1 && count(strjoin(string(app.KSLogArea.Value), newline), "not queued again") == 2, ...
    'a dataset whose Kilosort4 folder already has a run queued or going is not queued again');
pipe = app.buildPipeline();
Tp = pipe.plan(Steps="sorting");
check(any([pipe.PriorRuns.queued]) && Tp.Status(Tp.Dataset == "recM003_260103_120000") == "skip: Kilosort4 queued", ...
    'the queued run is one of the pipeline''s PriorRuns, so a plan (and a run) leaves its dataset alone');
app.onStopKSQueue();
writelines('{"state": "done"}', holdStatus);
t0 = tic;
while toc(t0) < 20 && ~isempty(app.KSRuns); pause(0.25); end

fprintf('\n== 6c2. closing with runs queued and going: kept for the next launch ==\n');
% A run going on recM002 (a stand-in that would sort ~60 s), one with no
% process left (no status, no exit marker: as after a restart), and three
% queued runs: recM003's files are all there, recM001's .bin goes before
% the next launch, and recA is not in this project.
dM1 = app.Project.Datasets(names == "recM001_260101_120000");
holdPython = fullfile(root, 'hold_python.cmd');
writelines(["@echo off"; "ping -n 61 127.0.0.1 > nul"
    "echo {""state"": ""done""}> ""%~dp1ks4_status.json"""], holdPython, LineEnding="\r\n");
resA = dM2.launchSorting(keptRunFiles(dM2, holdPython, probe4), Wait=false);
staleDir = fullfile(root, 'stale_run'); mkdir(staleDir);
app.KSRuns = [EphysPipeline.sortRun(dM2.Name, resA), EphysPipeline.sortRun("stale", struct('statusFile', ...
    string(fullfile(staleDir, 'ks4_status.json')), 'resultsDir', string(staleDir), 'stdoutLog', "", 'device', ""))];
prep3 = keptRunFiles(dM3, holdPython, probe4);
prep1 = keptRunFiles(dM1, holdPython, probe4);
dA = EphysDataset(f1);
dA.OutputDir = fullfile(root, 'outA');
app.queueKSRun(dM3, prep3);
app.queueKSRun(dM1, prep1);
app.queueKSRun(dA, keptRunFiles(dA, holdPython, probe4));
check(numel(app.KSQueue) == 3 && all(EphysDataset.pathKey([app.KSQueue.root]) == EphysDataset.pathKey(root2)), ...
    'each queued run records the root of the project it was queued in');
AppPrefs.setpref(g, 'KeptSortingQueue', struct('root', "C:/elsewhere/proj", 'saved', "2026-01-01 00:00", ...
    'runs', struct('Name', "x", 'key', "x", 'prepared', struct())));   % kept for another root earlier
app.keepKSRuns(true);   % what Close does with "Keep the queue for next time"
K = AppPrefs.getpref(g, 'KeptSortingQueue');
i2 = find(EphysDataset.pathKey([K.root]) == EphysDataset.pathKey(root2));
check(numel(K) == 2 && isscalar(i2) && isequal([K(i2).runs.Name], [dM3.Name dM1.Name dA.Name]) ...
    && K(i2).runs(1).key == "recM003_260103_120000" && K(i2).runs(2).key == "recM001_260101_120000" ...
    && string(K(i2).runs(1).prepared.resultsDir) == string(prep3.resultsDir), ...
    'closing keeps the queue under its project root: each run''s dataset key and prepared result; another root''s stays');
Kr = AppPrefs.getpref(g, 'KeptSortingRuns');
check(numel(Kr) == 2 && isequal(sort([Kr.Name]), sort([dM2.Name "stale"])), 'and the runs going, to follow them again');
app.stopKSMonitor();   % the app closes: what it held is gone
app.KSQueue(:) = [];
app.KSRuns(:) = [];
delete(prep1.binFile);   % recM001's .bin goes before the next launch
app3 = EphysPipelineApp;   % the next launch
ksLog3 = strjoin(string(app3.KSLogArea.Value), newline);
check(isscalar(app3.KSRuns) && app3.KSRuns(1).Name == dM2.Name && ~app3.KSRuns(1).done ...
    && ~isempty(app3.KSMonitorTimer) && strcmp(app3.KSMonitorTimer.Running, 'on') && ~AppPrefs.ispref(g, 'KeptSortingRuns') ...
    && contains(ksLog3, "following again 1 Kilosort4 run(s) going when the app last closed: " + dM2.Name) ...
    && contains(ksLog3, "stale: going when the app last closed, but no process of it is left"), ...
    'the next launch follows the run still going again; one with no process left is logged and left out');
check(isempty(app3.KSQueue) && AppPrefs.ispref(g, 'KeptSortingQueue'), 'the kept queue waits for its project''s scan');
delete(app3.Fig);
app.KSRuns = EphysPipeline.sortRun(dM2.Name, resA);   % still going: it holds the only slot
app.startKSMonitor();
T = app.restoreKSQueue("check");
check(height(T) == 3 && T.Problem(T.Dataset == dM3.Name) == "" ...
    && T.Problem(T.Dataset == dM1.Name) == "run files missing: recording.bin" ...
    && T.Problem(T.Dataset == dA.Name) == "its dataset is no longer in the project" ...
    && ~any(T.Queued) && isempty(app.KSQueue) && numel(AppPrefs.getpref(g, 'KeptSortingQueue')) == 2, ...
    'a check says which kept runs can go back in the queue, and why the others cannot; nothing changes');
T = app.restoreKSQueue("requeue");   % what "Queue them again" does
K = AppPrefs.getpref(g, 'KeptSortingQueue');
check(isequal(T.Queued.', [true false false]) && isscalar(app.KSQueue) && app.KSQueue(1).dataset == dM3 ...
    && string(app.KSQueue(1).prepared.resultsDir) == string(prep3.resultsDir) ...
    && strcmp(app.RunKSStopQueueButton.Enable, 'on') && isscalar(K) && K.root == "C:/elsewhere/proj", ...
    'queued again: the run that can goes back in the queue with the scanned dataset; this root''s kept queue is forgotten, another root''s stays');
check(isempty(app.restoreKSQueue("check")) && contains(strjoin(string(app.KSLogArea.Value), newline), ...
    dM1.Name + ": kept when the app last closed, not queued again: run files missing"), ...
    'nothing is kept for this root any more; the log says why a run was not queued again');
app.onStopKSQueue();
app.queueKSRun(dM1, prep1);   % its .bin is gone: it cannot go back in the queue
app.keepKSRuns(true);
app.onStopKSQueue();
app.offerKeptKSQueue();   % an alert, not a question: no run can go back in the queue
K = AppPrefs.getpref(g, 'KeptSortingQueue');
check(isscalar(K) && K.root == "C:/elsewhere/proj" && isempty(app.KSQueue) ...
    && contains(strjoin(string(app.KSLogArea.Value), newline), "dropped the 1 Kilosort4 run(s) queued for"), ...
    'offered back with no run that can go back in the queue, the kept queue is reported and forgotten');
AppPrefs.rmpref(g, 'KeptSortingQueue');
AppPrefs.rmpref(g, 'KeptSortingRuns');
app.stopKSRuns();   % the stand-in on recM002
t0 = tic;
while toc(t0) < 20 && ~isempty(app.KSRuns); pause(0.25); end
while toc(t0) < 30 && ~isfile(fullfile(resA.resultsDir, EphysDataset.SortExitMarker)); pause(0.25); end
check(isempty(app.KSRuns), 'the stand-in run is stopped');

fprintf('\n== 6d. phy starts in a folder whose path holds & and spaces ==\n');
phyHome = fullfile(root, 'Mouse & Rat', 'kilo sort4');
mkdir(phyHome);
writelines("dat_path = 'recording.bin'", fullfile(phyHome, 'params.py'));
fakePhy = fullfile(root, 'fake phy.cmd');
writelines(["@echo off"; "cd > launched.txt"; "if exist params.py echo params.py found>> launched.txt"
    "echo %*>> launched.txt"], fakePhy, LineEnding="\r\n");
phyCmd0 = app.PhyCmdField.Value;
app.PhyCmdField.Value = ['"' fakePhy '"'];
app.launchPhy(phyHome, "Mouse & Rat");
marker = fullfile(phyHome, 'launched.txt');
t0 = tic;
while toc(t0) < 15 && ~(isfile(marker) && numel(readlines(marker)) >= 3); pause(0.25); end
L = strings(0, 1);
if isfile(marker); L = strtrim(readlines(marker)); end
check(~isempty(L) && strcmpi(L(1), phyHome) && any(L == "params.py found") && any(L == "template-gui params.py"), ...
    'phy is started in the results folder, also when its path holds & and spaces');
app.PhyCmdField.Value = phyCmd0;

fprintf('\n== 6e. Source settings for a TDT block ==\n');
proj3 = fullfile(root, 'proj3');
FsT = 24414.0625;
spec = struct('Name', 'Subj9-260105-120000', 'StartTime', posixtime(datetime(2026, 1, 5, 12, 0, 0, 'TimeZone', 'local')));
spec.Streams = [struct('Name', 'Wav1', 'Fs', FsT, 'Data', single(randn(2560, 4) * 1e-4), 'Npts', 256, 'Sev', false, ...
        'T0', 0, 'ChunkTimes', [], 'Rate', [], 'Decimate', [], 'Channels', []), ...
    struct('Name', 'LFP1', 'Fs', FsT / 8, 'Data', int16(randi([-300 300], 320, 2)), 'Npts', 32, 'Sev', false, ...
        'T0', 0, 'ChunkTimes', [], 'Rate', [], 'Decimate', [], 'Channels', [])];
spec.Epocs = struct([]);
writeTDTBlock(fullfile(proj3, spec.Name), spec);
app.RootPathField.Value = char(proj3);
app.onConfigChanged();
app.onScan();
app.selectDataset(1);
check(app.SourcePanel.Title == "Source settings: TDT (Synapse)" && app.SourceTDTGrid.Visible == "on" ...
    && app.SourceOEGrid.Visible == "off" && app.SourceNoteLabel.Visible == "off", ...
    'a TDT block is active: the panel shows the TDT settings only');
check(all(ismember({'automatic' 'Wav1' 'LFP1'}, app.TDTStreamDropDown.Items)) && startsWith(app.TDTStatusLabel.Text, "reads Wav1") ...
    && contains(app.TDTStatusLabel.Tooltip, "LFP1: 2 channels"), ...
    'the Stream list holds the block''s streams; the status says which one is read');
app.TDTStreamDropDown.Value = 'LFP1';
app.onAcquisitionChanged();
app.selectDataset(1);
check(app.Config.Acquisition.TDT.Stream == "LFP1" && contains(app.TDTStatusLabel.Text, "set the gain"), ...
    'an integer stream without a gain: the status asks for one');
app.TDTGainField.Value = '0.5';
app.onAcquisitionChanged();
app.selectDataset(1);
dT3 = app.currentDataset();
check(startsWith(app.TDTStatusLabel.Text, "reads LFP1") && dT3.Fs == FsT / 8 && dT3.NumChannels == 2, ...
    'with a gain the rescan reads the chosen stream');
app.applyAcquisitionSection(cfg.Acquisition);
app.onAcquisitionChanged();

fprintf('\n== 7. deleting the figure (not Close) stops the timers ==\n');
never = fullfile(root, 'never_run');
app.KSRuns = EphysPipeline.sortRun("never", struct('statusFile', fullfile(never, 'ks4_status.json'), ...
    'resultsDir', never, 'stdoutLog', "", 'device', ""));
app.startKSMonitor();
tK = app.KSMonitorTimer;
delete(app.Fig);   % as close all force does
check(~isvalid(tK) && isempty(app.KSMonitorTimer) && isempty(timerfindall('Name', 'EphysPipelineAppMonitor')), ...
    'deleting the figure stops the Kilosort4 monitor (the figure''s DeleteFcn)');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysPipelineApp:Failures', '%d checks failed.', nFail);
end
end


function prep = keptRunFiles(d, python, probe)
%keptRunFiles  A Kilosort4 run of dataset D prepared as runKilosort(Launch=false)
%   returns it, with stand-in run files: the driver command runs PYTHON.
ks = d.kilosortDir();
if ~isfolder(ks); mkdir(ks); end
settings = fullfile(ks, 'settings.json');
script = fullfile(ks, 'run_ks4.py');
bin = fullfile(ks, 'recording.bin');
writelines("{}", settings);
writelines("# stand-in", script);
writelines("", bin);
prep = struct('status', NaN, 'command', "", 'stdoutLog', fullfile(ks, 'ks4_run.log'), 'scriptPath', script, ...
    'settingsPath', settings, 'resultsDir', ks, 'runDir', ks, 'binFile', bin, 'probeFile', string(probe), ...
    'dryRun', false, 'wait', false, 'statusFile', fullfile(ks, 'ks4_status.json'), 'background', false, ...
    'driverCommand', sprintf('"%s" "%s" "%s"', python, script, settings), 'device', "", 'launched', false, ...
    'previousDir', "");
end


function closeApp(app)
try
    if isvalid(app) && isvalid(app.Fig)
        app.stopKSMonitor();
        app.stopResourceMonitor();
        delete(app.Fig);
    end
catch
end
end


function removeRoot(root)
if isfolder(root); rmdir(root, 's'); end
end


function tip = tabTip(app, tab)
%tabTip  Status tooltip of TAB's button in the tab strip.
tip = string(app.TabButtons(app.TabList == tab).Tooltip);
end


function [nCross, nOverlap, nThrough, nBadEnd] = flowGeometry(M)
%flowGeometry  Check the Diagram overview's routing (flowOverviewHTML's MODEL):
%   the points where arrows from different sources cross, the stretches two
%   of them share, the pieces running through a box, and the arrows that do
%   not end going down onto the top of their target.
ids = [M.nodes.id];
R = vertcat(M.nodes.rect);
S = zeros(0, 5);   % x1 y1 x2 y2 source
nThrough = 0; nBadEnd = 0;
for k = 1:numel(M.edges)
    p = M.edges(k).points;
    t = R(ids == M.edges(k).to, :);
    nBadEnd = nBadEnd + ~(abs(p(end, 2) - t(2)) < 0.01 && p(end, 1) > t(1) && p(end, 1) < t(1) + t(3) ...
        && abs(p(end - 1, 1) - p(end, 1)) < 0.01 && p(end - 1, 2) < p(end, 2));
    for j = 1:size(p, 1) - 1
        a = p(j, :); b = p(j + 1, :);
        S(end + 1, :) = [a, b, find(ids == M.edges(k).from)]; %#ok<AGROW>
        nThrough = nThrough + nnz(max(a(1), b(1)) > R(:, 1) + 0.5 & min(a(1), b(1)) < R(:, 1) + R(:, 3) - 0.5 ...
            & max(a(2), b(2)) > R(:, 2) + 0.5 & min(a(2), b(2)) < R(:, 2) + R(:, 4) - 0.5);
    end
end
isH = abs(S(:, 2) - S(:, 4)) < 1e-6;
at = zeros(0, 4);
nOverlap = 0;
for i = 1:size(S, 1)
    for j = i + 1:size(S, 1)
        a = S(i, :); b = S(j, :);
        if a(5) == b(5); continue; end   % one source's arrows share their first stretch
        if isH(i) ~= isH(j)
            if isH(i); h = a; v = b; else; h = b; v = a; end
            if v(1) > min(h(1), h(3)) + 0.5 && v(1) < max(h(1), h(3)) - 0.5 ...
                    && h(2) > min(v(2), v(4)) + 0.5 && h(2) < max(v(2), v(4)) - 0.5
                at(end + 1, :) = round([v(1), h(2), sort([a(5), b(5)])]); %#ok<AGROW>
            end
        else   % both horizontal (same y, x ends 1 and 3) or both vertical (same x, y ends 2 and 4)
            if isH(i); c = 2; r = [1 3]; else; c = 1; r = [2 4]; end
            nOverlap = nOverlap + (abs(a(c) - b(c)) < 0.5 ...
                && min(max(a(r)), max(b(r))) - max(min(a(r)), min(b(r))) > 0.5);
        end
    end
end
nCross = size(unique(at, 'rows'), 1);
end


function [x, y] = vizTrace(ax)
% The points of the Visualize plot's trace lines (width 0.5) that hold data.
x = []; y = [];
for h = findall(ax, 'Type', 'line', 'LineWidth', 0.5, 'Visible', 'on').'
    if all(isnan(h.YData)); continue; end
    in = ~isnan(h.YData);
    x = [x; h.XData(in).']; y = [y; h.YData(in).']; %#ok<AGROW>
end
end


function p = markPixel(ax, t)
% The figure pixel at time T, mid-height of the inner box of the uiaxes AX.
pp = getpixelposition(ax, true);
box = [pp(1:2) + ax.InnerPosition(1:2) - ax.OuterPosition(1:2), ax.InnerPosition(3:4)];
p = [box(1) + (t - ax.XLim(1)) / diff(ax.XLim) * box(3), box(2) + box(4) / 2];
end
