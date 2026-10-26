function test_copyFigureSettings()
%test_copyFigureSettings  Verification suite for copying a figure's settings, one by one, onto other figures or into a design.
%   1. figureSettingParts: the parts. figureSettingItems: a raster + PSTH
%      figure's settings, each with its part, groups (a panel's group,
%      an Appearance group), paths, value, generic key and whether a
%      design holds it; the Style fields a figure does not use left out.
%   2. copyFigureSettings: one setting (the rest of its part kept), a
%      part, a panel's options (to the panel of its type only; another
%      type's that does not take them unchanged), one figure onto many
%      (CHANGED), the layout (grid and panels), remembered looks added
%      one by one, panels matched by id then type, a copy that changes
%      nothing, every setting by default (the id, title and enabled kept;
%      it validates), the errors (BadSetting, BadFigure), and the time of
%      a copy of every setting onto ten figures.
%   3. figureLookToDesign: a colormap's name (sequential colors and a
%      palette), the heat colors, the remembered looks into the rules, one
%      color (the single color), what a design does not hold left out, an
%      unknown key (BadSetting).
%
%   Usage:  test_copyFigureSettings

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

fprintf('\n== 1. figureSettingParts, figureSettingItems ==\n');
P = figureSettingParts();
check(isequal(P.Part.', ["observe" "alignment" "latency" "arrangement" "panel" "style" "looks" "sessions"]) && all(P.Label ~= "") ...
    && all(P.Description ~= ""), 'figureSettingParts: observe, alignment, latency, arrangement, panel, style, looks, sessions, each labeled and described');
fc = EphysAnalysisConfig();
[fc, idA] = fc.addFigure("rasterPsth", Id="a");
[fc, idB] = fc.addFigure("psth", Id="b");
[fc, idC] = fc.addFigure("continuous", Id="c");
A = fc.Figures(1);
A.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 1));
fc.Figures(1) = A;
A0 = fc.Figures(1);
I = figureSettingItems(A0);
row = @(key) I(I.Key == key, :);
y = row("panel.psth_1.options.yLim");
fs = row("style.FontSize");
check(height(y) == 1 && isequal(y.Groups{1}, ["psth_1  (PSTH)" "Axes and limits"]) && y.Scope == "panel" && y.Index == 2 ...
    && isequal(y.Paths{1}, "options.yLim") && y.Generic == "panel:psth.options.yLim" && y.Value == "(auto)" && ~y.Design, ...
    'a panel option: under its panel and group, its path from the panel, its generic key by type, its value as text');
check(height(fs) == 1 && fs.Groups{1} == "Text and legend" && isequal(fs.Paths{1}, "style.FontSize") && fs.Value == "9" ...
    && fs.Label == "Font size" && ~any(startsWith(I.Key, ["style.YLim" "style.MaxTiles" "style.TileSpacing" "style.StackSpacing"])), ...
    'an Appearance setting in its group; the Style fields a figure does not use are left out');
lay = row("arrangement.layout");
check(height(lay) == 1 && ismember("panels", lay.Paths{1}) && ismember("grid.rows", lay.Paths{1}) && contains(lay.Value, "raster, psth") ...
    && height(row("observe.data")) == 1 && height(row("alignment.ref")) == 1 && height(row("panel.raster_1.options.tickColor")) == 1 ...
    && height(row("sessions.series")) == 1 && isequal(row("sessions.datasets").Paths{1}, ["sessions.datasets" "sessions.datasetKeys"]), ...
    'the layout holds the grid and the panels; observations, alignment, the raster''s options and the session fields are listed');
lk = row("looks.1");
check(height(lk) == 1 && lk.Scope == "looks" && lk.Index == 1 && lk.Generic == "looks" && lk.Design ...
    && ~row("style.Colormap").Design && ~row("style.HeatColormap").Design, ...
    'a remembered look is one setting a design holds; the group colors "lines" and blank heat colors are not offered to a design');

