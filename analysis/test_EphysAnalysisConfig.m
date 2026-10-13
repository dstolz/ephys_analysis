function test_EphysAnalysisConfig()
%test_EphysAnalysisConfig  Verification suite for the analysis config.
%   Defaults, JSON save / load round trips (Inf, NaN, empty lists, one-item
%   lists, "default" sentinels, a heterogeneous Plots array), plotFor's
%   merge of the Defaults, plot ids (auto ids, DuplicatePlotId), every
%   validate rule (ids and patterns whose files would collide too), the
%   behavior kind, the raster's sort (by an event's latency too: its
%   rasterSortEvent) and event marks, the mean aux signal (aux), the error
%   bands' style (ErrorType, resamples, look), events shifted by
%   a trial parameter and event sequences (fields, round trips, rules), session
%   plots (defaults, Export.SessionsFolder / Data, addSessionPlot ids,
%   DuplicateSessionPlotId, the JSON round trip, sessionPlotFor, every
%   validate rule), LoadWarnings, BadSchema, figureFileName and plotFileName's
%   page suffix.
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
    'a corrmap over a "between" window (peak, Spearman, baseline subtract) validates; its colors are the default');
bad = ok; bad.Plots(end).metric = "max";
check(hasIssue(bad, "corr_ok.metric", "error"), 'corrmap metric is mean or peak');
bad = ok; bad.Plots(end).correlation = "kendall";
check(hasIssue(bad, "corr_ok.correlation", "error"), 'corrmap correlation is pearson or spearman');
ok.Plots(end).fisherZ = true;
check(~any(ok.validate().Severity == "error") && ok.Plots(end).fisherZ, 'a corrmap with fisherZ validates');
bad = ok; bad.Plots(end).measure = "fano";
check(hasIssue(bad, "corr_ok.measure", "error"), 'the measure is rate, count or probability');
bad = ok; bad.Plots(end).style.TileSpacing = "wide";
check(hasIssue(bad, "corr_ok.style.TileSpacing", "error"), 'TileSpacing is loose, compact, tight or none');
bad = ok; bad.Plots(end).style.LegendLocation = "northeast";
check(hasIssue(bad, "corr_ok.style.LegendLocation", "error"), 'LegendLocation is auto, inside, north, south, east or west');
bad = ok; bad.Plots(end).style.LegendOrientation = "diagonal";
check(hasIssue(bad, "corr_ok.style.LegendOrientation", "error"), 'LegendOrientation is auto, vertical or horizontal');
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
check(hasIssue(bad, "psth_1.normalize", "error"), 'psth normalize is none, unitPeak, groupPeak or allPeak');
bad = cfg; bad.Plots(1).fillAlpha = 1.5;
check(hasIssue(bad, "psth_1.fillAlpha", "error"), 'psth fillAlpha is 0-1');
bad = cfg; bad.Plots(1).stackSpacing = 0;
check(hasIssue(bad, "psth_1.stackSpacing", "error"), 'psth stackSpacing > 0');
ok = cfg; ok.Plots(1).style.Colormap = "black"; ok.Plots(2).style.Colormap = "#1f77b4"; ok.Plots(3).style.Colormap = "turbo";
check(~hasIssue(ok, "Colormap", "warning"), 'a single color ("black", "#1f77b4") or a colormap function are group colors');
bad = cfg; bad.Plots(1).style.Colormap = "nope";
check(hasIssue(bad, "Colormap", "warning"), 'an unknown group color warns');
au = cfg; au.Plots(1).baseline.Mode = "auroc";
check(~hasIssue(au, "psth_1.baseline", "error") && ~hasIssue(au, "psth_1.auroc", "error") && au.Plots(1).auroc.cutoff == "ci", ...
    'a PSTH of units takes the auROC baseline, its default settings valid');
rs = cfg.addPlot("raster");
rs.Plots(end).baseline.Mode = "auroc";
check(hasIssue(rs, rs.Plots(end).id + ".baseline.Mode", "error"), 'a raster has no auROC baseline');
bad = au; bad.Plots(1).auroc.windowSec = 0.015;
check(hasIssue(bad, "psth_1.auroc.windowSec", "error"), 'the auROC window is a whole number of bins');
bad = au; bad.Plots(1).auroc.cutoff = "none"; bad.Plots(1).auroc.modulatedOnly = true;
check(hasIssue(bad, "psth_1.auroc.modulatedOnly", "error"), 'modulated units only needs a cutoff');
hm = cfg.addPlot("heatmap");
hm.Plots(end).order = "modulation";
hid = hm.Plots(end).id;
before = hasIssue(hm, hid + ".order", "error");
hm.Plots(end).baseline.Mode = "auroc";
check(before && ~hasIssue(hm, hid + ".order", "error") && ~hasIssue(hm, hid + ".baseline", "error"), ...
    'a heatmap''s modulation order needs the auROC baseline');
bad = cfg; bad.Plots(1).units.response.enabled = true; bad.Plots(1).units.response.test = "auroc";
ok = bad;
bad.Plots(1).units.response.auroc.cutoff = "none";
check(~hasIssue(ok, "psth_1.units.response", "error") && hasIssue(bad, "psth_1.units.response.auroc.cutoff", "error"), ...
    'the auROC response test validates with its defaults and needs a cutoff');
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
    'stack, spacing, normalize, fill, opacity and group colors survive save / load (NaN opacity too)');
d = EphysAnalysisConfig.defaults("Plot").waveform;
check(d.mode == "off" && d.location == "northeast" && d.box && d.scale == 1 && d.maxSpikes == 100, ...
    'unit waveforms: off by default; northeast, with its axis box, a third of the tile, 100 spikes');
