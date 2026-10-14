function test_copyPlotSettings()
%test_copyPlotSettings  Verification suite for copying a plot's settings onto another plot (of another kind).
%   plotSettingParts: the parts two kinds share (the kind's options in
%   common, the layout when the layouts match, unaligned kinds' alignment,
%   unit-waveforms plots against insets, the reasons). copyPlotSettings:
%   every shared part by default, a chosen part alone, what a plot keeps
%   (id, kind, title, enabled; a source, window mode or baseline mode its
%   kind does not take, with a note), a part named but not shared, an
%   unknown part, and a copy that validates. figureSettingParts and
%   copyFigureSettings: each part alone (its fields copied, the rest and
%   the id, title and enabled kept), every part by default, two parts, a
%   copy that validates, an unknown part.
%
%   Usage:  test_copyPlotSettings

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);

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

fprintf('\n== 1. plotSettingParts ==\n');
T = plotSettingParts("raster", "psth");
check(isequal(T.Part.', ["units" "ref" "window" "selection" "bins" "kind" "marks" "style" "waveform" "aux" "note" ...
    "overlays" "looks"]) && all(T.Shared) && all(T.Reason == ""), 'a PSTH and a raster share every part');
check(isequal(T.Fields{T.Part == "kind"}, ["rasterSort" "rasterSortEvent" "rasterSortOrder" "rasterByGroup"]), ...
    'their options in common are the raster''s sort and grouping (no layout: theirs differ)');
T = plotSettingParts("tuning", "psth");
check(isequal(T.Fields{T.Part == "kind"}, "layout") && T.Shared(T.Part == "kind"), ...
    'a PSTH and a tuning curve share no options but their layouts (grid / overlay): the layout copies');
T = plotSettingParts("probemap", "psth");
check(~any(T.Shared(ismember(T.Part, ["ref" "window" "selection" "bins" "marks" "aux" "waveform" "kind"]))) ...
    && T.Reason(T.Part == "ref") == "Probe map has none" && all(T.Shared(ismember(T.Part, ["units" "style" "note" "overlays" "looks"]))), ...
    'a probe map takes no alignment, bins, marks, aux or waveform from a PSTH; its units, look, note and overlays it does');
T = plotSettingParts("psth", "behavior");
check(~T.Shared(T.Part == "units") && T.Reason(T.Part == "units") == "Behavior has none", ...
    'a reason names the kind without the part when it is the source''s');
T = plotSettingParts("waveforms", "psth");
check(~T.Shared(T.Part == "waveform") && contains(T.Reason(T.Part == "waveform"), "waveforms plot"), ...
    'a unit waveforms plot''s waveform settings and a PSTH''s inset do not copy one to the other');
T = plotSettingParts("waveforms");
check(T.Shared(T.Part == "waveform") && T.Shared(T.Part == "kind") && isequal(T.Fields{T.Part == "kind"}, "layout"), ...
    'two waveforms plots share their waveform settings and layout');
check(strcmp(errorId(@() plotSettingParts("pie")), 'plotSettingParts:BadKind'), 'an unknown kind raises BadKind');

