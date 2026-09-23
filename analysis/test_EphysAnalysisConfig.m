function test_EphysAnalysisConfig()
%test_EphysAnalysisConfig  Verification suite for the analysis config.
%   Defaults, JSON save / load round trips (Inf, NaN, empty lists, one-item
%   lists, "default" sentinels, a heterogeneous Plots array), plotFor's
%   merge of the Defaults, plot ids (auto ids, DuplicatePlotId), every
%   validate rule (ids and patterns whose files would collide too),
%   LoadWarnings, BadSchema, figureFileName and plotFileName's page suffix.
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

fprintf('\n== 1. defaults and a JSON round trip ==\n');
cfg = EphysAnalysisConfig();
check(cfg.Name == "Untitled" && isempty(cfg.Plots) && cfg.Source.Mode == "project" && isequal(cfg.Export.Formats, ["png" "svg"]) ...
    && isequal(cfg.Defaults.Selection.pairingFlags, "ok") && isempty(cfg.Defaults.Window.stop), 'defaults');
f = fullfile(root, 'defaults.json');
cfg.save(f);
c2 = EphysAnalysisConfig.load(f);
check(cfg.isequalConfig(c2) && c2.File == string(f) && isempty(c2.LoadWarnings), 'defaults survive save / load exactly');

cfg.Name = "AM quick look";
cfg.Source.Root = root;
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.EventRef.timeRange = [0 Inf];
cfg.Defaults.EventRef.maxDurationSec = Inf;
cfg.Defaults.Selection.groupBy = "Depth";
cfg.Defaults.Selection.response = "Hit";
cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', struct('line', "Stim", 'edge', "offset"));
[cfg, id1] = cfg.addPlot("psth");
[cfg, id2] = cfg.addPlot(struct('kind', "evoked", 'source', "LFP", 'channels', [1 3], ...
    'window', struct('mode', "fixed", 'pre', -0.1, 'post', 0.5), 'baseline', struct('Mode', "subtract", 'Window', [-0.1 0])));
[cfg, id3] = cfg.addPlot(struct('kind', "rate", 'ref', struct('line', "Platform", 'scope', "trial"), ...
    'window', struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Platform", 'edge', "offset")), ...
    'selection', struct('filter', "Hit | Miss", 'groupBy', ["Depth" "TrialType"])), Id="rate_platform");
[cfg, id4] = cfg.addPlot(struct('kind', "tuning", 'param', "Depth", 'units', struct('classes', "su", 'maxUnits', 5)));
[cfg, id5] = cfg.addPlot(struct('kind', "probemap", 'source', "detected", 'value', "nSpikes", 'enabled', false));
check(isequal([id1 id2 id3 id4 id5], ["psth_1" "evoked_1" "rate_platform" "tuning_1" "probemap_1"]) && numel(cfg.Plots) == 5, ...
    'addPlot assigns "<kind>_<n>" ids and keeps a given one');
f = fullfile(root, 'full.json');
cfg.save(f);
txt = fileread(f);
c2 = EphysAnalysisConfig.load(f);
check(cfg.isequalConfig(c2), 'a full config survives save / load exactly');
check(contains(txt, '"maxDurationSec": "Inf"') && contains(txt, '"schema": "ephys-analysis-config"') && contains(txt, '"ref": "default"'), ...
    'Inf is written as "Inf", and "default" sentinels as text');
check(isequal(c2.Plots(3).selection.groupBy, ["Depth" "TrialType"]) && isequal(c2.Defaults.Selection.groupBy, "Depth") ...
    && isstring(c2.Defaults.Selection.response) && isequal(c2.Plots(4).units.classes, "su") && c2.Plots(4).units.maxUnits == 5 ...
    && isequal(c2.Plots(2).channels, [1 3]) && isequal(c2.Defaults.EventRef.timeRange, [0 Inf]), ...
    'lists of one and two, numbers and Inf come back with their shapes');
