function test_EphysAnalysisFigures()
%test_EphysAnalysisFigures  Verification suite for the analysis config's figures.
%   Config sections (1-6): the defaults of Figure / Panel / Layer /
%   Observe; panelTypes, sourceCategories, categoryOf, observeKind and
%   defaultLayer; addFigure's templates and ids; figureFor's resolution
%   (Defaults, panel overrides, sharesTime, units.source, the observe kind,
%   options completed and re-seeded on a type change); a JSON round trip
%   with every panel type, relative sizes, an events layer with a sequence,
%   fixed and following layers and "default" sentinels, a cell Figures
%   from jsondecode, unknown fields in LoadWarnings; the grid editors
%   (placePanel in four directions, removePanel, movePanel, figureCells);
%   DuplicateFigureId / DuplicatePanelId; every validate rule of the
%   Figures section, and the Plots style messages unchanged by the
%   shared checkStyle.
%   Compute (7), on makeAnalysisFixture's "clean" dataset:
%   figureObservations (the filter's units in probe order, a tightened
%   filter, the LFP channels of a continuous figure, one row for a dataset
%   figure); computeFigure of the raster + PSTH figure (the first
%   observation by default, one unit in each layer, the PSTH equal to
%   computePlot's, Observation= as a row or a struct); an LFP layer
%   following the unit (its recording channel's column), a fixed AUX layer
%   with aggregate "mean" (R.layerMean) and an AUX layer following the unit
%   (skipped with its reason, in figureSkipReason too); a fixed layer of
%   three units averaged; events as marks (epochEvents) and as a train (a
%   one-unit PSTH peaking at 0 when aligned to its own line); a panel's own
%   window (its epochs, the figure's groups); a channel observation (its
%   column, the MUA column of the same channel, the units on it); a raster sorted by a
%   missing parameter skipped while the PSTH under it is computed; a
%   signal's baseline with no sample in the window skipping its layer;
%   probemap, corrmap and waveforms as computePlot's; PollFcn checkpoints
%   and cancel; figureCompute (no runner) equal to computeFigure, its
%   Check=; figureOutputName's names and figureCaption; a rate panel and a
%   tuning panel equal to computePlot's rate / tuning of the unit (the
%   tuning parameter from groupBy, else the first numeric one; a series
%   and the waveform inset; a missing parameter skipping the panel); a
%   rate layer of three units' mean; an auROC PSTH equal to computePlot's;
%   a stacked PSTH; the waveforms' probe layout (a following layer to
%   ring); one observation faster than computePlot over every unit.
%   Render (8): figureTiles (relative sizes in quarter steps, spans, the
%   32-unit cap); a compute and a draw function for every panel type;
%   every panel type drawn by renderFigure into an axes, a uiaxes, a
%   figure, a uipanel and a grid layout, every component tagged with a
%   known role and the tiles named by panel; the title (automatic, and the
%   figure's own with the observation on the top-left panel); one time axis
%   down a stack (the window on every time panel, tick labels and "Time
%   (s)" at the bottom only, a panel's own window kept); one legend, each
%   group once; skipped layers' notes; events marks on a raster and as
%   latency lines and a rug on a PSTH; a stacked continuous panel of marks
%   alone; a raster of
%   five blocks keeping every block's name; a raster over a waveforms
%   panel keeping its time axis; a stacked PSTH (rows, the legend's
%   groups once, one group overlaid, a second layer in the rows), an
%   auROC PSTH (0-1, chance line, modulation window, calls; stacked too)
%   and heat map (diverging, 0-1), rate panels (bars, boxes of two
%   layers, points), tuning curves (a series, the inset), the waveforms'
%   probe layout with the observed unit framed; figureTiles' order past its cap;
%   Editable, OnRemember and the context's redraw; the editor's colormap;
%   one observation drawn in under a second.
%
%   Usage:  test_EphysAnalysisFigures

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);

root = fullfile(tempdir, sprintf('AnaFigures_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
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
    function tf = has(cfg, field, sev)
        % a Figures issue with exactly this Field and Severity
        I = cfg.validate(CheckPaths=false);
        tf = any(I.Section == "Figures" & I.Field == field & I.Severity == sev);
    end
    function I = figIssues(cfg)
        I = cfg.validate(CheckPaths=false);
        I = I(I.Section == "Figures", :);
    end

T = EphysAnalysisConfig.panelTypes();
types = ["raster" "psth" "continuous" "heatmap" "waveforms" "probemap" "corrmap" "rate" "tuning"];
place = @EphysAnalysisConfig.placePanel;
remove = @EphysAnalysisConfig.removePanel;
move = @EphysAnalysisConfig.movePanel;
cellsOf = @EphysAnalysisConfig.figureCells;
layerOf = @EphysAnalysisConfig.defaultLayer;

%% ============================================================================ config
fprintf('\n== 1. config: defaults and the tables ==\n');
F = EphysAnalysisConfig.defaults("Figure");
check(F.id == "" && F.enabled && F.title == "" && F.observe.kind == "auto" && isequal(F.ref, "default") ...
    && isequal(F.window, "default") && isequal(F.selection, "default") && isequaln(F.style, EphysAnalysisConfig.defaults("Style")) ...
    && isempty(F.aesthetics) && isstruct(F.panels) && isempty(F.panels), 'defaults("Figure")');
check(F.grid.rows == 1 && F.grid.cols == 1 && isequal(F.grid.rowHeights, []) && isequal(F.grid.colWidths, []) ...
    && F.grid.spacing == "tight", 'a figure''s grid: 1 x 1, equal sizes ([]), tight');
check(isequal(fieldnames(F.panels), fieldnames(EphysAnalysisConfig.defaults("Panel"))), 'Figure.panels is an empty list of Panels');
P = EphysAnalysisConfig.defaults("Panel");
check(P.id == "" && P.type == "psth" && P.title == "" && P.row == 1 && P.col == 1 && P.rowSpan == 1 && P.colSpan == 1 ...
    && isequal(P.ref, "default") && isequal(P.window, "default") && isempty(P.layers) ...
    && isequal(fieldnames(P.layers), fieldnames(EphysAnalysisConfig.defaults("Layer"))) ...
    && isequaln(P.options, T.DefaultOptions{T.Type == "psth"}), 'defaults("Panel"): a PSTH with its options, no layers');
L = EphysAnalysisConfig.defaults("Layer");
check(L.name == "" && L.enabled && L.source == "units" && L.binding == "observation" && ~isfield(L.units, 'source') ...
    && isequaln(L.units, rmfield(EphysAnalysisConfig.defaults("UnitSelection"), 'source')) && isequal(L.channels, []) ...
    && L.aggregate == "each" && isequaln(L.event, EphysAnalysisConfig.defaults("EventMark")) && L.eventsAs == "marks" ...
    && L.color == "" && L.lineStyle == "" && ~isfield(L, 'yParam') && ~isfield(L, 'seriesParam'), 'defaults("Layer")');
O = EphysAnalysisConfig.defaults("Observe");
check(O.kind == "auto" && O.source == "units" && ~isfield(O.units, 'source') && O.signal == "LFP" && isequal(O.channels, []) ...
    && O.datasets == "ticked" && isstring(O.datasetKeys) && isequal(size(O.datasetKeys), [1 0]), 'defaults("Observe")');

check(isequal(T.Type.', types) && isequal(string(T.Properties.VariableNames), ["Type" "Label" "Categories" "Aligned" ...
    "SharesTime" "OneGroup" "MultiLayer" "DefaultBinding" "Description" "DefaultOptions"]), 'panelTypes: the nine types and the columns');
check(isequal(T.SharesTime.', [true true true true false false false false false]) && isequal(T.Aligned.', [true true true true false false true true true]) ...
    && isequal(T.OneGroup.', [false false false true false false true false false]) && isequal(T.MultiLayer.', [true true true false false false false true true]) ...
    && isequal(T.DefaultBinding.', ["observation" "observation" "observation" "fixed" "observation" "fixed" "fixed" "observation" "observation"]) ...
    && isequal(T.Categories{T.Type == "rate"}, "point") && isequal(T.Categories{T.Type == "tuning"}, "point") && T.Label(8) == "Firing rate" && T.Label(9) == "Tuning curve" ...
    && isequal(T.Categories{T.Type == "heatmap"}, ["point" "continuous"]), 'panelTypes: aligned, shared time, one group, layers, binding, categories');
O = T.DefaultOptions;
check(isempty(O{1}.rasterSortEvent) && O{1}.rasterSortOrder == "ascending" && O{1}.waveform.mode == "off" ...
    && O{2}.bins.BinSec == 0.01 && O{2}.histStyle == "bar" && isnan(O{2}.fillAlpha) && isequal(O{2}.yLim, []) ...
    && O{3}.display == "lines" && O{3}.errorType == "sem" && isnan(O{3}.stackSpacing) ...
    && O{4}.order == "probe" && O{4}.group == 1 && O{5}.waveform.mode == "both" ...
    && O{6}.value == "rate" && O{7}.metric == "mean" && O{7}.correlation == "pearson" && ~O{7}.fisherZ ...
    && ~O{2}.stack && O{2}.stackSpacing == 1.1 && isequaln(O{2}.auroc, EphysAnalysisConfig.defaults("Auroc")) ...
    && isequaln(O{4}.auroc, EphysAnalysisConfig.defaults("Auroc")) && O{5}.layout == "grid" ...
    && isequal(string(fieldnames(O{8})).', ["measure" "baseline" "display" "yLim"]) && O{8}.display == "bar" && O{8}.measure == "rate" ...
    && O{8}.baseline.Mode == "none" && isequal(O{8}.yLim, []) ...
    && isequal(string(fieldnames(O{9})).', ["param" "seriesParam" "measure" "baseline" "yLim" "waveform"]) && O{9}.param == "" ...
    && O{9}.seriesParam == "" && O{9}.waveform.mode == "off", ...
    'panelTypes: each type''s DefaultOptions (psth stack / auroc, heatmap auroc, waveforms layout, rate, tuning)');
S = EphysAnalysisConfig.sourceCategories();
check(isequal(S.Category.', ["point" "continuous" "unit"]) && isequal(S.Sources{1}, ["units" "detected" "events"]) ...
    && isequal(S.Sources{3}, ["units" "detected"]) && isequal(S.Aligned.', [true true false]), 'sourceCategories (no trial category)');
check(isequal(EphysAnalysisConfig.FigureSources, ["units" "detected" "events" "LFP" "MUA" "SPIKE" "AUX"]), 'FigureSources (no trials)');
catOf = @EphysAnalysisConfig.categoryOf;
check(catOf("units", "raster") == "point" && catOf("detected", "waveforms") == "unit" && catOf("units", "corrmap") == "unit" ...
    && catOf("LFP", "heatmap") == "continuous" && catOf("units", "heatmap") == "point" ...
    && catOf("trials", "heatmap") == "" && catOf("units", "behavior") == "" && catOf("LFP", "raster") == "" && catOf("units", "continuous") == "" && catOf("units", "nope") == "", ...
    'categoryOf: the category a type draws a source in, else ""');
check(catOf("events", "continuous") == "point" && catOf("events", "heatmap") == "point" && catOf("events", "raster") == "point" ...
    && catOf("events", "waveforms") == "" && catOf("events", "probemap") == "", 'categoryOf: events fit every time panel, and no other');
D1 = layerOf("continuous");
D2 = layerOf("probemap");
D3 = layerOf("heatmap");
D4 = layerOf("waveforms");
check(D1.source == "LFP" && D1.binding == "observation" && D2.source == "units" && D2.binding == "fixed" ...
    && D3.source == "units" && D3.binding == "fixed" && D4.source == "units" && D4.binding == "observation", ...
    'defaultLayer: the type''s first source with its default binding');
check(strcmp(errorId(@() layerOf("violin")), 'EphysAnalysisConfig:BadValue') && strcmp(errorId(@() layerOf("behavior")), 'EphysAnalysisConfig:BadValue'), ...
    'defaultLayer of an unknown type (behavior is not a panel type): BadValue');
C = EphysAnalysisConfig.defaults("FigureCommon");
fnF = string(fieldnames(F)).';
check(isequal(string(fieldnames(C)).', ["bins" "measure" "baseline" "auroc" "maskAfterStop" "waveform"]) && C.bins.BinSec == 0.01 ...
    && isequaln(C.auroc, EphysAnalysisConfig.defaults("Auroc")) ...
    && C.bins.SmoothSec == 0.01 && C.measure == "rate" && C.baseline.Mode == "none" && isequal(C.baseline.Window, [-0.2 0]) ...
    && ~C.maskAfterStop && isequal(C.waveform, EphysAnalysisConfig.defaults("Waveform")) && isequaln(F.common, C) ...
    && find(fnF == "common") == find(fnF == "grid") + 1, 'defaults("FigureCommon"), and Figure.common after grid');
fnP = string(fieldnames(P)).';
check(P.common == true && islogical(P.common) && find(fnP == "selection") == find(fnP == "window") + 1 ...
    && find(fnP == "common") == find(fnP == "selection") + 1 && isequal(P.selection, "default"), ...
    'Panel.selection: "default", after window; Panel.common: true, after it');
Oc = T.DefaultOptions{T.Type == "continuous"};
Oh = T.DefaultOptions{T.Type == "heatmap"};
check(Oc.trials == "off" && isinf(Oc.maxTrials) && Oh.rows == "items" && Oh.rasterSort == "" && isempty(Oh.rasterSortEvent) ...
    && Oh.rasterSortOrder == "ascending" && Oh.rasterByGroup && ~EphysAnalysisConfig.defaults("Observe").perGroup, ...
    'continuous trials "off", maxTrials Inf; heat map rows "items" with a raster''s sort fields; observe.perGroup false');
cfo = @EphysAnalysisConfig.commonFieldsOf;
check(isequal(EphysAnalysisConfig.commonFields(), ["bins" "measure" "baseline" "auroc" "maskAfterStop" "waveform"]) ...
    && isequal(cfo("raster"), ["maskAfterStop" "waveform"]) && isequal(cfo("psth"), ["bins" "measure" "baseline" "auroc" "maskAfterStop" "waveform"]) ...
    && isequal(cfo("continuous"), "baseline") && isequal(cfo("heatmap"), ["bins" "measure" "baseline" "auroc" "maskAfterStop"]) ...
    && isequal(cfo("rate"), ["measure" "baseline"]) && isequal(cfo("tuning"), ["measure" "baseline" "waveform"]) ...
    && isequal(cfo("waveforms"), "waveform") && isequal(cfo("corrmap"), ["bins" "baseline"]) ...
    && isempty(cfo("probemap")) && isempty(cfo("violin")), 'commonFields and commonFieldsOf(type)');

fu = EphysAnalysisConfig.normalizeFigure(struct('panels', {{struct('type', "raster", 'layers', layerOf("raster"))}}));
fc = EphysAnalysisConfig.normalizeFigure(struct('panels', {{struct('type', "continuous", 'layers', layerOf("continuous"))}}));
fd = EphysAnalysisConfig.normalizeFigure(struct('panels', {{struct('type', "probemap", 'layers', layerOf("probemap"))}}));
foff = fu; foff.panels(1).layers(1).enabled = false;
fx = fd; fx.observe.kind = "channel";
check(EphysAnalysisConfig.observeKind(fu) == "unit" && EphysAnalysisConfig.observeKind(fc) == "channel" ...
    && EphysAnalysisConfig.observeKind(fd) == "dataset" && EphysAnalysisConfig.observeKind(foff) == "dataset" ...
    && EphysAnalysisConfig.observeKind(fx) == "channel", ...
    'observeKind: auto -> unit (a spike layer follows), channel (a signal layer), dataset (none; a disabled layer does not count); explicit kinds kept');

fprintf('\n== 2. config: addFigure, templates and ids ==\n');
FT = EphysAnalysisConfig.figureTemplates();
check(FT.Template(1) == "rasterPsth" && FT.Label(1) == "Raster over PSTH (per unit)" ...
    && isequal(FT.Template(2:end-1).', ["psth" "raster" "continuous" "heatmap" "waveforms" "probemap" "corrmap" "rate" "tuning"]) ...
    && FT.Template(end) == "blank", 'figureTemplates: rasterPsth first, one per type, blank last');
ct = EphysAnalysisConfig();
ct = ct.addFigure("rate");
ct = ct.addFigure("tuning");
check(ct.Figures(1).panels.id == "rate_1" && ct.Figures(2).panels.id == "tuning_1" && isscalar(ct.Figures(1).panels.layers) ...
    && ct.Figures(1).panels.layers.source == "units" && ct.Figures(1).panels.layers.binding == "observation" ...
    && ct.Figures(2).panels.layers.source == "units" && ct.Figures(2).panels.layers.binding == "observation" ...
    && FT.Label(FT.Template == "rate") == "Firing rate" && FT.Label(FT.Template == "tuning") == "Tuning curve", ...
    'the rate and tuning templates: one panel, one units layer following the observed unit');
cfg = EphysAnalysisConfig();
[cfg, id1] = cfg.addFigure();
f1 = cfg.Figures(1);
check(id1 == "figure_1" && f1.grid.rows == 2 && f1.grid.cols == 1 && isequal(f1.grid.rowHeights, [1 1]) && f1.grid.spacing == "none" ...
    && isequal([f1.panels.id], ["raster_1" "psth_1"]) && isequal([f1.panels.row], [1 2]) && isequal([f1.panels.col], [1 1]), ...
    'addFigure(): figure_1, raster_1 flush over psth_1 on a 2 x 1 grid');
check(isscalar(f1.panels(1).layers) && isscalar(f1.panels(2).layers) && f1.panels(1).layers.source == "units" ...
    && f1.panels(1).layers.binding == "observation" && f1.panels(2).layers.binding == "observation", ...
    'rasterPsth: each panel one units layer following the observation');
[cfg, id2] = cfg.addFigure("continuous");
[cfg, id3] = cfg.addFigure("blank", Id="empty");
[cfg, id4] = cfg.addFigure(struct('panels', struct('type', "heatmap")));
check(isequal([id2 id3 id4], ["figure_2" "empty" "figure_3"]) && cfg.Figures(2).panels.id == "continuous_1" ...
    && cfg.Figures(2).panels.layers.source == "LFP" && isempty(cfg.Figures(3).panels) && cfg.Figures(4).panels.id == "heatmap_1", ...
    'addFigure: free ids "figure_<n>", a given id, single-type and blank templates, a partial struct gets panel ids');
check(strcmp(errorId(@() cfg.addFigure("nope")), 'EphysAnalysisConfig:BadValue'), 'an unknown template: BadValue');
check(strcmp(errorId(@() cfg.addFigure("psth", Id="figure_1")), 'EphysAnalysisConfig:DuplicateFigureId'), 'a taken id: DuplicateFigureId');
cfg.Figures(3).enabled = false;
check(isequal(cfg.figureIds(), ["figure_1" "figure_2" "empty" "figure_3"]) && cfg.figureIndex("empty") == 3 && cfg.figureIndex("x") == 0 ...
    && isequal(cfg.enabledFigures(), ["figure_1" "figure_2" "figure_3"]), 'figureIds, figureIndex, enabledFigures');
c2 = cfg.removeFigure("empty");
check(isequal(c2.figureIds(), ["figure_1" "figure_2" "figure_3"]) && strcmp(errorId(@() cfg.removeFigure("x")), 'EphysAnalysisConfig:NoFigure'), ...
    'removeFigure (NoFigure for an unknown id)');
c2.Figures = {struct(), struct('id', "figure_1")};
check(isequal(c2.figureIds(), ["figure_2" "figure_1"]), 'a cell of partial figures gets free ids');
check(strcmp(errorId(@() setFigures(c2, [cfg.Figures(1) cfg.Figures(1)])), 'EphysAnalysisConfig:DuplicateFigureId'), ...
    'two figures with one id: DuplicateFigureId');
dupPanels = struct('panels', {{struct('id', "a", 'type', "psth"), struct('id', "a", 'type', "raster")}});
check(strcmp(errorId(@() setFigures(c2, dupPanels)), 'EphysAnalysisConfig:DuplicatePanelId'), 'two panels with one id: DuplicatePanelId');
c2.Figures = [];
check(isempty(c2.Figures) && isstruct(c2.Figures), 'Figures = [] empties them');

fprintf('\n== 3. config: figureFor ==\n');
cfg = EphysAnalysisConfig();
cfg.Defaults.EventRef.line = "Platform";
cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.5, 'post', 1.5);
cfg.Defaults.Selection.groupBy = "Depth";
cfg = cfg.addFigure();
cfg = cfg.addFigure("continuous");
cfg = cfg.addFigure("probemap");
s = cfg.figureFor("figure_1");
check(isequaln(s.ref, cfg.Defaults.EventRef) && isequaln(s.window, cfg.Defaults.Window) && isequaln(s.selection, cfg.Defaults.Selection), ...
    'figureFor: the figure''s "default" ref / window / selection from Defaults');
check(s.observe.kind == "unit" && s.observe.units.source == "units" ...
    && isequal(fieldnames(s.observe.units), fieldnames(EphysAnalysisConfig.defaults("UnitSelection"))), ...
    'figureFor: observe.kind auto -> unit, and a complete observe.units (source = observe.source)');
check(all([s.panels.aligned]) && all([s.panels.sharesTime]) && isequaln(s.panels(1).ref, s.ref) && isequaln(s.panels(2).window, s.window), ...
    'figureFor: panels take the figure''s ref and window, aligned and sharing its time');
Lr = s.panels(1).layers;
check(Lr.category == "point" && Lr.units.source == "units" && isequal(fieldnames(Lr.units), fieldnames(EphysAnalysisConfig.defaults("UnitSelection"))), ...
    'figureFor: a layer''s category and units.source');
check(isequal(sort(fieldnames(s.panels(2).options)), sort(fieldnames(T.DefaultOptions{T.Type == "psth"}))), 'figureFor: options complete');
cfg.Figures(1).panels(2).window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.3);
cfg.Figures(1).panels(1).ref = struct('line', "Stim", 'edge', "offset");
s = cfg.figureFor(1);
check(~s.panels(1).sharesTime && ~s.panels(2).sharesTime && s.panels(2).window.post == 0.3 && s.panels(1).ref.edge == "offset" ...
    && isequaln(s.panels(1).window, s.window) && isequaln(s.panels(2).ref, s.ref), ...
    'a panel''s own ref or window: kept, the other part from the figure, and it no longer shares time');
s = cfg.figureFor("figure_2");
check(s.observe.kind == "channel" && s.panels.layers.category == "continuous" && s.panels.layers.units.source == "LFP", ...
    'figureFor: a following LFP layer -> channel observations');
s = cfg.figureFor("figure_3");
check(s.observe.kind == "dataset" && ~s.panels.aligned && ~s.panels.sharesTime && s.panels.layers.category == "unit", ...
    'figureFor: a probe map with a fixed layer -> the dataset; not aligned');
check(strcmp(errorId(@() cfg.figureFor("x")), 'EphysAnalysisConfig:NoFigure') && strcmp(errorId(@() cfg.figureFor(9)), 'EphysAnalysisConfig:NoFigure'), ...
    'figureFor: NoFigure');
cfg.Figures(1).panels(2).options.bins.BinSec = 0.02;
cfg.Figures(1).panels(2).options.histStyle = "line";
cfg.Figures(1).panels(2).type = "heatmap";
op = cfg.Figures(1).panels(2).options;
check(isequal(sort(fieldnames(op)), sort(fieldnames(T.DefaultOptions{T.Type == "heatmap"}))) && op.bins.BinSec == 0.02 && ~isfield(op, 'histStyle'), ...
    'a type change re-seeds the options: the new type''s fields, shared values kept, the others dropped');
cfg.Figures(1).panels(2).type = "violin";
s = cfg.figureFor(1);
check(isempty(fieldnames(cfg.Figures(1).panels(2).options)) && ~s.panels(2).aligned && s.panels(2).layers.category == "", ...
    'an unknown type keeps empty options (validate reports it)');
cc = EphysAnalysisConfig();
cc = cc.addFigure();
cc = cc.addFigure("waveforms", Id="wf");
cc.Figures(1).common.bins = struct('BinSec', 0.05, 'SmoothSec', 0);
cc.Figures(1).common.baseline = struct('Mode', "zscore", 'Window', [-0.3 0]);
cc.Figures(1).common.waveform.mode = "mean";
cc.Figures(1).panels(2).options.histStyle = "line";
cc.Figures(1).panels(2).options.bins.BinSec = 0.002;
s = cc.figureFor(1);
check(s.panels(2).common && s.panels(2).options.bins.BinSec == 0.05 && s.panels(2).options.bins.SmoothSec == 0 ...
    && s.panels(2).options.baseline.Mode == "zscore" && s.panels(2).options.histStyle == "line" ...
    && s.panels(1).options.waveform.mode == "mean" && s.panels(2).options.waveform.mode == "mean" && isequaln(s.common, cc.Figures(1).common), ...
    'figureFor: a linked PSTH takes the common bins, baseline and waveform, and keeps its own type-specific options');
cc.Figures(1).panels(2).common = false;
s = cc.figureFor(1);
check(~s.panels(2).common && s.panels(2).options.bins.BinSec == 0.002 && s.panels(2).options.baseline.Mode == "none" ...
    && s.panels(2).options.waveform.mode == "off" && s.panels(1).options.waveform.mode == "mean", ...
    'figureFor: an unlinked PSTH keeps its own; the linked raster still takes the common waveform');
s = cc.figureFor("wf");
cc.Figures(2).common.waveform.mode = "subsample";
s2 = cc.figureFor("wf");
check(s.panels.common && s.panels.options.waveform.mode == "both" && s2.panels.options.waveform.mode == "subsample", ...
    'figureFor: a waveforms panel takes the common waveform, its mode "off" drawn as "both"');
ca = EphysAnalysisConfig();
ca.Defaults.Selection.groupBy = "Depth";
ca = ca.addFigure();
ca = ca.addFigure("heatmap", Id="hm");
ca = ca.addFigure("rate", Id="rt");
ca = ca.addFigure("tuning", Id="tc");
ca.Figures(1).common.baseline = struct('Mode', "auroc", 'Window', [-0.3 0]);
ca.Figures(1).common.auroc.windowSec = 0.05;
ca.Figures(1).common.auroc.cutoff = "fixed";
ca.Figures(1).panels(2).options.stack = true;
ca.Figures(1).panels(2).options.stackSpacing = 1.4;
ca.Figures(2).common.baseline.Mode = "auroc";
ca.Figures(2).common.auroc.modulationWindow = [0 0.2];
ca.Figures(3).common.measure = "count";
ca.Figures(3).common.baseline = struct('Mode', "zscore", 'Window', [-0.4 0]);
ca.Figures(3).panels.options.display = "points";
ca.Figures(4).panels.options.param = "Depth";
ca.Figures(4).panels.options.seriesParam = "TrialType";
ca.Figures(4).common.waveform.mode = "mean";
s = ca.figureFor(1);
s2 = ca.figureFor("hm");
s3 = ca.figureFor("rt");
s4 = ca.figureFor("tc");
check(s.panels(2).options.baseline.Mode == "auroc" && s.panels(2).options.auroc.windowSec == 0.05 && s.panels(2).options.auroc.cutoff == "fixed" ...
    && s.panels(2).options.stack && s.panels(2).options.stackSpacing == 1.4 && ~isfield(s.panels(1).options, 'auroc') ...
    && s2.panels.options.baseline.Mode == "auroc" && isequal(s2.panels.options.auroc.modulationWindow, [0 0.2]), ...
    'figureFor: a linked PSTH and heat map take the common auroc settings; the PSTH keeps its own stack options');
check(s3.panels.aligned && ~s3.panels.sharesTime && s3.panels.options.measure == "count" && s3.panels.options.baseline.Mode == "zscore" ...
    && s3.panels.options.display == "points" && s3.panels.layers.category == "point" ...
    && s4.panels.aligned && ~s4.panels.sharesTime && s4.panels.options.param == "Depth" && s4.panels.options.seriesParam == "TrialType" ...
    && s4.panels.options.waveform.mode == "mean" && s4.observe.kind == "unit", ...
    'figureFor: rate and tuning panels: aligned, not on the time axis, the common measure / baseline / waveform, their own display / param / series');
cw = EphysAnalysisConfig();
cw = cw.addFigure("waveforms");
cw.Figures(1).panels.options.layout = "probe";
cw2 = cw; cw2.Figures(1).panels.options.layout = "grid";
check(cw.figureFor(1).panels.options.layout == "probe" && cw2.figureFor(1).panels.options.layout == "grid", 'figureFor: the waveforms layout');
cs = EphysAnalysisConfig();
cs.Defaults.Selection.groupBy = "Depth";
cs = cs.addFigure();
cs.Figures(1).panels(2).selection = struct('groupBy', "TrialType");
s = cs.figureFor(1);
check(isequaln(s.panels(1).selection, cs.Defaults.Selection) && isstruct(s.panels(2).selection) ...
    && isequal(s.panels(2).selection.groupBy, "TrialType") && s.panels(2).sharesTime && s.panels(1).sharesTime, ...
    'figureFor: a panel''s "default" selection is the figure''s; its own is kept, and time stays shared (ref + window only)');
ap2 = cs.Figures(1);
ap2.panels(1).window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.2);
al3 = EphysAnalysisConfig.adoptPanelAlignment(ap2, "psth_1");
rl3 = EphysAnalysisConfig.relinkPanels(ap2);
check(isequal(al3.selection.groupBy, "TrialType") && all(arrayfun(@(p) isequal(p.selection, "default"), al3.panels)) ...
    && isequal(al3.window, "default") && all(arrayfun(@(p) isequal(p.selection, "default") && isequal(p.window, "default"), rl3.panels)), ...
    'adoptPanelAlignment takes a panel''s own selection as the figure''s; both link every panel''s selection again');

fprintf('\n== 4. config: a JSON round trip ==\n');
cfg = EphysAnalysisConfig();
cfg.Source.Root = root;
cfg = cfg.addPlot("psth");
Pc = cell(1, numel(types));
for t = 1:numel(types)
    Pc{t} = struct('type', types(t), 'row', ceil(t / 2), 'col', 2 - mod(t, 2), 'layers', layerOf(types(t)));
end
ev = layerOf("raster");
ev.source = "events"; ev.binding = "fixed"; ev.name = "licks after a trough";
ev.event.line = "Lick"; ev.event.marker = "|"; ev.event.color = "#ff0000"; ev.event.size = 6;
ev.event.sequence = struct('line', {"Trough" "Stim"}, 'maxGapSec', {1 Inf}, 'relation', {"followedBy" "notFollowedBy"});
Pc{1}.layers = [Pc{1}.layers, ev];
Pc{1}.options = struct('rasterSort', "event", 'rasterSortEvent', struct('line', "Platform", 'edge', "offset"), 'waveform', struct('mode', "mean"));
fixedUnits = layerOf("psth");
fixedUnits.binding = "fixed"; fixedUnits.units.ids = [3 5]; fixedUnits.aggregate = "mean"; fixedUnits.color = "#1f77b4"; fixedUnits.lineStyle = "--";
Pc{2}.layers = [Pc{2}.layers, fixedUnits];
Pc{2}.options = struct('yLim', [0 50], 'baseline', struct('Mode', "zscore", 'Window', [-0.3 0]), 'stack', true, 'stackSpacing', 1.3, ...
    'auroc', struct('windows', "sliding", 'stepSec', 0.02, 'modulationWindow', [0 0.3]));
Pc{2}.window = struct('mode', "fixed", 'pre', -0.5, 'post', 1);
aux = layerOf("continuous");
aux.source = "AUX"; aux.binding = "fixed"; aux.channels = [1 2]; aux.aggregate = "mean";
Pc{3}.layers = [Pc{3}.layers, aux];
Pc{3}.options = struct('errorType', "std", 'display', "stacked");
Pc{4}.layers.source = "LFP"; Pc{4}.layers.channels = [1 2 3];
Pc{4}.options = struct('cLim', [-1 1], 'group', 2);
Pc{6}.options = struct('value', "nUnits");
Pc{7}.ref = struct('line', "Platform");
Pc{7}.window = struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Platform", 'edge', "offset"));
Pc{5}.options = struct('layout', "probe");
Pc{8}.options = struct('display', "points", 'measure', "probability", 'baseline', struct('Mode', "ratio", 'Window', [-0.3 0]));
Pc{9}.options = struct('param', "Depth", 'seriesParam', "TrialType", 'yLim', [0 20]);
allTypes = struct('id', "all_types", 'title', "Every panel type", ...
    'observe', struct('kind', "unit", 'datasets', "list", 'datasetKeys', ["S1/a" "S2/b"], 'units', struct('classes', "su", 'maxUnits', 4)), ...
    'grid', struct('rows', 5, 'cols', 2, 'rowHeights', [1 1.5 1 1 1], 'colWidths', [2 1], 'spacing', "compact"), ...
    'panels', {Pc}, 'ref', struct('line', "Stim", 'timeRange', [0 Inf]), 'selection', struct('groupBy', ["Depth" "TrialType"]), ...
    'aesthetics', struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2));
cfg = cfg.addFigure(allTypes);
cfg = cfg.addFigure("rasterPsth", Id="unit_card");
cfg.Figures(2).grid.rowHeights = [1 1.5];
f = fullfile(root, 'figures.json');
cfg.save(f);
txt = fileread(f);
c2 = EphysAnalysisConfig.load(f);
check(cfg.isequalConfig(c2) && isempty(c2.LoadWarnings), 'a config with figures survives save / load exactly');
fn = string(fieldnames(cfg.toStruct())).';
check(find(fn == "Figures") == find(fn == "Plots") + 1 && contains(txt, '"Figures"') && contains(txt, '"rowHeights"'), ...
    'toStruct writes Figures after Plots');
g = c2.Figures(1);
check(isequal(g.grid.rowHeights, [1 1.5 1 1 1]) && isequal(g.grid.colWidths, [2 1]) && isequal(c2.Figures(2).grid.rowHeights, [1 1.5]) ...
    && isequal(c2.Figures(2).grid.colWidths, []), 'relative sizes come back as rows; [] stays []');
check(isequal([g.panels.type], types) && isequal([g.panels.id], types + "_1") && g.panels(3).options.display == "stacked" ...
    && g.panels(6).options.value == "nUnits" && g.panels(4).options.group == 2, ...
    'every panel type, with its options');
check(g.panels(2).options.stack && g.panels(2).options.stackSpacing == 1.3 && g.panels(2).options.auroc.windows == "sliding" ...
    && g.panels(2).options.auroc.stepSec == 0.02 && isequal(g.panels(2).options.auroc.modulationWindow, [0 0.3]) ...
    && g.panels(2).options.auroc.windowSec == 0.1 && g.panels(5).options.layout == "probe" ...
    && g.panels(8).options.display == "points" && g.panels(8).options.measure == "probability" && g.panels(8).options.baseline.Mode == "ratio" ...
    && g.panels(9).options.param == "Depth" && g.panels(9).options.seriesParam == "TrialType" && isequal(g.panels(9).options.yLim, [0 20]), ...
    'the PSTH''s stack and auroc, the waveforms layout, the rate and tuning options');
e = g.panels(1).layers(2);
check(e.source == "events" && e.binding == "fixed" && numel(e.event.sequence) == 2 && e.event.sequence(2).relation == "notFollowedBy" ...
    && isinf(e.event.sequence(2).maxGapSec) && e.event.sequence(1).maxGapSec == 1 && e.event.marker == "|" && e.event.color == "#ff0000" ...
    && e.event.size == 6 && e.name == "licks after a trough", 'an events layer with a sequence');
check(isequal(g.panels(2).layers(2).units.ids, [3 5]) && g.panels(2).layers(2).aggregate == "mean" && g.panels(2).layers(1).binding == "observation" ...
    && g.panels(2).layers(2).lineStyle == "--" && isequal(g.panels(3).layers(2).channels, [1 2]) && isequal(g.panels(4).layers.channels, [1 2 3]), ...
    'fixed and following layers');
check(isequal(c2.Figures(2).ref, "default") && isequal(c2.Figures(2).window, "default") && isequal(c2.Figures(2).panels(1).ref, "default") ...
    && isstruct(g.panels(2).window) && isequal(g.panels(2).ref, "default") && isstruct(g.panels(7).window.stop) ...
    && g.panels(7).window.mode == "between" && isequal(g.ref.timeRange, [0 Inf]), '"default" sentinels and overrides');
check(isequal(g.observe.datasetKeys, ["S1/a" "S2/b"]) && isequal(g.observe.units.classes, "su") && g.observe.units.maxUnits == 4 ...
    && isequal(g.selection.groupBy, ["Depth" "TrialType"]) && isscalar(g.aesthetics) && isstruct(g.panels(1).options.rasterSortEvent) ...
    && g.panels(1).options.rasterSortEvent.edge == "offset" && isnan(g.panels(2).options.fillAlpha) && g.panels(2).options.baseline.Mode == "zscore", ...
    'lists of one and two, an event to sort by, NaN and aesthetics');

s = cfg.toStruct();
s.Figures(1).bogus = 1;
s.Figures(1).observe.qux = 1;
s.Figures(1).panels(1).foo = 1;
s.Figures(1).panels(1).layers(1).bar = 1;
s.Figures(1).panels(1).options.baz = 1;
f2 = fullfile(root, 'unknown.json');
writeJsonFile(f2, s, NonFinite="string");
ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
c3 = EphysAnalysisConfig.load(f2);
warning(ws);
w = strjoin(c3.LoadWarnings, " | ");
check(contains(w, "Figures: dropped unknown field(s)") && contains(w, "Figures(1).bogus") && contains(w, "Figures(1).observe.qux") ...
    && contains(w, "Figures(1).panels(1).foo") && contains(w, "Figures(1).panels(1).layers(1).bar") ...
    && contains(w, "Figures(1).panels(1).options.baz") && ~contains(w, "top-level"), ...
    'unknown figure, observe, panel, layer and options fields are dropped and listed in LoadWarnings');
check(c3.isequalConfig(cfg), 'and the rest loads unchanged');
cj = cfg;
cj.Figures(1).common = struct('bins', struct('BinSec', 0.02, 'SmoothSec', 0), 'measure', "count", ...
    'baseline', struct('Mode', "subtract", 'Window', [-0.5 -0.1]), 'maskAfterStop', true, 'waveform', struct('mode', "both", 'scale', 1.5));
cj.Figures(1).panels(2).common = false;
fj = fullfile(root, 'common.json');
cj.save(fj);
cj2 = EphysAnalysisConfig.load(fj);
check(cj.isequalConfig(cj2) && isempty(cj2.LoadWarnings) && cj2.Figures(1).common.measure == "count" ...
    && cj2.Figures(1).common.waveform.scale == 1.5 && ~cj2.Figures(1).panels(2).common && cj2.Figures(1).panels(1).common ...
    && cj2.Figures(2).panels(1).common && contains(fileread(fj), '"common"'), ...
    'the common options and a panel''s common = false survive save / load');
rpt = EphysAnalysisConfig();
rpt = rpt.addFigure("rasterPsth");
rpt.save(fj);
check(rpt.isequalConfig(EphysAnalysisConfig.load(fj)), 'the rasterPsth template round-trips (its panels linked)');
rn4 = EphysAnalysisConfig();
rn4 = rn4.addFigure("rasterPsth");
rn4 = rn4.addFigure("continuous", Id="ct4");
rn4 = rn4.addFigure("heatmap", Id="hm4");
rn4.Figures(1).observe.perGroup = true;
rn4.Figures(1).panels(2).selection = struct('groupBy', "TrialType", 'filter', "Depth > 0");
rn4.Figures(2).panels.options.trials = "faint";
rn4.Figures(2).panels.options.maxTrials = 25;
rn4.Figures(3).panels.options.rows = "trials";
rn4.Figures(3).panels.options.rasterSort = "Depth";
rn4.Figures(3).panels.options.rasterSortOrder = "descending";
rn4.save(fj);
rn5 = EphysAnalysisConfig.load(fj);
check(rn4.isequalConfig(rn5) && isempty(rn5.LoadWarnings) && rn5.Figures(1).observe.perGroup ...
    && isequal(rn5.Figures(1).panels(2).selection.groupBy, "TrialType") && rn5.Figures(1).panels(2).selection.filter == "Depth > 0" ...
    && isequal(rn5.Figures(1).panels(1).selection, "default") && rn5.Figures(2).panels.options.trials == "faint" ...
    && rn5.Figures(2).panels.options.maxTrials == 25 && rn5.Figures(3).panels.options.rows == "trials" ...
    && rn5.Figures(3).panels.options.rasterSort == "Depth" && rn5.Figures(3).panels.options.rasterSortOrder == "descending", ...
    'perGroup, a panel''s own selection, continuous trials / maxTrials and a heat map of trials survive save / load');
v = jsondecode('[{"id": "a", "panels": [{"type": "raster"}]}, {"grid": {"rows": 2, "rowHeights": [1, 1.5]}, "panels": {"type": "psth", "row": 2}}]');
c4 = EphysAnalysisConfig();
c4.Figures = v;
check(iscell(v) && isequal(c4.figureIds(), ["a" "figure_1"]) && c4.Figures(1).panels.id == "raster_1" ...
    && isequal(c4.Figures(2).grid.rowHeights, [1 1.5]) && c4.Figures(2).panels.row == 2, ...
    'a cell Figures from jsondecode (figures with different fields)');
c5 = EphysAnalysisConfig(struct('schema', EphysAnalysisConfig.Schema, 'version', 1, 'Figures', struct('id', "solo")));
check(isequal(c5.figureIds(), "solo") && isempty(c5.LoadWarnings), 'one figure as a JSON object (not a list)');
s = rmfield(cfg.toStruct(), 'Figures');
fo = fullfile(root, 'no_figures.json');
writeJsonFile(fo, s, NonFinite="string");
co = EphysAnalysisConfig.load(fo);
check(isempty(co.Figures) && isstruct(co.Figures) && isempty(co.LoadWarnings) && isequaln(co.Plots, cfg.Plots), ...
    'a config file without Figures loads with none and no warning');

fprintf('\n== 5. config: grid editing ==\n');
f = EphysAnalysisConfig.normalizeFigure(struct());
f = place(f, struct('type', "raster"));
check(isscalar(f.panels) && f.panels.id == "raster_1" && f.panels.row == 1 && f.panels.col == 1 && f.grid.rows == 1 && f.grid.cols == 1, ...
    'placePanel: the first panel goes to (1,1), no anchor needed');
f = place(f, struct('type', "psth"), "below", "raster_1");
check(f.grid.rows == 2 && f.panels(2).id == "psth_1" && f.panels(2).row == 2 && f.panels(2).col == 1, 'below: a new row under the anchor');
f.grid.rowHeights = [1 2];
f = place(f, struct('type', "psth"), "below", "psth_1");
check(f.grid.rows == 3 && isequal(f.grid.rowHeights, [1 2 2]) && f.panels(3).id == "psth_2" && f.panels(3).row == 3, ...
    'below copies the anchor row''s height; a second PSTH gets psth_2');
f = place(f, struct('type', "continuous"), "above", "raster_1");
check(f.grid.rows == 4 && isequal(f.grid.rowHeights, [1 1 2 2]) && f.panels(4).row == 1 && isequal([f.panels(1:3).row], [2 3 4]), ...
    'above: a new row before the anchor, the rows below shift down');

lr = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 2, 'cols', 2, 'rowHeights', [1 3]), 'panels', {{ ...
    struct('id', "L", 'type', "heatmap", 'row', 1, 'col', 1, 'rowSpan', 2), struct('id', "R1", 'type', "raster", 'row', 1, 'col', 2), ...
    struct('id', "R2", 'type', "psth", 'row', 2, 'col', 2)}}));
check(isequal(cellsOf(lr), [1 2; 1 3]), 'figureCells: the panel in each cell, spans included');
g = place(lr, struct('id', "N", 'type', "continuous"), "below", "R1");
check(g.grid.rows == 3 && isequal(g.grid.rowHeights, [1 1 3]) && g.panels(1).rowSpan == 3 && g.panels(3).row == 3 ...
    && g.panels(4).row == 2 && g.panels(4).col == 2 && isequal(cellsOf(g), [1 2; 1 4; 1 3]), ...
    'below: a span crossing the new row stretches, the panels past it shift down');
check(isequaln(remove(g, "N"), lr), 'removePanel undoes below exactly');
g2 = place(lr, struct('id', "N", 'type', "continuous"), "above", "R2");
check(isequaln(g2.panels, g.panels) && g2.grid.rows == 3 && isequal(g2.grid.rowHeights, [1 3 3]) && isequaln(remove(g2, "N"), lr), ...
    'above the lower panel: the same panels (its own row''s height copied); removed, the original');
tb = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 2, 'cols', 2, 'colWidths', [1 3]), 'panels', {{ ...
    struct('id', "T", 'type', "heatmap", 'row', 1, 'col', 1, 'colSpan', 2), struct('id', "B1", 'type', "raster", 'row', 2, 'col', 1), ...
    struct('id', "B2", 'type', "psth", 'row', 2, 'col', 2)}}));
