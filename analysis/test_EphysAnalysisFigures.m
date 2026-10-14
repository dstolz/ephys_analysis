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
types = ["raster" "psth" "continuous" "heatmap" "waveforms" "behavior" "probemap" "corrmap"];
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
    && L.yParam == "" && L.seriesParam == "" && L.color == "" && L.lineStyle == "", 'defaults("Layer")');
O = EphysAnalysisConfig.defaults("Observe");
check(O.kind == "auto" && O.source == "units" && ~isfield(O.units, 'source') && O.signal == "LFP" && isequal(O.channels, []) ...
    && O.datasets == "ticked" && isstring(O.datasetKeys) && isequal(size(O.datasetKeys), [1 0]), 'defaults("Observe")');

check(isequal(T.Type.', types) && isequal(string(T.Properties.VariableNames), ["Type" "Label" "Categories" "Aligned" ...
    "SharesTime" "OneGroup" "MultiLayer" "DefaultBinding" "Description" "DefaultOptions"]), 'panelTypes: the eight types and the columns');
check(isequal(T.SharesTime.', [true true true true false false false false]) && isequal(T.Aligned.', [true true true true false true false true]) ...
    && isequal(T.OneGroup.', [false false false true false false false true]) && isequal(T.MultiLayer.', [true true true false false false false false]) ...
    && isequal(T.DefaultBinding.', ["observation" "observation" "observation" "fixed" "observation" "fixed" "fixed" "fixed"]) ...
    && isequal(T.Categories{T.Type == "heatmap"}, ["point" "continuous"]), 'panelTypes: aligned, shared time, one group, layers, binding, categories');
O = T.DefaultOptions;
check(isempty(O{1}.rasterSortEvent) && O{1}.rasterSortOrder == "ascending" && O{1}.waveform.mode == "off" ...
    && O{2}.bins.BinSec == 0.01 && O{2}.histStyle == "bar" && isnan(O{2}.fillAlpha) && isequal(O{2}.yLim, []) ...
    && O{3}.display == "lines" && O{3}.errorType == "sem" && isnan(O{3}.stackSpacing) ...
    && O{4}.order == "probe" && O{4}.group == 1 && O{5}.waveform.mode == "both" && O{6}.display == "points" && O{6}.jitter ...
    && O{7}.value == "rate" && O{8}.metric == "mean" && O{8}.correlation == "pearson" && ~O{8}.fisherZ, ...
    'panelTypes: each type''s DefaultOptions');
S = EphysAnalysisConfig.sourceCategories();
check(isequal(S.Category.', ["point" "continuous" "trial" "unit"]) && isequal(S.Sources{1}, ["units" "detected" "events"]) ...
    && isequal(S.Sources{4}, ["units" "detected"]) && isequal(S.Aligned.', [true true true false]), 'sourceCategories');
check(isequal(EphysAnalysisConfig.FigureSources, ["units" "detected" "events" "LFP" "MUA" "SPIKE" "AUX" "trials"]), 'FigureSources');
catOf = @EphysAnalysisConfig.categoryOf;
check(catOf("units", "raster") == "point" && catOf("detected", "waveforms") == "unit" && catOf("units", "corrmap") == "unit" ...
    && catOf("LFP", "heatmap") == "continuous" && catOf("units", "heatmap") == "point" && catOf("trials", "behavior") == "trial" ...
    && catOf("trials", "heatmap") == "" && catOf("LFP", "raster") == "" && catOf("units", "continuous") == "" && catOf("units", "nope") == "", ...
    'categoryOf: the category a type draws a source in, else ""');
check(catOf("events", "continuous") == "point" && catOf("events", "heatmap") == "point" && catOf("events", "raster") == "point" ...
    && catOf("events", "waveforms") == "" && catOf("events", "behavior") == "", 'categoryOf: events fit every time panel, and no other');
D1 = layerOf("continuous");
D2 = layerOf("behavior");
D3 = layerOf("heatmap");
D4 = layerOf("waveforms");
check(D1.source == "LFP" && D1.binding == "observation" && D2.source == "trials" && D2.binding == "fixed" ...
    && D3.source == "units" && D3.binding == "fixed" && D4.source == "units" && D4.binding == "observation", ...
    'defaultLayer: the type''s first source with its default binding');
check(strcmp(errorId(@() layerOf("violin")), 'EphysAnalysisConfig:BadValue'), 'defaultLayer of an unknown type: BadValue');

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
    && isequal(FT.Template(2:end-1).', ["psth" "raster" "continuous" "heatmap" "waveforms" "behavior" "probemap" "corrmap"]) ...
    && FT.Template(end) == "blank", 'figureTemplates: rasterPsth first, one per type, blank last');
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
Pc{2}.options = struct('yLim', [0 50], 'baseline', struct('Mode', "zscore", 'Window', [-0.3 0]));
Pc{2}.window = struct('mode', "fixed", 'pre', -0.5, 'post', 1);
aux = layerOf("continuous");
aux.source = "AUX"; aux.binding = "fixed"; aux.channels = [1 2]; aux.aggregate = "mean";
Pc{3}.layers = [Pc{3}.layers, aux];
Pc{3}.options = struct('errorType', "std", 'display', "stacked");
Pc{4}.layers.source = "LFP"; Pc{4}.layers.channels = [1 2 3];
Pc{4}.options = struct('cLim', [-1 1], 'group', 2);
Pc{6}.layers.yParam = "RespLatency"; Pc{6}.layers.seriesParam = "Depth";
Pc{6}.options = struct('param', "Depth", 'display', "box");
Pc{6}.window = struct('mode', "fixed", 'pre', 0, 'post', 2, 'stop', struct('line', "Response"));
Pc{7}.options = struct('value', "nUnits");
Pc{8}.ref = struct('line', "Platform");
Pc{8}.window = struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Platform", 'edge', "offset"));
allTypes = struct('id', "all_types", 'title', "Every panel type", ...
    'observe', struct('kind', "unit", 'datasets', "list", 'datasetKeys', ["S1/a" "S2/b"], 'units', struct('classes', "su", 'maxUnits', 4)), ...
    'grid', struct('rows', 4, 'cols', 2, 'rowHeights', [1 1.5 1 1], 'colWidths', [2 1], 'spacing', "compact"), ...
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
check(isequal(g.grid.rowHeights, [1 1.5 1 1]) && isequal(g.grid.colWidths, [2 1]) && isequal(c2.Figures(2).grid.rowHeights, [1 1.5]) ...
    && isequal(c2.Figures(2).grid.colWidths, []), 'relative sizes come back as rows; [] stays []');
check(isequal([g.panels.type], types) && isequal([g.panels.id], types + "_1") && g.panels(3).options.display == "stacked" ...
    && g.panels(7).options.value == "nUnits" && g.panels(4).options.group == 2 && g.panels(6).options.display == "box", ...
    'every panel type, with its options');
e = g.panels(1).layers(2);
check(e.source == "events" && e.binding == "fixed" && numel(e.event.sequence) == 2 && e.event.sequence(2).relation == "notFollowedBy" ...
    && isinf(e.event.sequence(2).maxGapSec) && e.event.sequence(1).maxGapSec == 1 && e.event.marker == "|" && e.event.color == "#ff0000" ...
    && e.event.size == 6 && e.name == "licks after a trough", 'an events layer with a sequence');
check(isequal(g.panels(2).layers(2).units.ids, [3 5]) && g.panels(2).layers(2).aggregate == "mean" && g.panels(2).layers(1).binding == "observation" ...
    && g.panels(2).layers(2).lineStyle == "--" && isequal(g.panels(3).layers(2).channels, [1 2]) && isequal(g.panels(4).layers.channels, [1 2 3]), ...
    'fixed and following layers');
check(isequal(c2.Figures(2).ref, "default") && isequal(c2.Figures(2).window, "default") && isequal(c2.Figures(2).panels(1).ref, "default") ...
    && isstruct(g.panels(2).window) && isequal(g.panels(2).ref, "default") && isstruct(g.panels(8).window.stop) ...
    && g.panels(8).window.mode == "between" && isequal(g.ref.timeRange, [0 Inf]), '"default" sentinels and overrides');
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
check(isempty(I(~startsWith(I.Field, ["t_behavior." "t_blank."]), :)), 'every template validates clean but behavior and blank');
check(has(tc, "t_behavior.behavior_1.options.param", "error") && has(tc, "t_behavior.behavior_1.layers(1).yParam", "error") ...
    && has(tc, "t_blank.panels", "warning"), 'a behavior panel needs its param and yParam; a blank figure has no panels');
nf = EphysAnalysisConfig();
nf.Source.Root = root;
nf = nf.addFigure();
I = nf.validate(CheckPaths=false);
check(any(I.Section == "Plots" & I.Field == "enabled" & I.Severity == "error"), ...
    'the "nothing enabled" rule is unchanged: figures do not run yet, so a config of figures alone has nothing enabled');

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
b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.layers.source = "trials";
I = figIssues(b);
check(any(I.Field == "hm.heatmap_1.layers(1).source" & I.Severity == "error" ...
    & I.Message == "A heat map panel draws point-process or continuous layers, not trials."), 'a source the panel type does not draw');
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
b = base; b.Figures(1).panels(1).layers(1).aggregate = "sum";
check(has(b, "figure_1.raster_1.layers(1).aggregate", "error"), 'aggregate is each or mean');
b = base; b.Figures(1).panels(1).layers(1).units.maxUnits = 0;
check(has(b, "figure_1.raster_1.layers(1).units.maxUnits", "error"), 'a layer''s maxUnits >= 1');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).panels.layers.channels = 1.5;
check(has(b, "ct.continuous_1.layers(1).channels", "error"), 'a layer''s channels are whole numbers >= 1');
b = base.addFigure("behavior", Id="bh"); b.Figures(2).panels.options.param = "Depth"; b.Figures(2).panels.layers.yParam = "stop";
b2 = b; b2.Figures(2).window = struct('mode', "fixed", 'pre', 0, 'post', 1, 'stop', struct('line', "Response"));
check(has(b, "bh.behavior_1.layers(1).yParam", "error") && ~has(b2, "bh.behavior_1.layers(1).yParam", "error") && isempty(figIssues(b2)), ...
    'yParam "stop" needs a stop event in the panel''s window');
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

% 9. options
o = "figure_1.raster_1.options.";
b = base; b.Figures(1).panels(1).options.rasterSortOrder = "up";
check(has(b, o + "rasterSortOrder", "error"), 'raster: rasterSortOrder');
b = base; b.Figures(1).panels(1).options.rasterSort = "event";
b2 = b; b2.Figures(1).panels(1).options.rasterSortEvent = struct('line', "Platform", 'edge', "middle");
check(has(b, o + "rasterSortEvent", "error") && has(b2, o + "rasterSortEvent", "error"), 'raster: rasterSort "event" needs a valid rasterSortEvent');
b = base; b.Figures(1).panels(1).options.waveform.mode = "huge";
check(has(b, o + "waveform.mode", "error"), 'raster: the waveform inset''s mode');
b = base; b.Figures(1).panels(1).options.waveform = struct('mode', "mean", 'scale', 5, 'location', "up", 'maxSpikes', 0.5, 'ampScale', "x");
check(has(b, o + "waveform.scale", "error") && has(b, o + "waveform.location", "error") && has(b, o + "waveform.maxSpikes", "error") ...
    && has(b, o + "waveform.ampScale", "error"), 'raster: the waveform inset''s scale, location, maxSpikes, ampScale');
o = "figure_1.psth_1.options.";
b = base; b.Figures(1).panels(2).options.bins.BinSec = 0; b.Figures(1).panels(2).options.bins.SmoothSec = -1;
check(has(b, o + "bins.BinSec", "error") && has(b, o + "bins.SmoothSec", "error"), 'psth: bins');
b = base; b.Figures(1).panels(2).options.measure = "volts";
check(has(b, o + "measure", "error"), 'psth: measure');
b = base; b.Figures(1).panels(2).options.baseline.Mode = "auroc";
b2 = base; b2.Figures(1).panels(2).options.baseline = struct('Mode', "subtract", 'Window', [0 -1]);
check(has(b, o + "baseline.Mode", "error") && has(b2, o + "baseline.Window", "error"), 'psth: baseline mode (no auROC) and window');
b = base; b.Figures(1).panels(2).options.histStyle = "pie"; b.Figures(1).panels(2).options.normalize = "max";
b.Figures(1).panels(2).options.fillAlpha = 2; b.Figures(1).panels(2).options.yLim = [1 0];
check(has(b, o + "histStyle", "error") && has(b, o + "normalize", "error") && has(b, o + "fillAlpha", "error") && has(b, o + "yLim", "error"), ...
    'psth: histStyle, normalize, fillAlpha, yLim');
b = base.addFigure("continuous", Id="ct");
b.Figures(2).panels.options = struct('display', "grid", 'statistic', "mode", 'transform', "log", 'errorType', "mad", 'stackSpacing', -1, ...
    'baseline', struct('Mode', "zscore"));
o = "ct.continuous_1.options.";
check(has(b, o + "display", "error") && has(b, o + "statistic", "error") && has(b, o + "transform", "error") && has(b, o + "errorType", "error") ...
    && has(b, o + "stackSpacing", "error") && has(b, o + "baseline.Mode", "error"), 'continuous: display, statistic, transform, errorType, stackSpacing, baseline');
haveBoot = license('test', 'Statistics_Toolbox') && exist('bootci', 'file');
b = base.addFigure("continuous", Id="ct"); b.Figures(2).panels.options.errorType = "ci95";
check(has(b, o + "errorType", "error") == ~haveBoot, 'continuous: the bootstrap CI needs the Statistics and Machine Learning Toolbox');
b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.options.order = "modulation"; b.Figures(2).panels.options.group = 0;
b.Figures(2).panels.options.cLim = [2 1];
o = "hm.heatmap_1.options.";
check(has(b, o + "order", "error") && has(b, o + "group", "error") && has(b, o + "cLim", "error"), 'heatmap: order, group, cLim');
b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.layers.source = "LFP"; b.Figures(2).panels.options.baseline.Mode = "zscore";
b2 = base.addFigure("heatmap", Id="hm"); b2.Figures(2).panels.options.baseline.Mode = "zscore";
check(has(b, o + "baseline.Mode", "error") && isempty(figIssues(b2)), 'heatmap: z-score for spikes, not for a signal');
b = base.addFigure("waveforms", Id="wf"); b.Figures(2).panels.options.waveform.mode = "off";
check(has(b, "wf.waveforms_1.options.waveform.mode", "error"), 'waveforms: the mode is never off');
b = base.addFigure("behavior", Id="bh"); b.Figures(2).panels.layers.yParam = "RespLatency";
b.Figures(2).panels.options.display = "pie"; b.Figures(2).panels.options.xScale = "log";
o = "bh.behavior_1.options.";
check(has(b, o + "param", "error") && has(b, o + "display", "error") && has(b, o + "xScale", "error"), 'behavior: param, display, xScale');
b = base.addFigure("behavior", Id="bh"); b.Figures(2).panels.layers.yParam = "RespLatency";
b.Figures(2).panels.options.param = "Depth"; b.Figures(2).panels.options.display = "violin";
check(has(b, o + "display", "error") == ~exist('violinplot', 'file'), 'behavior: violin needs violinplot');
b = base.addFigure("probemap", Id="pm"); b.Figures(2).panels.options.value = "x";
check(has(b, "pm.probemap_1.options.value", "error"), 'probemap: value');
b = base.addFigure("corrmap", Id="cm"); b.Figures(2).panels.options.metric = "max"; b.Figures(2).panels.options.correlation = "kendall";
b2 = base.addFigure("corrmap", Id="cm"); b2.Figures(2).panels.options.metric = "peak"; b2.Figures(2).panels.options.bins.BinSec = 0;
check(has(b, "cm.corrmap_1.options.metric", "error") && has(b, "cm.corrmap_1.options.correlation", "error") ...
    && has(b2, "cm.corrmap_1.options.bins.BinSec", "error"), 'corrmap: metric, correlation, bins of a peak rate');

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

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisFigures:Failures', '%d checks failed.', nFail);
end
end


function cfg = setFigures(cfg, f)
cfg.Figures = f;
end