check(isequal(c2.Plots(1).ref, "default") && isstruct(c2.Plots(3).ref) && c2.Plots(3).ref.line == "Platform" ...
    && isstruct(c2.Plots(3).window.stop) && c2.Plots(3).window.stop.edge == "offset" && isempty(c2.Plots(2).window.stop), ...
    '"default", overrides and stop events round-trip');
check(isequal(cfg.enabledPlots(), ["psth_1" "evoked_1" "rate_platform" "tuning_1"]), 'enabledPlots skips the disabled probe map');

fprintf('\n== 2. plotFor ==\n');
s = cfg.plotFor("psth_1");
check(isequal(s.ref, cfg.Defaults.EventRef) && isequal(s.window, cfg.Defaults.Window) && isequal(s.selection, cfg.Defaults.Selection) ...
    && s.units.source == "units" && s.layout == "grid", 'plotFor fills "default" from Defaults, the unit source and the layout');
s = cfg.plotFor("rate_platform");
check(s.ref.line == "Platform" && s.ref.edge == "onset" && s.window.mode == "between" && s.selection.filter == "Hit | Miss" ...
    && isequal(s.selection.pairingFlags, "ok") && s.layout == "bar", 'plot overrides are complete structs');
s = cfg.plotFor(2);
check(s.id == "evoked_1" && s.layout == "stack", 'plotFor takes an index too');
check(strcmp(errorId(@() cfg.plotFor("nope")), 'EphysAnalysisConfig:NoPlot'), 'an unknown id: EphysAnalysisConfig:NoPlot');
c3 = cfg.removePlot("tuning_1");
check(numel(c3.Plots) == 4 && c3.plotIndex("tuning_1") == 0 && c3.plotIndex("probemap_1") == 4, 'removePlot');

fprintf('\n== 3. plot ids ==\n');
check(strcmp(errorId(@() setPlots(cfg, [cfg.Plots(1) cfg.Plots(1)])), 'EphysAnalysisConfig:DuplicatePlotId'), ...
    'two plots with one id: DuplicatePlotId');
c4 = cfg;
c4.Plots = {struct('kind', "raster"), struct('kind', "raster", 'id', "raster_1"), struct('kind', "raster")};
check(isequal([c4.Plots.id], ["raster_2" "raster_1" "raster_3"]), 'a cell of partial plots (jsondecode) gets free ids');
c4.Plots = [];
check(isempty(c4.Plots) && isstruct(c4.Plots), 'Plots = [] empties them');

fprintf('\n== 4. validate ==\n');
good = cfg;
I = good.validate(CheckPaths=true);
check(~any(I.Severity == "error"), 'the full config validates (no errors)');
bad = cfg; bad.Source.Root = fullfile(root, 'missing');
check(any(bad.validate().Field == "Root"), 'a missing root is an error (CheckPaths)');
bad = cfg; bad.Source.Mode = "folders";
check(hasIssue(bad, "Folders", "error"), 'folders mode without folders');
bad = cfg; bad.Source.Selection = "list";
check(hasIssue(bad, "Datasets", "warning"), 'a list selection without datasets warns');
bad = cfg; [bad.Plots.enabled] = deal(false);
check(hasIssue(bad, "enabled", "error"), 'no enabled plot');
bad = cfg; bad.Plots(1).kind = "violin";
check(hasIssue(bad, "psth_1.kind", "error"), 'an unknown kind');
bad = cfg; bad.Plots(1).source = "LFP";
check(hasIssue(bad, "psth_1.source", "error"), 'a spike kind reading a signal');
bad = cfg; bad.Plots(2).source = "units";
check(hasIssue(bad, "evoked_1.source", "error"), 'a signal kind reading units');
bad = cfg; bad.Plots(1).layout = "stack";
check(hasIssue(bad, "psth_1.layout", "error"), 'a layout the kind does not have');
bad = cfg; bad.Plots(1).window = struct('mode', "between", 'stop', struct('line', "Stim", 'edge', "offset"));
check(hasIssue(bad, "psth_1.window", "error"), '"between" is for rate, tuning and corrmap only');
bet = struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Stim", 'edge', "offset"));
ok = cfg.addPlot(struct('kind', "corrmap", 'window', bet, 'metric', "peak", 'correlation', "spearman", ...
    'baseline', struct('Mode', "subtract", 'Window', [-0.2 0])), Id="corr_ok");