wv = cfg; wv.Plots(1).waveform.mode = "both";
check(~hasIssue(wv, "psth_1.waveform", "error") && ~hasIssue(wv, "psth_1.waveform", "warning"), 'a PSTH grid of units takes the waveform boxes');
bad = wv; bad.Plots(1).waveform.mode = "spikes";
bad2 = wv; bad2.Plots(1).waveform.location = "top";
bad3 = wv; bad3.Plots(1).waveform.scale = 4;
bad4 = wv; bad4.Plots(1).waveform.maxSpikes = 2.5;
check(hasIssue(bad, "psth_1.waveform.mode", "error") && hasIssue(bad2, "psth_1.waveform.location", "error") ...
    && hasIssue(bad3, "psth_1.waveform.scale", "error") && hasIssue(bad4, "psth_1.waveform.maxSpikes", "error"), ...
    'the waveform mode, location, scale (0-3) and maxSpikes (whole) are checked');
ov = wv; ov.Plots(1).layout = "overlay";
ev = cfg; ev.Plots(2).waveform.mode = "mean";
check(hasIssue(ov, "psth_1.waveform.mode", "warning") && hasIssue(ev, "evoked_1.waveform.mode", "warning") ...
    && ~hasIssue(cfg, ".waveform", "warning"), 'waveforms on an overlay, or on a plot of signals, warn that none are drawn');
wv.Plots(1).waveform = struct('mode', "subsample", 'location', "southwest", 'box', false, 'scale', 1.5, 'maxSpikes', 40);
wv.save(f);
w2 = EphysAnalysisConfig.load(f);
check(w2.isequalConfig(wv) && isequal(w2.Plots(1).waveform, wv.Plots(1).waveform) && ~w2.Plots(1).waveform.box, ...
    'the waveform settings survive save / load');
d = EphysAnalysisConfig.defaults("Plot").aux;
check(d.mode == "off" && isempty(d.channels) && d.placement == "below" && d.baseline == "none" ...
    && isequal(d.baselineWindow, [-0.2 0]) && d.byGroup && isempty(d.yLim) && isequal(d.overPosition, [0 1]), ...
    'the mean aux signal: off by default; all channels, below, no baseline, a trace per group');
d0aux = d;
xs = cfg; xs.Plots(1).aux.mode = "magnitude";
check(~hasIssue(xs, "psth_1.aux", "error") && ~hasIssue(xs, "psth_1.aux", "warning") && ~hasIssue(cfg, ".aux", "warning"), ...
    'a PSTH of units takes the aux signal');
bad = xs; bad.Plots(1).aux.mode = "vector";
bad2 = xs; bad2.Plots(1).aux.placement = "beside";
bad3 = xs; bad3.Plots(1).aux.channels = [1 2.5];
bad4 = xs; bad4.Plots(1).aux.baseline = "zscore";
bad5 = xs; bad5.Plots(1).aux.baseline = "subtract"; bad5.Plots(1).aux.baselineWindow = [0 -0.1];
bad6 = xs; bad6.Plots(1).aux.baseline = "subtract"; bad6.Plots(1).aux.baselineWindow = [-2 -1];   % outside the [-0.2 0.8] window
ok6 = xs; ok6.Plots(1).aux.baseline = "subtract"; ok6.Plots(1).aux.baselineWindow = [-0.5 0];   % overlaps it
check(hasIssue(bad, "psth_1.aux.mode", "error") && hasIssue(bad2, "psth_1.aux.placement", "error") ...
    && hasIssue(bad3, "psth_1.aux.channels", "error") && hasIssue(bad4, "psth_1.aux.baseline", "error") ...
    && hasIssue(bad5, "psth_1.aux.baselineWindow", "error") && hasIssue(bad6, "psth_1.aux.baselineWindow", "error") ...
    && ~hasIssue(ok6, "psth_1.aux", "error"), ...
    'the aux mode, placement, channels (whole, >= 1), baseline and its window (ordered, overlapping the epoch window) are checked');
bad7 = xs; bad7.Plots(1).aux.yLim = [1 0];
bad8 = xs; bad8.Plots(1).aux.overPosition = [0.5 0.2];
bad9 = xs; bad9.Plots(1).aux.overPosition = [-0.1 1];
ok7 = xs; ok7.Plots(1).aux.yLim = [-0.05 0.05]; ok7.Plots(1).aux.overPosition = [0 0.3];
check(hasIssue(bad7, "psth_1.aux.yLim", "error") && hasIssue(bad8, "psth_1.aux.overPosition", "error") ...
    && hasIssue(bad9, "psth_1.aux.overPosition", "error") && ~hasIssue(ok7, "psth_1.aux", "error"), ...
    'the aux y limits ([] or ascending) and its span over the plot (0 <= bottom < top <= 1) are checked');
st = xs; st.Plots(1).stack = true; st.Plots(1).aux.placement = "over";
ev = cfg; ev.Plots(2).aux.mode = "channels";
check(hasIssue(st, "psth_1.aux.placement", "warning") && hasIssue(ev, "evoked_1.aux.mode", "warning"), ...
    'over a stacked PSTH warns (drawn below); an aux signal on a plot of signals warns that none is drawn');
check(d0aux.display == "lines" && d0aux.statistic == "mean" && d0aux.transform == "none" && d0aux.errorType == "sem" ...
    && d0aux.colorBy == "auto", 'the aux signal: lines, the mean as recorded, an SEM band, colored automatically by default');
for fld = ["display" "statistic" "transform" "errorType" "colorBy"]
    bx = xs; bx.Plots(1).aux.(fld) = "nope";
    check(hasIssue(bx, "psth_1.aux." + fld, "error"), 'the aux ' + fld + ' is one of its list');
end
f = fullfile(root, 'aux_signal.json');   % not aux.json: a reserved device name on Windows
hm = xs; hm.Plots(1).aux.display = "heatmap"; hm.Plots(1).aux.placement = "over";
md = xs; md.Plots(1).aux.statistic = "median"; md.Plots(1).aux.errorType = "std";
okb = xs; okb.Plots(1).aux.display = "stacked"; okb.Plots(1).aux.statistic = "median"; okb.Plots(1).aux.errorType = "iqr";
check(hasIssue(hm, "psth_1.aux.placement", "warning") && hasIssue(hm, "psth_1.aux.errorType", "warning") ...
    && hasIssue(md, "psth_1.aux.errorType", "warning") && ~hasIssue(okb, "psth_1.aux", "error") && ~hasIssue(okb, "psth_1.aux", "warning"), ...
    'a heat map warns it goes below and draws no band; SEM / SD around a median warns; the median with iqr or stacked rows is fine');
