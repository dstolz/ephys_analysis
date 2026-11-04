function test_FigureTemplate()
%test_FigureTemplate  Verification suite for figure templates (FigureTemplate): making, keeping, reading and applying them.
%   1. fromFigure: a raster + PSTH figure with an id, title, enabled off,
%      its own page, a font size, a remembered look and Inf units as a
%      template: every setting kept, but its id (automatic again), title
%      and enabled; summary; figureOf.
%   2. save, list, load: the file (schema, version, no identity fields in
%      its figure, Inf as a string), read back equal; a name in any case;
%      saving again under another case replaces the one file; the errors
%      (Exists without Overwrite, BadName, Unknown).
%   3. later versions of the code: a template written by a newer version,
%      with fields this code does not know (top level, in its figure and in
%      a panel) and identity fields, reads with its notes; a partial figure
%      takes the defaults; what is not a template is refused
%      (FigureTemplate:Bad: another schema, no figure, a value the config
%      refuses, a template of the old shape whose figure has a grid); list
%      shows a bad file's reason (the old grid named) and a newer one's
%      notes.
%   4. import and export: written anywhere, read back under the file's own
%      name field, another name, Exists and Overwrite; remove.
%   5. check: the config's checks of a template's figure (validate), clean
%      and with an error, the fields without the figure's id.
%   6. applied as the app applies it (copyFigureSettings from the
%      template's figure onto others): each figure takes every setting and
%      keeps its id, title and enabled; one part only; as a new figure
%      (addFigure).
%   7. panel types: the built-in Raster over PSTH; a template saved with
%      Panel=true (the file's "panel", list's Panel) listed by panelTypes
%      after it; a file without "panel"; panelFigure (built in, yours,
%      Unknown); its panels placed in a figure (placeBlock); removed.
%   The preferences and the templates folder are temporary
%   (AppPrefs.useTemporary).
%
%   Usage:  test_FigureTemplate

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU>
folder = FigureTemplate.folder();
cleanFolder = onCleanup(@() removeFolder(folder));
out = string(tempname);
mkdir(out);
cleanOut = onCleanup(@() removeFolder(out));

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

fprintf('\n== 1. fromFigure, summary, figureOf ==\n');
cfg = EphysAnalysisConfig();
cfg = cfg.addFigure("rasterPsth", Id="card");
cfg = cfg.addFigure("psth", Id="other");
A = cfg.Figures(1);
A.title = "My card";
A.enabled = false;
A.size = struct('source', "own", 'width', 6, 'height', 4, 'units', "in", 'lock', true);
A.style.FontSize = 13;
A.observe.units.maxUnits = Inf;
A.panels(2).options.yLimMode = "fixed";
A.panels(2).options.yLim = [0 40];
A.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2));
cfg.Figures(1) = A;
A = cfg.Figures(1);
t = FigureTemplate.fromFigure(A, Description="Raster over PSTH");
f = t.figure;
check(f.id == "" && f.autoId && f.title == "" && f.enabled && t.from == "card" && t.description == "Raster over PSTH" ...
    && strlength(t.saved) == 16 && isempty(t.notes) && t.file == "", ...
    'a figure as a template: no id (automatic), no title, enabled; made from card, described, stamped');
same = @(x, y) isequaln(rmfield(x, cellstr(FigureTemplate.IdentityFields)), rmfield(y, cellstr(FigureTemplate.IdentityFields)));
check(same(f, A) && isequal(f.panels(2).options.yLim, [0 40]) && f.style.FontSize == 13 && f.size.units == "in" ...
    && isscalar(f.aesthetics) && isinf(f.observe.units.maxUnits), ...
    'every other setting kept: the panels and their options, the page, the appearance, the remembered look, Inf units');
check(FigureTemplate.summary(f) == "2 panels: raster, psth; observes units, 6 x 4 in" ...
    && FigureTemplate.summary(cfg.Figures(2)) == "1 panel: psth; observes units", ...
    sprintf('summary: "%s"', FigureTemplate.summary(f)));
g = FigureTemplate.figureOf(t);
check(g.id == "" && g.autoId && g.enabled && same(g, A), 'figureOf: the settings, with an automatic id');

