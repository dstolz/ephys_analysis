function test_plotToFigure()
%test_plotToFigure  Verification suite for converting a plot of the Plots section into a figure.
%   EphysAnalysisConfig.plotToFigure, field by field (observe, panels,
%   layers, options, common, style, notes) for every convertible kind and
%   layout: a PSTH grid with its raster, event marks, waveform inset and
%   aux magnitude; a PSTH without its raster; a PSTH overlay; stacking and
%   the auROC baseline carried (stackRaster a note); a raster with its aux
%   above, and "over"; evoked grid / stack / butterfly; heat maps of units
%   (auROC, modulation order) and of LFP; a probe map; a correlation map;
%   unit waveforms in a grid and on the probe; firing rates (each layout
%   as the display); tuning curves in a grid and as an overlay. A behavior
%   plot raises NotConvertible; an unknown id NoPlot;
%   the ids ("<plotId>_fig", "_fig2", ...: free among plots and figures); "default" sentinels kept and own
%   alignment carried; the text note to the panel it borders and the
%   overlays to the panels they name (one naming a panel the figure lacks
%   a note); MaxTiles, TileSpacing,
%   XLim and an unused YLim as notes; every converted figure validates.
%   convertPlotToFigure appends the figure. On makeAnalysisFixture's
%   "clean" dataset a converted PSTH with its raster, Stim offset marks and
%   aux channels computes and renders for one unit.
%
%   Usage:  test_plotToFigure

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);