xs.Plots(1).aux = struct('mode', "channels", 'channels', 2, 'placement', "over", 'baseline', "subtract", ...
    'baselineWindow', [-0.1 0], 'byGroup', false, 'yLim', [-0.05 0.05], 'overPosition', [0.6 1]);
xs.save(f);
x2 = EphysAnalysisConfig.load(f);
check(x2.isequalConfig(xs) && isequal(x2.Plots(1).aux, xs.Plots(1).aux) && isequal(x2.Plots(1).aux.channels, 2) ...
    && ~x2.Plots(1).aux.byGroup, 'the aux settings survive save / load (one channel stays a number)');
d = EphysAnalysisConfig.defaults("Style");
check(d.ShowSEM && d.ErrorType == "sem" && d.ErrorResamples == 1000 && d.ErrorFaceColor == "" && isnan(d.ErrorFaceAlpha) ...
    && d.ErrorEdgeColor == "none" && d.ErrorEdgeStyle == "-" && d.ErrorEdgeWidth == 0.5, ...
    'the error: mean +/- SEM by default, bands opaque and paled with no edge (as before)');
es = cfg; es.Plots(1).style.ErrorType = "std";
check(~hasIssue(es, "psth_1.style.Error", "error") && ~hasIssue(es, "psth_1.style.Error", "warning"), 'mean +/- SD is a valid error');
bad = cfg; bad.Plots(1).style.ErrorType = "iqr";
bad2 = cfg; bad2.Plots(1).style.ErrorResamples = 2.5;
bad3 = cfg; bad3.Plots(1).style.ErrorFaceAlpha = 1.5;
bad4 = cfg; bad4.Plots(1).style.ErrorEdgeStyle = "~";
bad5 = cfg; bad5.Plots(1).style.ErrorEdgeWidth = 0;
w1 = cfg; w1.Plots(1).style.ErrorFaceColor = "plaid"; w1.Plots(1).style.ErrorEdgeColor = "nope";
check(hasIssue(bad, "psth_1.style.ErrorType", "error") && hasIssue(bad2, "psth_1.style.ErrorResamples", "error") ...
    && hasIssue(bad3, "psth_1.style.ErrorFaceAlpha", "error") && hasIssue(bad4, "psth_1.style.ErrorEdgeStyle", "error") ...
    && hasIssue(bad5, "psth_1.style.ErrorEdgeWidth", "error") && hasIssue(w1, "psth_1.style.ErrorFaceColor", "warning") ...
    && hasIssue(w1, "psth_1.style.ErrorEdgeColor", "warning"), ...
    'the error type, resamples (whole), opacity (0-1 or NaN), edge style and width are checked; a color that is not one warns');
ci = cfg; ci.Plots(1).style.ErrorType = "ci95";
haveBoot = license('test', 'Statistics_Toolbox') && exist('bootci', 'file') == 2;
check(hasIssue(ci, "psth_1.style.ErrorType", "error") == ~haveBoot, 'the bootstrap CI needs the Statistics and Machine Learning Toolbox');
es.Plots(1).style.ErrorFaceAlpha = 0.3; es.Plots(1).style.ErrorEdgeColor = "auto"; es.Plots(1).style.ErrorType = "ci95";
es.Plots(1).style.ErrorResamples = 500;
es.save(f);
e2 = EphysAnalysisConfig.load(f);
check(e2.isequalConfig(es) && e2.Plots(1).style.ErrorType == "ci95" && e2.Plots(1).style.ErrorFaceAlpha == 0.3 ...
    && isnan(e2.Plots(2).style.ErrorFaceAlpha), 'the error settings survive save / load (a NaN opacity too)');
d = EphysAnalysisConfig.defaults("Plot").note;
check(d.text == "" && d.placement == "below" && d.align == "left" && d.valign == "middle" && isnan(d.fontSize) ...
    && ~d.bold && ~d.italic && ~d.box && d.color == "" && d.interpreter == "none", ...
    'a plot''s note: no text by default; below the plot, left-aligned, the design''s font and color');
nt = cfg;
nt.Plots(1).note.placement = "nowhere";   % no text: nothing to check
check(~hasIssue(nt, "psth_1.note", "error"), 'a note without text is not checked');
nt = cfg; nt.Plots(1).note.text = "Condition A" + newline + "n = 12";
check(~hasIssue(nt, "psth_1.note", "error") && ~hasIssue(nt, "psth_1.note", "warning"), 'a note with text and the defaults is valid');
for kv = {"placement", "top", "psth_1.note.placement"; "align", "middle", "psth_1.note.align"; "valign", "center", "psth_1.note.valign"; ...
        "interpreter", "latex", "psth_1.note.interpreter"; "fontSize", -2, "psth_1.note.fontSize"; "rotation", Inf, "psth_1.note.rotation"}.'
    bn = nt; bn.Plots(1).note.(kv{1}) = kv{2};
    check(hasIssue(bn, kv{3}, "error"), "a note's " + kv{1} + " is checked");
end
bn = nt; bn.Plots(1).note.placement = "custom"; bn.Plots(1).note.x = NaN;
bn2 = nt; bn2.Plots(1).note.color = "notacolor"; bn2.Plots(1).note.background = "alsonot";
check(hasIssue(bn, "psth_1.note.x", "error") && hasIssue(bn2, "psth_1.note.color", "warning") ...
    && hasIssue(bn2, "psth_1.note.background", "warning"), 'a custom note needs x and y; a color that is not one is a warning');
nt.Plots(1).note = struct('text', "Condition A" + newline + "n = 12 (\mu)", 'placement', "custom", 'x', 0.1, 'y', 0.9, 'align', "right", ...
    'valign', "top", 'rotation', 90, 'fontName', "Arial", 'fontSize', 12, 'bold', true, 'italic', true, 'color', "#336699", ...
    'background', "white", 'box', true, 'interpreter', "tex");