check(~any(ok.validate().Severity == "error") && ok.Plots(end).style.HeatColormap == "", ...
    'a corrmap over a "between" window (peak, Spearman, baseline subtract) validates; its colours are the default');
bad = ok; bad.Plots(end).metric = "max";
check(hasIssue(bad, "corr_ok.metric", "error"), 'corrmap metric is mean or peak');
bad = ok; bad.Plots(end).correlation = "kendall";
check(hasIssue(bad, "corr_ok.correlation", "error"), 'corrmap correlation is pearson or spearman');
bad = ok; bad.Plots(end).order = "peak";
check(hasIssue(bad, "corr_ok.order", "error"), 'corrmap orders by depth or channel');
bad = ok; bad.Plots(end).baseline.Mode = "zscore";
check(hasIssue(bad, "corr_ok.baseline.Mode", "error"), 'corrmap baseline is none or subtract');
bad = ok; bad.Plots(end).bins.BinSec = 0;
check(hasIssue(bad, "corr_ok.bins.BinSec", "error"), 'a peak corrmap needs BinSec > 0');
bad.Plots(end).metric = "mean";
check(~hasIssue(bad, "corr_ok.bins.BinSec", "error"), 'a mean corrmap does not use bins');
bad = cfg; bad.Plots(3).window = struct('mode', "between");
check(hasIssue(bad, "rate_platform.window", "error"), '"between" needs a stop');
bad = cfg; bad.Plots(4).param = "";
check(hasIssue(bad, "tuning_1.param", "error"), 'tuning needs a parameter');
bad = cfg; bad.Plots(3).selection.groupBy = ["a" "b" "c"];
check(hasIssue(bad, "rate_platform.selection", "error"), 'groupBy <= 2');
bad = cfg; bad.Plots(1).bins.BinSec = 0;
check(hasIssue(bad, "psth_1.bins.BinSec", "error"), 'BinSec > 0');
bad = cfg; bad.Defaults.Window.pre = 1; bad.Defaults.Window.post = 0;
check(hasIssue(bad, "Window", "error"), 'pre <= post');
bad = cfg; bad.Plots(2).baseline.Mode = "zscore";
check(hasIssue(bad, "evoked_1.baseline.Mode", "error"), 'a baseline mode the kind does not have');
bad = cfg; bad.Plots(1).baseline = struct('Mode', "subtract", 'Window', [0 -0.1]);
check(hasIssue(bad, "psth_1.baseline.Window", "error"), 'a baseline window [b0 b1] needs b0 < b1');
bad = cfg; bad.Export.Formats = ["png" "tiff"];
check(hasIssue(bad, "Formats", "error"), 'formats are png / eps / svg / pdf');
bad = cfg; bad.Report.Format = "docx";
check(hasIssue(bad, "Format", "error"), 'report format html / pdf / both');
bad = cfg; bad.Export.FilenamePattern = "{Name}_{Nope}";
check(hasIssue(bad, "FilenamePattern", "error"), 'an unknown file-name token');
bad = cfg; bad.Report.Folder = "{Plot}";
check(hasIssue(bad, "Report", "error") || hasIssue(bad, "Folder", "error"), 'an unknown folder token');
bad = cfg; bad.Defaults.Selection.filter = "Depth >";
check(hasIssue(bad, "filter", "warning"), 'a filter that does not parse is a warning');
bad = cfg; bad.Plots(1).style.HeatColormap = "notacolormap";
check(hasIssue(bad, "HeatColormap", "warning"), 'an unknown colormap warns');
d = EphysAnalysisConfig.defaults("Plot");
check(d.fill && isnan(d.fillAlpha) && d.normalize == "none" && ~d.stack && d.stackSpacing == 1.1, ...
    'PSTH defaults: filled, automatic opacity, not normalized, not stacked, spacing 1.1');