root = fullfile(tempdir, sprintf('PlotToFigure_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdirQuiet(root));

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
    function [F, notes, cfg] = convert(p)
        % the figure of plot P (a partial plot struct) in a fresh config
        cfg = base;
        [cfg, pid] = cfg.addPlot(p);
        [F, notes] = EphysAnalysisConfig.plotToFigure(cfg, pid);
    end
    function tf = validates(cfg, F)
        % no Figures error with F as the config's only figure
        cfg.Figures = F;
        I = cfg.validate(CheckPaths=false);
        tf = ~any(I.Section == "Figures" & I.Severity == "error");
        if ~tf; disp(I(I.Section == "Figures" & I.Severity == "error", :)); end
    end

base = EphysAnalysisConfig();
base.Defaults.EventRef.line = "Stim";
mark = EphysAnalysisConfig.defaults("EventMark");
mark.line = "Stim";
mark.edge = "offset";
typesOf = @(F) [F.panels.type];

fprintf('\n== 1. a PSTH grid: raster, marks, inset, aux magnitude ==\n');
p = struct('kind', "psth", 'source', "detected");
p.units = struct('maxUnits', 5, 'classes', "su");
p.bins = struct('BinSec', 0.02, 'SmoothSec', 0);
p.measure = "count";
p.baseline = struct('Mode', "zscore", 'Window', [-0.3 0]);
p.maskAfterStop = true;
p.rasterSort = "stop";
p.rasterSortOrder = "descending";
p.rasterByGroup = false;
p.rasterEvents = mark;
p.histStyle = "line";
p.fill = false;
p.fillAlpha = 0.3;
p.normalize = "unitPeak";
p.waveform = struct('mode', "mean", 'location', "northwest");
p.aux = struct('mode', "magnitude", 'channels', [1 2], 'baseline', "subtract", 'baselineWindow', [-0.1 0], ...
    'statistic', "median", 'transform', "rectify", 'errorType', "std", 'yLim', [0 2]);
p.style = struct('FontSize', 12, 'YLim', [0 50], 'MaxTiles', 9);
p.aesthetics = struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2);
[F, notes, cfg] = convert(p);
check(F.id == "psth_1_fig" && F.enabled && F.title == "" && isequal(F.ref, "default") && isequal(F.window, "default") ...
    && isequal(F.selection, "default"), 'the figure is "<plotId>_fig" (not the plot''s own id); its "default" ref, window and selection stay "default"');
check(F.observe.kind == "unit" && F.observe.source == "detected" && F.observe.units.maxUnits == 5 ...
    && isequal(F.observe.units.classes, "su"), 'it is drawn per unit of the plot''s source, through the plot''s unit filter');
check(isequal(typesOf(F), ["raster" "psth" "continuous"]) && isequal([F.panels.row], 1:3) && all([F.panels.col] == 1) ...
    && F.grid.rows == 3 && F.grid.cols == 1 && isequal(F.grid.rowHeights, [2 2 1]) && F.grid.spacing == "none", ...
    'a raster over the PSTH over the aux panel, flush, the aux panel half their height (as the plot drew them)');
r = F.panels(1);
check(numel(r.layers) == 2 && r.layers(1).source == "detected" && r.layers(1).binding == "observation" ...
    && r.layers(2).source == "events" && r.layers(2).binding == "fixed" && r.layers(2).eventsAs == "marks" ...
    && r.layers(2).event.line == "Stim" && r.layers(2).event.edge == "offset" && r.layers(2).event.marker == mark.marker, ...
    'the raster: a layer following the unit, and the event mark as an events layer drawn as marks');
check(~r.common && r.options.rasterSort == "stop" && r.options.rasterSortOrder == "descending" && ~r.options.rasterByGroup ...
    && r.options.maskAfterStop && r.options.waveform.mode == "off", ...
    'the raster keeps its own options (sort, mask after stop), without the inset the PSTH draws');
q = F.panels(2);
check(q.common && isscalar(q.layers) && q.layers.binding == "observation" && q.options.histStyle == "line" && ~q.options.fill ...
    && q.options.fillAlpha == 0.3 && q.options.normalize == "unitPeak" && isequal(q.options.yLim, [0 50]), ...
    'the PSTH: linked to the common options, its histStyle, fill, fillAlpha, normalize, and the style''s YLim as its yLim');
x = F.panels(3);
check(~x.common && isscalar(x.layers) && x.layers.source == "AUX" && x.layers.binding == "fixed" && isequal(x.layers.channels, [1 2]) ...
    && x.layers.aggregate == "mean" && x.options.baseline.Mode == "subtract" && isequal(x.options.baseline.Window, [-0.1 0]) ...
    && x.options.statistic == "median" && x.options.transform == "rectify" && x.options.errorType == "std" ...
    && isequal(x.options.yLim, [0 2]) && x.options.display == "lines", ...
    'the aux magnitude: a continuous panel of a fixed AUX layer averaged over its channels, with the aux''s own options');
c = F.common;
check(c.bins.BinSec == 0.02 && c.bins.SmoothSec == 0 && c.measure == "count" && c.baseline.Mode == "zscore" ...
    && isequal(c.baseline.Window, [-0.3 0]) && c.maskAfterStop && c.waveform.mode == "mean" && c.waveform.location == "northwest", ...
    'common: the plot''s bins, measure, baseline, mask after stop and waveform inset');
check(F.style.FontSize == 12 && F.style.MaxTiles == 16 && isempty(F.style.YLim) && isscalar(F.aesthetics) ...
    && F.aesthetics.role == "rate", 'the style and looks carried; MaxTiles and YLim back at their defaults');
check(numel(notes) == 2 && any(contains(notes, "MaxTiles 9")) && any(notes == "The aux magnitude became the mean of the AUX channels."), ...
    sprintf('two notes: MaxTiles and the aux magnitude (%s)', strjoin(notes, " | ")));
check(validates(cfg, F), 'the converted figure validates');
[cfg2, fid, n2] = cfg.convertPlotToFigure("psth_1");
check(fid == "psth_1_fig" && isscalar(cfg2.Figures) && isequaln(cfg2.Figures, F) && isequal(n2, notes) && numel(cfg2.Plots) == 1, ...
    'convertPlotToFigure appends the figure; the plot stays');
[cfg3, fid3] = cfg2.convertPlotToFigure("psth_1");
cfg3 = cfg3.addPlot("psth", Id="PSTH_1_FIG3");
[cfg3, fid4] = cfg3.convertPlotToFigure("psth_1");
check(fid3 == "psth_1_fig2" && fid4 == "psth_1_fig4" && isequal(cfg3.figureIds(), ["psth_1_fig" "psth_1_fig2" "psth_1_fig4"]), ...
    'each further figure takes the next "<plotId>_fig<n>" no figure or plot has (case ignored)');

fprintf('\n== 2. PSTH variants ==\n');
[F, notes, cfg] = convert(struct('kind', "psth", 'withRaster', false, 'rasterEvents', mark));
check(isequal(typesOf(F), "psth") && F.grid.rows == 1 && isempty(F.grid.rowHeights) && isscalar(notes) ...
    && contains(notes, "1 raster event mark(s) not carried") && validates(cfg, F), ...
    'without its raster: one PSTH panel; the marks it had no raster for are a note');
[F, notes, cfg] = convert(struct('kind', "psth", 'layout', "overlay", 'units', struct('classes', "su", 'maxUnits', 4), ...
    'waveform', struct('mode', "both")));
L = F.panels.layers;
check(F.observe.kind == "dataset" && isequal(typesOf(F), "psth") && isscalar(L) && L.binding == "fixed" && L.source == "units" ...
    && isequal(L.units.classes, "su") && L.units.maxUnits == 4 && L.aggregate == "mean" && F.common.waveform.mode == "off" ...
    && numel(notes) == 2 && contains(notes(1), "withRaster") && contains(notes(2), "waveform inset") && validates(cfg, F), ...
    'an overlay: per dataset, one PSTH of a fixed units layer averaged; withRaster and the inset are notes');
au = struct('windowSec', 0.05, 'cutoff', "fixed");
[F, notes, cfg] = convert(struct('kind', "psth", 'stack', true, 'stackSpacing', 1.4, 'stackRaster', true, ...
    'baseline', struct('Mode', "auroc"), 'auroc', au));
q = F.panels([F.panels.type] == "psth");
check(F.common.baseline.Mode == "auroc" && F.common.auroc.windowSec == 0.05 && F.common.auroc.cutoff == "fixed" ...
    && q.options.stack && q.options.stackSpacing == 1.4 && isscalar(notes) && contains(notes, "stackRaster") && validates(cfg, F), ...
    'the auROC baseline and its settings, stack and stackSpacing are carried; stackRaster alone is a note');
[F, notes] = convert(struct('kind', "psth", 'aux', struct('mode', "channels", 'placement', "over", 'display', "heatmap", ...
    'colorBy', "channel", 'byGroup', false)));
x = F.panels(end);
check(isequal(typesOf(F), ["raster" "psth" "continuous"]) && x.layers.aggregate == "each" && isempty(x.layers.channels) ...
    && x.options.display == "lines" && numel(notes) == 4 && any(contains(notes, "heat map display")) ...
    && any(contains(notes, "colorBy")) && any(contains(notes, "byGroup")) && any(contains(notes, """over""")), ...
    'aux channels "over" in a heat map: a panel below, each channel a line; the display, colors, byGroup and placement are notes');

fprintf('\n== 3. raster ==\n');
[F, notes, cfg] = convert(struct('kind', "raster", 'rasterEvents', [mark mark], 'rasterSort', "Depth", ...
    'aux', struct('mode', "channels", 'placement', "above"), 'waveform', struct('mode', "mean"), 'style', struct('YLim', [0 9])));
check(F.observe.kind == "unit" && isequal(typesOf(F), ["continuous" "raster"]) && isequal(F.grid.rowHeights, [1 2]) ...
    && F.panels(2).common && numel(F.panels(2).layers) == 3 && all([F.panels(2).layers(2:3).source] == "events") ...
    && F.panels(2).options.rasterSort == "Depth" && F.common.waveform.mode == "mean", ...
    'a raster: per unit, its aux panel above, two events layers, linked to the common options (its inset there)');
check(isscalar(notes) && contains(notes, "YLim [0 9]") && validates(cfg, F), 'a YLim no panel takes is a note; it validates');

fprintf('\n== 4. evoked ==\n');
[F, notes, cfg] = convert(struct('kind', "evoked", 'source', "LFP", 'layout', "grid", 'channels', [1 3], ...
    'baseline', struct('Mode', "subtract", 'Window', [-0.1 0]), 'style', struct('ShowSEM', false, 'YLim', [-1 1])));
o = F.panels.options;
check(F.observe.kind == "channel" && F.observe.signal == "LFP" && isequal(F.observe.channels, [1 3]) ...
    && isequal(typesOf(F), "continuous") && F.panels.layers.source == "LFP" && F.panels.layers.binding == "observation" ...
    && F.common.baseline.Mode == "subtract" && o.errorType == "off" && isequal(o.yLim, [-1 1]) && isempty(notes) && validates(cfg, F), ...
    'a grid: per channel of its extract and channels, a continuous panel following the channel; no band (ShowSEM off), its YLim');
[F, notes, cfg] = convert(struct('kind', "evoked", 'source', "MUA", 'layout', "stack", 'channels', 2:4, ...
    'style', struct('StackSpacing', 50, 'ErrorType', "std")));
L = F.panels.layers;
check(F.observe.kind == "dataset" && L.binding == "fixed" && L.source == "MUA" && isequal(L.channels, 2:4) && L.aggregate == "each" ...
    && F.panels.options.display == "stacked" && F.panels.options.stackSpacing == 50 && F.panels.options.errorType == "std" ...
    && isempty(notes) && validates(cfg, F), 'a stack: per dataset, a fixed layer of its channels, stacked at the style''s spacing');
[F, notes] = convert(struct('kind', "evoked", 'source', "LFP", 'layout', "butterfly", 'baseline', struct('Mode', "zscore")));
check(F.panels.options.display == "lines" && F.common.baseline.Mode == "none" && numel(notes) == 2 ...
    && contains(notes(1), "baseline ""zscore""") && contains(notes(2), "butterfly"), ...
    'a butterfly: the channels as lines in one panel, a note; a baseline other than subtract becomes none, a note');

fprintf('\n== 5. heat map, probe map, correlation map ==\n');
gcfg = base;
gcfg.Defaults.Selection.groupBy = "Depth";
[gcfg, pid] = gcfg.addPlot(struct('kind', "heatmap", 'order', "modulation", 'units', struct('ids', [3 5]), ...
    'baseline', struct('Mode', "auroc"), 'style', struct('CLim', [0 20])));
[F, notes] = EphysAnalysisConfig.plotToFigure(gcfg, pid);
o = F.panels.options;
check(F.observe.kind == "dataset" && isequal(typesOf(F), "heatmap") && F.panels.layers.binding == "fixed" ...
    && isequal(F.panels.layers.units.ids, [3 5]) && o.order == "modulation" && o.group == 1 && isequal(o.cLim, [0 20]) ...
    && F.common.baseline.Mode == "auroc" && isempty(F.style.CLim) && isscalar(notes) && contains(notes, "one trial group") ...
    && validates(gcfg, F), ...
    'a heat map of units: a fixed layer of its ids, the auROC baseline and modulation order kept, group 1, CLim as cLim; the groups a note');
[F, notes, cfg] = convert(struct('kind', "heatmap", 'source', "LFP", 'channels', [2 4], 'baseline', struct('Mode', "zscore")));
check(F.panels.layers.source == "LFP" && isequal(F.panels.layers.channels, [2 4]) && F.common.baseline.Mode == "none" ...
    && isscalar(notes) && validates(cfg, F), 'a heat map of LFP: a fixed layer of its channels; zscore is no signal baseline (a note)');
[F, notes, cfg] = convert(struct('kind', "probemap", 'source', "detected", 'value', "nUnits"));
check(F.observe.kind == "dataset" && isequal(typesOf(F), "probemap") && F.panels.layers.source == "detected" ...
    && F.panels.options.value == "nUnits" && isempty(notes) && validates(cfg, F), 'a probe map: its value, a fixed layer');
[F, notes, cfg] = convert(struct('kind', "corrmap", 'metric', "peak", 'correlation', "spearman", 'fisherZ', true, ...
    'window', struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Stim", 'edge', "offset"))));
o = F.panels.options;
check(isequal(typesOf(F), "corrmap") && o.metric == "peak" && o.correlation == "spearman" && o.fisherZ && o.group == 1 ...
    && isstruct(F.window) && F.window.mode == "between" && isempty(notes) && validates(cfg, F), ...
    'a correlation map: metric, correlation, fisherZ, its own "between" window carried');

fprintf('\n== 6. unit waveforms ==\n');
[F, notes, cfg] = convert(struct('kind', "waveforms", 'units', struct('classes', "su"), 'waveform', struct('mode', "subsample", 'maxSpikes', 30)));
check(F.observe.kind == "unit" && isequal(F.observe.units.classes, "su") && isequal(typesOf(F), "waveforms") ...
    && F.panels.layers.binding == "observation" && F.common.waveform.mode == "subsample" && F.common.waveform.maxSpikes == 30 ...
    && F.panels.options.layout == "grid" && isempty(notes) && validates(cfg, F), ...
    'a grid: per unit, a waveforms panel following it, the plot''s settings as the common waveform');
[F, notes, cfg] = convert(struct('kind', "waveforms", 'layout', "probe", 'units', struct('classes', "su")));
check(F.observe.kind == "dataset" && F.panels.layers.binding == "fixed" && isequal(F.panels.layers.units.classes, "su") ...
    && F.panels.options.layout == "probe" && isempty(notes) && validates(cfg, F), ...
    'on the probe: per dataset, a fixed layer of the filter, options.layout "probe", no note');

fprintf('\n== 6b. firing rate and tuning curves ==\n');
[F, notes, cfg] = convert(struct('kind', "rate", 'source', "detected", 'layout', "box", 'measure', "count", ...
    'baseline', struct('Mode', "ratio", 'Window', [-0.3 0]), 'units', struct('maxUnits', 4), 'style', struct('YLim', [0 30]), ...
    'window', struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Stim", 'edge', "offset"))));
q = F.panels;
check(F.observe.kind == "unit" && F.observe.source == "detected" && F.observe.units.maxUnits == 4 && isequal(typesOf(F), "rate") ...
    && q.layers.binding == "observation" && q.layers.source == "detected" && q.options.display == "box" ...
    && F.common.measure == "count" && F.common.baseline.Mode == "ratio" && isequal(F.common.baseline.Window, [-0.3 0]) ...
    && isequal(q.options.yLim, [0 30]) && F.window.mode == "between" && isempty(notes) && validates(cfg, F), ...
    'a rate plot: per unit, a rate panel following it, its layout as the display, measure and ratio baseline, YLim, "between" window');
for lay = ["bar" "points"]
    F = convert(struct('kind', "rate", 'layout', lay));
    check(F.panels.options.display == lay, sprintf('a rate plot''s %s layout is the panel''s display', lay));
end
[F, notes, cfg] = convert(struct('kind', "tuning", 'param', "Depth", 'seriesParam', "Level", ...
    'baseline', struct('Mode', "zscore"), 'waveform', struct('mode', "mean")));
o = F.panels.options;
check(F.observe.kind == "unit" && isequal(typesOf(F), "tuning") && F.panels.layers.binding == "observation" && o.param == "Depth" ...
    && o.seriesParam == "Level" && F.common.baseline.Mode == "zscore" && F.common.waveform.mode == "mean" && F.panels.common ...
    && isempty(notes) && validates(cfg, F), 'a tuning grid: per unit, a tuning panel following it, param and seriesParam, its inset');
[F, notes, cfg] = convert(struct('kind', "tuning", 'layout', "overlay", 'param', "Depth", 'units', struct('ids', [1 2 3]), ...
    'waveform', struct('mode', "mean")));
L = F.panels.layers;
check(F.observe.kind == "dataset" && L.binding == "fixed" && isequal(L.units.ids, [1 2 3]) && L.aggregate == "mean" ...
    && F.common.waveform.mode == "off" && isscalar(notes) && contains(notes, "waveform inset") && validates(cfg, F), ...
    'a tuning overlay: per dataset, a fixed units layer averaged (the plot''s mean over units); the inset is a note');

fprintf('\n== 7. not convertible, ids, alignment, notes ==\n');
cfg = base.addPlot("behavior");
check(strcmp(errorId(@() EphysAnalysisConfig.plotToFigure(cfg, "behavior_1")), 'EphysAnalysisConfig:NotConvertible') ...
    && strcmp(errorId(@() cfg.convertPlotToFigure("behavior_1")), 'EphysAnalysisConfig:NotConvertible'), ...
    'a behavior plot raises NotConvertible');
check(strcmp(errorId(@() EphysAnalysisConfig.plotToFigure(base, "nope")), 'EphysAnalysisConfig:NoPlot'), 'an unknown plot raises NoPlot');
ref = EphysAnalysisConfig.defaults("EventRef");
ref.line = "Stim";
ref.edge = "offset";
ov = EphysAnalysisConfig.defaults("Overlay");
[F, notes] = convert(struct('kind', "psth", 'ref', ref, 'enabled', false, 'title', "Mine", 'note', struct('text', "hello"), ...
    'overlays', [ov ov], 'style', struct('XLim', [0 1], 'TileSpacing', "loose")));
check(isstruct(F.ref) && F.ref.edge == "offset" && isequal(F.window, "default") && ~F.enabled && F.title == "Mine", ...
    'the plot''s own event reference, enabled and title are carried');
check(numel(notes) == 3 && contains(notes(1), "TileSpacing ""loose""") && contains(notes(2), "XLim [0 1]") ...
    && contains(notes(3), "text note went to panel 2 of 2") && isempty(F.style.XLim) && F.style.TileSpacing == "compact" ...
    && F.panels(2).note.text == "hello" && F.panels(1).note.text == "" && numel(F.panels(1).overlays) == 2 ...
    && numel(F.panels(2).overlays) == 2, ...
    'TileSpacing and XLim are notes; the text note (below) goes to the bottom panel, saying so; an overlay on "all" to every panel');
ovR = ov; ovR.panel = "raster";
ovD = ov; ovD.panel = "data";
[F, notes, cfg] = convert(struct('kind', "psth", 'overlays', [ovR ovD], 'note', struct('text', "top", 'placement', "above")));
check(isequal(typesOf(F), ["raster" "psth"]) && isscalar(F.panels(1).overlays) && isscalar(F.panels(2).overlays) ...
    && F.panels(1).overlays.panel == "all" && F.panels(2).overlays.panel == "all" && F.panels(1).note.text == "top" ...
    && F.panels(2).note.text == "" && any(contains(notes, "panel 1 of 2")) && validates(cfg, F), ...
    'an overlay on the raster goes to the raster panel, one on the data to the PSTH; a note above to the top panel');
[F, notes] = convert(struct('kind', "raster", 'overlays', ovD, 'note', struct('text', "x", 'placement', "northeast")));
check(isempty(F.panels(1).overlays) && any(contains(notes, "1 overlay(s) not carried")) && F.panels(1).note.text == "x" ...
    && ~any(contains(notes, "text note")), 'a raster plot''s overlay on its (missing) data panel is a note; its one panel takes the note');
[F, notes] = convert(struct('kind', "psth", 'aux', struct('mode', "channels"), 'overlays', ovD, ...
    'note', struct('text', "beside", 'placement', "right")));
check(isequal(typesOf(F), ["raster" "psth" "continuous"]) && F.panels(2).note.text == "beside" && F.panels(1).note.text == "" ...
    && F.panels(3).note.text == "" && any(contains(notes, "panel 2 of 3")) && isempty(F.panels(1).overlays) ...
    && isscalar(F.panels(2).overlays) && isempty(F.panels(3).overlays), ...
    'a note right of the plot goes to its data panel (the PSTH, panel 2), and a "data" overlay to the PSTH only: not the raster, not the aux panel');

fprintf('\n== 8. a converted PSTH computes and renders (fixture) ==\n');
froot = string(root) + "_fixture";
cleanFixture = onCleanup(@() rmdirQuiet(froot));
FX = makeAnalysisFixture(froot, Scenarios="clean", NumTrials=12);
cfg = EphysAnalysisConfig();
cfg.Source.Root = FX.proj;
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
cfg.Defaults.Selection.groupBy = "Depth";
[cfg, pid] = cfg.addPlot(struct('kind', "psth", 'rasterEvents', mark, 'aux', struct('mode', "channels")));
[cfg, fid, notes] = cfg.convertPlotToFigure(pid);
spec = cfg.figureFor(fid);
rn = EphysAnalysisRunner(cfg, LogFcn=[]);
src = rn.source(1);
T = figureObservations(src, spec);
F1 = rn.computeFigure(src, spec, Observation=T(1, :));
skips = strings(1, 0);
for j = 1:numel(F1.panels)
    skips = [skips, F1.panels(j).skip, [F1.panels(j).layers.skip]]; %#ok<AGROW>
end
check(isempty(notes) && height(T) >= 1 && F1.observation.unitId == T.unitId(1) && isequal([F1.panels.type], ["raster" "psth" "continuous"]) ...
    && all(skips == "") && size(F1.panels(2).layers(1).R.rate, 2) == 1, ...
    sprintf('computeFigure: the raster with Stim offset marks, the PSTH and the aux of one unit (%s), nothing skipped', T.label(1)));
fg = figure('Visible', 'off', 'Position', [100 100 600 800]);
closeFig = onCleanup(@() delete(fg));
h = renderFigure(F1, spec, fg);
drawnow;
check(numel(h.panels) == 3 && all(arrayfun(@(s) ~isempty(s.axes) && isvalid(s.axes), h.panels)) && contains(h.title, T.label(1)), ...
    'renderFigure draws its three panels, the title naming the unit');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_plotToFigure:Failures', '%d checks failed.', nFail);
end
end


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