nt.save(f);
n2 = EphysAnalysisConfig.load(f);
check(n2.isequalConfig(nt) && isequal(n2.Plots(1).note, nt.Plots(1).note) && contains(n2.Plots(1).note.text, newline), ...
    'a note''s settings, lines too, survive save / load');

d = EphysAnalysisConfig.defaults("Overlay");
check(isempty(EphysAnalysisConfig.defaults("Plot").overlays) && isempty(cfg.Plots(1).overlays) && d.enabled && d.shape == "line" ...
    && d.axis == "x" && d.panel == "all" && d.layer == "over" && d.lineStyle == "--" && d.alpha == 1 && d.faceAlpha == 0.25 && d.edgeColor == "none", ...
    'a plot has no overlays by default; a new one is a dashed line at x = 0 over the data of every panel');
oc = cfg; oc.Plots(1).overlays = EphysAnalysisConfig.defaults("Overlay");
check(~hasIssue(oc, "psth_1.overlays", "error") && ~hasIssue(oc, "psth_1.overlays", "warning"), 'an overlay with the defaults is valid');
for kv = {"shape", "circle", "psth_1.overlays(1).shape"; "axis", "z", "psth_1.overlays(1).axis"; "panel", "left", "psth_1.overlays(1).panel"; ...
        "layer", "behind", "psth_1.overlays(1).layer"; "lineStyle", "none", "psth_1.overlays(1).lineStyle"; ...
        "lineWidth", 0, "psth_1.overlays(1).lineWidth"; "alpha", 1.5, "psth_1.overlays(1).alpha"; "faceAlpha", -0.1, "psth_1.overlays(1).faceAlpha"; ...
        "value", NaN, "psth_1.overlays(1).value"}.'
    bo = oc; bo.Plots(1).overlays(1).(kv{1}) = kv{2};
    check(hasIssue(bo, kv{3}, "error"), "an overlay's " + kv{1} + " is checked");
end
bo = oc; bo.Plots(1).overlays(1).shape = "region"; bo.Plots(1).overlays(1).from = 0.2; bo.Plots(1).overlays(1).to = 0.2;
bo2 = bo; bo2.Plots(1).overlays(1).to = Inf;
bo3 = bo; bo3.Plots(1).overlays(1).to = 0.1;   % either order: the patch lies between them
check(hasIssue(bo, "psth_1.overlays(1).to", "error") && hasIssue(bo2, "psth_1.overlays(1).from", "error") ...
    && ~hasIssue(bo3, "psth_1.overlays", "error"), 'a patch needs two finite edges that differ, in either order');
bo = oc; bo.Plots(1).overlays(1).color = "notacolor"; bo.Plots(1).overlays(1).faceColor = "alsonot"; bo.Plots(1).overlays(1).edgeColor = "nor";
check(hasIssue(bo, "psth_1.overlays(1).color", "warning") && hasIssue(bo, "psth_1.overlays(1).faceColor", "warning") ...
    && hasIssue(bo, "psth_1.overlays(1).edgeColor", "warning") && ~hasIssue(oc, "edgeColor", "warning"), ...
    'a color that is not one is a warning ("none" is a valid outline)');
bo = oc; bo.Plots(1).overlays(1).panel = "raster"; bo.Plots(1).withRaster = false;
bo2 = oc; bo2.Plots(1).overlays(1).panel = "raster"; bo2.Plots(1).withRaster = true;
bo3 = oc; bo3.Plots(2).overlays = EphysAnalysisConfig.defaults("Overlay"); bo3.Plots(2).overlays(1).panel = "raster";
check(hasIssue(bo, "psth_1.overlays(1).panel", "warning") && ~hasIssue(bo2, "psth_1.overlays(1).panel", "warning") ...
    && hasIssue(bo3, "evoked_1.overlays(1).panel", "warning"), ...
    'a raster panel on a PSTH without its raster, or on an evoked plot, warns that nothing is drawn there');
bo = oc; bo.Plots(1).overlays(2) = bo.Plots(1).overlays(1); bo.Plots(1).overlays(1).name = "Stim"; bo.Plots(1).overlays(2).name = "Stim";
bo2 = bo; bo2.Plots(1).overlays(2).name = "Stim end";
check(hasIssue(bo, "psth_1.overlays(2).name", "warning") && ~hasIssue(bo2, "overlays", "warning"), ...
    'two overlays of a plot with one name warn (a look remembered for the name reaches both)');
oc.Plots(1).overlays = struct('name', {"Stim"; "Window"; "Rate"}.', 'enabled', {true, false, true}, 'shape', {"line", "region", "line"}, ...
    'axis', {"x", "x", "y"}, 'value', {0.25, 0, 12}, 'from', {0, 0.1, 0}, 'to', {0.1, 0.4, 0.1}, 'panel', {"data", "all", "raster"}, ...
    'layer', {"under", "over", "over"}, 'color', {"#336699", "red", "black"}, 'alpha', {0.5, 1, 1}, 'lineStyle', {":", "--", "-."}, ...
    'lineWidth', {3, 1.5, 0.75}, 'faceColor', {"gray", "#00ff00", "gray"}, 'faceAlpha', {0.25, 0.4, 0.25}, 'edgeColor', {"none", "black", "none"});
oc.save(f);
o2 = EphysAnalysisConfig.load(f);
check(o2.isequalConfig(oc) && numel(o2.Plots(1).overlays) == 3 && isequal(o2.Plots(1).overlays, oc.Plots(1).overlays) ...
    && o2.Plots(1).overlays(2).shape == "region" && o2.Plots(1).overlays(2).from == 0.1 && isempty(o2.Plots(2).overlays), ...
    'a plot''s overlays, each with its own look, survive save / load in order');
oc.Plots(1).overlays = oc.Plots(1).overlays(2);
oc.save(f);
o2 = EphysAnalysisConfig.load(f);
check(o2.isequalConfig(oc) && isscalar(o2.Plots(1).overlays) && o2.Plots(1).overlays.name == "Window", 'a single overlay survives save / load too');
pp = EphysAnalysisConfig.normalizePlot(struct('kind', "psth", 'overlays', struct('shape', "region", 'axis', "y", 'from', 3, 'to', "7")));
check(isscalar(pp.overlays) && pp.overlays.shape == "region" && pp.overlays.axis == "y" && pp.overlays.to == 7 && pp.overlays.layer == "over" ...
    && pp.overlays.faceColor == "#808080", 'a partial overlay is filled from the defaults, its text number read');