fprintf('\n== 2. save, list, load ==\n');
check(isempty(FigureTemplate.list()) && contains(folder, "_templates"), ...
    'no template yet; the folder is beside the temporary preferences file');
file = FigureTemplate.save(t, "Unit card");
s = jsondecode(fileread(file));
check(isfile(file) && endsWith(file, "Unit card.json") && s.schema == "ephys-figure-template" && s.version == FigureTemplate.Version ...
    && s.name == "Unit card" && s.from == "card" && ~any(isfield(s.figure, ["id" "autoId" "title" "enabled"])) ...
    && isequal(s.figure.observe.units.maxUnits, 'Inf'), ...
    'saved as "<name>.json": schema, version, name, from; its figure without id, autoId, title and enabled; Inf as a string');
L = FigureTemplate.list();
check(height(L) == 1 && L.Name == "Unit card" && L.Description == "Raster over PSTH" && L.Problem == "" ...
    && L.Summary == FigureTemplate.summary(f) && L.Saved == t.saved && L.File == file, 'list: the template, its description, shape and time');
r = FigureTemplate.load("unit CARD");
check(r.name == "Unit card" && r.file == file && isequaln(r.figure, t.figure) && isempty(r.notes) && r.description == t.description, ...
    'load (any case): the figure read back equal, Inf and all; no notes');
check(strcmp(errorId(@() FigureTemplate.save(t, "Unit card")), 'FigureTemplate:Exists') ...
    && strcmp(errorId(@() FigureTemplate.save(t, "a/b")), 'FigureTemplate:BadName') ...
    && strcmp(errorId(@() FigureTemplate.save(t, "  ")), 'FigureTemplate:BadName') ...
    && strcmp(errorId(@() FigureTemplate.load("nope")), 'FigureTemplate:Unknown'), ...
    'refused: an existing name without Overwrite, a name that is no file name, an unknown template');
t2 = t;
t2.description = "again";
FigureTemplate.save(t2, "UNIT CARD", Overwrite=true);
L = FigureTemplate.list();
check(height(L) == 1 && L.Name == "UNIT CARD" && L.Description == "again", 'saved again in another case: one file, replaced');

fprintf('\n== 3. later versions of the code ==\n');
s = FigureTemplate.toStruct(t);
s.version = 99;
s.extraTop = "x";
s.figure.wobble = 1;
s.figure.panels(1).options.notAnOption = 3;
s.figure.id = "should go";
s.figure.title = "should go too";
newer = fullfile(out, "newer.json");
writeJsonFile(newer, s, NonFinite="string");
r = FigureTemplate.load(newer);
check(r.version == 99 && numel(r.notes) == 3 && contains(r.notes(1), "newer version") && contains(r.notes(2), "wobble") ...
    && contains(r.notes(2), "notAnOption") && contains(r.notes(3), "extraTop") && r.figure.id == "" && r.figure.title == "" ...
    && same(r.figure, t.figure), ...
    'a newer template with unknown fields reads: its notes name the version and each field dropped; the identity fields are left out');
part = struct('schema', "ephys-figure-template", 'figure', struct('layout', struct('padding', 0.5), ...
    'panels', {{struct('type', "psth", 'rect', [0.5 0 0.5 1])}}));
r = FigureTemplate.normalize(part, "partial");
check(r.version == FigureTemplate.Version && isempty(r.notes) && r.figure.layout.padding == 0.5 && r.figure.layout.boxesMean == "plot" ...
    && isequal(r.figure.panels(1).rect, [0.5 0 0.5 1]) && r.figure.panels(1).id == "psth_1" ...
    && r.figure.style.FontSize == EphysAnalysisConfig.defaults("Figure").style.FontSize && r.name == "", ...
    'a partial figure takes the defaults (a setting added since a template was saved): normalized as a config''s figures');
