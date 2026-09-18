function test_EphysAnalysisConfig()
%test_EphysAnalysisConfig  Verification suite for the analysis config.
%   Defaults, JSON save / load round trips (Inf, NaN, empty lists, one-item
%   lists, "default" sentinels, a heterogeneous Plots array), plotFor's
%   merge of the Defaults, plot ids (auto ids, DuplicatePlotId), every
%   validate rule, LoadWarnings, BadSchema and figureFileName.
%
%   Usage:  test_EphysAnalysisConfig

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);

root = fullfile(tempdir, sprintf('AnaConfig_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
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
check(hasIssue(bad, "psth_1.window", "error"), '"between" is for rate and tuning only');
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