[pp, unk] = EphysAnalysisConfig.normalizePlot(struct('kind', "psth", 'overlays', {{struct('value', 1, 'bogus', 2), struct('shape', "region")}}));
check(numel(pp.overlays) == 2 && pp.overlays(1).value == 1 && pp.overlays(2).shape == "region" && any(contains(unk, "overlays(1).bogus")), ...
    'overlays decoded as a cell of structs are listed in order; an unknown field is dropped and reported');
pp = EphysAnalysisConfig.normalizePlot(struct('kind', "psth", 'overlays', []));
check(isempty(pp.overlays) && isstruct(pp.overlays) && isequal(fieldnames(pp.overlays), fieldnames(EphysAnalysisConfig.defaults("Overlay"))), ...
    'empty overlays stay an empty list with the overlay fields');

fprintf('\n== 4b. behavior plots, raster options, events shifted by a parameter ==\n');
[cb, idb] = cfg.addPlot("behavior");
pb = cb.Plots(end);
check(idb == "behavior_1" && pb.source == "trials" && pb.yParam == "" && pb.jitter && pb.xScale == "category" ...
    && cb.plotFor(idb).layout == "points", 'addPlot("behavior") reads the trials (its kind''s source); points by default');
[ce, ide] = cfg.addPlot("evoked");
check(ce.Plots(ce.plotIndex(ide)).source == "LFP", 'a plot added without a source reads its kind''s first (LFP for evoked)');
check(hasIssue(cb, idb + ".param", "error") && hasIssue(cb, idb + ".yParam", "error"), 'a behavior plot needs param and yParam');
cb.Plots(end).param = "Depth";
cb.Plots(end).yParam = "RespLatency";
cb.Plots(end).seriesParam = "TrialType";
Ib = cb.validate(CheckPaths=false);
check(~any(startsWith(Ib.Field, idb)), 'a behavior plot of RespLatency by Depth, per TrialType, validates');
bad = cb; bad.Plots(end).yParam = "stop"; bad.Defaults.Window.stop = [];
check(hasIssue(bad, idb + ".yParam", "error"), 'yParam "stop" without a stop event');
bad = cb; bad.Plots(end).yParam = "stop";
check(~hasIssue(bad, idb + ".yParam", "error"), 'yParam "stop" with the default window''s stop event');
bad = cb; bad.Plots(end).xScale = "log";
check(hasIssue(bad, idb + ".xScale", "error"), 'an unknown xScale');
bad = cb; bad.Plots(end).layout = "violin";
check(hasIssue(bad, idb + ".layout", "error") == ~exist('violinplot', 'file'), 'the violin layout needs violinplot (R2024b)');
bad = cb; bad.Plots(end).source = "units";
check(hasIssue(bad, idb + ".source", "error"), 'a behavior plot reads the trials, not units');
bad = cb; bad.Plots(end).window = struct('mode', "between", 'stop', struct('line', "Stim", 'edge', "offset"));
check(hasIssue(bad, idb + ".window", "error"), 'a behavior plot takes a fixed window');
f = fullfile(root, 'behavior.json');
cr = cb;
cr.Plots(1).rasterSort = "Depth";
cr.Plots(1).rasterSortOrder = "descending";
cr.Plots(1).rasterByGroup = false;
cr.Plots(1).rasterEvents = struct('lines', "Trough", 'edge', "both", 'scope', "trial", 'marker', "^", 'size', 6, 'color', "#ff00ff");
cr.Plots(1).ref = struct('line', "RespWindow", 'offsetParam', "RespLatency");
cr.Defaults.Window.stop = struct('line', "RespWindow", 'edge', "onset", 'offsetParam', "RespLatency", 'offsetParamUnit', "s");
cr.save(f);
c5 = EphysAnalysisConfig.load(f);
p1 = c5.Plots(1);
check(cr.isequalConfig(c5) && p1.rasterSortOrder == "descending" && ~p1.rasterByGroup && isequal(p1.rasterEvents.lines, "Trough") ...
    && p1.ref.offsetParam == "RespLatency" && p1.ref.offsetParamUnit == "ms" && c5.Defaults.Window.stop.offsetParamUnit == "s" ...
    && c5.Plots(end).yParam == "RespLatency", ...
    'the raster sort, its event marks, behavior fields and parameter shifts round-trip (a one-line list stays a list)');
check(~any(cr.validate(CheckPaths=false).Severity == "error"), 'that config validates');
bad = cr; bad.Plots(1).rasterSortOrder = "up";
check(hasIssue(bad, "psth_1.rasterSortOrder", "error"), 'an unknown raster sort order');
bad = cr; bad.Plots(1).rasterEvents.edge = "middle";
check(hasIssue(bad, "psth_1.rasterEvents.edge", "error"), 'an unknown mark edge');
bad = cr; bad.Plots(1).rasterEvents.scope = "session";
check(hasIssue(bad, "psth_1.rasterEvents.scope", "error"), 'an unknown mark scope');
bad = cr; bad.Plots(1).rasterEvents.marker = "star";
check(hasIssue(bad, "psth_1.rasterEvents.marker", "error"), 'a marker the editor does not know');
bad = cr; bad.Plots(1).rasterEvents.size = 0;
check(hasIssue(bad, "psth_1.rasterEvents.size", "error"), 'a mark size of 0');
bad = cr; bad.Plots(1).rasterEvents.color = "notacolor";
check(hasIssue(bad, "psth_1.rasterEvents.color", "warning"), 'a mark color that is not one warns');
bad = cr; bad.Plots(1).ref.offsetParamUnit = "min";
check(hasIssue(bad, "psth_1.ref", "error"), 'a shift unit other than ms / s');
ce = cr;
ce.Plots(1).rasterSort = "event";
ce.Plots(1).rasterSortEvent = struct('line', "Platform", 'edge', "offset");
ce.save(f);
c8 = EphysAnalysisConfig.load(f);
pe = c8.Plots(1).rasterSortEvent;
check(ce.isequalConfig(c8) && c8.Plots(1).rasterSort == "event" && isstruct(pe) && pe.line == "Platform" && pe.edge == "offset" ...
    && pe.which == "first" && pe.scope == "auto" && isempty(pe.sequence) && isempty(c8.Plots(end).rasterSortEvent), ...
    'a raster sorted by an event round-trips: rasterSortEvent is a whole event reference; the other plots have none');