check(strcmp(errorId(@() FigureTemplate.normalize(struct('schema', "ephys-analysis-config", 'figure', struct()))), 'FigureTemplate:Bad') ...
    && strcmp(errorId(@() FigureTemplate.normalize(struct('schema', "ephys-figure-template"))), 'FigureTemplate:Bad') ...
    && strcmp(errorId(@() FigureTemplate.normalize(struct('schema', "ephys-figure-template", 'figure', struct('panels', 5)))), 'FigureTemplate:Bad') ...
    && strcmp(errorId(@() FigureTemplate.normalize(3)), 'FigureTemplate:Bad'), ...
    'refused: another schema, no figure, a value the config refuses (panels not structs), not an object');
oldShape = struct('schema', "ephys-figure-template", 'version', 1, 'figure', struct('grid', struct('rows', 2, 'cols', 1), ...
    'panels', {{struct('type', "raster", 'row', 1), struct('type', "psth", 'row', 2)}}));
check(strcmp(errorId(@() FigureTemplate.normalize(oldShape, "old")), 'FigureTemplate:Bad'), ...
    'a template of the old shape (its figure has a grid): refused, not converted');
copyfile(newer, fullfile(folder, "Newer.json"));
fid = fopen(fullfile(folder, "Broken.json"), 'w'); fprintf(fid, '{"schema": "nope"}'); fclose(fid);
writeJsonFile(fullfile(folder, "Gridded.json"), oldShape, NonFinite="string");
L = FigureTemplate.list();
check(isequal(L.Name.', ["Broken" "Gridded" "Newer" "UNIT CARD"]) && startsWith(L.Problem(1), "Not readable") ...
    && startsWith(L.Problem(2), "Not readable") && contains(L.Problem(2), "grid") && L.Summary(2) == "" ...
    && contains(L.Problem(3), "newer version") && L.Problem(4) == "", ...
    'list: by name; a file that is no template says why, an old one names its grid, a newer one its notes');
delete(fullfile(folder, "Broken.json"));
delete(fullfile(folder, "Gridded.json"));
delete(fullfile(folder, "Newer.json"));

fprintf('\n== 4. import, export, remove ==\n');
ex = fullfile(out, "shared.json");
FigureTemplate.export("unit card", ex);
s = jsondecode(fileread(ex));
check(isfile(ex) && s.name == "UNIT CARD" && s.description == "again", 'export writes the template anywhere, its name inside');
check(strcmp(errorId(@() FigureTemplate.import(ex)), 'FigureTemplate:Exists'), 'importing it back: one of yours has its name (Exists)');
[n1, r] = FigureTemplate.import(ex, Name="Colleague card");
check(n1 == "Colleague card" && r.name == n1 && isfile(r.file) && isequaln(r.figure, t.figure), 'import under another name');
s.name = "From the name field";
writeJsonFile(fullfile(out, "file name.json"), s, NonFinite="string");
n2 = FigureTemplate.import(fullfile(out, "file name.json"));
n3 = FigureTemplate.import(ex, Overwrite=true);
check(n2 == "From the name field" && n3 == "UNIT CARD" && height(FigureTemplate.list()) == 3, ...
    'imported under the file''s name field; Overwrite replaces one of yours');
FigureTemplate.remove("from the NAME field");
check(height(FigureTemplate.list()) == 2 && strcmp(errorId(@() FigureTemplate.remove("From the name field")), 'FigureTemplate:Unknown'), ...
    'remove deletes one of yours (any case); again: Unknown');

fprintf('\n== 5. check ==\n');
I = FigureTemplate.check(t);
check(~any(string(I.Severity) == "error"), 'a template of a valid figure has no error in the config''s checks');
bad = t;
bad.figure.panels(2).rect = [0.5 0 1 0.5];
I = FigureTemplate.check(bad, cfg.Defaults);
errs = I(string(I.Severity) == "error", :);
check(~isempty(errs) && isequal(string(errs.Field), "psth_1.rect"), ...
    sprintf('a panel reaching off the page is an error, its field without the figure''s id (%s)', strjoin(string(errs.Field), ", ")));

fprintf('\n== 6. applied ==\n');
F = cfg.Figures;
n = numel(F);
tf = FigureTemplate.figureOf(t);
G = copyFigureSettings([F tf], cfg.Defaults, n + 1, 2);
B = G(2);
check(B.id == "other" && B.title == F(2).title && B.enabled == F(2).enabled && isequal([B.panels.type], ["raster" "psth"]) ...
    && isequal(B.panels(2).options.yLim, [0 40]) && B.style.FontSize == 13 && B.size.units == "in" && isequaln(G(1), F(1)), ...
    'every setting copied onto a figure: it keeps its id, title and enabled; the others are untouched');
G = copyFigureSettings([F tf], cfg.Defaults, n + 1, 2, "style");
check(G(2).style.FontSize == 13 && isequal([G(2).panels.type], "psth") && G(2).size.source == F(2).size.source, ...
    'one part (Appearance): the panels and the page stay');
[c2, id] = cfg.addFigure(tf);
check(numel(c2.Figures) == 3 && c2.Figures(3).autoId && id ~= "" && c2.Figures(3).id == id && same(c2.Figures(3), A), ...
    sprintf('as a new figure: the whole template, an automatic id (%s)', id));

fprintf('\n== 7. panel types ==\n');
P0 = FigureTemplate.panelTypes();
check(P0.Key(1) == "builtin:rasterPsth" && P0.Label(1) == "Raster over PSTH" && P0.Builtin(1) && isscalar(P0.Key) ...
    && isequal([P0.Figure{1}.panels.type], ["raster" "psth"]) && isequal(vertcat(P0.Figure{1}.panels.rect), [0 0.5 1 0.5; 0 0 1 0.5]) ...
    && P0.Summary(1) == "2 panels: raster, psth; observes units", ...
    'panelTypes: the built-in Raster over PSTH (flush), none of yours while no template is a panel type');
tp = FigureTemplate.fromFigure(A, Description="a card to place", Panel=true);
fp = FigureTemplate.save(tp, "Panel card");
s = jsondecode(fileread(fp));
L = FigureTemplate.list();
P1 = FigureTemplate.panelTypes();
check(~t.panel && tp.panel && isequal(s.panel, true) && FigureTemplate.load("Panel card").panel && L.Panel(L.Name == "Panel card") ...
    && nnz(L.Panel) == 1 && isequal(P1.Key.', ["builtin:rasterPsth" "Panel card"]) && ~P1.Builtin(2) ...
    && P1.Description(2) == "a card to place" && isequaln(P1.Figure{2}, tp.figure), ...
    'Panel=true: the file says "panel": true, list''s Panel, panelTypes lists it after the built-in one with its figure');
old = rmfield(FigureTemplate.toStruct(tp), 'panel');
r = FigureTemplate.normalize(old);
check(~r.panel && isempty(r.notes), 'a file without "panel" reads as a template only, with no note');
[pf, pl] = FigureTemplate.panelFigure("Panel card");
[bf, bl] = FigureTemplate.panelFigure("builtin:rasterPsth");
check(isequaln(pf, tp.figure) && pl == "Panel card" && bl == "Raster over PSTH" && isequal([bf.panels.type], ["raster" "psth"]) ...
    && strcmp(errorId(@() FigureTemplate.panelFigure("builtin:nothing")), 'FigureTemplate:Unknown') ...
    && strcmp(errorId(@() FigureTemplate.panelFigure("No such")), 'FigureTemplate:Unknown'), ...
    'panelFigure: a panel type''s figure and name, the built-in and yours; Unknown for one that is not there');
host = cfg.Figures(2);   % "other": one PSTH
[placed, pids] = EphysAnalysisConfig.placeBlock(host, pf, "below", host.panels(1).id);
check(isequal([placed.panels.type], ["psth" "raster" "psth"]) && isequal(pids, ["raster_1" "psth_2"]) ...
    && isequal(vertcat(placed.panels.rect), [0 0.5 1 0.5; 0 0.25 1 0.25; 0 0 1 0.25]) ...
    && isequal(placed.panels(3).options.yLim, [0 40]) && placed.style.FontSize == host.style.FontSize, ...
    'placed in a figure below its PSTH: its panels flush in the bottom half, with their options, ids made free; the figure keeps its own look');
FigureTemplate.remove("Panel card");
check(isscalar(FigureTemplate.panelTypes().Key), 'removed: no longer a panel type');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_FigureTemplate:Failures', '%d checks failed.', nFail);
end
end


function removeFolder(f)
if isfolder(f); rmdir(f, 's'); end
end