g = place(tb, struct('id', "N", 'type', "psth"), "right", "B1");
check(g.grid.cols == 3 && isequal(g.grid.colWidths, [1 1 3]) && g.panels(1).colSpan == 3 && g.panels(3).col == 3 ...
    && g.panels(4).col == 2 && g.panels(4).row == 2 && isequal(cellsOf(g), [1 1 1; 2 4 3]), ...
    'right: a span crossing the new column stretches, the panels past it shift right');
check(isequaln(remove(g, "N"), tb), 'removePanel undoes right exactly');
g = place(tb, struct('id', "N", 'type', "psth"), "left", "B1");
check(g.grid.cols == 3 && isequal(g.grid.colWidths, [1 1 3]) && isequal([g.panels.col], [2 2 3 1]) && g.panels(1).colSpan == 2 ...
    && isequal(cellsOf(g), [0 1 1; 4 2 3]) && isequaln(remove(g, "N"), tb), ...
    'left: a new column before the anchor (a cell left blank); removed, the original');
x = remove(lr, "R2");
check(x.grid.rows == 1 && x.panels(1).rowSpan == 1 && isequal(x.grid.rowHeights, 1) && isequal(cellsOf(x), [1 2]), ...
    'removePanel drops a row no panel starts in, shrinking the span across it');
