function test_EphysAnalysisConfig()
%test_EphysAnalysisConfig  Verification suite for the analysis config.
%   Defaults (config version 2: no Plots or SessionPlots) and JSON save /
%   load round trips (Inf, NaN, empty lists, one-item lists, "default"
%   sentinels, a heterogeneous Figures array, event sequences on the
%   defaults, a figure and an events layer), figure ids (auto ids,
%   DuplicateFigureId), the validate rules of Source, Defaults, Export and
%   Report (ids and patterns whose files would collide too), "No figure is
%   enabled." (a session figure counts), the units.response checks on a
%   figure's observed units and its layers, the session figures' rules
%   (Figure.sessions), LoadWarnings (a version-2 file holding Plots or
%   SessionPlots: unknown top-level fields), BadSchema (another schema,
%   version 3, no version), a version-1 file migrated on load (its plots
%   and session plots as figures of the same ids, the converter's notes as
%   LoadWarnings, saved as version 2; test_ConfigMigration checks the
%   conversion itself) and figureFileName.
%
%   Usage:  test_EphysAnalysisConfig

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);

root = fullfile(tempdir, sprintf('AnaConfig_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));

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
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end
    function tf = hasIssue(cfg, field, sev)
        I = cfg.validate(CheckPaths=false);
        tf = any(contains(I.Field, field) & I.Severity == sev);
    end
    function tf = exportIssue(cfg, field)
        I = cfg.validate(CheckPaths=false);
        tf = any(I.Section == "Export" & I.Field == field & I.Severity == "warning");
    end
    function c = loadQuiet(f)
        ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
        c = EphysAnalysisConfig.load(f);
        warning(ws);
    end

fprintf('\n== 1. defaults and a JSON round trip ==\n');
cfg = EphysAnalysisConfig();
s0 = cfg.toStruct();
check(cfg.Name == "Untitled" && isempty(cfg.Figures) && cfg.Source.Mode == "project" && isequal(cfg.Export.Formats, ["png" "svg"]) ...
    && isequal(cfg.Defaults.Selection.pairingFlags, "ok") && isempty(cfg.Defaults.Window.stop) && EphysAnalysisConfig.Version == 2 ...
    && s0.version == 2 && ~isfield(s0, 'Plots') && ~isfield(s0, 'SessionPlots') && ~isprop(cfg, 'Plots') && ~isprop(cfg, 'SessionPlots'), ...
    'defaults: version 2, no Plots or SessionPlots');
f = fullfile(root, 'defaults.json');
cfg.save(f);
c2 = EphysAnalysisConfig.load(f);
check(cfg.isequalConfig(c2) && c2.File == string(f) && isempty(c2.LoadWarnings) && contains(fileread(f), '"version": 2'), ...
    'defaults survive save / load exactly; the file says version 2');

cfg.Name = "AM quick look";
cfg.Source.Root = root;
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.EventRef.timeRange = [0 Inf];
cfg.Defaults.EventRef.maxDurationSec = Inf;
cfg.Defaults.Selection.groupBy = "Depth";
cfg.Defaults.Selection.response = "Hit";
cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', struct('line', "Stim", 'edge', "offset"));
[cfg, id1] = cfg.addFigure("rasterPsth");
[cfg, id2] = cfg.addFigure("continuous");
cfg.Figures(2).observe.channels = [1 3];
cfg.Figures(2).window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.5);
[cfg, id3] = cfg.addFigure("rate", Id="rate_platform");
cfg.Figures(3).ref = struct('line', "Platform", 'scope', "trial");
cfg.Figures(3).window = struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Platform", 'edge', "offset"));
cfg.Figures(3).selection = struct('filter', "Hit | Miss", 'groupBy', ["Depth" "TrialType"]);
[cfg, id4] = cfg.addFigure("probemap");
cfg.Figures(4).enabled = false;
check(isequal([id1 id2 id3 id4], ["figure_1" "figure_2" "rate_platform" "figure_3"]) && numel(cfg.Figures) == 4, ...
    'addFigure assigns "figure_<n>" ids and keeps a given one');
f = fullfile(root, 'full.json');
cfg.save(f);
txt = fileread(f);
c2 = EphysAnalysisConfig.load(f);
check(cfg.isequalConfig(c2) && isempty(c2.LoadWarnings), 'a full config survives save / load exactly');
check(contains(txt, '"maxDurationSec": "Inf"') && contains(txt, '"schema": "ephys-analysis-config"') && contains(txt, '"ref": "default"') ...
    && ~contains(txt, '"Plots"') && ~contains(txt, '"SessionPlots"'), ...
    'Inf is written as "Inf", "default" sentinels as text; no Plots or SessionPlots');
check(isequal(c2.Figures(3).selection.groupBy, ["Depth" "TrialType"]) && isequal(c2.Defaults.Selection.groupBy, "Depth") ...
    && isstring(c2.Defaults.Selection.response) && isequal(c2.Figures(2).observe.channels, [1 3]) ...
    && isequal(c2.Defaults.EventRef.timeRange, [0 Inf]), 'lists of one and two, numbers and Inf come back with their shapes');
check(isequal(c2.Figures(1).ref, "default") && isstruct(c2.Figures(3).ref) && c2.Figures(3).ref.line == "Platform" ...
    && isstruct(c2.Figures(3).window.stop) && c2.Figures(3).window.stop.edge == "offset" && isempty(c2.Figures(2).window.stop), ...
    '"default", overrides and stop events round-trip');
check(isequal(cfg.enabledFigures(), ["figure_1" "figure_2" "rate_platform"]) && isempty(cfg.enabledSessionFigures()), ...
    'enabledFigures skips the disabled probe map');
s = cfg.figureFor("figure_1");
check(isequal(s.ref, cfg.Defaults.EventRef) && isequal(s.window, cfg.Defaults.Window) && isequal(s.selection, cfg.Defaults.Selection), ...
    'figureFor fills "default" from Defaults');

fprintf('\n== 2. figure ids ==\n');
check(strcmp(errorId(@() setFigures(cfg, [cfg.Figures(1) cfg.Figures(1)])), 'EphysAnalysisConfig:DuplicateFigureId'), ...
    'two figures with one id: DuplicateFigureId');
c4 = cfg;
c4.Figures = {struct('title', "a"), struct('id', "figure_1"), struct('title', "c")};
check(isequal([c4.Figures.id], ["figure_2" "figure_1" "figure_3"]), 'a cell of partial figures (jsondecode) gets free ids');
c4.Figures = [];
check(isempty(c4.Figures) && isstruct(c4.Figures), 'Figures = [] empties them');
check(numel(cfg.removeFigure("figure_2").Figures) == 3 && strcmp(errorId(@() cfg.removeFigure("nope")), 'EphysAnalysisConfig:NoFigure'), ...
    'removeFigure (NoFigure for an unknown id)');

fprintf('\n== 3. validate ==\n');
good = cfg;
I = good.validate(CheckPaths=true);
check(~any(I.Severity == "error"), 'the full config validates (no errors)');
bad = cfg; bad.Source.Root = fullfile(root, 'missing');
check(any(bad.validate().Field == "Root"), 'a missing root is an error (CheckPaths)');
bad = cfg; bad.Source.Mode = "folders";
check(hasIssue(bad, "Folders", "error"), 'folders mode without folders');
bad = cfg; bad.Source.Selection = "list";
check(hasIssue(bad, "Datasets", "warning"), 'a list selection without datasets warns');
bad = cfg; bad.Defaults.Window.pre = 1; bad.Defaults.Window.post = 0;
check(hasIssue(bad, "Window", "error"), 'pre <= post');
bad = cfg; bad.Defaults.Selection.filter = "Depth >";
check(hasIssue(bad, "filter", "warning"), 'a filter that does not parse is a warning');
bad = cfg; bad.Export.Formats = ["png" "tiff"];
check(hasIssue(bad, "Formats", "error"), 'formats are png / eps / svg / pdf');
bad = cfg; bad.Report.Format = "docx";
check(hasIssue(bad, "Format", "error"), 'report format html / pdf / both');
bad = cfg; bad.Export.FilenamePattern = "{Name}_{Nope}";
check(hasIssue(bad, "FilenamePattern", "error"), 'an unknown file-name token');
bad = cfg; bad.Report.Folder = "{Plot}";
check(hasIssue(bad, "Report", "error") || hasIssue(bad, "Folder", "error"), 'an unknown folder token');
bad = cfg; bad.Figures(1).style.HeatColormap = "notacolormap";
check(hasIssue(bad, "HeatColormap", "warning"), 'an unknown colormap warns');
% nothing enabled: figures and session figures count, nothing else
nf = EphysAnalysisConfig();
nf2 = nf.addFigure("rasterPsth");
nf3 = nf2; nf3.Figures(1).enabled = false;
nf4 = nf2; nf4.Figures(1).sessions.enabled = true;
isNone = @(c) any(c.validate(CheckPaths=false).Section == "Figures" & c.validate(CheckPaths=false).Field == "enabled" ...
    & c.validate(CheckPaths=false).Severity == "error" & c.validate(CheckPaths=false).Message == "No figure is enabled.");
check(isNone(nf) && ~isNone(nf2) && isNone(nf3) && ~isNone(nf4), ...
    'nothing enabled: "No figure is enabled." (Figures.enabled); an enabled figure, or session figure, is enough');
bad = cfg.addFigure("rasterPsth", Id="FIGURE_1");
bad2 = cfg.addFigure("rasterPsth", Id="figure 1");
check(hasIssue(bad, "FIGURE_1.id", "error") && hasIssue(bad2, "figure 1.id", "error") && ~hasIssue(cfg, ".id", "error"), ...
    'figure ids that {Plot} or a case-blind file system would merge ("figure 1", "FIGURE_1" vs "figure_1") are errors');
bad = cfg.addFigure("rasterPsth", Id="a/b");
check(hasIssue(bad, "a/b.id", "error"), 'a figure id names its files: no \ / : * ? " < > |');
bad = cfg; bad.Export.FilenamePattern = "{Name}_{Unit}";
ok = cfg; ok.Export.FilenamePattern = "{Name}_{Kind}_{Plot}";
one = cfg; one.Figures = one.Figures(1); one.Export.FilenamePattern = "{Name}_{Unit}";
check(exportIssue(bad, "FilenamePattern") && ~exportIssue(ok, "FilenamePattern") && ~exportIssue(cfg, "FilenamePattern") ...
    && ~exportIssue(one, "FilenamePattern"), ...
    'a file-name pattern without {Plot} warns when two enabled figures would share names ({Kind} is "figure" for each); one figure alone does not');
bad = cfg; bad.Export.Folder = fullfile(root, "figs"); bad.Export.FilenamePattern = "{Plot}";
ok = bad; ok.Source.Mode = "folders"; ok.Source.Folders = string(root);
check(exportIssue(bad, "Folder") && ~exportIssue(ok, "Folder") && ~exportIssue(cfg, "Folder"), ...
    'an export folder and pattern that name no dataset warn, unless there is one dataset folder');
bad = cfg; bad.Export.SessionsFolder = "{Bogus}";
check(hasIssue(bad, "SessionsFolder", "error"), 'Export.SessionsFolder: a folder pattern');
bad.Export.SessionsFolder = "{OutputFolder}";
I = bad.validate(CheckPaths=false);
check(any(I.Field == "SessionsFolder" & I.Severity == "warning" & contains(I.Message, "session figures")), ...
    'Export.SessionsFolder with {OutputFolder}: the first dataset''s folder (a warning naming the session figures)');
bad = cfg; bad.Export.Data.Folder = "{Plot}";
check(hasIssue(bad, "Data.Folder", "error"), 'Export.Data.Folder: a folder pattern');
bad = cfg; bad.Export.Data.FilenamePattern = "{OutputRoot}";
check(hasIssue(bad, "Data.FilenamePattern", "error"), 'Export.Data.FilenamePattern: a file pattern');
bad = cfg; bad.Export.Data.MatVersion = "-v6";
check(hasIssue(bad, "Data.MatVersion", "error"), 'Export.Data.MatVersion: -v7.3 or -v7');
d = EphysAnalysisConfig.defaults("Export");
check(d.SessionsFolder == "{OutputRoot}" + filesep + "analysis" + filesep + "sessions" ...
    && isequal(d.Data, struct('Enabled', false, 'Folder', "{OutputRoot}" + filesep + "analysis" + filesep + "data", ...
    'FilenamePattern', "{Name}_{Plot}", 'MatVersion', "-v7.3")), ...
    'Export.SessionsFolder and Export.Data (off, -v7.3): the session figures'' files and data');

fprintf('\n== 4. the units.response test on a figure''s units ==\n');
ur = cfg;
ur.Figures(1).observe.units.response.enabled = true;
ur.Figures(1).observe.units.response.test = "auroc";
ok = ur;
ur.Figures(1).observe.units.response.auroc.cutoff = "none";
check(~hasIssue(ok, "figure_1.observe.units.response", "error") && hasIssue(ur, "figure_1.observe.units.response.auroc.cutoff", "error"), ...
    'observe.units.response: the auROC test validates with its defaults and needs a cutoff');
r0 = "figure_1.observe.units.response";
mods = {
    "test",       @(c) setResp(c, 'test', "chi2"),            r0 + ".test"
    "param",      @(c) setResp(c, 'test', "tuning"),          r0 + ".param"
    "window",     @(c) setResp(c, 'window', [0.2 0.1]),       r0 + ".window"
    "baseline",   @(c) setResp(c, 'baseline', [0 NaN]),       r0 + ".baseline"
    "direction",  @(c) setResp(c, 'direction', "up"),         r0 + ".direction"
    "correction", @(c) setResp(c, 'correction', "fdr"),       r0 + ".correction"
    "alpha",      @(c) setResp(c, 'alpha', 0),                r0 + ".alpha"
    };
for m = 1:size(mods, 1)
    I = mods{m, 2}(cfg).validate(CheckPaths=false);
    hit = I(I.Field == mods{m, 3}, :);
    check(height(hit) == 1 && hit.Section == "Figures" && hit.Severity == "error", "observe.units.response: " + mods{m, 1} + " -> an error at " + mods{m, 3});
end
I = setResp(cfg, 'test', "chi2").validate(CheckPaths=false);
check(any(I.Message == "The response test is evoked, tuning, either, both or auroc."), 'the messages are the plots'' former ones');
off = cfg; off.Figures(1).observe.units.response.test = "chi2";   % not enabled: not checked
check(~hasIssue(off, ".response", "error"), 'a response test that is off is not checked');
ly = cfg;
ly.Figures(1).panels(2).layers(1).units.response.enabled = true;
ly.Figures(1).panels(2).layers(1).units.response.direction = "up";
lsig = cfg;   % a signal layer's units are not read: its response test is not checked
lsig.Figures(2).panels(1).layers(1).units.response.enabled = true;
lsig.Figures(2).panels(1).layers(1).units.response.direction = "up";
check(hasIssue(ly, "figure_1.psth_1.layers(1).units.response.direction", "error") && ~hasIssue(lsig, ".response", "error"), ...
    'each spike layer''s units.response is checked at "<figure>.<panel>.layers(<j>).units.response.<field>"; a signal layer''s is not');
nu = cfg;   % a figure observing channels or the dataset reads no units: its observe.units.response is not checked
nu.Figures(2).observe.units.response.enabled = true;
nu.Figures(2).observe.units.response.test = "chi2";
nu.Figures(4).observe.units.response.enabled = true;
nu.Figures(4).observe.units.response.direction = "up";
check(EphysAnalysisConfig.observeKind(nu.Figures(2)) == "channel" && EphysAnalysisConfig.observeKind(nu.Figures(4)) ~= "unit" ...
    && ~hasIssue(nu, ".observe.units.response", "error") && hasIssue(setResp(cfg, 'test', "chi2"), r0 + ".test", "error"), ...
    'observe.units.response is checked only on a figure observing units (not on a channel or dataset figure)');

fprintf('\n== 5. event sequences, a figure''s ref and an events layer round-trip ==\n');
cs = cfg;
cs.Figures(1).ref = struct('line', "Trial", 'edge', "offset", 'sequence', struct('line', "Trough"));
cs.Defaults.EventRef.sequence = {struct('line', "Trough", 'maxGapSec', 2), ...
    struct('relation', "notFollowedBy", 'line', "Platform", 'edge', "offset")};
cs.Defaults.EventRef.alignStep = 1;
cs.Defaults.Window.stop = struct('line', "RespWindow", 'edge', "offset", 'sequence', struct('line', "Trough", 'n', 2));
ev = EphysAnalysisConfig.defaults("Layer");
ev.source = "events"; ev.binding = "fixed";
ev.event.line = "Trial"; ev.event.edge = "offset";
ev.event.sequence = EphysAnalysisConfig.normalizeSection("SequenceStep", struct('line', "Trough"));
cs.Figures(1).panels(1).layers(end+1) = ev;
f = fullfile(root, 'sequences.json');
cs.save(f);
c6 = EphysAnalysisConfig.load(f);
d = c6.Defaults.EventRef;
pr = c6.Figures(1).ref;
L2 = c6.Figures(1).panels(1).layers(2);
check(cs.isequalConfig(c6) && numel(d.sequence) == 2 && d.sequence(1).maxGapSec == 2 && d.sequence(1).relation == "followedBy" ...
    && d.sequence(2).relation == "notFollowedBy" && isinf(d.sequence(2).maxGapSec) && d.alignStep == 1 ...
    && pr.sequence.line == "Trough" && pr.sequence.edge == "onset" && pr.sequence.n == 1 && isinf(pr.alignStep) ...
    && c6.Defaults.Window.stop.sequence.n == 2 && L2.source == "events" && L2.event.sequence.line == "Trough", ...
    'event sequences round-trip: the default event''s two steps (a cell in), alignStep, a figure''s, the stop''s and an events layer''s');
check(~any(cs.validate(CheckPaths=false).Severity == "error"), 'that config validates');
bad = cs; bad.Defaults.EventRef.sequence(1).relation = "before";
check(hasIssue(bad, "EventRef", "error"), 'a step relation other than followedBy / notFollowedBy');
bad = cs; bad.Defaults.EventRef.alignStep = 2;
check(hasIssue(bad, "EventRef", "error"), 'alignStep on a notFollowedBy step');
bad = cs; bad.Figures(1).panels(1).layers(2).event.sequence(1).line = "";
check(hasIssue(bad, "figure_1.raster_1.layers(2).event", "error"), 'an events layer''s sequence step without a line');
s = cs.toStruct();
s.Defaults.EventRef.sequence(1).bogus = 1;
writeJsonFile(f, s, NonFinite="string");
c7 = loadQuiet(f);
check(any(contains(c7.LoadWarnings, "sequence(1).bogus")), 'an unknown step field is dropped and listed');

fprintf('\n== 6. session figures: validate''s rules ==\n');
mf = fullfile(root, 'map.csv');
writelines(["cell,SYNTH-01/a"; "cellA,3"], mf);
sfc = EphysAnalysisConfig();
sfc.Defaults.EventRef.line = "Stim";
sfc = sfc.addFigure("rasterPsth", Id="sf");
sfc.Figures(1).sessions.enabled = true;
I = sfc.validate(CheckPaths=false);
check(~any(I.Section == "Figures" & contains(I.Field, ".sessions")) && ~any(I.Section == "Figures" & I.Severity == "error") ...
    && ~any(I.Field == "enabled" & I.Severity == "error") && isequal(sfc.enabledSessionFigures(), "sf") ...
    && isempty(sfc.enabledFigures()), 'a session figure with the default sessions block raises no issue; it counts as something to run');
mods = {
    "datasets",       @(c) setSf(c, 'datasets', "some"),           "sf.sessions.datasets",     "error"
    "facet",          @(c) setSf(c, 'facet', "day"),               "sf.sessions.facet",        "error"
    "series",         @(c) setSf(c, 'series', "unit"),             "sf.sessions.series",       "error"
    "colorOrder",     @(c) setSf(c, 'colorOrder', "rainbow"),      "sf.sessions.colorOrder",   "error"
    "error",          @(c) setSf(c, 'error', "iqr"),               "sf.sessions.error",        "error"
    "match pool",     @(c) setSf(c, 'match', "pool"),              "sf.sessions.match",        "error"
    "trialGroups",    @(c) setSf(c, 'trialGroups', "split"),       "sf.sessions.trialGroups",  "error"
    "minSessions",    @(c) setSf(c, 'minSessions', 0),             "sf.sessions.minSessions",  "error"
    "list, no keys",  @(c) setSf(c, 'datasets', "list"),           "sf.sessions.datasetKeys",  "warning"
    "showMembers",    @(c) setSf(c, 'showMembers', true),          "sf.sessions.showMembers",  "warning"
    "mapping, no file", @(c) setSf(c, 'match', "mapping"),         "sf.sessions.mappingFile",  "error"
    "pool with groups", @(c) setSel(c, "TrialType"),             "sf.sessions.trialGroups",  "warning"
    };
for m = 1:size(mods, 1)
    check(hasIssue(mods{m, 2}(sfc), mods{m, 3}, mods{m, 4}), "validate session figures: " + mods{m, 1} + " -> " + mods{m, 4} + " on " + mods{m, 3});
end
bad = setSf(sfc, 'trialGroups', "combine");
bad.Figures(1).panels(2).options.histStyle = "bar";
check(hasIssue(bad, "sf.psth_1.histStyle", "warning"), 'trialGroups "combine" with a PSTH drawn as bars: a warning');
bad = sfc.addFigure("probemap", Id="pm");
bad.Figures(2).sessions.enabled = true;
check(hasIssue(bad, "pm.probemap_1.type", "error") && ~hasIssue(setFigEnabled(bad, 2, false), "pm.probemap_1.type", "error"), ...
    'a session figure cannot hold a probe map (an error); the same figure per dataset can');
bad = sfc;
bad.Figures(1).panels(2).options.baseline = struct('Mode', "auroc", 'Window', [-0.2 0]);
check(hasIssue(bad, "sf.psth_1.baseline.Mode", "error"), 'a session figure cannot hold an auROC baseline');
bad = sfc.addFigure("continuous", Id="ch");
bad.Figures(2).sessions.enabled = true;
bad.Figures(2).sessions.match = "mapping";
bad.Figures(2).sessions.mappingFile = mf;
check(hasIssue(bad, "ch.sessions.match", "error") && ~hasIssue(setSf(sfc, 'mappingFile', mf), "sf.sessions", "error"), ...
    'match "mapping" needs a unit observation; a channel figure gets an error');
bad = setSf(setSf(sfc, 'match', "mapping"), 'mappingFile', fullfile(root, 'nomap.csv'));
I = bad.validate(CheckPaths=true);
check(any(I.Field == "sf.sessions.mappingFile" & I.Severity == "error"), 'a session figure''s mapping file that does not exist: an error with CheckPaths');
mfn = fullfile(root, 'map_nocell.csv');
writelines(["unit,SYNTH-01/a"; "u1,3"], mfn);
check(hasIssue(setSf(setSf(sfc, 'match', "mapping"), 'mappingFile', mfn), "sf.sessions.mappingFile", "error"), ...
    'a mapping file without a cell column: an error');
bad = setSf(setSf(sfc, 'match', "mapping"), 'mappingFile', mf);
bad.Figures(1).sessions.datasets = "list";
bad.Figures(1).sessions.datasetKeys = ["SYNTH-01/a" "SYNTH-01/b"];
I = bad.validate(CheckPaths=false);
check(~any(I.Field == "sf.sessions.mappingFile" & I.Severity == "error") && any(I.Field == "sf.sessions.mappingFile" & I.Severity == "warning" ...
    & contains(I.Message, "SYNTH-01/b")), 'a session figure''s mapping file lacking a listed key''s column: a warning');
pg = sfc; pg.Figures(1).observe.perGroup = true;
check(~hasIssue(pg, "sf.observe.perGroup", "warning") && hasIssue(setSf(pg, 'enabled', false), "sf.observe.perGroup", "warning"), ...
    'perGroup without a groupBy warns on a per-dataset figure only (a session figure ignores perGroup)');
off = setSf(sfc, 'enabled', false); off = setSf(off, 'facet', "day");
check(hasIssue(off, "sf.sessions.facet", "error") && ~hasIssue(setSf(setSf(sfc, 'enabled', false), 'showMembers', true), "sf.sessions.showMembers", "warning"), ...
    'the sessions block''s values are checked on every figure; the session rules only on a session figure');
two = sfc.addFigure("rasterPsth", Id="SF");
check(hasIssue(two, "SF.id", "error"), 'two (session) figure ids that name the same files (case-blind) are an error');

fprintf('\n== 7. load warnings and schema ==\n');
s = cfg.toStruct();
s.Export.Nope = 1;
s.extra = 2;
s.Figures(1).bogus = 3;
f = fullfile(root, 'extra.json');
writeJsonFile(f, s, NonFinite="string");
c5 = loadQuiet(f);
check(numel(c5.LoadWarnings) == 3 && any(contains(c5.LoadWarnings, "Export.Nope")) && any(contains(c5.LoadWarnings, "extra")) ...
    && any(contains(c5.LoadWarnings, "Figures(1).bogus")) && c5.isequalConfig(cfg), 'unknown fields are dropped and listed in LoadWarnings');
s = cfg.toStruct();
s.Plots = struct('kind', "psth", 'id', "psth_1");
s.SessionPlots = struct('plot', "psth_1");
f = fullfile(root, 'v2_with_plots.json');
writeJsonFile(f, s, NonFinite="string");
c9 = loadQuiet(f);
check(c9.isequalConfig(cfg) && isscalar(c9.LoadWarnings) && contains(c9.LoadWarnings, "dropped unknown top-level field(s)") ...
    && contains(c9.LoadWarnings, "Plots") && contains(c9.LoadWarnings, "SessionPlots") && numel(c9.Figures) == numel(cfg.Figures), ...
    'a version-2 file holding Plots / SessionPlots: unknown top-level fields, dropped and listed (nothing migrated)');
writeJsonFile(fullfile(root, 'pipe.json'), struct('schema', "ephys-pipeline-config", 'version', 1));
writeJsonFile(fullfile(root, 'v3.json'), struct('schema', "ephys-analysis-config", 'version', 3));
writeJsonFile(fullfile(root, 'v0.json'), struct('schema', "ephys-analysis-config", 'version', 0));
writeJsonFile(fullfile(root, 'nov.json'), struct('schema', "ephys-analysis-config"));
check(strcmp(errorId(@() EphysAnalysisConfig.load(fullfile(root, 'pipe.json'))), 'EphysAnalysisConfig:BadSchema') ...
    && strcmp(errorId(@() EphysAnalysisConfig.load(fullfile(root, 'v3.json'))), 'EphysAnalysisConfig:BadSchema') ...
    && strcmp(errorId(@() EphysAnalysisConfig.load(fullfile(root, 'v0.json'))), 'EphysAnalysisConfig:BadSchema') ...
    && strcmp(errorId(@() EphysAnalysisConfig.load(fullfile(root, 'nov.json'))), 'EphysAnalysisConfig:BadSchema'), ...
    'a pipeline config, version 3 (or 0), or no version: BadSchema');
check(strcmp(errorId(@() setSection(cfg, "Export", struct('Dpi', "lots"))), 'EphysAnalysisConfig:BadValue'), ...
    'text where a number belongs: BadValue');

fprintf('\n== 8. a version-1 file is migrated on load ==\n');
v1 = struct('schema', "ephys-analysis-config", 'version', 1, 'name', "old", 'description', "", ...
    'Source', struct('Root', root), 'Defaults', struct('EventRef', struct('line', "Stim")));
v1.Plots = {struct('kind', "psth", 'id', "psth_1", 'style', struct('MaxTiles', 9)), ...
    struct('kind', "evoked", 'id', "lfp", 'source', "LFP", 'layout', "grid", 'channels', [1 2]), ...
    struct('kind', "behavior", 'id', "beh", 'source', "trials", 'param', "Depth", 'yParam', "RespLatency"), ...
    struct('kind', "probemap", 'enabled', false)};
v1.Figures = struct('id', "card", 'panels', {{struct('type', "raster")}});
v1.SessionPlots = {struct('id', "psth_days", 'plot', "psth_1", 'series', "all", 'trialGroups', "each"), ...
    struct('id', "beh_days", 'plot', "beh")};
f = fullfile(root, 'v1.json');
writeJsonFile(f, v1, NonFinite="string");
lastwarn('');
ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
cm = EphysAnalysisConfig.load(f);
warning(ws);
W = cm.LoadWarnings;
check(isequal(cm.figureIds(), ["psth_1" "lfp" "probemap_1" "card" "psth_days"]) && cm.Name == "old" ...
    && ~cm.Figures(3).enabled && cm.Figures(4).panels(1).type == "raster", ...
    'the plots become figures of the same ids (an id-less one its version-1 free id), first; the file''s own figure next; then the session plot');
check(isequal(cm.enabledFigures(), ["psth_1" "lfp" "card"]) && isequal(cm.enabledSessionFigures(), "psth_days") ...
    && cm.Figures(5).sessions.enabled && cm.Figures(5).sessions.series == "all" && cm.Figures(5).sessions.trialGroups == "each" ...
    && cm.Figures(5).sessions.match == "site" && isequal([cm.Figures(5).panels.type], [cm.Figures(1).panels.type]), ...
    'the session plot is a session figure: its base plot''s panels, the sessions block from its fields (match "pool" became "site")');
check(startsWith(W(1), "config version 1: 3 of 4 plot(s) and 1 of 2 session plot(s) migrated to figures") ...
    && any(startsWith(W, "plot psth_1 migrated to figure psth_1: ") & contains(W, "MaxTiles 9")) ...
    && any(startsWith(W, "plot beh not migrated: ") & contains(W, "behavior")) ...
    && any(startsWith(W, "session plot psth_days migrated to session figure psth_days: ") & contains(W, "became ""site""")) ...
    && any(startsWith(W, "session plot beh_days not migrated: ")), ...
    'every converter note is a LoadWarning "plot <id> migrated to figure <id>: ..."; what cannot be migrated says so');
check(~any(cm.validate(CheckPaths=false).Severity == "error" & cm.validate(CheckPaths=false).Section == "Figures"), ...
    'the migrated figures validate');
f2 = fullfile(root, 'v1_saved.json');
cm.save(f2);
t2 = fileread(f2);
c10 = EphysAnalysisConfig.load(f2);
check(contains(t2, '"version": 2') && ~contains(t2, '"Plots"') && ~contains(t2, '"SessionPlots"') && isempty(c10.LoadWarnings) ...
    && c10.isequalConfig(cm), 'save writes version 2 with no Plots or SessionPlots; it loads again without a warning');
c11 = EphysAnalysisConfig.fromStruct(v1);
check(c11.isequalConfig(cm) && isequal(c11.LoadWarnings, W), 'fromStruct migrates a version-1 struct the same way');
lastwarn('');
cw = EphysAnalysisConfig.load(f); %#ok<NASGU>
[msgW, wid] = lastwarn();
check(string(wid) == "EphysAnalysisConfig:LoadWarnings" && contains(msgW, "migrated to figure"), ...
    'load raises EphysAnalysisConfig:LoadWarnings with the migration''s notes');

fprintf('\n== 9. figureFileName ==\n');
n = figureFileName("{Name}_{Plot}_{Index}", struct('Name', "SYNTH 01/a", 'Plot', "psth_stim", 'Index', 2));
check(n == "SYNTH_01_a_psth_stim_2", 'token values are sanitized');
n = figureFileName("{OutputFolder}" + filesep + "analysis", struct('OutputFolder', "D:\out\x"), Kind="folder");
check(n == "D:\out\x" + filesep + "analysis", 'folder tokens keep their paths');
check(strcmp(errorId(@() figureFileName("{Name}_{Bogus}", struct('Name', "a"))), 'figureFileName:UnknownToken') ...
    && strcmp(errorId(@() figureFileName("{Name}_{Plot}", struct('Name', "a"))), 'figureFileName:MissingToken') ...
    && strcmp(errorId(@() figureFileName("{Name", struct('Name', "a"))), 'figureFileName:BadPattern'), ...
    'unknown and missing tokens, unmatched braces');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisConfig:Failures', '%d checks failed.', nFail);
end
end


function cfg = setFigures(cfg, f)
cfg.Figures = f;
end


function cfg = setSection(cfg, name, s)
cfg.(name) = s;
end


function cfg = setResp(cfg, field, value)
cfg.Figures(1).observe.units.response.enabled = true;
cfg.Figures(1).observe.units.response.(field) = value;
end


function cfg = setSf(cfg, field, value)
cfg.Figures(1).sessions.(field) = value;
end


function cfg = setSel(cfg, groupBy)
cfg.Figures(1).selection = EphysAnalysisConfig.defaults("TrialSelection");
cfg.Figures(1).selection.groupBy = groupBy;
end


function cfg = setFigEnabled(cfg, k, tf)
cfg.Figures(k).sessions.enabled = tf;
end