bad = cfg; bad.Plots(1).normalize = "area";
check(hasIssue(bad, "psth_1.normalize", "error"), 'psth normalize is none, unitPeak or groupPeak');
bad = cfg; bad.Plots(1).fillAlpha = 1.5;
check(hasIssue(bad, "psth_1.fillAlpha", "error"), 'psth fillAlpha is 0-1');
bad = cfg; bad.Plots(1).stackSpacing = 0;
check(hasIssue(bad, "psth_1.stackSpacing", "error"), 'psth stackSpacing > 0');
ok = cfg; ok.Plots(1).style.Colormap = "black"; ok.Plots(2).style.Colormap = "#1f77b4"; ok.Plots(3).style.Colormap = "turbo";
check(~hasIssue(ok, "Colormap", "warning"), 'a single colour ("black", "#1f77b4") or a colormap function are group colours');
bad = cfg; bad.Plots(1).style.Colormap = "nope";
check(hasIssue(bad, "Colormap", "warning"), 'an unknown group colour warns');
bad = cfg.addPlot("raster", Id="psth 1");
bad2 = cfg.addPlot("raster", Id="PSTH_1");
check(hasIssue(bad, "psth 1.id", "error") && hasIssue(bad2, "PSTH_1.id", "error") && ~hasIssue(cfg, ".id", "error"), ...
    'plot ids that {Plot} or a case-blind file system would merge ("psth 1", "PSTH_1" vs "psth_1") are errors');
bad = cfg; bad.Export.FilenamePattern = "{Name}_{Unit}";
ok = cfg; ok.Export.FilenamePattern = "{Name}_{Kind}";
check(exportIssue(bad, "FilenamePattern") && ~exportIssue(ok, "FilenamePattern") && ~exportIssue(cfg, "FilenamePattern"), ...
    'a file-name pattern without {Plot} warns when enabled plots would share names ({Kind} is enough for plots of different kinds)');
bad = cfg; bad.Export.Folder = fullfile(root, "figs"); bad.Export.FilenamePattern = "{Plot}";
ok = bad; ok.Source.Mode = "folders"; ok.Source.Folders = string(root);
check(exportIssue(bad, "Folder") && ~exportIssue(ok, "Folder") && ~exportIssue(cfg, "Folder"), ...
    'an export folder and pattern that name no dataset warn, unless there is one dataset folder');
rt = cfg;
rt.Plots(1).stack = true; rt.Plots(1).stackSpacing = 0.8; rt.Plots(1).normalize = "groupPeak";
rt.Plots(1).fill = false; rt.Plots(1).fillAlpha = 0.3; rt.Plots(1).style.Colormap = "black";
f = fullfile(root, 'psth_look.json');
rt.save(f);
rt2 = EphysAnalysisConfig.load(f);
p1 = rt2.Plots(1);
check(rt2.isequalConfig(rt) && p1.stack && p1.stackSpacing == 0.8 && p1.normalize == "groupPeak" && ~p1.fill ...
    && p1.fillAlpha == 0.3 && p1.style.Colormap == "black" && isnan(rt2.Plots(2).fillAlpha), ...
    'stack, spacing, normalize, fill, opacity and group colours survive save / load (NaN opacity too)');