y = remove(remove(x, "R1"), "L");
check(isempty(y.panels) && y.grid.rows == 1 && y.grid.cols == 1, 'removing the last panel leaves a 1 x 1 grid');
check(strcmp(errorId(@() remove(lr, "Z")), 'EphysAnalysisConfig:NoPanel') ...
    && strcmp(errorId(@() place(lr, struct('type', "psth"), "below", "Z")), 'EphysAnalysisConfig:NoPanel') ...
    && strcmp(errorId(@() place(lr, struct('type', "psth"))), 'EphysAnalysisConfig:NoPanel') ...
    && strcmp(errorId(@() place(lr, struct('id', "R1", 'type', "psth"), "below", "L")), 'EphysAnalysisConfig:DuplicatePanelId'), ...
    'placePanel / removePanel: NoPanel (no or an unknown anchor), DuplicatePanelId');
rp = EphysAnalysisConfig.normalizeFigure(FT.Figure{1});
[m1, moved1] = move(rp, "psth_1", "up");
[m2, moved2] = move(rp, "psth_1", "left");
[m3, moved3] = move(lr, "R1", "left");
[~, moved4] = move(rp, "raster_1", "up");
[m5, moved5] = move(lr, "R1", "down");
check(moved1 && isequal([m1.panels.row], [2 1]) && moved5 && m5.panels(2).row == 2 && m5.panels(3).row == 1, ...
    'movePanel swaps a panel with its same-shaped neighbor');
check(~moved2 && isequaln(m2, rp) && ~moved3 && isequaln(m3, lr) && ~moved4, 'no neighbor there, or one of another shape: no move');
ov = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 1, 'cols', 2), 'panels', ...
    {{struct('type', "psth", 'colSpan', 2), struct('type', "raster", 'col', 2)}}));
[cl, over] = cellsOf(ov);
check(isequal(cl, [1 1]) && isequal(over, [1 2]), 'figureCells lists overlapping panels once');

% apply to all panels, re-link
ap = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 3, 'cols', 1), 'panels', {{ ...
    struct('id', "p1", 'type', "psth", 'row', 1, 'common', false, 'ref', struct('line', "Platform"), ...
        'options', struct('bins', struct('BinSec', 0.05), 'baseline', struct('Mode', "zscore"), 'histStyle', "line", 'yLim', [0 9])), ...
    struct('id', "p2", 'type', "psth", 'row', 2, 'common', false, 'window', struct('mode', "fixed", 'pre', -1, 'post', 2)), ...
    struct('id', "c1", 'type', "continuous", 'row', 3, 'common', false, 'options', struct('display', "stacked"))}}));
ad = EphysAnalysisConfig.adoptPanelOptions(ap, "p1");
check(ad.common.bins.BinSec == 0.05 && ad.common.baseline.Mode == "zscore" && all([ad.panels.common]) ...
    && ad.panels(2).options.histStyle == "line" && isequal(ad.panels(2).options.yLim, [0 9]) && ad.panels(2).options.bins.BinSec == 0.01 ...
    && ad.panels(3).options.display == "stacked" && isequaln(ad.panels(3).options, ap.panels(3).options) ...
    && isequal(ad.panels(1).ref, ap.panels(1).ref), ...
    'adoptPanelOptions: the panel''s common fields become the figure''s, every panel linked, type-specific options only to same-type panels');
ad2 = EphysAnalysisConfig.adoptPanelOptions(ad, "c1");
check(isequaln(ad2.common, ad.common), 'adoptPanelOptions from a linked panel leaves the common options as they are');
al = EphysAnalysisConfig.adoptPanelAlignment(ap, "p1");
al2 = EphysAnalysisConfig.adoptPanelAlignment(ap, "p2");
check(isstruct(al.ref) && al.ref.line == "Platform" && isequal(al.window, "default") && isequal([al.panels.ref], ["default" "default" "default"]) ...
    && isequal([al.panels.window], ["default" "default" "default"]) && isequal(al2.ref, "default") && al2.window.pre == -1 ...
    && ~any([al.panels.common]), 'adoptPanelAlignment: the panel''s own ref / window become the figure''s; every panel follows it');
rl = EphysAnalysisConfig.relinkPanels(ap);
check(all([rl.panels.common]) && isequal([rl.panels.ref], ["default" "default" "default"]) ...
    && isequal([rl.panels.window], ["default" "default" "default"]) && isequaln(rl.common, ap.common) ...
    && isequaln(rl.panels(1).options, ap.panels(1).options), 'relinkPanels: every panel''s ref, window and options linked again (own values kept)');
check(strcmp(errorId(@() EphysAnalysisConfig.adoptPanelOptions(ap, "zz")), 'EphysAnalysisConfig:NoPanel') ...
    && strcmp(errorId(@() EphysAnalysisConfig.adoptPanelAlignment(ap, "zz")), 'EphysAnalysisConfig:NoPanel'), ...
    'adoptPanelOptions / adoptPanelAlignment: NoPanel');

fprintf('\n== 6. config: validate ==\n');
base = EphysAnalysisConfig();
base.Source.Root = root;
base = base.addPlot("psth");
base = base.addFigure();
check(isempty(figIssues(base)), 'the rasterPsth figure validates clean');
tc = base;
for t = FT.Template.'
    tc = tc.addFigure(t, Id="t_" + t);
end
I = figIssues(tc);
check(isempty(I(~startsWith(I.Field, "t_blank."), :)), 'every template validates clean but blank');
check(has(tc, "t_blank.panels", "warning"), 'a blank figure has no panels');
nf = EphysAnalysisConfig();
nf.Source.Root = root;
nf = nf.addFigure();
I = nf.validate(CheckPaths=false);
check(~any(I.Section == "Plots" & I.Field == "enabled" & I.Severity == "error"), ...
    'the "nothing enabled" rule counts figures: a config of one enabled figure alone has something to run');

% 1. ids
b = base.addFigure("psth", Id="Figure_1");
check(has(b, "Figure_1.id", "error"), 'figure ids that name the same files');
b = base.addFigure("psth", Id="a:b");
check(has(b, "a:b.id", "error"), 'a figure id that is not file-name safe');

% 2. observe
b = base; b.Figures(1).observe.kind = "bogus";
check(has(b, "figure_1.observe.kind", "error"), 'observe.kind is a known kind');
b = base; b.Figures(1).observe.source = "LFP";
check(has(b, "figure_1.observe.source", "error"), 'observe.source is units or detected');
b = base; b.Figures(1).observe.signal = "units";
check(has(b, "figure_1.observe.signal", "error"), 'observe.signal is a signal');
b = base; b.Figures(1).observe.channels = 0.5;
check(has(b, "figure_1.observe.channels", "error"), 'observe.channels are whole numbers >= 1');
b = base; b.Figures(1).observe.units.maxUnits = 0;
check(has(b, "figure_1.observe.units.maxUnits", "error"), 'observe.units.maxUnits >= 1');
b = base; b.Figures(1).observe.datasets = "some";
check(has(b, "figure_1.observe.datasets", "error"), 'observe.datasets is ticked or list');
b = base; b.Figures(1).observe.datasets = "list";
check(has(b, "figure_1.observe.datasetKeys", "warning"), 'a "list" without dataset keys warns');
b = base; b.Figures(1).observe.kind = "dataset";
check(has(b, "figure_1.observe.kind", "error"), 'a layer following a dataset observation');
b = base.addFigure("probemap", Id="pm"); b.Figures(2).observe.kind = "unit";
check(has(b, "pm.observe.kind", "warning"), 'a unit observation that no layer follows warns');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).observe.kind = "channel"; b.Figures(2).observe.signal = "MUA";
check(has(b, "ct.continuous_1.layers(1).source", "warning"), 'an LFP layer following a MUA channel warns (the channel''s number)');
auxFollow = layerOf("continuous"); auxFollow.source = "AUX";
b = base; b.Figures(1) = place(b.Figures(1), struct('type', "continuous", 'layers', auxFollow), "below", "psth_1");
check(has(b, "figure_1.continuous_1.layers(1).binding", "error"), 'AUX cannot follow a unit (no recording channel)');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).observe.kind = "channel"; b.Figures(2).panels.layers.source = "AUX";
I = figIssues(b);
check(any(I.Field == "ct.continuous_1.layers(1).binding" & I.Severity == "error" ...
    & I.Message == "AUX has no recording channel: bind it to fixed channels.") && ~has(b, "ct.continuous_1.layers(1).source", "warning"), ...
    'AUX cannot follow an LFP channel (no recording channel): an error, as the compute skips it');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).observe.kind = "channel"; b.Figures(2).observe.signal = "AUX";
I = figIssues(b);
check(any(I.Field == "ct.continuous_1.layers(1).binding" & I.Severity == "error" ...
    & I.Message == "The observed AUX channel has no recording channel for LFP to follow.") && ~has(b, "ct.continuous_1.layers(1).source", "warning"), ...
    'an LFP layer cannot follow an AUX channel (no recording channel): an error, as the compute skips it');

% 3. grid
b = base; b.Figures(1).grid.rows = 0;
check(has(b, "figure_1.grid.rows", "error"), 'grid.rows is a whole number >= 1');
b = base; b.Figures(1).grid.cols = 1.5;
check(has(b, "figure_1.grid.cols", "error"), 'grid.cols is a whole number >= 1');
b = base; b.Figures(1).grid.rowHeights = [1 2 3];
check(has(b, "figure_1.grid.rowHeights", "error"), 'rowHeights: one per row');
b = base; b.Figures(1).grid.colWidths = -1;
check(has(b, "figure_1.grid.colWidths", "error"), 'colWidths: positive');
b = base; b.Figures(1).grid.spacing = "wide";
check(has(b, "figure_1.grid.spacing", "error"), 'grid.spacing is loose, compact, tight or none');

% 4. panels
b = base; b.Figures(1).panels(1).type = "violin";
check(has(b, "figure_1.raster_1.type", "error"), 'an unknown panel type');
b = base; b.Figures(1).panels(1).row = 0;
check(has(b, "figure_1.raster_1.row", "error"), 'a panel''s row is a whole number >= 1');
b = base; b.Figures(1).panels(2).rowSpan = 2;
check(has(b, "figure_1.psth_1.row", "error"), 'a panel reaching past the grid''s rows');
b = base; b.Figures(1).panels(2).colSpan = 2;
check(has(b, "figure_1.psth_1.col", "error"), 'a panel reaching past the grid''s columns');
b = base; b.Figures(1).panels(2).row = 1;
check(has(b, "figure_1.psth_1.row", "error") && has(b, "figure_1.grid", "warning"), 'overlapping panels (and the cell they leave blank)');
b = base; b.Figures(1).grid.rows = 3; b.Figures(1).grid.rowHeights = [];
I = figIssues(b);
check(has(b, "figure_1.grid", "warning") && contains(I.Message(I.Field == "figure_1.grid"), "(3,1)"), 'a cell no panel covers warns');

% 5. layers
evL = layerOf("raster"); evL.source = "events"; evL.binding = "fixed"; evL.event.line = "Stim";
b = base; b.Figures(1).panels(1).layers(1).source = "spikes";
check(has(b, "figure_1.raster_1.layers(1).source", "error"), 'a layer source not in FigureSources');
b = base.addFigure("waveforms", Id="wf"); b.Figures(2).panels.layers.source = "LFP";
I = figIssues(b);
check(any(I.Field == "wf.waveforms_1.layers(1).source" & I.Severity == "error" ...
    & I.Message == "A unit waveforms panel draws unit-summary layers, not LFP."), 'a source the panel type does not draw');
b = base; b.Figures(1).panels(1).layers(1).source = "trials";
check(has(b, "figure_1.raster_1.layers(1).source", "error"), 'trials is no layer source (the behavior panel type is gone)');
b = base; b.Figures(1).panels(1).layers(1).binding = "both";
check(has(b, "figure_1.raster_1.layers(1).binding", "error"), 'binding is observation or fixed');
b = base; ev2 = evL; ev2.binding = "observation"; b.Figures(1).panels(1).layers(2) = ev2;
check(has(b, "figure_1.raster_1.layers(2).binding", "error"), 'an events layer is always fixed');
b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.layers.binding = "observation";
check(has(b, "hm.heatmap_1.layers(1).binding", "error"), 'a heat map''s layers are fixed');
b = base; b.Figures(1).panels(1).layers(1).enabled = false;
check(has(b, "figure_1.raster_1.layers", "warning"), 'a panel without an enabled layer warns');
b = base.addFigure("waveforms", Id="wf"); b.Figures(2).panels.layers(2) = layerOf("waveforms");
check(has(b, "wf.waveforms_1.layers", "warning"), 'two layers on a one-layer type warn');
b = base; b.Figures(1).panels(2).layers(1).binding = "fixed";
b2 = b; b2.Figures(1).panels(2).layers(1).units.ids = [1 2];
check(has(b, "figure_1.psth_1.layers(1).units.maxUnits", "warning") && ~has(b2, "figure_1.psth_1.layers(1).units.maxUnits", "warning"), ...
    'a fixed layer of possibly more than 8 units drawn each in a PSTH warns');