fprintf('\n== 2. copyPlotSettings ==\n');
cfg = EphysAnalysisConfig();
[cfg, idP] = cfg.addPlot(struct('kind', "psth", 'source', "detected", 'title', "Mine"));
[cfg, idR] = cfg.addPlot(struct('kind', "raster", 'enabled', false));
P = cfg.Plots(cfg.plotIndex(idP));
P.units.maxUnits = 7;
P.channels = [1 2 3];
P.ref = EphysAnalysisConfig.defaults("EventRef");
P.ref.line = "Stim";
P.bins.BinSec = 0.025;
P.baseline.Mode = "zscore";
P.rasterSort = "stop";
P.rasterByGroup = false;
P.histStyle = "line";
P.style.FontSize = 13;
P.aux.mode = "magnitude";
P.note.text = "copied";
P.overlays = EphysAnalysisConfig.defaults("Overlay");
P.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2));
R0 = cfg.Plots(cfg.plotIndex(idR));
[R, copied, notes] = copyPlotSettings(R0, P);
check(R.id == idR && R.kind == "raster" && R.title == "" && ~R.enabled, 'the copy keeps the plot''s id, kind, title and enabled');
check(R.source == "detected" && R.units.maxUnits == 7 && isequal(R.channels, [1 2 3]) && isstruct(R.ref) && R.ref.line == "Stim" ...
    && R.bins.BinSec == 0.025 && R.baseline.Mode == "zscore" && R.rasterSort == "stop" && ~R.rasterByGroup ...
    && R.style.FontSize == 13 && R.aux.mode == "magnitude" && R.note.text == "copied" && isscalar(R.overlays) ...
    && isscalar(R.aesthetics) && isempty(notes) && isequal(copied, plotSettingParts("raster", "psth").Part.'), ...
    'by default every shared part copies: source, units, channels, event, bins, baseline, raster sort, look, aux, note, overlays, looks');
check(R.histStyle == R0.histStyle, 'a PSTH''s own option (PSTH as line) does not reach the raster');
cfg.Plots(cfg.plotIndex(idR)) = R;
I = cfg.validate(CheckPaths=false);
check(~any(I.Severity == "error" & startsWith(I.Field, idR)), 'the raster copied onto validates');
[R, copied] = copyPlotSettings(R0, P, "style");
check(isequal(copied, "style") && R.style.FontSize == 13 && R.bins.BinSec ~= 0.025 && R.source == R0.source && isempty(R.overlays), ...
    'Parts "style" copies the appearance alone');

P.baseline.Mode = "auroc";
[R, copied, notes] = copyPlotSettings(R0, P, "bins");
check(isequal(copied, "bins") && R.bins.BinSec == 0.025 && R.baseline.Mode == R0.baseline.Mode && isscalar(notes) ...
    && startsWith(notes, "Baseline: kept none"), 'an auROC baseline is not given to a raster (its bins are), and a note says so');
E0 = EphysAnalysisConfig.normalizePlot(struct('kind', "evoked", 'source', "LFP"));
[E, ~, notes] = copyPlotSettings(E0, P, ["units" "bins"]);
check(E.source == "LFP" && E.units.maxUnits == 7 && E.baseline.Mode == "none" && numel(notes) == 2 ...
    && startsWith(notes(1), "Source: kept LFP"), 'an evoked potential keeps its LFP source and its baseline, and takes the rest');
W = EphysAnalysisConfig.normalizePlot(struct('kind', "rate"));
W.window = struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Stim", 'edge', "offset"));
W.selection = struct('filter', "Level > 10");
[Q, copied, notes] = copyPlotSettings(R0, W, ["window" "selection"]);
check(isequal(Q.window, R0.window) && isstruct(Q.selection) && Q.selection.filter == "Level > 10" ...
    && isequal(copied, ["window" "selection"]) && isscalar(notes) && startsWith(notes, "Epoch window: not copied"), ...
    'a "between" window does not go to a raster (it needs a fixed one); the trial selection does');
M = EphysAnalysisConfig.normalizePlot(struct('kind', "probemap"));
[M2, copied, notes] = copyPlotSettings(M, P, ["ref" "style"]);
check(isequal(copied, "style") && isequal(M2.ref, M.ref) && isscalar(notes) && notes == "Event reference: not copied, Probe map has none.", ...
    'a part named that the kinds do not share is left, with a note; the others copy');
check(strcmp(errorId(@() copyPlotSettings(R0, P, "colors")), 'copyPlotSettings:BadPart'), 'an unknown part raises BadPart');

fprintf('\n== 3. figureSettingParts, copyFigureSettings ==\n');
T = figureSettingParts();
check(isequal(T.Part.', ["observe" "alignment" "common" "arrangement" "style" "looks"]) ...
    && isequal(T.Fields{T.Part == "alignment"}, ["ref" "window" "selection"]) && isequal(T.Fields{T.Part == "arrangement"}, ["grid" "panels"]) ...
    && isequal(T.Fields{T.Part == "looks"}, "aesthetics") && all(T.Label ~= "") && all(T.Description ~= ""), ...
    'figureSettingParts: observe, alignment (ref, window, selection), common, arrangement (grid, panels), style, looks');
fc = EphysAnalysisConfig();
[fc, idA] = fc.addFigure("rasterPsth", Id="a");
[fc, idB] = fc.addFigure("heatmap", Id="b");
B = fc.Figures(2);
B.title = "B's";
B.enabled = false;
B.observe.kind = "dataset";
B.observe.units.maxUnits = 3;
B.ref = EphysAnalysisConfig.defaults("EventRef");
B.ref.line = "Stim";
B.selection = EphysAnalysisConfig.defaults("TrialSelection");
B.selection.groupBy = "Depth";
B.common.bins.BinSec = 0.05;
B.style.FontSize = 14;
B.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2));
fc.Figures(2) = B;
B = fc.Figures(2);
A0 = fc.Figures(1);
parts = T.Part.';
for i = 1:numel(parts)
    [A, copied] = copyFigureSettings(A0, B, parts(i));
    fs = T.Fields{i};
    same = all(arrayfun(@(f) isequaln(A.(f), B.(f)), fs));
    rest = setdiff(string(fieldnames(A0)).', [fs "id" "title" "enabled"]);
    kept = all(arrayfun(@(f) isequaln(A.(f), A0.(f)), rest));
    check(isequal(copied, parts(i)) && same && kept && A.id == idA && A.title == A0.title && A.enabled == A0.enabled, ...
        sprintf('copyFigureSettings "%s": %s from the other figure, the rest and the id, title and enabled kept', parts(i), strjoin(fs, ", ")));
end
[A, copied] = copyFigureSettings(A0, B);
check(isequal(copied, parts) && isequal([A.panels.id], [B.panels.id]) && A.grid.rows == B.grid.rows && A.id == idA ...
    && A.title == A0.title && A.enabled, 'by default every part copies: the heat map''s grid and panels (their ids) onto the raster + PSTH');
[A, copied] = copyFigureSettings(A0, B, ["looks" "alignment"]);
check(isequal(copied, ["alignment" "looks"]) && isstruct(A.ref) && A.ref.line == "Stim" && isscalar(A.aesthetics) ...
    && isequal([A.panels.type], ["raster" "psth"]), 'two parts named copy in the table''s order; the panels stay');
fc.Figures(1) = A;
I = fc.validate(CheckPaths=false);
check(~any(I.Section == "Figures" & I.Severity == "error" & startsWith(I.Field, idA)), 'the figure copied onto validates');
check(strcmp(errorId(@() copyFigureSettings(A0, B, "colors")), 'copyFigureSettings:BadPart') && idB == "b", ...
    'an unknown part raises BadPart');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_copyPlotSettings:Failures', '%d checks failed.', nFail);
end
end