check(~any(ce.validate(CheckPaths=false).Severity == "error"), 'that config validates');
ce.Plots(1).rasterSortEvent = "Platform";
check(isequal(ce.Plots(1).rasterSortEvent, EphysAnalysisConfig.normalizeSection("EventRef", struct('line', "Platform"))), ...
    'a line name alone is short for its onset');
bad = ce; bad.Plots(1).rasterSortEvent = [];
check(hasIssue(bad, "psth_1.rasterSortEvent", "error"), 'rasterSort "event" without a rasterSortEvent');
bad = ce; bad.Plots(1).rasterSortEvent.edge = "middle";
check(hasIssue(bad, "psth_1.rasterSortEvent", "error"), 'a rasterSortEvent that is not a valid event reference');
bad.Plots(1).rasterSort = "Depth";
check(~hasIssue(bad, "psth_1.rasterSortEvent", "error"), 'the other sorts ignore rasterSortEvent');
cs = cr;
cs.Plots(1).ref = struct('line', "Trial", 'edge', "offset", 'sequence', struct('line', "Trough"));
cs.Defaults.EventRef.sequence = {struct('line', "Trough", 'maxGapSec', 2), ...
    struct('relation', "notFollowedBy", 'line', "Platform", 'edge', "offset")};
cs.Defaults.EventRef.alignStep = 1;
cs.Defaults.Window.stop = struct('line', "RespWindow", 'edge', "offset", 'sequence', struct('line', "Trough", 'n', 2));
cs.Plots(1).rasterEvents.sequences = struct('line', "Trial", 'edge', "offset", 'sequence', struct('line', "Trough"));
cs.save(f);
c6 = EphysAnalysisConfig.load(f);
d = c6.Defaults.EventRef;
pr = c6.Plots(1).ref;
check(cs.isequalConfig(c6) && numel(d.sequence) == 2 && d.sequence(1).maxGapSec == 2 && d.sequence(1).relation == "followedBy" ...
    && d.sequence(2).relation == "notFollowedBy" && isinf(d.sequence(2).maxGapSec) && d.alignStep == 1 ...
    && pr.sequence.line == "Trough" && pr.sequence.edge == "onset" && pr.sequence.n == 1 && isinf(pr.alignStep) ...
    && c6.Defaults.Window.stop.sequence.n == 2 && numel(c6.Plots(1).rasterEvents.sequences) == 1 ...
    && c6.Plots(1).rasterEvents.sequences.sequence.line == "Trough" && isempty(cr.Defaults.EventRef.sequence), ...
    'event sequences round-trip: the default event''s two steps (a cell in), alignStep, a plot''s, the stop''s and a mark''s; missing step fields take their defaults');
check(~any(cs.validate(CheckPaths=false).Severity == "error"), 'that config validates');
bad = cs; bad.Defaults.EventRef.sequence(1).relation = "before";
check(hasIssue(bad, "EventRef", "error"), 'a step relation other than followedBy / notFollowedBy');
bad = cs; bad.Defaults.EventRef.alignStep = 2;
check(hasIssue(bad, "EventRef", "error"), 'alignStep on a notFollowedBy step');
bad = cs; bad.Plots(1).rasterEvents.sequences(1).sequence(1).line = "";
check(hasIssue(bad, "psth_1.rasterEvents.sequences(1)", "error"), 'a mark sequence step without a line');
s = cs.toStruct();
s.Defaults.EventRef.sequence(1).bogus = 1;
writeJsonFile(f, s, NonFinite="string");
ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
c7 = EphysAnalysisConfig.load(f);
warning(ws);
check(any(contains(c7.LoadWarnings, "sequence(1).bogus")), 'an unknown step field is dropped and listed');

fprintf('\n== 4c. session plots ==\n');
c0 = EphysAnalysisConfig();
check(isempty(c0.SessionPlots) && isstruct(c0.SessionPlots) && isempty(c0.enabledSessionPlots()) ...
    && c0.Export.SessionsFolder == "{OutputRoot}" + filesep + "analysis" + filesep + "sessions" ...
    && isequal(c0.Export.Data, struct('Enabled', false, 'Folder', "{OutputRoot}" + filesep + "analysis" + filesep + "data", ...
    'FilenamePattern', "{Name}_{Plot}", 'MatVersion', "-v7.3")), ...
    'defaults: no session plots; Export.SessionsFolder and Export.Data (off, -v7.3)');
d = EphysAnalysisConfig.defaults("SessionPlot");
check(d.datasets == "ticked" && d.series == "session" && d.match == "pool" && d.minSessions == 1 && d.trialGroups == "pool" ...
    && isequal(d.data, "results") && d.error == "sem" && d.colorOrder == "palette" && ~d.showMembers && isempty(d.datasetKeys) ...
    && isempty(d.aesthetics) && d.facet == "none", 'defaults("SessionPlot")');
cs = cfg;
[cs, s1] = cs.addSessionPlot("psth_1");
[cs, s2] = cs.addSessionPlot(struct('plot', "psth_1", 'series', "all", 'showMembers', true));
[cs, s3] = cs.addSessionPlot("tuning_1", Id="tuning_days");
check(isequal([s1 s2 s3], ["psth_1_sessions_1" "psth_1_sessions_2" "tuning_days"]) && isequal(cs.sessionPlotIds(), [s1 s2 s3]) ...
    && cs.sessionPlotIndex("tuning_days") == 3 && cs.sessionPlotIndex("nope") == 0, ...
    'addSessionPlot: ids "<plot>_sessions_<n>" in their own namespace, a given one kept');