b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.type = "psth";   % a heat map's fixed all-units layer, its panel made a PSTH
check(has(b, "hm.heatmap_1.layers(1).units.maxUnits", "warning"), ...
    'so does a heat map''s fixed all-units layer left in a panel made a PSTH (the app makes it follow the observation)');
b = base; b.Figures(1).panels(1).layers(1).aggregate = "sum";
check(has(b, "figure_1.raster_1.layers(1).aggregate", "error"), 'aggregate is each or mean');
b = base; b.Figures(1).panels(1).layers(1).units.maxUnits = 0;
check(has(b, "figure_1.raster_1.layers(1).units.maxUnits", "error"), 'a layer''s maxUnits >= 1');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).panels.layers.channels = 1.5;
check(has(b, "ct.continuous_1.layers(1).channels", "error"), 'a layer''s channels are whole numbers >= 1');
b = base; b.Figures(1).panels(1).type = "behavior";
check(has(b, "figure_1.raster_1.type", "error") && strcmp(errorId(@() base.addFigure("behavior")), 'EphysAnalysisConfig:BadValue'), ...
    'behavior is no panel type, nor a figure template');
b = base; b.Figures(1).panels(1).layers(1).color = "plaid";
check(has(b, "figure_1.raster_1.layers(1).color", "warning"), 'a layer color that is not one warns');
b = base; b.Figures(1).panels(1).layers(1).lineStyle = "~";
check(has(b, "figure_1.raster_1.layers(1).lineStyle", "error"), 'a layer''s line style');

% 6. events layers
b = base; b.Figures(1).panels(1).layers(2) = evL;
check(isempty(figIssues(b)), 'events marks on a raster with rows validate clean');
b = base.addFigure("probemap", Id="pm"); b.Figures(2).panels.layers(2) = evL;
check(has(b, "pm.probemap_1.layers(2).source", "error"), 'events layers only on time panels');
b = base.addFigure("continuous", Id="ct"); evT = evL; evT.eventsAs = "train"; b.Figures(2).panels.layers(2) = evT;
b2 = base.addFigure("continuous", Id="ct"); b2.Figures(2).panels.layers(2) = evL;
check(has(b, "ct.continuous_1.layers(2).eventsAs", "error") && isempty(figIssues(b2)), 'a train only on raster / psth / heatmap (marks on continuous)');
b = base; evB = evL; evB.eventsAs = "bogus"; b.Figures(1).panels(1).layers(2) = evB;
check(has(b, "figure_1.raster_1.layers(2).eventsAs", "error"), 'eventsAs is marks or train');
b = base; b.Figures(1).panels(1).layers(1) = evL;
b2 = base; b2.Figures(1).panels(1).layers(1) = evT;
check(has(b, "figure_1.raster_1.layers", "error") && ~has(b2, "figure_1.raster_1.layers", "error"), 'a raster of marks alone has no rows (a train has)');
b = base; evE = evL; evE.event.line = ""; b.Figures(1).panels(1).layers(2) = evE;
check(has(b, "figure_1.raster_1.layers(2).event", "error"), 'the mark''s event reference is checked');
b = base; evM = evL; evM.event.marker = "star"; evM.event.size = 0; evM.event.color = "nope"; b.Figures(1).panels(1).layers(2) = evM;
check(has(b, "figure_1.raster_1.layers(2).event.marker", "error") && has(b, "figure_1.raster_1.layers(2).event.size", "error") ...
    && has(b, "figure_1.raster_1.layers(2).event.color", "warning"), 'the mark''s marker, size and color');

% 7. the figure's alignment
b = base; b.Figures(1).ref = struct('line', "Stim", 'edge', "middle");
check(has(b, "figure_1.ref", "error"), 'the figure''s ref');
b = base; b.Figures(1).window = struct('mode', "fixed", 'pre', 1, 'post', 0);
check(has(b, "figure_1.window", "error"), 'the figure''s window');
b = base; b.Figures(1).selection = struct('groupBy', ["A" "B" "C"]);
check(has(b, "figure_1.selection", "error"), 'the figure''s selection (groupBy <= 2)');

% 8. a panel's alignment
b = base.addFigure("probemap", Id="pm"); b.Figures(2).panels.ref = struct('line', "Stim");
check(has(b, "pm.probemap_1.ref", "error"), 'a panel''s own ref only on aligned types');
b = base; b.Figures(1).panels(2).window = struct('mode', "fixed", 'pre', 1, 'post', 0);
check(has(b, "figure_1.psth_1.window", "error"), 'a panel''s own window is checked');
between = struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Platform"));
b = base; b.Figures(1).window = between;
b2 = base.addFigure("corrmap", Id="cm"); b2.Figures(2).window = between;
check(has(b, "figure_1.raster_1.window", "error") && has(b, "figure_1.psth_1.window", "error") && isempty(figIssues(b2)), ...
    'a "between" window only on a unit correlation panel');

% 9. options (a panel's own common fields are checked where it is not linked to the figure's common options)
ub = unlinkFigure(base, 1);
o = "figure_1.raster_1.options.";
b = base; b.Figures(1).panels(1).options.rasterSortOrder = "up";
check(has(b, o + "rasterSortOrder", "error"), 'raster: rasterSortOrder');
b = base; b.Figures(1).panels(1).options.rasterSort = "event";
b2 = b; b2.Figures(1).panels(1).options.rasterSortEvent = struct('line', "Platform", 'edge', "middle");
check(has(b, o + "rasterSortEvent", "error") && has(b2, o + "rasterSortEvent", "error"), 'raster: rasterSort "event" needs a valid rasterSortEvent');
b = ub; b.Figures(1).panels(1).options.waveform.mode = "huge";
check(has(b, o + "waveform.mode", "error"), 'raster: the waveform inset''s mode');
b = ub; b.Figures(1).panels(1).options.waveform = struct('mode', "mean", 'scale', 5, 'location', "up", 'maxSpikes', 0.5, 'ampScale', "x");
check(has(b, o + "waveform.scale", "error") && has(b, o + "waveform.location", "error") && has(b, o + "waveform.maxSpikes", "error") ...
    && has(b, o + "waveform.ampScale", "error"), 'raster: the waveform inset''s scale, location, maxSpikes, ampScale');
o = "figure_1.psth_1.options.";
b = ub; b.Figures(1).panels(2).options.bins.BinSec = 0; b.Figures(1).panels(2).options.bins.SmoothSec = -1;
check(has(b, o + "bins.BinSec", "error") && has(b, o + "bins.SmoothSec", "error"), 'psth: bins');
b = ub; b.Figures(1).panels(2).options.measure = "volts";
check(has(b, o + "measure", "error"), 'psth: measure');
b = ub; b.Figures(1).panels(2).options.baseline.Mode = "ratio";
b2 = ub; b2.Figures(1).panels(2).options.baseline = struct('Mode', "subtract", 'Window', [0 -1]);
check(has(b, o + "baseline.Mode", "error") && has(b2, o + "baseline.Window", "error"), 'psth: baseline mode (no ratio) and window');
haveAuroc = license('test', 'Statistics_Toolbox') && exist('tiedrank', 'file');
b = ub; b.Figures(1).panels(2).options.baseline.Mode = "auroc";
b2 = b; b2.Figures(1).panels(2).options.auroc.windowSec = 0.015; b2.Figures(1).panels(2).options.auroc.cutoff = "maybe";
b3 = b; b3.Figures(1).panels(2).options.auroc.modulatedOnly = true; b3.Figures(1).panels(2).options.auroc.cutoff = "none";
check(~has(b, o + "baseline.Mode", "error") && has(b, o + "auroc", "error") == ~haveAuroc && has(b2, o + "auroc.windowSec", "error") ...
    && has(b2, o + "auroc.cutoff", "error") && has(b3, o + "auroc.modulatedOnly", "error"), ...
    'psth: the auROC baseline, its settings checked as a plot''s (windows of whole bins, cutoff, modulatedOnly)');
b = ub; b.Figures(1).panels(2).options.stackSpacing = 0;
b2 = ub; b2.Figures(1).panels(2).options.stack = true;
check(has(b, o + "stackSpacing", "error") && isempty(figIssues(b2)), 'psth: stack, and a positive stackSpacing');
b = base; b.Figures(1).panels(2).options.histStyle = "pie"; b.Figures(1).panels(2).options.normalize = "max";
b.Figures(1).panels(2).options.fillAlpha = 2; b.Figures(1).panels(2).options.yLim = [1 0];
check(has(b, o + "histStyle", "error") && has(b, o + "normalize", "error") && has(b, o + "fillAlpha", "error") && has(b, o + "yLim", "error"), ...
    'psth: histStyle, normalize, fillAlpha, yLim');
b = unlinkFigure(base.addFigure("continuous", Id="ct"), 2);
b.Figures(2).panels.options = struct('display', "grid", 'statistic', "mode", 'transform', "log", 'errorType', "mad", 'stackSpacing', -1, ...
    'baseline', struct('Mode', "zscore"));
o = "ct.continuous_1.options.";
check(has(b, o + "display", "error") && has(b, o + "statistic", "error") && has(b, o + "transform", "error") && has(b, o + "errorType", "error") ...
    && has(b, o + "stackSpacing", "error") && has(b, o + "baseline.Mode", "error"), 'continuous: display, statistic, transform, errorType, stackSpacing, baseline');
haveBoot = license('test', 'Statistics_Toolbox') && exist('bootci', 'file');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).panels.options.errorType = "ci95";
check(has(b, o + "errorType", "error") == ~haveBoot, 'continuous: the bootstrap CI needs the Statistics and Machine Learning Toolbox');
b = unlinkFigure(base.addFigure("continuous", Id="ct"), 2); b.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [-1 -0.5]);
b2 = unlinkFigure(base.addFigure("continuous", Id="ct"), 2); b2.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [-0.5 -0.1]);
b3 = unlinkFigure(base.addFigure("continuous", Id="ct"), 2); b3.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [-0.2 -0.15]);
b3.Figures(2).panels.window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.3);
b4 = unlinkFigure(base.addFigure("heatmap", Id="hm"), 2); b4.Figures(2).panels.layers.source = "LFP";
b4.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [1 2]);
b5 = unlinkFigure(base.addFigure("heatmap", Id="hm"), 2); b5.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [1 2]);
check(has(b, o + "baseline", "error") && ~has(b2, o + "baseline", "error") && has(b3, o + "baseline", "error") ...
    && has(b4, "hm.heatmap_1.options.baseline", "error") && ~has(b5, "hm.heatmap_1.options.baseline", "error"), ...
    'a signal''s baseline window must overlap the panel''s resolved window (continuous, a heat map of a signal; not of spikes)');
b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.options.order = "modulation"; b.Figures(2).panels.options.group = 0;
b.Figures(2).panels.options.cLim = [2 1];
o = "hm.heatmap_1.options.";
check(has(b, o + "order", "error") && has(b, o + "group", "error") && has(b, o + "cLim", "error"), 'heatmap: order, group, cLim');
b = unlinkFigure(base.addFigure("heatmap", Id="hm"), 2); b.Figures(2).panels.options.baseline.Mode = "auroc"; b.Figures(2).panels.options.order = "modulation";
b2 = b; b2.Figures(2).panels.layers.source = "LFP";
b3 = base.addFigure("heatmap", Id="hm"); b3.Figures(2).panels.layers.source = "LFP"; b3.Figures(2).common.baseline.Mode = "auroc";
check(~has(b, o + "order", "error") && ~has(b, o + "baseline.Mode", "error") && has(b2, o + "baseline.Mode", "error") ...
    && has(b2, o + "order", "error") && has(b3, "hm.heatmap_1.common", "error"), ...
    'heatmap: the auROC baseline and modulation order for spikes, not for a signal (own or common)');
b = unlinkFigure(base.addFigure("heatmap", Id="hm"), 2); b.Figures(2).panels.layers.source = "LFP"; b.Figures(2).panels.options.baseline.Mode = "zscore";
b2 = unlinkFigure(base.addFigure("heatmap", Id="hm"), 2); b2.Figures(2).panels.options.baseline.Mode = "zscore";
check(has(b, o + "baseline.Mode", "error") && isempty(figIssues(b2)), 'heatmap: z-score for spikes, not for a signal');
b = unlinkFigure(base.addFigure("waveforms", Id="wf"), 2); b.Figures(2).panels.options.waveform.mode = "off";
check(has(b, "wf.waveforms_1.options.waveform.mode", "error"), 'waveforms: the mode is never off');
b = base.addFigure("waveforms", Id="wf"); b.Figures(2).panels.options.layout = "map";
b2 = base.addFigure("waveforms", Id="wf"); b2.Figures(2).panels.options.layout = "probe";
b3 = b2; b3.Figures(2).panels.layers(1).binding = "fixed"; b3.Figures(2).panels.layers(2) = layerOf("waveforms");
check(has(b, "wf.waveforms_1.options.layout", "error") && has(b2, "wf.waveforms_1.options.layout", "warning") ...
    && isempty(figIssues(b3)), 'waveforms: layout grid or probe; a probe of the observed unit alone warns; a fixed layer ringing a following one is clean');
b = unlinkFigure(base.addFigure("rate", Id="rt"), 2);
b.Figures(2).panels.options = struct('display', "pie", 'measure', "volts", 'baseline', struct('Mode', "percent", 'Window', [-0.2 0]), 'yLim', [3 1]);
o = "rt.rate_1.options.";
b2 = base.addFigure("rate", Id="rt"); b2.Figures(2).common.baseline.Mode = "percent";
b3 = base.addFigure("rate", Id="rt"); b3.Figures(2).common.baseline.Mode = "ratio";
b4 = base.addFigure("rate", Id="rt"); b4.Figures(2).window = between;
b5 = base.addFigure("rate", Id="rt"); b5.Figures(2).panels.layers.binding = "fixed";
check(has(b, o + "display", "error") && has(b, o + "measure", "error") && has(b, o + "baseline.Mode", "error") && has(b, o + "yLim", "error") ...
    && has(b2, "rt.rate_1.common", "error") && isempty(figIssues(b3)) && isempty(figIssues(b4)) ...
    && has(b5, "rt.rate_1.layers(1).units.maxUnits", "warning"), ...
    'rate: display, measure, baseline (firingRate''s modes: ratio, not percent; own or common), yLim; a "between" window; many fixed units warn');
b = unlinkFigure(base.addFigure("tuning", Id="tc"), 2);
b.Figures(2).panels.options.param = "Depth"; b.Figures(2).panels.options.seriesParam = "Depth"; b.Figures(2).panels.options.waveform.mode = "huge";
b2 = base.addFigure("tuning", Id="tc"); b2.Figures(2).panels.options.param = "not a name";
b3 = base.addFigure("tuning", Id="tc"); b3.Figures(2).panels.options.param = "Depth"; b3.Figures(2).panels.options.seriesParam = "TrialType";
b3.Figures(2).window = between;
b4 = base.addFigure("tuning", Id="tc"); b4.Figures(2).common.baseline.Mode = "auroc";
o = "tc.tuning_1.options.";
check(has(b, o + "seriesParam", "error") && has(b, o + "waveform.mode", "error") && has(b2, o + "param", "error") ...
    && isempty(figIssues(b3)) && has(b4, "tc.tuning_1.common", "error"), ...
    'tuning: param and seriesParam (names, not the same), its waveform inset; a "between" window; no auROC baseline');
b = base.addFigure("probemap", Id="pm"); b.Figures(2).panels.options.value = "x";
check(has(b, "pm.probemap_1.options.value", "error"), 'probemap: value');
b = base.addFigure("corrmap", Id="cm"); b.Figures(2).panels.options.metric = "max"; b.Figures(2).panels.options.correlation = "kendall";
b2 = unlinkFigure(base.addFigure("corrmap", Id="cm"), 2); b2.Figures(2).panels.options.metric = "peak"; b2.Figures(2).panels.options.bins.BinSec = 0;
check(has(b, "cm.corrmap_1.options.metric", "error") && has(b, "cm.corrmap_1.options.correlation", "error") ...
    && has(b2, "cm.corrmap_1.options.bins.BinSec", "error"), 'corrmap: metric, correlation, bins of a peak rate');

% 9b. the common options
c0 = "figure_1.common.";
b = base; b.Figures(1).common.bins.BinSec = 0; b.Figures(1).common.measure = "volts";
b.Figures(1).common.waveform = struct('mode', "mean", 'scale', 5);
check(has(b, c0 + "bins.BinSec", "error") && has(b, c0 + "measure", "error") && has(b, c0 + "waveform.scale", "error") ...
    && ~has(b, "figure_1.psth_1.options.bins.BinSec", "error"), 'the common block: bins, measure, waveform (once, not per linked panel)');
b = base; b.Figures(1).common.baseline.Mode = "bogus";
b2 = base; b2.Figures(1).common.baseline = struct('Mode', "subtract", 'Window', [0 -1]);
check(has(b, c0 + "baseline.Mode", "error") && has(b2, c0 + "baseline.Window", "error"), 'the common block: baseline Mode and window');
b = base; b.Figures(1).common.baseline.Mode = "auroc";
b2 = b; b2.Figures(1).common.auroc.windowSec = 0.015;
check(isempty(figIssues(b)) == haveAuroc && has(b2, c0 + "auroc.windowSec", "error") && ~has(b2, "figure_1.psth_1.options.auroc.windowSec", "error"), ...
    'the common block: the auROC settings, checked once while the PSTH is linked');
b3 = unlinkFigure(base, 1); b3.Figures(1).panels(2).options.baseline.Mode = "auroc";
b3.Figures(1).panels(2).options.bins.BinSec = 0.04;   % its own bins: the 0.1 s auROC windows no longer fit
check(has(b3, "figure_1.psth_1.options.auroc.windowSec", "error"), 'an unlinked PSTH''s own auROC windows must be whole numbers of its own bins');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).common.baseline.Mode = "auroc";
check(has(b, "ct.continuous_1.common", "error"), 'a common auROC baseline a linked continuous panel does not take: an error at the panel''s common');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).common.baseline.Mode = "zscore";
I = figIssues(b);
check(any(I.Field == "ct.continuous_1.common" & I.Severity == "error" & contains(I.Message, """zscore""") ...
    & contains(I.Message, "continuous signal panel") & contains(I.Message, "untick")) && ~has(b, "ct.common.baseline.Mode", "error"), ...
    'a common baseline "zscore" a linked continuous panel does not take: an error at the panel''s common');
b.Figures(2).panels.common = false;
check(isempty(figIssues(b)), 'unlinking the panel clears it (its own baseline is "none")');
b = base; b.Figures(1).common.baseline.Mode = "zscore";
check(isempty(figIssues(b)), 'a PSTH takes the common z-score');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).common.baseline = struct('Mode', "subtract", 'Window', [-1 -0.5]);
check(has(b, "ct.continuous_1.common.baseline", "error"), 'a linked signal''s common baseline must overlap the panel''s window');
b = base.addFigure("waveforms", Id="wf");
check(isempty(figIssues(b)), 'a linked waveforms panel takes the common waveform mode "off" as "both"');