fprintf('\n== 2. copyFigureSettings ==\n');
B = fc.Figures(2);
B.style.FontSize = 14;
B.style.LineWidth = 2;
B.ref = EphysAnalysisConfig.defaults("EventRef");
B.ref.line = "Stim";
B.panels(1).options.yLimMode = "fixed";
B.panels(1).options.yLim = [0 50];
B.panels(1).options.bins.BinSec = 0.05;
B.aesthetics = PlotAesthetics.normalizeRules([struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 3) ...
    struct('role', "sem", 'group', "", 'property', "FaceAlpha", 'value', 0.2)]);
fc.Figures(2) = B;
B = fc.Figures(2);
F0 = fc.Figures;
D = fc.Defaults;
[F, changed, copied] = copyFigureSettings(F0, D, 2, 1, "style.FontSize");
check(isequal(changed, 1) && isequal(copied, "style.FontSize") && F(1).style.FontSize == 14 && F(1).style.LineWidth == A0.style.LineWidth ...
    && isequaln(rmfield(F(1), 'style'), rmfield(A0, 'style')) && isequaln(F(3), F0(3)), ...
    'one setting: the font size alone (the line width and the rest kept; the figure not ticked unchanged)');
F = copyFigureSettings(F0, D, 2, 1, "alignment");
check(isstruct(F(1).ref) && F(1).ref.line == "Stim" && isequaln(F(1).panels, A0.panels), 'a part: the alignment, the panels kept');
[F, changed] = copyFigureSettings(F0, D, 2, [1 3], ["panel.psth_1.options.yLimMode" "panel.psth_1.options.yLim" "style.FontSize"]);
check(isequal(changed, [1 3]) && F(1).panels(2).options.yLimMode == "fixed" && isequal(F(1).panels(2).options.yLim, [0 50]) ...
    && isequaln(F(1).panels(1), A0.panels(1)) && F(3).panels(1).options.yLimMode == F0(3).panels(1).options.yLimMode ...
    && isempty(F(3).panels(1).options.yLim) && F(3).style.FontSize == 14, ...
    ['one figure onto two: the PSTH''s fixed y limits go to the raster + PSTH''s PSTH (not its raster); the continuous panel ' ...
    'does not take them (yLim is in a PSTH''s units, "fixed" needs its own); both take the font size']);
F = copyFigureSettings(F0, D, 2, 1, "panel.psth_1");
check(F(1).panels(2).options.bins.BinSec == 0.05 && isequal(F(1).panels(2).options.yLim, [0 50]) && F(1).panels(2).id == "psth_1" ...
    && isequaln(F(1).panels(1), A0.panels(1)), 'a panel''s every setting: "panel.psth_1" names them all');
F = copyFigureSettings(F0, D, 2, 1, "arrangement.layout");
check(isequal([F(1).panels.type], "psth") && F(1).grid.rows == 1 && isequal(F(1).panels(1).options.yLim, [0 50]) ...
    && F(1).style.FontSize == A0.style.FontSize, 'the layout: the grid and the panels as they are; the appearance kept');
F = copyFigureSettings(F0, D, 2, 1, "looks.1");
check(isscalar(F(1).aesthetics) && F(1).aesthetics.value == 3, 'a remembered look replaces the one it covers; the look not ticked stays out');
F = copyFigureSettings(F0, D, 2, 1, "looks");
check(numel(F(1).aesthetics) == 2 && isequal(sort([F(1).aesthetics.role]), ["rate" "sem"]), 'every remembered look, added to the figure''s own');
[~, changed, copied] = copyFigureSettings(F0, D, 1, 2, "style.Colormap");
check(isempty(changed) && isequal(copied, "style.Colormap"), 'a setting the figure has already changes nothing');