cs.SessionPlots(2).enabled = false;
check(isequal(cs.enabledSessionPlots(), [s1 s3]) && numel(cs.removeSessionPlot(s1).SessionPlots) == 2 ...
    && strcmp(errorId(@() cs.removeSessionPlot("nope")), 'EphysAnalysisConfig:NoSessionPlot'), ...
    'enabledSessionPlots, removeSessionPlot (NoSessionPlot for an unknown id)');
check(strcmp(errorId(@() setSessionPlots(cs, [cs.SessionPlots(1) cs.SessionPlots(1)])), 'EphysAnalysisConfig:DuplicateSessionPlotId'), ...
    'two session plots with one id: DuplicateSessionPlotId');
c4 = cs;
c4.SessionPlots = {struct('plot', "psth_1"), struct('plot', "evoked_1", 'id', "evoked_1_sessions_1"), struct('plot', "evoked_1")};
check(isequal([c4.SessionPlots.id], ["psth_1_sessions_1" "evoked_1_sessions_1" "evoked_1_sessions_2"]), ...
    'a cell of partial session plots (jsondecode) gets free ids');
cs.SessionPlots(1).datasets = "list";
cs.SessionPlots(1).datasetKeys = "SYNTH-01/260908_103000";
cs.SessionPlots(1).data = ["results" "epochs"];
cs.SessionPlots(1).title = "Across days";
cs.SessionPlots(1).layout = "overlay";
cs.SessionPlots(1).aesthetics = PlotAesthetics.normalizeRules(struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2));
cs.SessionPlots(3).trialGroups = "each";
cs.Export.Data.Enabled = true;
cs.Export.Data.MatVersion = "-v7";
f = fullfile(root, 'sessions.json');
cs.save(f);
cs2 = EphysAnalysisConfig.load(f);
txt = fileread(f);
check(cs.isequalConfig(cs2) && isequal(cs2.SessionPlots(1).datasetKeys, "SYNTH-01/260908_103000") ...
    && isequal(cs2.SessionPlots(1).data, ["results" "epochs"]) && isequal(cs2.SessionPlots(2).data, "results") ...
    && numel(cs2.SessionPlots(1).aesthetics) == 1 && cs2.Export.Data.Enabled && cs2.Export.Data.MatVersion == "-v7" ...
    && contains(txt, '"SessionPlots"') && isempty(cs2.LoadWarnings), ...
    'session plots and Export.Data survive save / load exactly (a one-key list stays a list)');
s = rmfield(cfg.toStruct(), 'SessionPlots');
fo = fullfile(root, 'no_sessions.json');
writeJsonFile(fo, s, NonFinite="string");
co = EphysAnalysisConfig.load(fo);
check(co.isequalConfig(cfg) && isempty(co.SessionPlots) && isempty(co.LoadWarnings), ...
    'a config file without SessionPlots loads with none and no warning (schema v1 unchanged)');
sp1 = cs.sessionPlotFor(s1);
sp3 = cs.sessionPlotFor("tuning_days");
base = cs.plotFor("psth_1");
check(sp1.id == s1 && sp1.title == "Across days" && sp1.layout == "overlay" && sp1.enabled && isempty(sp1.selection.groupBy) ...
    && isequal(sp1.ref, base.ref) && isequal(sp1.bins, base.bins) && isequal(sp1.sessionAesthetics, cs.SessionPlots(1).aesthetics) ...
    && isequal(sp1.aesthetics, base.aesthetics) && isequal(sp3.selection.groupBy, cs.plotFor("tuning_1").selection.groupBy) ...
    && sp3.layout == cs.plotFor("tuning_1").layout && sp3.title == "", ...
    'sessionPlotFor: the base plot with id, title, layout and the session plot''s own aesthetics; trialGroups "pool" clears groupBy, "each" keeps it');
ct = cs; ct.Plots(ct.plotIndex("tuning_1")).seriesParam = "TrialType";
ct.SessionPlots(3).trialGroups = "pool";
check(ct.sessionPlotFor("tuning_days").seriesParam == "" && ct.plotFor("tuning_1").seriesParam == "TrialType" ...
    && strcmp(errorId(@() cs.sessionPlotFor("nope")), 'EphysAnalysisConfig:NoSessionPlot') ...
    && strcmp(errorId(@() cs.sessionPlotFor(struct('plot', "nope"))), 'EphysAnalysisConfig:NoPlot') ...
    && cs.sessionPlotFor(struct('plot', "psth_1", 'id', "x")).id == "x" && cs.sessionPlotFor(2).id == s2, ...
    'sessionPlotFor: a tuning plot''s series pooled too; an unknown id or base plot errors; a struct or an index works');