% 10. the style, shared with the plots (checkStyle)
st = base.Plots(1).style;
st.MaxTiles = 0; st.TileSpacing = "wide"; st.LegendLocation = "northeast"; st.LegendOrientation = "diagonal";
st.ErrorType = "iqr"; st.ErrorResamples = 2.5; st.ErrorFaceAlpha = 1.5; st.ErrorFaceColor = "plaid"; st.ErrorEdgeColor = "nope";
st.ErrorEdgeStyle = "~"; st.ErrorEdgeWidth = 0; st.FontSize = 0; st.LineWidth = 0; st.SiteSize = 0;
st.Colormap = "nope"; st.HeatColormap = "notacolormap";
expect = [ ...
    "MaxTiles"          "error"   "MaxTiles must be >= 1."
    "TileSpacing"       "error"   "TileSpacing is loose, compact, tight or none."
    "LegendLocation"    "error"   "LegendLocation is auto, inside, north, south, east or west."
    "LegendOrientation" "error"   "LegendOrientation is auto, vertical or horizontal."
    "ErrorType"         "error"   "ErrorType is sem (mean +/- SEM), std (mean +/- SD) or ci95 (bootstrap 95% CI)."
    "ErrorResamples"    "error"   "ErrorResamples is a whole number of bootstrap resamples, at least 1."
    "ErrorFaceAlpha"    "error"   "ErrorFaceAlpha is an opacity from 0 to 1 (NaN = opaque, the trace's color paled)."
    "ErrorFaceColor"    "warning" "No color ""plaid""; the bands take their trace's color."
    "ErrorEdgeColor"    "warning" "No color ""nope""; the bands have no edge."
    "ErrorEdgeStyle"    "error"   "ErrorEdgeStyle is one of -  --  :  -.."
    "ErrorEdgeWidth"    "error"   "ErrorEdgeWidth must be positive (points)."
    "FontSize"          "error"   "FontSize must be positive."
    "LineWidth"         "error"   "LineWidth must be positive."
    "SiteSize"          "error"   "SiteSize must be positive."
    "Colormap"          "warning" "No colormap function or color ""nope""; the default is used."
    "HeatColormap"      "warning" "No colormap function ""notacolormap""; the default is used."];
b = base; b.Plots(1).style = st;
I = b.validate(CheckPaths=false);
I = I(startsWith(I.Field, "psth_1.style."), :);
check(isequal(I.Section, repmat("Plots", height(I), 1)) && isequal(I.Field, "psth_1.style." + expect(:, 1)) ...
    && isequal(I.Severity, expect(:, 2)) && isequal(I.Message, expect(:, 3)), 'a plot''s style messages are unchanged (checkStyle)');
b = base; b.Figures(1).style = st;
I = figIssues(b);
I = I(startsWith(I.Field, "figure_1.style."), :);
check(isequal(I.Field, "figure_1.style." + expect(:, 1)) && isequal(I.Severity, expect(:, 2)) && isequal(I.Message, expect(:, 3)), ...
    'a figure''s style is checked as a plot''s');
b = base; b.Figures(1).style.ErrorType = "ci95";
b2 = base; b2.Figures(1).style.ErrorType = "ci95"; b2.Figures(1).panels(2).type = "raster";
check(has(b, "figure_1.style.ErrorType", "error") == ~haveBoot && ~has(b2, "figure_1.style.ErrorType", "error"), ...
    'a figure''s bootstrap CI needs the toolbox only where a panel draws the style''s error');

% phase 4b: per-trial traces, a heat map of trials, a panel's own selection, per trial group
b = base.addFigure("continuous", Id="ct");
b.Figures(2).panels.options.trials = "faint";
b.Figures(2).panels.options.maxTrials = 40;
check(isempty(figIssues(b)), 'continuous trials "faint" with maxTrials 40 validates clean');
b.Figures(2).panels.options.trials = "some";
b.Figures(2).panels.options.maxTrials = 0.5;
check(has(b, "ct.continuous_1.options.trials", "error") && has(b, "ct.continuous_1.options.maxTrials", "error"), ...
    'continuous trials is off / faint / only, maxTrials a whole number >= 1');
hmT = EphysAnalysisConfig.defaultLayer("heatmap");
hmT.binding = "observation";
b = base.addFigure(struct('panels', {{struct('id', "ht", 'type', "heatmap", 'layers', hmT, ...
    'options', struct('rows', "trials", 'rasterSort', "stop"))}}), Id="trialmap");
check(isempty(figIssues(b)), 'a heat map of trials following the observed unit validates clean (it may follow)');
b2 = b; b2.Figures(2).panels.options.rows = "rows";
check(has(b2, "trialmap.ht.options.rows", "error"), 'heat map rows are items or trials');
b2 = b; b2.Figures(2).panels.layers.binding = "fixed";
check(has(b2, "trialmap.ht.layers(1).units", "error"), 'a heat map of trials fixed to every unit: one unit only');
b2.Figures(2).panels.layers.units.ids = 7;
check(~has(b2, "trialmap.ht.layers(1).units", "error"), '... one fixed id is fine');
b2 = b; b2.Figures(2).panels.layers.source = "LFP";
check(has(b2, "trialmap.ht.options.rows", "error"), 'a heat map of trials of a signal: an error');
b2 = b; b2.Figures(2).panels.common = false; b2.Figures(2).panels.options.baseline.Mode = "auroc";
check(has(b2, "trialmap.ht.options.baseline.Mode", "error"), 'a heat map of trials takes no auROC baseline');
b2 = b; b2.Figures(2).panels.options.rasterSort = "event";
check(has(b2, "trialmap.ht.options.rasterSortEvent", "error"), 'a heat map of trials sorted by "event" needs its event (the raster''s rule)');
b2 = b; b2.Figures(2).panels.options.rows = "items";
check(has(b2, "trialmap.ht.layers(1).binding", "error"), 'a heat map of items still draws fixed layers only');
b = base; b.Figures(1).panels(2).selection = struct('groupBy', "TrialType");
check(isempty(figIssues(b)), 'a PSTH with a trial selection of its own validates clean');
b.Figures(1).panels(2).selection = struct('groupBy', ["A" "B" "C"]);
check(has(b, "figure_1.psth_1.selection", "error"), 'a panel''s own selection is checked as the figure''s (groupBy <= 2)');
b = base.addFigure("probemap", Id="pm6");
b.Figures(2).panels.selection = struct('groupBy', "TrialType");
check(has(b, "pm6.probemap_1.selection", "error"), 'a selection of its own only on an aligned panel type');
b = base; b.Figures(1).observe.perGroup = true;
b2 = b; b2.Defaults.Selection.groupBy = "Depth";
check(has(b, "figure_1.observe.perGroup", "warning") && ~has(b2, "figure_1.observe.perGroup", "warning"), ...
    'perGroup warns while the figure''s selection groups by nothing');

%% ============================================================================ compute
fprintf('\n== 7. compute: observations, bindings, panels and layers ==\n');
froot = string(root) + "_fixture";
cleanFixture = onCleanup(@() rmdirQuiet(froot));
FX = makeAnalysisFixture(froot, Scenarios="clean", NumTrials=12);
cfg = EphysAnalysisConfig();
cfg.Source.Root = FX.proj;
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
cfg.Defaults.Selection.groupBy = "Depth";
cfg = cfg.addFigure("rasterPsth", Id="rp");
cfg = cfg.addFigure("continuous", Id="ct");
cfg = cfg.addFigure("probemap", Id="pm");
rn = EphysAnalysisRunner(cfg, LogFcn=[]);
src = rn.source(1);
spec = cfg.figureFor("rp");
varsObs = ["kind" "label" "unitId" "channel" "column" "shank" "depth" "meta" "group" "groupLabel"];

% observations
Tu = figureObservations(src, spec);
[~, mU] = selectUnits(src, spec.observe.units);
ordU = probeOrder(mU, height(mU), spec.style);
nU = height(Tu);
check(nU == height(mU) && nU >= 2 && all(Tu.kind == "unit") && isequal(Tu.unitId, mU.unitId(ordU)) ...
    && isequal(Tu.channel, mU.channel(ordU)) && isequaln(Tu.depth, mU.y(ordU)) && all(isnan(Tu.column)) ...
    && isequal(string(Tu.Properties.VariableNames), varsObs) && isequal(Tu.meta{1}.unitId, Tu.unitId(1)) ...
    && all(arrayfun(@(k) contains(Tu.label(k), "ch " + Tu.channel(k)), 1:nU)), ...
    sprintf('figureObservations: the filter''s %d units in probe order ("%s", ...)', nU, Tu.label(1)));
s2 = spec; s2.observe.units.ids = Tu.unitId([1 end]).';
T2 = figureObservations(src, s2);
s3 = spec; s3.observe.units.ids = 9999;
T3 = figureObservations(src, s3);
check(height(T2) == 2 && isequal(sort(T2.unitId), sort(Tu.unitId([1 end]))) && height(T3) == 0 ...
    && isequal(string(T3.Properties.VariableNames), varsObs), 'a tightened filter lists its units only; none left gives an empty table');
sc = cfg.figureFor("ct");
Tc = figureObservations(src, sc);
[~, ~, mL] = selectChannels(src, "LFP");
check(sc.observe.kind == "channel" && height(Tc) == height(mL) && all(Tc.kind == "channel") && isequal(sort(Tc.column), sort(mL.channel)) ...
    && isequal(Tc.channel, mL.recordingChannel(Tc.column)) && all(startsWith(Tc.label, "LFP ch ")) && all(isnan(Tc.unitId)), ...
    sprintf('figureObservations: the LFP channels of a continuous-only figure ("%s", ...)', Tc.label(1)));
sp = cfg.figureFor("pm");
Td = figureObservations(src, sp);
check(sp.observe.kind == "dataset" && isscalar(Td.kind) && Td.kind == "dataset" && Td.label == src.name && isnan(Td.unitId), ...
    'figureObservations: one row, the dataset, for a dataset figure');

% raster + PSTH of one unit
F1 = rn.computeFigure(src, spec);
L1 = F1.panels(1).layers;
L2 = F1.panels(2).layers;
check(F1.kind == "figure" && F1.id == "rp" && F1.dataset == src.name && F1.observation.kind == "unit" ...
    && F1.observation.unitId == Tu.unitId(1) && F1.observation.label == Tu.label(1) && isequal([F1.panels.id], ["raster_1" "psth_1"]) ...
    && all([F1.panels.sharesTime]) && isempty(F1.panels(1).epochs) && istable(F1.epochs) && isequal(F1.panels(2).groups, F1.groups), ...
    'computeFigure: the first observation by default; both panels on the figure''s epochs and groups');
check(isscalar(L1) && L1.skip == "" && L2.skip == "" && isscalar(L1.R.raster) && size(L2.R.rate, 2) == 1 ...
    && L1.meta.unitId == Tu.unitId(1) && L2.meta.unitId == Tu.unitId(1) && L2.name == shortUnitLabels(Tu.meta{1}.label) ...
    && L2.binding == "observation" && L2.category == "point", 'one unit in each layer''s R: the observed one, named by its label');
cfg = cfg.addPlot(struct('kind', "psth"), Id="psth_all");
Rp = rn.computePlot(src, cfg.plotFor("psth_all"));
u1 = find(Rp.meta.unitId == Tu.unitId(1));
check(isscalar(u1) && isequaln(L2.R.rate, Rp.rate(:, u1, :)) && isequaln(L2.R.err.lo, Rp.err.lo(:, u1, :)) ...
    && isequaln(F1.epochs.t0, Rp.epochs.t0), 'the PSTH layer is computePlot''s PSTH of that unit (the same epochs, bins and band)');
F2 = rn.computeFigure(src, spec, Observation=Tu(2, :));
Fs = rn.computeFigure(src, spec, Observation=struct('kind', "unit", 'unitId', Tu.unitId(2), 'channel', Tu.channel(2)));
check(F2.observation.unitId == Tu.unitId(2) && F2.panels(2).layers(1).meta.unitId == Tu.unitId(2) ...
    && isequaln(Fs.panels(2).layers(1).R.rate, F2.panels(2).layers(1).R.rate), 'Observation= picks another unit (a table row or a struct)');

% a continuous panel: LFP following the unit, AUX fixed, AUX following (skipped)
lfpL = EphysAnalysisConfig.defaultLayer("continuous");
auxL = lfpL; auxL.source = "AUX"; auxL.binding = "fixed"; auxL.channels = [1 2]; auxL.aggregate = "mean";
auxF = lfpL; auxF.source = "AUX";
stack = EphysAnalysisConfig.placePanel(cfg.Figures(cfg.figureIndex("rp")), ...
    struct('id', "sig", 'type', "continuous", 'layers', [lfpL auxL auxF]), "below", "psth_1");
stack.id = "stack";
cfg = cfg.addFigure(stack);
ss = cfg.figureFor("stack");
F3 = rn.computeFigure(src, ss, Observation=Tu(2, :));
Ls = F3.panels(3).layers;
[Yl, fsl] = selectChannels(src, "LFP");
col = find(mL.recordingChannel == Tu.channel(2), 1);
Rref = evokedPotential(Yl, fsl, F3.epochs, Window=[ss.window.pre ss.window.post], Channels=col, Groups=F3.groups, Meta=mL(col, :));
check(Ls(1).skip == "" && isequal(Ls(1).R.channels, col) && isequaln(Ls(1).R.mean, Rref.mean) && Ls(1).name == "LFP ch " + Tu.channel(2) ...
    && Ls(1).meta.recordingChannel == Tu.channel(2), 'an LFP layer following the unit reads the column of its recording channel, as evokedPotential does');