fprintf('\n== 5. load warnings and schema ==\n');
s = cfg.toStruct();
s.Export.Nope = 1;
s.extra = 2;
s.Plots(1).bogus = 3;
f = fullfile(root, 'extra.json');
writeJsonFile(f, s, NonFinite="string");
ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
c5 = EphysAnalysisConfig.load(f);
warning(ws);
check(numel(c5.LoadWarnings) == 3 && any(contains(c5.LoadWarnings, "Export.Nope")) && any(contains(c5.LoadWarnings, "extra")) ...
    && any(contains(c5.LoadWarnings, "bogus")) && c5.isequalConfig(cfg), 'unknown fields are dropped and listed in LoadWarnings');
writeJsonFile(fullfile(root, 'pipe.json'), struct('schema', "ephys-pipeline-config", 'version', 1));
writeJsonFile(fullfile(root, 'v2.json'), struct('schema', "ephys-analysis-config", 'version', 2));
check(strcmp(errorId(@() EphysAnalysisConfig.load(fullfile(root, 'pipe.json'))), 'EphysAnalysisConfig:BadSchema') ...
    && strcmp(errorId(@() EphysAnalysisConfig.load(fullfile(root, 'v2.json'))), 'EphysAnalysisConfig:BadSchema'), ...
    'a pipeline config or another version: BadSchema');
check(strcmp(errorId(@() setSection(cfg, "Export", struct('Dpi', "lots"))), 'EphysAnalysisConfig:BadValue'), ...
    'text where a number belongs: BadValue');

fprintf('\n== 6. figureFileName ==\n');
n = figureFileName("{Name}_{Plot}_{Index}", struct('Name', "SYNTH 01/a", 'Plot', "psth_stim", 'Index', 2));
check(n == "SYNTH_01_a_psth_stim_2", 'token values are sanitized');
n = figureFileName("{OutputFolder}" + filesep + "analysis", struct('OutputFolder', "D:\out\x"), Kind="folder");
check(n == "D:\out\x" + filesep + "analysis", 'folder tokens keep their paths');
check(strcmp(errorId(@() figureFileName("{Name}_{Bogus}", struct('Name', "a"))), 'figureFileName:UnknownToken') ...
    && strcmp(errorId(@() figureFileName("{Name}_{Plot}", struct('Name', "a"))), 'figureFileName:MissingToken') ...
    && strcmp(errorId(@() figureFileName("{Name", struct('Name', "a"))), 'figureFileName:BadPattern'), ...
    'unknown and missing tokens, unmatched braces');
ev = EphysAnalysisConfig.normalizePlot(struct('kind', "evoked", 'id', "lfp", 'layout', "grid"));
ch = struct('labels', "A-" + compose("%03d", (0:31).'));
check(plotFileName("{Name}_{Plot}_{Unit}", "DS1", ev, ch, 1, 2) == "DS1_lfp_all_p1" ...
    && plotFileName("{Name}_{Plot}_{Unit}", "DS1", ev, ch, 2, 2) == "DS1_lfp_all_p2", ...
    'plotFileName: a paged evoked grid, whose {Unit} is "all", still gets _p<page>');
ps = EphysAnalysisConfig.normalizePlot(struct('kind', "psth", 'id', "psth"));
un = struct('labels', "su" + compose("%03d", (1:32).'));
check(plotFileName("{Name}_{Plot}_{Unit}", "DS1", ps, un, 2, 2) == "DS1_psth_su017" ...
    && plotFileName("{Name}_{Plot}_{Index}", "DS1", ps, un, 2, 2) == "DS1_psth_2" ...
    && plotFileName("{Name}_{Plot}", "DS1", ps, un, 2, 2) == "DS1_psth_p2" && plotFileName("{Name}_{Plot}", "DS1", ps, un, 1, 1) == "DS1_psth", ...
    'plotFileName: a unit grid''s pages are told apart by {Unit} (its first unit) or {Index}, else by _p<page>');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisConfig:Failures', '%d checks failed.', nFail);
end
end


function cfg = setPlots(cfg, p)
cfg.Plots = p;
end


function cfg = setSection(cfg, name, s)
cfg.(name) = s;
end