% validate
good = cs;
good.SessionPlots(1).datasets = "ticked";
good.SessionPlots(1).datasetKeys = string.empty(1, 0);
I = good.validate(CheckPaths=false);
check(~any(I.Section == "SessionPlots") && ~any(I.Severity == "error"), 'valid session plots raise no issue');
bad = good; [bad.Plots.enabled] = deal(false);
check(~hasIssue(bad, "enabled", "error"), 'no plot enabled but a session plot is: not an error');
bad.SessionPlots = EphysAnalysisConfig.emptySessionPlots();
I = bad.validate(CheckPaths=false);
check(any(I.Field == "enabled" & I.Severity == "error" & contains(I.Message, "session plot")), 'neither a plot nor a session plot enabled: an error');
mods = {
    "id",           @(c) setSp(c, 1, 'id', "a/b"),                     "a/b.id",                 "error"
    "plot",         @(c) setSp(c, 1, 'plot', "nope"),                  s1 + ".plot",             "error"
    "kind",         @(c) setSp(c, 1, 'plot', "probemap_1"),            s1 + ".plot",             "error"
    "layout",       @(c) setSp(c, 1, 'layout', "stack"),               s1 + ".layout",           "error"
    "datasets",     @(c) setSp(c, 1, 'datasets', "some"),              s1 + ".datasets",         "error"
    "facet",        @(c) setSp(c, 1, 'facet', "day"),                  s1 + ".facet",            "error"
    "series",       @(c) setSp(c, 1, 'series', "unit"),                s1 + ".series",           "error"
    "colorOrder",   @(c) setSp(c, 1, 'colorOrder', "rainbow"),         s1 + ".colorOrder",       "error"
    "error",        @(c) setSp(c, 1, 'error', "iqr"),                  s1 + ".error",            "error"
    "match",        @(c) setSp(c, 1, 'match', "nearest"),              s1 + ".match",            "error"
    "trialGroups",  @(c) setSp(c, 1, 'trialGroups', "split"),          s1 + ".trialGroups",      "error"
    "data",         @(c) setSp(c, 1, 'data', ["results" "spikes"]),    s1 + ".data",             "error"
    "minSessions",  @(c) setSp(c, 1, 'minSessions', 1.5),              s1 + ".minSessions",      "error"
    "minSessions 0", @(c) setSp(c, 1, 'minSessions', 0),               s1 + ".minSessions",      "error"
    "list, no keys", @(c) setSp(c, 1, 'datasets', "list"),             s1 + ".datasetKeys",      "warning"
    "mapping, no file", @(c) setSp(c, 1, 'match', "mapping"),          s1 + ".mappingFile",      "error"
    "showMembers",  @(c) setSp(c, 1, 'showMembers', true),             s1 + ".showMembers",      "warning"
    "combine bars", @(c) setSp(c, 1, 'trialGroups', "combine"),        s1 + ".trialGroups",      "warning"
    "match a signal", @(c) setSp(setSp(c, 1, 'plot', "evoked_1"), 1, 'match', "site"), s1 + ".match", "warning"
    "series pooled", @(c) setSp(setPlotField(c, "tuning_1", 'seriesParam', "TrialType"), 3, 'trialGroups', "pool"), "tuning_days.trialGroups", "warning"
    };
for m = 1:size(mods, 1)
    check(hasIssue(mods{m, 2}(good), mods{m, 3}, mods{m, 4}), "validate SessionPlots: " + mods{m, 1} + " -> " + mods{m, 4} + " on " + mods{m, 3});
end
bad = good; bad.SessionPlots(2).id = upper(bad.SessionPlots(1).id);
check(hasIssue(bad, ".id", "error"), 'two session plot ids that name the same files (case-blind)');
bad = good; bad.Plots(1).baseline = struct('Mode', "auroc", 'Window', [-0.2 0]);
check(hasIssue(bad, s1 + ".plot", "error"), 'a base plot with an auROC baseline');
bad = good; bad.Plots(end+1) = EphysAnalysisConfig.normalizePlot(struct('kind', "heatmap", 'id', "heat"));
bad = bad.addSessionPlot("heat", Id="heat_days");
check(hasIssue(bad, "heat_days.series", "warning") && ~hasIssue(setSp(bad, 4, 'series', "all"), "heat_days.series", "warning") ...
    && hasIssue(setSp(bad, 4, 'match', "site"), "heat_days.match", "warning"), ...
    'a heatmap base: series other than all, and a match other than pool, are ignored (warnings)');
bad = setSp(good, 1, 'match', "mapping");
bad.SessionPlots(1).mappingFile = fullfile(root, 'nomap.csv');
I = bad.validate(CheckPaths=true);
check(any(I.Field == s1 + ".mappingFile" & I.Severity == "error") && ~hasIssue(bad, s1 + ".mappingFile", "error"), ...
    'a mapping file that does not exist: an error with CheckPaths');
mf = fullfile(root, 'map_nocell.csv');
writelines(["unit,SYNTH-01/a"; "u1,3"], mf);
bad.SessionPlots(1).mappingFile = mf;
check(hasIssue(bad, s1 + ".mappingFile", "error"), 'a mapping file without a cell column');
mf = fullfile(root, 'map.csv');
writelines(["cell,SYNTH-01/a"; "cellA,3"], mf);
bad.SessionPlots(1).mappingFile = mf;
bad.SessionPlots(1).datasets = "list";
bad.SessionPlots(1).datasetKeys = ["SYNTH-01/a" "SYNTH-01/b"];
I = bad.validate(CheckPaths=false);
check(~any(I.Field == s1 + ".mappingFile" & I.Severity == "error") && any(I.Field == s1 + ".mappingFile" & I.Severity == "warning" ...
    & contains(I.Message, "SYNTH-01/b")), 'a mapping file lacking a listed dataset key''s column: a warning');
bad = good; bad.Export.SessionsFolder = "{Bogus}";
check(hasIssue(bad, "SessionsFolder", "error"), 'Export.SessionsFolder: a folder pattern');
bad.Export.SessionsFolder = "{OutputFolder}";
check(hasIssue(bad, "SessionsFolder", "warning"), 'Export.SessionsFolder with {OutputFolder}: the first dataset''s folder (warning)');
bad = good; bad.Export.Data.Folder = "{Plot}";
check(hasIssue(bad, "Data.Folder", "error"), 'Export.Data.Folder: a folder pattern');
bad = good; bad.Export.Data.FilenamePattern = "{OutputRoot}";
check(hasIssue(bad, "Data.FilenamePattern", "error"), 'Export.Data.FilenamePattern: a file pattern');
bad = good; bad.Export.Data.MatVersion = "-v6";
check(hasIssue(bad, "Data.MatVersion", "error"), 'Export.Data.MatVersion: -v7.3 or -v7');
s = cs.toStruct();
s.SessionPlots(1).bogus = 1;
writeJsonFile(f, s, NonFinite="string");
ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
c8 = EphysAnalysisConfig.load(f);
warning(ws);
check(any(contains(c8.LoadWarnings, "SessionPlots(1).bogus")) && c8.isequalConfig(cs), 'an unknown session plot field is dropped and listed');

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


function cfg = setSessionPlots(cfg, p)
cfg.SessionPlots = p;
end


function cfg = setSp(cfg, k, field, value)
cfg.SessionPlots(k).(field) = value;
end


function cfg = setPlotField(cfg, id, field, value)
cfg.Plots(cfg.plotIndex(id)).(field) = value;
end