d2 = Ls(2).R.layerMean;
check(Ls(2).skip == "" && isequal(Ls(2).R.channels(:).', [1 2]) && Ls(2).R.units == "V" && size(Ls(2).R.mean, 2) == 2 ...
    && isequaln(d2.mean, mean(Ls(2).R.mean, 2, 'omitnan')) && isequal(size(d2.lo), size(d2.mean)) && d2.over == "channels" && d2.n == 2, ...
    'a fixed AUX layer reads its columns; aggregate "mean" adds their mean with a band across them (R.layerMean)');
auxMsg = "AUX has no recording channel: bind it to fixed channels";
[~, lr] = figureSkipReason(src, ss);
hit = [lr.panel] == "sig" & [lr.layer] == 3;
check(Ls(3).skip == auxMsg && isempty(Ls(3).R) && F3.panels(3).skip == "" && isscalar(lr(hit)) && lr(hit).reason == auxMsg ...
    && all([lr(~hit).reason] == ""), 'an AUX layer following a unit is skipped with its reason (figureSkipReason''s too); the others are computed');

% a fixed point layer keeping three units, aggregate "mean"
n3 = min(3, nU);
fx = EphysAnalysisConfig.defaultLayer("psth");
fx.binding = "fixed"; fx.units.ids = Tu.unitId(1:n3).'; fx.aggregate = "mean";
cfg = cfg.addFigure(struct('panels', {{struct('id', "mean3", 'type', "psth", 'layers', fx)}}), Id="agg");
sa = cfg.figureFor("agg");
Fa = rn.computeFigure(src, sa);
Ra = Fa.panels(1).layers(1).R;
semU = std(Ra.rate, 0, 2, 'omitnan') / sqrt(n3);
check(sa.observe.kind == "dataset" && Fa.observation.kind == "dataset" && size(Ra.rate, 2) == n3 && isequal(sort(Ra.meta.unitId), sort(Tu.unitId(1:n3))) ...
    && isequaln(Ra.layerMean.mean, mean(Ra.rate, 2, 'omitnan')) && Ra.layerMean.n == n3 && Ra.layerMean.over == "units" ...
    && max(abs(Ra.layerMean.hi - Ra.layerMean.mean - semU), [], 'all') < 1e-9 && Fa.panels(1).layers(1).name == "mean of " + n3 + " units", ...
    sprintf('a fixed layer keeping %d units, aggregate "mean": each in R.rate, their mean +/- SEM across them in R.layerMean', n3));

% events: marks and a train
ev = EphysAnalysisConfig.defaultLayer("raster");
ev.source = "events"; ev.binding = "fixed"; ev.event.line = "Stim";
tr = ev; tr.eventsAs = "train";
fe = cfg.Figures(cfg.figureIndex("rp"));
fe.id = "events";
fe.panels(1).layers = [fe.panels(1).layers ev tr];
fe.panels(2).layers = tr;
cfg = cfg.addFigure(fe);
se = cfg.figureFor("events");
Fe = rn.computeFigure(src, se, Observation=Tu(1, :));
Lm = Fe.panels(1).layers(2);
Lt = Fe.panels(1).layers(3);
Lp = Fe.panels(2).layers(1);
M = epochEvents(src, Fe.epochs, Sequences=eventMarkRef(ev.event));
nE = height(Fe.epochs);
check(Lm.skip == "" && Lm.R.kind == "events" && isequaln(Lm.R.marks, M) && Lm.name == "Stim onset" && Lm.eventsAs == "marks", ...
    'events marks: epochEvents of the line over the figure''s epochs, named by the line');
at0 = abs(Lt.R.raster.times) < 1e-9;
check(Lt.skip == "" && Lt.name == "Stim onset" && Lt.R.labels == "Stim onset" && Lt.R.meta.class == "event" && Lt.eventsAs == "train" ...
    && isscalar(Lt.R.raster) && isequal(unique(Lt.R.raster.epoch(at0)).', 1:nE), ...
    'events as a train: a one-unit spike train named by the line, with a raster event at 0 in every epoch');
[~, kPk] = max(sum(Lp.R.rate, 3));
check(Lp.skip == "" && abs(Lp.R.edges(kPk)) < 1e-9 && nnz(abs(M.t) < 1e-9) == nE && nnz(at0) == nE, ...
    'the train''s PSTH of the Stim line peaks in the bin from 0 when aligned to Stim onset, as epochEvents'' latencies of 0 say');

% a panel's own window
fo = cfg.Figures(cfg.figureIndex("rp"));
fo.id = "own";
fo.panels(2).window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.3);
cfg = cfg.addFigure(fo);
so = cfg.figureFor("own");
Fo = rn.computeFigure(src, so, Observation=Tu(1, :));
Po = Fo.panels(2);
check(istable(Po.epochs) && ~Po.sharesTime && Fo.panels(1).sharesTime && isempty(Fo.panels(1).epochs) ...
    && all(abs(Po.epochs.tStop - Po.epochs.t0 - 0.3) < 1e-9) && all(abs(Po.epochs.tStart - Po.epochs.t0 + 0.1) < 1e-9) ...
    && isequal(Po.groups.label, Fo.groups.label) && sum(Po.groups.n) == height(Po.epochs) ...
    && all(abs(Po.layers(1).R.window - [-0.1 0.3]) < 1e-9) && isequal(Po.layers(1).R.groups.label, Fo.groups.label), ...
    'a panel''s own window: its own epochs over it, with the figure''s groups');

% a channel observation
k1 = find(Tc.channel == Tu.channel(1), 1);
fc = cfg.Figures(cfg.figureIndex("ct"));
fc.id = "chan";
fc.observe.kind = "channel";
muaL = lfpL; muaL.source = "MUA";
fc.panels(1).layers = [fc.panels(1).layers muaL];
fc = EphysAnalysisConfig.placePanel(fc, struct('id', "r", 'type', "raster", 'layers', EphysAnalysisConfig.defaultLayer("raster")), ...
    "below", "continuous_1");
cfg = cfg.addFigure(fc);
sch = cfg.figureFor("chan");
Fc = rn.computeFigure(src, sch, Observation=Tc(k1, :));
[~, ~, mM] = selectChannels(src, "MUA");
Lc = Fc.panels(1).layers;
check(isscalar(k1) && Fc.observation.kind == "channel" && Fc.observation.column == Tc.column(k1) && isequal(Lc(1).R.channels, Tc.column(k1)) ...
    && isequal(Lc(2).R.channels, find(mM.recordingChannel == Tc.channel(k1), 1)) && Fc.panels(2).layers(1).skip == "" ...
    && all(Fc.panels(2).layers(1).meta.channel == Tc.channel(k1)) && any(Fc.panels(2).layers(1).meta.unitId == Tu.unitId(1)), ...
    'a channel observation: its own column, the same recording channel in the MUA extract, the units on that channel');

% a panel whose only layer is skipped (an AUX layer following a unit)
auxOnly = EphysAnalysisConfig.defaultLayer("continuous");
auxOnly.source = "AUX";
cfg = cfg.addFigure(struct('observe', struct('kind', "unit"), 'panels', {{struct('id', "auxonly", 'type', "continuous", ...
    'layers', auxOnly)}}), Id="auxonly");
Fn = rn.computeFigure(src, cfg.figureFor("auxonly"), Observation=Tu(1, :));
check(Fn.panels(1).skip == "" && Fn.panels(1).layers(1).skip == auxMsg && isempty(Fn.panels(1).layers(1).R), ...
    'a panel whose only layer is skipped keeps the layer and its reason');

% a parameter or a baseline the panel cannot use skips it, not the figure
fr = cfg.Figures(cfg.figureIndex("rp"));
fr.id = "nosort";
fr.panels(1).options.rasterSort = "NoSuchSort";
cfg = cfg.addFigure(fr);
Fr = rn.computeFigure(src, cfg.figureFor("nosort"), Observation=Tu(1, :));
check(~ismember("NoSuchSort", string(src.trials.Properties.VariableNames)) && Fr.panels(1).skip == "no trial parameter NoSuchSort" ...
    && Fr.panels(1).layers(1).skip == "no trial parameter NoSuchSort" && isempty(Fr.panels(1).layers(1).R) ...
    && Fr.panels(2).skip == "" && Fr.panels(2).layers(1).skip == "" && isequaln(Fr.panels(2).layers(1).R.rate, L2.R.rate), ...
    'a raster sorted by a parameter the trials lack is skipped with that reason; the PSTH under it is still computed');
fbb = cfg.Figures(cfg.figureIndex("ct"));
fbb.id = "badbase";
fbb.panels(1).options.baseline = struct('Mode', "subtract", 'Window', [-1 -0.5]);
fbb.panels(1).common = false;   % its own baseline, not the figure's common one
cfg = cfg.addFigure(fbb);
Fbb = rn.computeFigure(src, cfg.figureFor("badbase"), Observation=Tc(1, :));
check(Fbb.panels(1).skip == "" && startsWith(Fbb.panels(1).layers(1).skip, "Baseline [") && isempty(Fbb.panels(1).layers(1).R), ...
    sprintf('a signal''s baseline with no sample in the window skips the layer with the reason ("%s")', Fbb.panels(1).layers(1).skip));

% probemap, corrmap, waveforms
Fp = rn.computeFigure(src, sp);
Lpm = Fp.panels(1).layers(1);
if isempty(src.probe)
    check(Fp.panels(1).skip == "no probe map", 'probemap: no probe map in the fixture, the panel says so');
else
    cfg = cfg.addPlot(struct('kind', "probemap", 'value', "rate"), Id="pm_plot");
    Rpm = rn.computePlot(src, cfg.plotFor("pm_plot"));
    check(Lpm.skip == "" && Lpm.R.kind == "probemap" && isequaln(Lpm.R.value, Rpm.value) && isempty(Fp.epochs) && isempty(Fp.panels(1).groups), ...
        'probemap: the units'' rates on the probe sites, as computePlot''s probe map; no epochs');
end
cfg = cfg.addFigure("corrmap", Id="cm");
Fcm = rn.computeFigure(src, cfg.figureFor("cm"));
cfg = cfg.addPlot(struct('kind', "corrmap"), Id="cm_plot");
Rcm = rn.computePlot(src, cfg.plotFor("cm_plot"));
Lcm = Fcm.panels(1).layers(1);
check(Lcm.skip == "" && Lcm.R.kind == "corrmap" && isequaln(Lcm.R.r, Rcm.r) && size(Lcm.R.r, 1) == height(Rcm.meta) && size(Lcm.R.r, 1) >= 2, ...
    'corrmap: the units'' pairwise correlations, as computePlot''s correlation map');
cfg = cfg.addFigure("waveforms", Id="wf");
sw = cfg.figureFor("wf");
wsw = warning('off', 'unitWaveforms:Templates');
wsn = warning('off', 'unitWaveforms:NoWaveforms');
Fw = rn.computeFigure(src, sw, Observation=Tu(1, :));
warning(wsn); warning(wsw);
Lw = Fw.panels(1).layers(1);
check(sw.observe.kind == "unit" && Lw.skip == "" && Lw.R.kind == "waveforms" && Lw.R.n == 1 && Lw.meta.unitId == Tu.unitId(1) ...
    && isscalar(Lw.R.waveforms.mean) && ismember(Lw.R.waveforms.from, ["spikes" "template"]) && isempty(Fw.epochs), ...
    'waveforms: the observed unit''s mean waveform (unitWaveforms); not aligned, no epochs');

% cancel, checkpoints
nPolls = 0;
    function countPoll()
        nPolls = nPolls + 1;
    end
rn.clearCancel();
rn.PollFcn = @countPoll;
Fq = rn.computeFigure(src, spec, Observation=Tu(1, :));
rn.PollFcn = @() rn.cancel();
cid = string(errorId(@() rn.computeFigure(src, spec, Observation=Tu(1, :))));
rn.PollFcn = [];
rn.clearCancel();
check(nPolls >= 5 && isequaln(Fq.panels(2).layers(1).R.rate, L2.R.rate) && cid == "EphysAnalysisRunner:Canceled", ...
    sprintf('with PollFcn set, computeFigure reaches %d checkpoints; a cancel() there stops it (EphysAnalysisRunner:Canceled)', nPolls));

% figureCompute: the runner's computeFigure without a runner
Fg = figureCompute(src, spec, Observation=Tu(2, :));
Fr2 = rn.computeFigure(src, spec, Observation=Tu(2, :));
nChk = 0;
    function countCheck()
        nChk = nChk + 1;
    end
Fg2 = figureCompute(src, spec, Observation=Tu(2, :), Check=@countCheck);
cidF = string(errorId(@() figureCompute(src, spec, Observation=Tu(2, :), Check=@() error('test:Stop', 'stop'))));
check(isequaln(rmfield(Fg, 'created'), rmfield(Fr2, 'created')) && isequaln(rmfield(Fg2, 'created'), rmfield(Fr2, 'created')) ...
    && nChk >= 5 && cidF == "test:Stop", ...
    sprintf('figureCompute equals computeFigure''s result; Check= is called at %d checkpoints and what it throws stops the compute', nChk));

% figureOutputName: {Plot} the figure, {Unit} the observation, "_<Unit>" when the pattern does not tell them apart
pat = "{Name}_{Plot}";
u2 = shortUnitLabels(Tu.meta{2}.label);
n1 = figureOutputName(pat, "DS-1", spec, Tu(2, :), 2, nU);
n2 = figureOutputName("{Name}_{Plot}_{Unit}", "DS-1", spec, Tu(2, :), 2, nU);
n3 = figureOutputName("{Plot}_{Index}_{Kind}", "DS-1", spec, Tu(2, :), 2, nU);
n4 = figureOutputName(pat, "DS-1", spec, Tu(2, :), 1, 1);
n5 = figureOutputName(pat, "DS-1", sc, Tc(1, :), 1, height(Tc));
n6 = figureOutputName(pat, "DS-1", sp, Td, 1, 1);
n7 = figureOutputName(pat, "DS-1", spec, struct('kind', "unit", 'unitId', 7), 1, 2);
check(n1 == "DS-1_rp_" + u2 && n2 == "DS-1_rp_" + u2 && n3 == "rp_2_figure" && n4 == "DS-1_rp" ...
    && n5 == "DS-1_ct_ch" + Tc.channel(1) && n6 == "DS-1_pm" && n7 == "DS-1_rp_u7", ...
    sprintf('figureOutputName: "%s", "%s" ({Unit}), "%s" ({Index}: no suffix), "%s" (one observation), "%s", "%s", "%s"', ...
    n1, n2, n3, n4, n5, n6, n7));

detObs = @(lbl, ch) struct('kind', "unit", 'unitId', ch, 'meta', table(lbl, ch, "det", 'VariableNames', {'label', 'unitId', 'class'}));
d1 = figureOutputName(pat, "DS-1", spec, detObs("Shank_1", 1), 1, 2);
d2 = figureOutputName(pat, "DS-1", spec, detObs("Shank_2", 2), 2, 2);
check(d1 == "DS-1_rp_Shank_1" && d2 == "DS-1_rp_Shank_2", ...
    sprintf('figureOutputName: detections keep their channel''s whole name ("%s", "%s"), never one shared short label', d1, d2));

% figureCaption
capU =figureCaption(spec, Tu, Dataset=src.name);
capD = figureCaption(sp, Td);
check(startsWith(capU, sprintf("rp: %d observations (sorted units", nU)) && contains(capU, " of " + src.name) ...
    && contains(capU, "panels: raster, PSTH") && contains(capU, "aligned to Stim onset") && contains(capU, "window [-0.2 0.8] s") ...
    && contains(capU, "groups by Depth") && startsWith(capD, "pm: 1 observation (the dataset); panels: probe map") ...
    && ~contains(capD, "aligned") && endsWith(capD, "."), "figureCaption: " + capU + " / " + capD);

% firing rate and tuning curve panels, an auROC PSTH, a stacked PSTH, the waveforms' probe layout
m3 = min(3, nU);
cfg = cfg.addFigure("rate", Id="rt");
Frt = rn.computeFigure(src, cfg.figureFor("rt"), Observation=Tu(1, :));
cfg = cfg.addPlot(struct('kind', "rate", 'units', struct('ids', Tu.unitId(1))), Id="rate_u1");
Rrt = rn.computePlot(src, cfg.plotFor("rate_u1"));
Lrt = Frt.panels(1).layers(1);
check(Lrt.skip == "" && Lrt.R.kind == "rate" && size(Lrt.R.meanRate, 1) == 1 && Lrt.meta.unitId == Tu.unitId(1) ...
    && isequaln(Lrt.R.meanRate, Rrt.meanRate) && isequaln(Lrt.R.rate, Rrt.rate) && isequaln(Lrt.R.err.lo, Rrt.err.lo) ...
    && isequal(Lrt.R.groups.label, Rrt.groups.label) && ~Frt.panels(1).sharesTime && istable(Frt.epochs), ...
    'a rate panel of the observed unit is computePlot''s rate plot of that unit (the same epochs, groups and error)');
fr3 = cfg.Figures(cfg.figureIndex("rt"));
fr3.id = "rt3";
fx3 = EphysAnalysisConfig.defaultLayer("rate");
fx3.binding = "fixed"; fx3.units.ids = Tu.unitId(1:m3).'; fx3.aggregate = "mean";
fr3.panels(1).layers = [fr3.panels(1).layers fx3];
fr3.panels(1).options.display = "box";
cfg = cfg.addFigure(fr3);
Frt3 = rn.computeFigure(src, cfg.figureFor("rt3"), Observation=Tu(2, :));
Lr3 = Frt3.panels(1).layers(2);
check(Lr3.skip == "" && size(Lr3.R.meanRate, 1) == m3 && isequaln(Lr3.R.layerMean.mean, reshape(mean(Lr3.R.meanRate, 1, 'omitnan'), 1, 1, [])) ...
    && Lr3.R.layerMean.n == m3 && Frt3.panels(1).layers(1).meta.unitId == Tu.unitId(2), ...
    'a rate panel''s second layer: three fixed units and their mean (R.layerMean over the units'' means)');
cfg = cfg.addFigure("tuning", Id="tc");
stc = cfg.figureFor("tc");
Ftc = rn.computeFigure(src, stc, Observation=Tu(1, :));
cfg = cfg.addPlot(struct('kind', "tuning", 'param', "Depth", 'units', struct('ids', Tu.unitId(1))), Id="tuning_u1");
Rtc = rn.computePlot(src, cfg.plotFor("tuning_u1"));
Ltc = Ftc.panels(1).layers(1);
check(Ltc.skip == "" && Ltc.R.kind == "tuning" && Ltc.R.param == "Depth" && stc.panels.options.param == "" ...
    && isequal(Ltc.R.x, Rtc.x) && isequaln(Ltc.R.mean, Rtc.mean) && isequaln(Ltc.R.err.lo, Rtc.err.lo) && isequal(Ltc.R.series, Rtc.series) ...
    && ismember("Depth", string(Ftc.epochs.Properties.VariableNames)), ...
    'a tuning panel (param "" = the figure''s groupBy, Depth) is computePlot''s tuning curve of that unit');
ft2 = cfg.Figures(cfg.figureIndex("tc"));
ft2.id = "tc2";
ft2.panels(1).options.seriesParam = "TrialType";
ft2.panels(1).options.waveform.mode = "mean";
ft2.panels(1).common = false;
ft2.selection = struct('groupBy', string.empty(1, 0));
cfg = cfg.addFigure(ft2);
wsw = warning('off', 'unitWaveforms:Templates');
wsn = warning('off', 'unitWaveforms:NoWaveforms');
Ftc2 = rn.computeFigure(src, cfg.figureFor("tc2"), Observation=Tu(1, :));
warning(wsn); warning(wsw);
Lt2 = Ftc2.panels(1).layers(1);
expParam = figureTuningParamOf(src);
check(Lt2.skip == "" && Lt2.R.param == expParam && Lt2.R.seriesParam == "TrialType" && height(Lt2.R.groups) >= 1 ...
    && isfield(Lt2.R, 'waveforms') && isequal(sort(string(Ftc2.epochs.Properties.VariableNames(end-1:end))), sort([expParam "TrialType"])), ...
    sprintf('a tuning panel without groupBy tunes over the first numeric trial parameter (%s), a series per TrialType, with the waveform inset', expParam));
fm2 = cfg.Figures(cfg.figureIndex("tc"));
fm2.id = "tcmiss";
fm2.panels(1).options.param = "NoSuchParam";
cfg = cfg.addFigure(fm2);
Ftm = rn.computeFigure(src, cfg.figureFor("tcmiss"), Observation=Tu(1, :));
[rm, lrm] = figureSkipReason(src, cfg.figureFor("tcmiss"));
check(rm == "" && Ftm.panels(1).skip == "no trial parameter NoSuchParam" && Ftm.panels(1).layers(1).skip == "no trial parameter NoSuchParam" ...
    && isempty(Ftm.panels(1).layers(1).R) && any([lrm.reason] == "no trial parameter NoSuchParam"), ...
    'a tuning panel over a parameter the trials lack is skipped: "no trial parameter NoSuchParam" (figureSkipReason too)');
fa4 = cfg.Figures(cfg.figureIndex("rp"));
fa4.id = "auroc";
fa4.common.baseline = struct('Mode', "auroc", 'Window', [-0.2 0]);
cfg = cfg.addFigure(fa4);
cfg = cfg.addPlot(struct('kind', "psth", 'baseline', struct('Mode', "auroc", 'Window', [-0.2 0]), 'units', struct('ids', Tu.unitId(1))), Id="psth_auroc");
wa1 = warning('off', 'aurocCall:NoCutoff');
wa2 = warning('off', 'aurocCall:WideCutoff');
Fau = rn.computeFigure(src, cfg.figureFor("auroc"), Observation=Tu(1, :));
Rau = rn.computePlot(src, cfg.plotFor("psth_auroc"));
warning(wa2); warning(wa1);
Lau = Fau.panels(2).layers(1);
check(Lau.skip == "" && isfield(Lau.R, 'auroc') && ~isempty(Lau.R.auroc) && Lau.R.units == "auROC" && isequaln(Lau.R.rate, Rau.rate) ...
    && isequaln(Lau.R.t, Rau.t) && isequal(Lau.R.auroc.direction, Rau.auroc.direction) && isequaln(Lau.R.auroc.mean, Rau.auroc.mean), ...
    'an auROC PSTH (the common baseline Mode "auroc") is computePlot''s PSTH with the auROC baseline, its calls too');
fs4 = cfg.Figures(cfg.figureIndex("rp"));
fs4.id = "stacked";
fs4.panels(2).options.stack = true;
fs4.panels(2).options.stackSpacing = 1.5;
cfg = cfg.addFigure(fs4);
Fst = rn.computeFigure(src, cfg.figureFor("stacked"), Observation=Tu(1, :));
check(Fst.panels(2).layers(1).skip == "" && isequaln(Fst.panels(2).layers(1).R.rate, L2.R.rate) && height(Fst.groups) >= 2, ...
    sprintf('a stacked PSTH computes as an overlaid one (%d groups; stacking is the draw''s)', height(Fst.groups)));
fwp = cfg.Figures(cfg.figureIndex("wf"));
fwp.id = "wfprobe";
fwp.panels(1).options.layout = "probe";
fxw = EphysAnalysisConfig.defaultLayer("waveforms");
fxw.binding = "fixed"; fxw.units.ids = Tu.unitId(1:m3).';
fwp.panels(1).layers = [fxw EphysAnalysisConfig.defaultLayer("waveforms")];
cfg = cfg.addFigure(fwp);
wsw = warning('off', 'unitWaveforms:Templates');
wsn = warning('off', 'unitWaveforms:NoWaveforms');
Fwp = rn.computeFigure(src, cfg.figureFor("wfprobe"), Observation=Tu(2, :));
warning(wsn); warning(wsw);
Lwp = Fwp.panels(1).layers;
check(numel(Lwp) == 2 && Lwp(1).skip == "" && Lwp(1).R.kind == "waveforms" && Lwp(1).R.n == m3 && numel(Lwp(1).R.waveforms.mean) == m3 ...
    && Lwp(2).skip == "" && Lwp(2).R.kind == "ring" && Lwp(2).meta.unitId == Tu.unitId(2) && ~isfield(Lwp(2).R, 'waveforms'), ...
    'a waveforms panel in the probe layout: its first layer''s units with their waveforms, a following layer naming the unit to ring');

% per-trial continuous traces: every epoch's, and at most maxTrials of them
ftr = cfg.Figures(cfg.figureIndex("ct"));
ftr.id = "trials";
ftr.panels.options.trials = "faint";
cfg = cfg.addFigure(ftr);
str = cfg.figureFor("trials");
Ttr = figureObservations(src, str);
Ftr = rn.computeFigure(src, str, Observation=Ttr(1, :));
Rtr = Ftr.panels.layers(1).R;
nK = numel(Rtr.keptEpochs);
gTr = Ftr.epochs.groupIndex(ismember(Ftr.epochs.epoch, Rtr.keptEpochs));
m1 = mean(double(Rtr.data(:, 1, Rtr.trialGroup == 1)), 3);
check(Ftr.panels.layers(1).skip == "" && isequal(size(Rtr.data, [1 2 3]), [numel(Rtr.t) 1 nK]) && isa(Rtr.data, 'single') ...
    && isequal(Rtr.trialEpochs, Rtr.keptEpochs(:)) && isequal(Rtr.trialGroup, gTr) ...
    && max(abs(m1 - Rtr.mean(:, 1, 1))) <= 1e-4 * max(abs(Rtr.mean(:, 1, 1))) + 1e-9, ...
    sprintf('continuous trials "faint": R.data holds every epoch''s trace [%d x 1 x %d], their epochs and groups; a group''s traces average to its mean', ...
    numel(Rtr.t), nK));
ftr5 = ftr;
ftr5.id = "trials5";
ftr5.panels.options.trials = "only";
ftr5.panels.options.maxTrials = 5;
cfg = cfg.addFigure(ftr5);
Ftr5 = rn.computeFigure(src, cfg.figureFor("trials5"), Observation=Ttr(1, :));
R5 = Ftr5.panels.layers(1).R;
pick = unique(round(linspace(1, nK, 5)));
check(nK > 5 && size(R5.data, 3) == 5 && isequal(R5.trialEpochs, reshape(Rtr.keptEpochs(pick), [], 1)) ...
    && isequaln(R5.data, Rtr.data(:, :, pick)) && isequaln(R5.trialGroup, Rtr.trialGroup(pick)) && isequaln(R5.mean, Rtr.mean), ...
    'maxTrials 5: five epochs picked evenly over their order (the mean still over every epoch)');
check(isempty(F3.panels(3).layers(1).R.data) && ~isfield(F3.panels(3).layers(1).R, 'trialEpochs'), 'trials "off" keeps no traces');

% a heat map of one unit's trials
hmL = EphysAnalysisConfig.defaultLayer("heatmap");
hmL.binding = "observation";
fth = struct('panels', {{struct('id', "tm", 'type', "heatmap", 'layers', hmL, 'common', false, 'options', struct('rows', "trials", ...
    'measure', "count", 'bins', struct('BinSec', 0.02, 'SmoothSec', 0), 'rasterSort', "Depth", 'rasterSortOrder', "descending"))}});
cfg = cfg.addFigure(fth, Id="trialmap");
sth = cfg.figureFor("trialmap");
Fth = rn.computeFigure(src, sth, Observation=Tu(1, :));
Rth = Fth.panels.layers(1).R;
nEh = height(Fth.epochs);
withSpikes = unique(Rth.raster.epoch);
e1 = withSpikes(1);
byHand = histcounts(Rth.raster.times(Rth.raster.epoch == e1) + 1e-9, Rth.edges);
okMean = true;
for g = 1:height(Fth.groups)
    okMean = okMean && max(abs(mean(Rth.trialMatrix(Rth.trialGroup == g, :), 1).' - Rth.rate(:, 1, g)), [], 'omitnan') < 1e-12;
end
check(Fth.panels.layers(1).skip == "" && sth.observe.kind == "unit" && Fth.panels.layers(1).meta.unitId == Tu.unitId(1) ...
    && isequal(size(Rth.trialMatrix), [nEh numel(Rth.t)]) && isequal(Rth.trialMatrix(e1, :), byHand) && okMean, ...
    sprintf('a heat map of trials: [%d epochs x %d bins], epoch %d''s row the raster binned by hand; each group''s rows average to its PSTH', ...
    nEh, numel(Rth.t), e1));
og = Rth.trialGroup(Rth.trialOrder);
dep = Fth.epochs.Depth(Rth.trialOrder);
okOrder = isequal(sort(Rth.trialOrder(:)), (1:nEh).') && issorted(og);
for g = reshape(unique(og), 1, [])
    okOrder = okOrder && issorted(flipud(dep(og == g)));
end
check(okOrder && Rth.trialRowsName == "Epoch (by Depth), descending", ...
    'its rows go as a raster sorts them: by group, then Depth descending');

% a panel with a trial selection of its own: its own epochs and groups
fos = cfg.Figures(cfg.figureIndex("rp"));
fos.id = "ownsel";
fos.panels(2).selection = struct('groupBy', string.empty(1, 0));
cfg = cfg.addFigure(fos);
Fos = rn.computeFigure(src, cfg.figureFor("ownsel"), Observation=Tu(1, :));
check(~Fos.panels(1).ownSelection && Fos.panels(2).ownSelection && height(Fos.groups) > 1 && height(Fos.panels(2).groups) == 1 ...
    && istable(Fos.panels(2).epochs) && height(Fos.panels(2).epochs) == height(Fos.epochs) && size(Fos.panels(2).layers(1).R.rate, 3) == 1 ...
    && Fos.panels(2).sharesTime && isempty(Fos.panels(1).epochs), ...
    sprintf('a PSTH with a selection of its own (no groupBy): its own epochs and one group, the raster on the figure''s %d groups', ...
    height(Fos.groups)));

% one figure per trial group
fpg = cfg.Figures(cfg.figureIndex("rp"));
fpg.id = "pergroup";
fpg.observe.perGroup = true;
cfg = cfg.addFigure(fpg);
spg = cfg.figureFor("pergroup");
Tpg = figureObservations(src, spg);
gOn = find(F1.groups.n > 0);
nGg = numel(gOn);
check(nGg >= 2 && height(Tpg) == nU * nGg && isequal(Tpg.unitId, repelem(Tu.unitId, nGg)) && isequal(Tpg.group(1:nGg), gOn) ...
    && isequal(Tpg.groupLabel(1:nGg), string(F1.groups.label(gOn))) && all(endsWith(Tpg.label, " · " + Tpg.groupLabel)) ...
    && all(isnan(Tu.group)) && all(Tu.groupLabel == ""), ...
    sprintf('perGroup: one observation per unit and trial group (%d units x %d groups), the label ending in its group', nU, nGg));
Fpg = rn.computeFigure(src, spg, Observation=Tpg(2, :));
g2 = Tpg.group(2);
check(height(Fpg.groups) == 1 && string(Fpg.groups.label) == Tpg.groupLabel(2) && Fpg.groups.n == F1.groups.n(g2) ...
    && height(Fpg.epochs) == F1.groups.n(g2) && all(Fpg.epochs.groupIndex == 1) && all(string(Fpg.epochs.group) == Tpg.groupLabel(2)) ...
    && isequaln(Fpg.panels(2).layers(1).R.rate, F1.panels(2).layers(1).R.rate(:, :, g2)) && Fpg.observation.groupLabel == Tpg.groupLabel(2), ...
    'a per-group figure keeps that group''s epochs only (one group, n recounted): its PSTH is the unit''s PSTH of the group');
fpo = fpg;
fpo.id = "pergroupown";
fpo.panels(2).selection = struct('groupBy', string.empty(1, 0));
cfg = cfg.addFigure(fpo);
Fpo = rn.computeFigure(src, cfg.figureFor("pergroupown"), Observation=Tpg(2, :));
check(height(Fpo.epochs) == F1.groups.n(g2) && height(Fpo.panels(2).epochs) == height(F1.epochs), ...
    'a panel with a selection of its own is not cut to the observation''s group');
u1 = figureOutputName("{Unit}", "DS", spg, Tu(1, :), 1, 1);
gs = regexprep(Tpg.groupLabel(2), '[^\w\-\.]', '_');
nm1 = figureOutputName("{Name}_{Plot}", "DS", spg, Tpg(2, :), 2, height(Tpg));
nm2 = figureOutputName("{Name}_{Plot}_{Group}", "DS", spg, Tpg(2, :), 2, height(Tpg));
nm3 = figureOutputName("{Name}_{Plot}_{Index}", "DS", spg, Tpg(2, :), 2, height(Tpg));
check(nm1 == "DS_pergroup_" + u1 + "_" + gs && nm2 == "DS_pergroup_" + gs + "_" + u1 && nm3 == "DS_pergroup_2" ...
    && contains(figureCaption(spg, Tpg), "one figure per trial group") && ~contains(figureCaption(spec, Tu), "per trial group"), ...
    sprintf('figureOutputName: {Group} = the group ("%s"; "_<Group>" appended without {Group} or {Index}); figureCaption says per trial group', nm1));

% one observation costs a fraction of every unit
haveBootT = license('test', 'Statistics_Toolbox') && exist('bootci', 'file');
if nU >= 4 && haveBootT
    % bootstrap bands make the per-unit work, not the fixed steps, the bulk of the time
    cfgT = cfg;
    cfgT.Figures(cfgT.figureIndex("rp")).style.ErrorType = "ci95";
    cfgT = cfgT.addPlot(struct('kind', "psth", 'style', struct('ErrorType', "ci95")), Id="psth_ci");
    specT = cfgT.figureFor("rp");
    plotT = cfgT.plotFor("psth_ci");
    rn.computeFigure(src, specT, Observation=Tu(1, :));   % warm both
    rn.computePlot(src, plotT);
    tF = Inf; tP = Inf;
    for rep = 1:3
        tc0 = tic; rn.computeFigure(src, specT, Observation=Tu(1, :)); tF = min(tF, toc(tc0));
        tc0 = tic; rn.computePlot(src, plotT); tP = min(tP, toc(tc0));
    end
    check(tF <= 0.5 * tP, sprintf(['one observation of the raster + PSTH figure (%.3f s) takes at most half the time of ' ...
        'computePlot''s PSTH of all %d units (%.3f s)'], tF, nU, tP));
else
    fprintf('  (timing check skipped: %d unit(s), bootci %d)\n', nU, haveBootT);
end

%% ============================================================================ render
fprintf('\n== 8. render: renderFigure, figureTiles, the draw functions ==\n');
% figureTiles: relative sizes as equal units
pp = struct('row', {1 2}, 'col', {1 1}, 'rowSpan', {1 1}, 'colSpan', {1 1});
gr = struct('rows', 2, 'cols', 1, 'rowHeights', [1 2], 'colWidths', [], 'spacing', "none");
[nr1, nc1, to1, so1] = figureTiles(gr, pp);
gr.rowHeights = [1 1.5];
[nr2, ~, to2, so2] = figureTiles(gr, pp);
gr.rowHeights = [];
[nr3, ~, to3, so3] = figureTiles(gr, pp);
check(nr1 == 3 && nc1 == 1 && isequal(to1, [1; 2]) && isequal(so1, [1 1; 2 1]) && nr2 == 5 && isequal(to2, [1; 3]) ...
    && isequal(so2, [2 1; 3 1]) && nr3 == 2 && isequal(to3, [1; 2]) && isequal(so3, [1 1; 1 1]), ...
    'figureTiles: rows [1 2] are 3 unit rows (spans 1 and 2), [1 1.5] are 2 + 3 of 5, [] equal');
pq = struct('row', {1 2 2}, 'col', {1 1 2}, 'rowSpan', {1 1 1}, 'colSpan', {2 1 1});
gq = struct('rows', 2, 'cols', 2, 'rowHeights', [], 'colWidths', [1 3], 'spacing', "tight");
[nr4, nc4, to4, so4] = figureTiles(gq, pq);
gq.colWidths = [1 1.37];
[~, nc5] = figureTiles(gq, pq);
gq.colWidths = [1 100];
[~, nc6, ~, so6] = figureTiles(gq, pq);
check(nr4 == 2 && nc4 == 4 && isequal(to4, [1; 5; 6]) && isequal(so4, [1 4; 1 1; 1 3]) && nc5 == 9 && nc6 <= 32 ...
    && so6(2, 2) == 1 && so6(1, 2) == nc6, ...
    sprintf('figureTiles: column widths [1 3] with a spanning panel; [1 1.37] in quarter steps (%d units); [1 100] capped (%d units)', nc5, nc6));
hc = [52 47 1 1 1 1 1 1 1 1 1];
pc = struct('row', num2cell(1:numel(hc)), 'col', 1, 'rowSpan', 1, 'colSpan', 1);
[nr7, ~, ~, so7] = figureTiles(struct('rows', numel(hc), 'cols', 1, 'rowHeights', hc, 'colWidths', [], 'spacing', "none"), pc);
[~, oc] = sort(hc);
check(nr7 <= 32 && all(so7(:, 1) >= 1) && all(diff(so7(oc, 1)) >= 0) && so7(1, 1) >= so7(2, 1), ...
    sprintf('figureTiles: past the 32-unit cap the sizes keep their order (rows %s as %s units)', mat2str(hc), mat2str(so7(:, 1).')));

% the registry
reg = figurePanelRegistry();
okReg = all(arrayfun(@(t) isfield(reg, t) && isa(reg.(t).compute, 'function_handle') && isa(reg.(t).draw, 'function_handle'), T.Type));
check(okReg && isequal(sort(string(fieldnames(reg))), sort(T.Type)), 'figurePanelRegistry: a compute and a draw function for every panel type');

% two more figures: a heat map, and a PSTH with latency marks
cfg = cfg.addFigure("heatmap", Id="hm");
Fh = rn.computeFigure(src, cfg.figureFor("hm"));
evOff = ev;
evOff.event.edge = "offset";
fm = cfg.Figures(cfg.figureIndex("rp"));
fm.id = "marks";
fm.panels(2).layers = [fm.panels(2).layers evOff];
cfg = cfg.addFigure(fm);
Fm = rn.computeFigure(src, cfg.figureFor("marks"), Observation=Tu(1, :));

% every panel type into every kind of target
fig = figure('Visible', 'off', 'Position', [100 100 700 800]);
ufig = uifigure('Visible', 'off', 'Position', [100 100 700 800]);
fe1 = figure('Visible', 'off', 'Position', [100 100 700 800]);
closeFigs = onCleanup(@() delete([fig ufig fe1]));
roles = PlotAesthetics.roles().Role;
rcases = {
    "raster + PSTH",                    F1
    "raster / PSTH / continuous stack", F3
    "events as marks and a train",      Fe
    "PSTH with latency marks",          Fm
    "a layer's mean of three units",    Fa
    "a panel's own window",             Fo
    "a channel observation",            Fc
    "heat map",                         Fh
    "a panel of one skipped layer",     Fn
    "probe map",                        Fp
    "unit correlation",                 Fcm
    "unit waveforms",                   Fw
    "firing rate",                      Frt
    "a rate of a unit and a 3-unit mean (box)", Frt3
    "tuning curve",                     Ftc
    "tuning curves per series, inset",  Ftc2
    "an auROC PSTH",                    Fau
    "a stacked PSTH",                   Fst
    "unit waveforms on the probe",      Fwp
    "continuous trials, faint",         Ftr
    "continuous trials only, 5 of them", Ftr5
    "a heat map of trials",             Fth
    "a PSTH with its own selection",    Fos
    "one trial group's figure",         Fpg};
for k = 1:size(rcases, 1)
    Fk = rcases{k, 2};
    ids = [Fk.panels.id];
    okAll = true;
    msgs = "";
    for mode = ["axes" "uiaxes" "figure" "panel" "grid"]
        try
            switch mode
                case "axes",   clf(fig); tg = axes(fig); %#ok<LAXES>
                case "uiaxes", delete(ufig.Children); tg = uiaxes(ufig);
                case "figure", tg = fig;
                case "panel",  delete(ufig.Children); tg = uipanel(ufig);
                case "grid",   delete(ufig.Children); tg = uigridlayout(ufig, [1 1]);
            end
            h = renderFigure(Fk, Fk.spec, tg);
            drawnow;
            ok = ~isempty(h.axes) && all(isgraphics(h.axes)) && ~isempty(h.axes(1).Children) && h.title ~= "" ...
                && isequal([h.panels.id], ids);
            if ismember(mode, ["axes" "uiaxes"])
                ok = ok && isempty(h.layout) && isscalar(h.axes) && h.axes == tg;
                C = PlotAesthetics.components(tg);
            else
                ok = ok && ~isempty(h.layout) && numel(h.axes) == numel(ids) && string(h.layout.Title.String) == h.title;
                C = PlotAesthetics.components(h.layout);
                named = all(ismember(ids, C.TileName(C.Tile > 0)));
                if ~named; msgs = msgs + mode + ": tiles " + strjoin(unique(C.TileName(C.Tile > 0)), ", ") + "  "; end
                ok = ok && named;
            end
            bad = C.Role == "" | ~ismember(C.Role, roles);
            if any(bad); msgs = msgs + mode + ": untagged " + strjoin(C.Type(bad) + " " + C.Role(bad), ", ") + "  "; end
            ok = ok && ~any(bad);
        catch ME
            ok = false;
            msgs = msgs + mode + ": " + ME.message + "  ";
        end
        okAll = okAll && ok;
    end
    msg = rcases{k, 1} + " draws into an axes, a uiaxes, a figure, a uipanel and a grid layout, every component tagged, the tiles named by panel";
    if msgs ~= ""; msg = msg + " (" + msgs + ")"; end
    check(okAll, msg);
end

% title and subtitle
h1 = renderFigure(F1, F1.spec, fig);
want = "rp: " + F1.observation.label + " — " + eventRefLabel(F1.spec.ref) + " (" + height(F1.epochs) + " epochs)";
check(h1.title == want && string(h1.layout.Title.String) == want && string(h1.layout.Subtitle.String) == src.name ...
    && isequal([h1.panels.type], ["raster" "psth"]) && isequal(h1.panels(2).axes, h1.axes(2)), ...
    sprintf('the title names the figure, the observation, the event and the epochs ("%s"); the dataset is the subtitle', want));
sT = F1.spec;
sT.title = "My figure";
hT = renderFigure(F1, sT, fig);
check(hT.title == "My figure" && string(hT.layout.Title.String) == "My figure" ...
    && string(hT.axes(1).Title.String) == F1.observation.label && string(hT.axes(2).Title.String) == "", ...
    'a title of the figure''s own: the top-left panel names the observation');

% one time axis down a stack
h3 = renderFigure(F3, F3.spec, fig);
A = h3.axes;
W = [F3.spec.window.pre F3.spec.window.post];
check(numel(A) == 3 && all(arrayfun(@(a) isequal(xlim(a), W), A)), ...
    sprintf('the three time panels of a stack all show the figure''s window [%g %g]', W));
check(isempty(A(1).XTickLabel) && isempty(A(2).XTickLabel) && ~isempty(A(3).XTickLabel) ...
    && string(A(3).XLabel.String) == "Time (s)" && string(A(1).XLabel.String) == "" && string(A(2).XLabel.String) == "", ...
    'the upper time panels of a column drop their x tick labels; the bottom one has them and "Time (s)"');
ho = renderFigure(Fo, Fo.spec, fig);
check(~isempty(ho.axes(1).XTickLabel) && ~isempty(ho.axes(2).XTickLabel) && isequal(xlim(ho.axes(2)), [-0.1 0.3]) ...
    && isequal(xlim(ho.axes(1)), [Fo.spec.window.pre Fo.spec.window.post]), ...
    'a panel with a window of its own keeps its own time axis, and the panel above keeps its tick labels');
hr = renderFigure(F3, F3.spec, fig);
lg = findall(fig, 'Type', 'legend');
ls3 = string(lg(1).String);
check(isscalar(lg) && all(arrayfun(@(g) nnz(ls3 == g) == 1, string(F3.groups.label))) && numel(unique(ls3)) == numel(ls3) ...
    && isequal(ls3(1:height(F3.groups)), reshape(string(F3.groups.label), 1, [])) && isgraphics(hr.layout), ...
    sprintf('one legend for the figure: each group once, first, then the layers (%s)', strjoin(ls3, ", ")));

% per-trial traces, a heat map of trials, a panel's own legend, one group's figure
htr = renderFigure(Ftr, Ftr.spec, fig);
tt = findall(htr.axes(1), 'Tag', 'trialTrace');
mt = findall(htr.axes(1), 'Tag', 'trace');
nGtr = height(Ftr.groups);
check(numel(tt) == nGtr && numel(mt) == nGtr && all(arrayfun(@(x) nnz(isnan(x.YData)), tt) >= 1) ...
    && sum(arrayfun(@(x) nnz(isnan(x.YData)), tt)) == nK && ismember("trialTrace", PlotAesthetics.roles().Role) ...
    && PlotAesthetics.roleLabel("trialTrace") == "Trial traces" && tt(1).LineWidth < mt(1).LineWidth ...
    && ~isequal(tt(1).Color, mt(1).Color), ...
    sprintf('trials "faint": one NaN-joined pale line of traces per group (%d epochs in all) under each mean, role trialTrace', nK));
ht5 = renderFigure(Ftr5, Ftr5.spec, fig);
lg5 = findall(fig, 'Type', 'legend');
check(numel(findall(ht5.axes(1), 'Tag', 'trialTrace')) == nGtr && isempty(findall(ht5.axes(1), 'Tag', 'trace')) ...
    && isempty(findall(ht5.axes(1), 'Tag', 'sem')) && (nGtr < 2 || (isscalar(lg5) && numel(lg5.String) >= nGtr)), ...
    'trials "only": the traces without the mean or its band; they stand for the groups in the legend');
hth = renderFigure(Fth, Fth.spec, fig);
ath = hth.axes(1);
img = findall(ath, 'Tag', 'image');
bands = findall(ath, 'Tag', 'rasterBand');
check(isscalar(img) && isequal(size(img.CData), [nEh numel(Rth.t)]) && isequaln(img.CData, Rth.trialMatrix(Rth.trialOrder, :)) ...
    && numel(bands) >= height(Fth.groups) && string(ath.YLabel.String) == "Epoch (by Depth), descending" ...
    && isequal(xlim(ath), [Fth.spec.window.pre Fth.spec.window.post]) && string(ath.YDir) == "reverse", ...
    'a heat map of trials draws a row per epoch in its order, the groups as a strip at the left, y label "Epoch (by ...)"');
hos = renderFigure(Fos, Fos.spec, fig);
check(string(hos.axes(2).Title.String) == "all trials" && isscalar(findall(fig, 'Type', 'legend')), ...
    'a PSTH with a selection of its own that groups by nothing: titled "all trials", no legend of one group');
fod = cfg.Figures(cfg.figureIndex("rp"));
fod.id = "ownsel2";
fod.panels(2).selection = struct('groupBy', "Depth", 'groupOrder', "descending");
cfg = cfg.addFigure(fod);
Fod = rn.computeFigure(src, cfg.figureFor("ownsel2"), Observation=Tu(1, :));
hod = renderFigure(Fod, Fod.spec, fig);
lgs = findall(fig, 'Type', 'legend');
mine = arrayfun(@(l) isequal(l.Axes, hod.axes(2)), lgs);
inPanel = lgs(mine);
outer = lgs(~mine);
gl = reshape(string(Fod.groups.label), 1, []);
check(Fod.panels(2).ownSelection && numel(lgs) == 2 && isscalar(inPanel) && isscalar(outer) && string(inPanel.Location) == "best" ...
    && isequal(string(inPanel.String), reshape(string(Fod.panels(2).groups.label), 1, [])) && isequal(string(inPanel.String), fliplr(gl)) ...
    && isequal(string(outer.String(1:numel(gl))), gl) && string(hod.axes(2).Title.String) == "", ...
    'a PSTH with its own selection (groups in descending order): its own legend inside it; the figure''s legend the raster''s groups');
hpg = renderFigure(Fpg, Fpg.spec, fig);
sTg = Fpg.spec;
sTg.title = "Card";
hpg2 = renderFigure(Fpg, sTg, fig);
check(endsWith(hpg.title, "(" + height(Fpg.epochs) + " epochs)") && contains(hpg.title, Tpg.label(2)) ...
    && hpg2.title == "Card · " + Tpg.groupLabel(2), ...
    sprintf('one trial group''s figure names its group in the title ("%s")', hpg.title));

% skipped layers say why
hr = renderFigure(F3, F3.spec, fig);   % again: the checks above drew other figures into fig
notes = findall(hr.layout, 'Tag', 'layerNote');
noteText = strjoin(string(get(notes, 'String')), " | ");
check(~isempty(notes) && contains(noteText, auxMsg), sprintf('a skipped layer shows its reason in its panel ("%s")', noteText));
hn = renderFigure(Fn, Fn.spec, fig);
notes = findall(hn.layout, 'Tag', 'layerNote');
check(isscalar(notes) && contains(string(notes.String), auxMsg) && notes.HorizontalAlignment == "center", ...
    'a panel with nothing to draw says why, in its middle');

% events: raster marks, PSTH latency lines and rug
he = renderFigure(Fe, Fe.spec, fig);
rm = findall(he.axes(1), 'Tag', 'rasterEvent');
okE = ~isempty(rm) && any(arrayfun(@(x) string(getappdata(x, 'PlotGroup')) == "Stim onset", rm)) ...
    && isequal(xlim(he.axes(1)), [Fe.spec.window.pre Fe.spec.window.post]);
check(okE, 'events marks on a raster: every block''s rows marked in the mark''s look');
hm = renderFigure(Fm, Fm.spec, fig);
el = findall(hm.axes(2), 'Tag', 'eventLine');
er = findall(hm.axes(2), 'Tag', 'eventRug');
lg = findall(fig, 'Type', 'legend');
check(~isempty(el) && numel(el) <= height(Fm.groups) && isscalar(er) && string(getappdata(er, 'PlotGroup')) == "Stim offset" ...
    && all(arrayfun(@(x) string(getappdata(x, 'PlotGroup')) == "Stim offset", el)) && any(string(lg(1).String) == "Stim offset"), ...
    sprintf('events marks on a PSTH: %d latency line(s) (one per group) and a rug, in the legend', numel(el)));

% a stacked continuous panel whose only signal layer is skipped still draws its marks
cfg = cfg.addFigure(struct('panels', {{struct('id', "sig", 'type', "continuous", 'layers', [auxF ev], ...
    'options', struct('display', "stacked"))}}), Id="cmarks");
try
    Fk1 = rn.computeFigure(src, cfg.figureFor("cmarks"));
    hk1 = renderFigure(Fk1, Fk1.spec, fig);
    nt = findall(hk1.axes(1), 'Tag', 'layerNote');
    noteText = "";
    if ~isempty(nt); noteText = strjoin(string(get(nt, 'String')), " "); end
    sk1 = Fk1.panels(1).layers(1).skip;
    ok1 = sk1 ~= "" && sk1 ~= "disabled" && Fk1.panels(1).layers(2).skip == "" ...
        && isscalar(findall(hk1.axes(1), 'Tag', 'eventRug')) && contains(noteText, sk1);
    msg1 = "";
catch ME
    ok1 = false;
    msg1 = " (" + ME.message + ")";
end
check(ok1, "a stacked continuous panel whose signal layers are all skipped still draws its marks, and says why" + msg1);

% a raster of five or more blocks keeps every block's name on a flush stack
fixedAll = EphysAnalysisConfig.defaultLayer("raster");
fixedAll.binding = "fixed";
trOff = tr;
trOff.event.edge = "offset";
fr5 = cfg.Figures(cfg.figureIndex("rp"));
fr5.id = "blocks";
fr5.panels(1).layers = [fr5.panels(1).layers fixedAll tr trOff];
cfg = cfg.addFigure(fr5);
F5 = rn.computeFigure(src, cfg.figureFor("blocks"), Observation=Tu(1, :));
h5 = renderFigure(F5, F5.spec, fig);
ra = h5.axes(1);
nb = 1 + numel(F5.panels(1).layers(2).R.raster) + 2;
check(nb >= 5 && numel(ra.YTick) == nb && numel(ra.YTickLabel) == nb && string(ra.YTickLabel{end}) == "Stim offset" ...
    && isempty(ra.XTickLabel), sprintf('a raster of %d blocks over a PSTH keeps every block''s name (no seam clearing of named ticks)', nb));

% a raster over a waveforms panel over a PSTH keeps its own time axis
fw3 = cfg.Figures(cfg.figureIndex("rp"));
fw3.id = "rwp";
fw3 = EphysAnalysisConfig.placePanel(fw3, struct('id', "wave", 'type', "waveforms", ...
    'layers', EphysAnalysisConfig.defaultLayer("waveforms")), "below", "raster_1");
cfg = cfg.addFigure(fw3);
wsw = warning('off', 'unitWaveforms:Templates');
wsn = warning('off', 'unitWaveforms:NoWaveforms');
Fw3 = rn.computeFigure(src, cfg.figureFor("rwp"), Observation=Tu(1, :));
warning(wsn); warning(wsw);
h6 = renderFigure(Fw3, Fw3.spec, fig);
axOf = @(id) h6.panels([h6.panels.id] == id).axes;
r6 = axOf("raster_1");
check(Fw3.spec.panels([Fw3.spec.panels.id] == "wave").row == 2 && ~isempty(r6.XTickLabel) && string(r6.XLabel.String) == "Time (s)" ...
    && ~isempty(axOf("psth_1").XTickLabel) && string(axOf("psth_1").XLabel.String) == "Time (s)", ...
    'a raster over a waveforms panel keeps its tick labels and "Time (s)": the next time panel down is not what sits under it');

% a stacked PSTH, an auROC PSTH, rate and tuning panels, the waveforms' probe layout
hs = renderFigure(Fst, Fst.spec, fig);
as = hs.axes(2);
nGs = height(Fst.groups);
sb = findall(as, 'Tag', 'stackBase');
lg = findall(fig, 'Type', 'legend');
lgs = string(lg(1).String);
check(numel(as.YAxis) == 2 && numel(sb) == nGs && numel(as.YAxis(1).TickValues) == nGs ...
    && all(arrayfun(@(g) nnz(lgs == g) == 1, string(Fst.groups.label))) && string(as.YAxis(1).Label.String) == "Depth" ...
    && isequal(xlim(as), [Fst.spec.window.pre Fst.spec.window.post]) && isempty(findall(as, 'Tag', 'chanceLine')), ...
    sprintf('a stacked PSTH: %d rows (a baseline each, the groups'' values on the left axis, named Depth), each group once in the legend', nGs));
fs5 = Fst;   % the PSTH's result cut to one group (figSliceGroup)
fs5.panels(2).layers(1).R = figSliceGroup(Fst.panels(2).layers(1).R, 1);
h1g = renderFigure(fs5, fs5.spec, fig);
check(numel(h1g.axes(2).YAxis) == 1 && isempty(findall(h1g.axes(2), 'Tag', 'stackBase')), 'a stack of one group is drawn overlaid');
fixedM = EphysAnalysisConfig.defaultLayer("psth");
fixedM.binding = "fixed"; fixedM.units.ids = Tu.unitId(1:m3).'; fixedM.aggregate = "mean";
cfgS = cfg;
k4 = cfgS.figureIndex("stacked");
cfgS.Figures(k4).panels(2).layers = [cfgS.Figures(k4).panels(2).layers fixedM];
Fs2 = rn.computeFigure(src, cfgS.figureFor("stacked"), Observation=Tu(1, :));
hs2 = renderFigure(Fs2, Fs2.spec, fig);
yl2 = ylim(hs2.axes(2));
rl2 = findall(hs2.axes(2), 'Tag', 'rate');
lg = findall(fig, 'Type', 'legend');
lgs2 = string(lg(1).String);
check(any(lgs2 == Fs2.panels(2).layers(2).name) && numel(rl2) >= 2 * nGs && yl2(2) > 0, ...
    'a stacked PSTH with a second layer: its mean drawn into the same rows, named in the legend');
ha = renderFigure(Fau, Fau.spec, fig);
aa = ha.axes(2);
check(isscalar(findall(aa, 'Tag', 'chanceLine')) && isequal(ylim(aa), [0 1]) && ~isempty(findall(aa, '-regexp', 'Tag', '^rate(Fill)?$')) ...
    && (Lau.R.auroc.cutoff == "none" || (isscalar(findall(aa, 'Tag', 'modWindow')) && isscalar(findall(aa, 'Tag', 'modMarks')))) ...
    && string(aa.YLabel.String) == "auROC", ...
    'an auROC PSTH: on 0-1 from the chance line at 0.5, the modulation window shaded and the unit''s calls marked');
fau2 = cfg.Figures(cfg.figureIndex("auroc"));
fau2.id = "aurocStack";
fau2.panels(2).options.stack = true;
cfgA = cfg.addFigure(fau2);
wa1 = warning('off', 'aurocCall:NoCutoff');
wa2 = warning('off', 'aurocCall:WideCutoff');
Fas = rn.computeFigure(src, cfgA.figureFor("aurocStack"), Observation=Tu(1, :));
warning(wa2); warning(wa1);
hAs = renderFigure(Fas, Fas.spec, fig);
check(numel(findall(hAs.axes(2), 'Tag', 'stackBase')) == nGs && numel(hAs.axes(2).YAxis) == 2, 'an auROC PSTH can be stacked too');
fhm = cfg.Figures(cfg.figureIndex("hm"));
fhm.id = "hmAuroc";
fhm.panels(1).common = false;
fhm.panels(1).options.baseline = struct('Mode', "auroc", 'Window', [-0.2 0]);
fhm.panels(1).options.order = "modulation";
cfgH = cfg.addFigure(fhm);
wa1 = warning('off', 'aurocCall:NoCutoff');
wa2 = warning('off', 'aurocCall:WideCutoff');
Fha = rn.computeFigure(src, cfgH.figureFor("hmAuroc"));
warning(wa2); warning(wa1);
feA = figure('Visible', 'off', 'Position', [100 100 700 800]);   % its own: fe1 must start without an editor below
hha = renderFigure(Fha, Fha.spec, feA, Editable=true);
ctxA = getappdata(feA, PlotAesthetics.ContextKey);
im = findall(hha.axes(1), 'Type', 'image');
check(isfield(Fha.panels(1).layers(1).R, 'auroc') && isscalar(im) && isequal(clim(hha.axes(1)), [0 1]) && ctxA.mapField == "diverging", ...
    'a heat map of auROCs: on 0-1, its group''s calls kept (figSliceGroup), the editor''s colormap diverging');
delete(feA);
hrt = renderFigure(Frt, Frt.spec, fig);
art = hrt.axes(1);
bars = findall(art, 'Tag', 'bar');
check(numel(bars) == height(Frt.groups) && isequal(art.XTick, 1:height(Frt.groups)) && string(art.XLabel.String) == "Depth" ...
    && string(art.YLabel.String) == Lrt.R.units && ~isempty(findall(art, 'Tag', 'errorBar')), ...
    'a rate panel: a bar per trial group along x (named by Depth), with error bars, the rate''s unit on y');
hr3 = renderFigure(Frt3, Frt3.spec, fig);
lg = findall(fig, 'Type', 'legend');
lgr = string(lg(1).String);
check(numel(findall(hr3.axes(1), 'Tag', 'box')) >= 2 && any(lgr == Frt3.panels(1).layers(2).name) ...
    && any(lgr == Frt3.panels(1).layers(1).name), 'a rate panel of two layers: boxes side by side, each layer in the legend');
fpts = Frt; fpts.spec.panels(1).options.display = "points";
hpt = renderFigure(fpts, fpts.spec, fig);
check(~isempty(findall(hpt.axes(1), 'Tag', 'points')) && ~isempty(findall(hpt.axes(1), 'Tag', 'meanBar')), ...
    'a rate panel''s points display: each epoch a dot over its mean''s bar');
htc = renderFigure(Ftc, Ftc.spec, fig);
atc = htc.axes(1);
cv = findall(atc, 'Tag', 'curve');
check(isscalar(cv) && isequal(cv.XData(:), double(Ltc.R.x(:))) && string(atc.XLabel.String) == "Depth" ...
    && string(atc.YLabel.String) == Ltc.R.units, 'a tuning panel: the curve over Depth''s values, labeled');
htc2 = renderFigure(Ftc2, Ftc2.spec, fig);
cv2 = findall(htc2.axes(1), 'Tag', 'curve');
check(numel(cv2) == height(Lt2.R.groups) && ~isempty(findall(htc2.axes(1), 'Tag', 'waveMean')), ...
    sprintf('a tuning panel with a series: %d curves, and the unit''s waveform inset', numel(cv2)));
hwp = renderFigure(Fwp, Fwp.spec, fig);
awp = hwp.axes(1);
ring = findall(awp, 'Tag', 'unitDots');
check(~isempty(findall(awp, 'Tag', 'waveMean')) && startsWith(string(awp.XLabel.String), "x (") ...
    && (isscalar(ring) || ~all(isfinite(Tu.meta{2}.y))), ...
    'a waveforms panel in the probe layout: the units at their places, the observed unit framed');
Fwx = Fwp;   % the ring layer made a detected one naming a sorted unit's id: its id is a channel, not that unit
Fwx.panels(1).layers(2).source = "detected";
Fwx.panels(1).layers(2).R.source = "detected";
hwx = renderFigure(Fwx, Fwx.spec, fig);
fwd = cfg.Figures(cfg.figureIndex("wfprobe"));
fwd.id = "wfprobeDet";
fwd.panels(1).layers(2).source = "detected";
cfgD = cfg.addFigure(fwd);
wsw = warning('off', 'unitWaveforms:Templates');
wsn = warning('off', 'unitWaveforms:NoWaveforms');
Fwd = rn.computeFigure(src, cfgD.figureFor("wfprobeDet"), Observation=Tu(2, :));
warning(wsn); warning(wsw);
hwd = renderFigure(Fwd, Fwd.spec, fig);
check(ismember(Tu.unitId(2), Fwx.panels(1).layers(2).R.meta.unitId) && isempty(findall(hwx.axes(1), 'Tag', 'unitDots')) ...
    && Fwd.panels(1).layers(2).skip == "" && Fwd.panels(1).layers(2).R.source == "detected" ...
    && isempty(findall(hwd.axes(1), 'Tag', 'unitDots')), ...
    'a probe layout of sorted units rings nothing a detected layer names (its unit ids are channels)');

% editing, OnRemember and redraw
remembered = [];
    function remember(r)
        remembered = r;
    end
renderFigure(F1, F1.spec, fe1);
noCtx = ~isappdata(fe1, PlotAesthetics.ContextKey);
hE = renderFigure(F1, F1.spec, fe1, Editable=true, OnRemember=@remember);
ctx = getappdata(fe1, PlotAesthetics.ContextKey);
menus = findall(fe1, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag);
check(noCtx && isstruct(ctx) && ctx.kind == "figure" && ctx.id == "rp" && isequal(ctx.root, hE.layout) && isequal(ctx.target, fe1) ...
    && ~isempty(menus) && ctx.mapField == "" && isempty(ctx.plotRules) && isa(ctx.redraw, 'function_handle'), ...
    sprintf('Editable=true installs the aesthetics editor (%d context menus, context kind "figure"); "auto" in an invisible figure does not', numel(menus)));
rules = PlotAesthetics.normalizeRules(struct('role', "rasterTicks", 'group', "", 'property', "LineWidth", 'value', 2));
ctx.onRemember(rules);
ctx.redraw(rules);
ctx2 = getappdata(fe1, PlotAesthetics.ContextKey);
tk = findall(fe1, 'Tag', 'rasterTicks');
check(isequaln(remembered, rules) && isequaln(ctx2.plotRules, rules) && ~isvalid(hE.layout) && ~isempty(tk) && all([tk.LineWidth] == 2), ...
    'OnRemember receives the rules; the context''s redraw draws the figure again with them as its own aesthetics');
renderFigure(Fh, Fh.spec, fe1, Editable=true);
ctxH = getappdata(fe1, PlotAesthetics.ContextKey);
renderFigure(Fcm, Fcm.spec, fe1, Editable=true);
ctxC = getappdata(fe1, PlotAesthetics.ContextKey);
check(ctxH.mapField == "heat" && ctxC.mapField == "diverging", 'the editor''s colormap: "heat" for a heat map, "diverging" for a correlation map');

% one observation draws fast
renderFigure(F1, F1.spec, fig);
drawnow;
tR = Inf;
for rep = 1:3
    tc0 = tic;
    renderFigure(F1, F1.spec, fig);
    drawnow;
    tR = min(tR, toc(tc0));
end
check(tR < 1, sprintf('the raster + PSTH figure of one observation renders in %.3f s (under 1 s)', tR));

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisFigures:Failures', '%d checks failed.', nFail);
end
end


function cfg = unlinkFigure(cfg, k)
%unlinkFigure  Figure k's panels with their own options (common = false).
for j = 1:numel(cfg.Figures(k).panels)
    cfg.Figures(k).panels(j).common = false;
end
end


function p = figureTuningParamOf(src)
%figureTuningParamOf  The parameter a tuning panel without param or groupBy tunes over: the first numeric one with two values.
p = "";
for n = reshape(string(src.paramNames), 1, [])
    if n == "TrialType" || ~ismember(n, string(src.trials.Properties.VariableNames)); continue; end
    v = src.trials.(n);
    if (isnumeric(v) || islogical(v)) && numel(unique(double(v(isfinite(double(v)))))) >= 2
        p = n;
        return
    end
end
end


function cfg = setFigures(cfg, f)
cfg.Figures = f;
end


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