% panels matched by id, then by type
S = B;
S.grid.rows = 2;
S.panels(2) = S.panels(1);
S.panels(2).id = "psth_2";
S.panels(2).row = 2;
S.panels(2).options.yLim = [0 20];
T1 = S;
T1.id = "t1";
T1.panels = T1.panels([2 1]);   % psth_2 first: matched by its id
T1.panels(1).row = 1;
T1.panels(2).row = 2;
T1.panels(1).options.yLim = [];
T1.panels(2).options.yLim = [];
T2 = B;
T2.id = "t2";
T2.panels(1).id = "psth_9";
T2.panels(1).options.yLim = [];
fm = EphysAnalysisConfig();
fm.Figures = [S T1 T2];
G = copyFigureSettings(fm.Figures, fm.Defaults, 1, [2 3], ["panel.psth_1.options.yLim" "panel.psth_2.options.yLim"]);
check(isequal(G(2).panels(1).options.yLim, [0 20]) && isequal(G(2).panels(2).options.yLim, [0 50]) ...
    && isequal(G(3).panels(1).options.yLim, [0 50]), ...
    'a panel takes the settings of the panel of its id and type (psth_2 the 20, psth_1 the 50), else the first of its type (psth_9 the 50)');

[F, changed] = copyFigureSettings(F0, D, 2, 1);
check(isequal(changed, 1) && isequal([F(1).panels.type], "psth") && F(1).id == idA && F(1).title == A0.title && F(1).enabled ...
    && F(1).style.FontSize == 14 && F(1).ref.line == "Stim", 'every setting by default: the PSTH figure''s; the id, title and enabled kept');
fc2 = fc;
fc2.Figures = F;
V = fc2.validate(CheckPaths=false);
check(~any(V.Section == "Figures" & V.Severity == "error" & startsWith(V.Field, idA)), 'the figure copied onto validates');
check(strcmp(errorId(@() copyFigureSettings(F0, D, 2, 1, "colors")), 'copyFigureSettings:BadSetting') ...
    && strcmp(errorId(@() copyFigureSettings(F0, D, 2, 9)), 'copyFigureSettings:BadFigure') && idB == "b" && idC == "c", ...
    'an unknown setting raises BadSetting, a figure out of range BadFigure');
many = repmat(F0(1), 1, 10);
for i = 1:10; many(i).id = "m" + i; end
many = [F0(2) many];
t0 = tic;
[~, changed] = copyFigureSettings(many, D, 1, 2:11);
sec = toc(t0);
fprintf('  (every setting of a PSTH figure onto ten raster + PSTH figures: %.3f s)\n', sec);
check(numel(changed) == 10 && sec < 5, sprintf('every setting onto ten figures at once (%.2f s)', sec));

fprintf('\n== 3. figureLookToDesign ==\n');
L = A0;
L.style.Colormap = "turbo";
L.style.HeatColormap = "hot";
L.aesthetics = B.aesthetics;
[Dz, copied] = figureLookToDesign(PlotDesign.none(), L);
check(Dz.sequential == "turbo" && isequal(size(Dz.palette), [7 3]) && Dz.heat == "hot" && numel(Dz.rules) == 2 ...
    && isequal(sort(copied), sort(["style.Colormap" "style.HeatColormap" "looks.1" "looks.2"])), ...
    'a colormap''s name gives the sequential colors and a palette, the heat colors and both remembered looks go in');
L.style.Colormap = "black";
[Dz, copied] = figureLookToDesign(PlotDesign.none(), L, ["style" "looks.2"]);
check(isequal(Dz.single, [0 0 0]) && isscalar(Dz.rules) && Dz.rules.role == "sem" && ~ismember("style.FontSize", copied), ...
    'one color gives the single color; only the look ticked; the font size (not a design''s) is left out');
check(strcmp(errorId(@() figureLookToDesign(PlotDesign.none(), L, "nope")), 'figureLookToDesign:BadSetting'), ...
    'an unknown setting raises BadSetting');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_copyFigureSettings:Failures', '%d checks failed.', nFail);
end
end
