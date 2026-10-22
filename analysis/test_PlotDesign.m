function test_PlotDesign()
%test_PlotDesign  Verification suite for plot designs (PlotDesign), on figures.
%   On makeAnalysisFixture's "clean" dataset (figureTestCases: one figure
%   per panel type and per layout that matters). Checks the built-in
%   designs (they load, name known roles and only known kinds -- a panel
%   type, "figure" or a Chronux kind: kindNames --, give the session roles,
%   and every panel type and layout draws in each without a refused value),
%   what a design does to a figure (ground, group colors by palette, single
%   and sequential colors, heat and diverging colormaps, rules for every
%   figure and for one panel type), the layering (design, then the user's
%   rules for a panel's type, then the figure's; a figure's own colors
%   win), choosing a design (the preference, redrawing every figure on
%   screen, listeners), the right-click Design submenu, capturing a
%   figure's look and saving, listing, importing and deleting designs, and
%   refused files and names. The preferences and your designs folder are
%   temporary (AppPrefs.useTemporary).
%
%   Usage:  test_PlotDesign

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
addpath(genpath(fullfile(repo, 'vendor')));   % Chronux, for the spectral panels
restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU>
folder = PlotDesign.folder();
cleanFolder = onCleanup(@() removeFolder(folder));
root = fullfile(tempdir, sprintf('PlotDesign_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
cleanRoot = onCleanup(@() removeFolder(root));

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);
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

fprintf('\n== 0. fixture: a figure per panel type and layout ==\n');
[cases, fx] = figureTestCases(string(root));
byId = @(id) cases([cases.id] == id);
check(numel(cases) >= 20, sprintf('%d figures computed on the fixture', numel(cases)));
Cp = byId("psth");
groups = string(Cp.F.groups.label);
check(numel(groups) == 2, sprintf('two trial groups (TrialType), not ordered: %s', strjoin(groups, ", ")));

fprintf('\n== 1. the built-in designs ==\n');
L = PlotDesign.list();
builtin = ["Default" "Gray panel" "Journal" "Night" "Talk" "Tufte"];
check(isequal(sort(L.Name(L.Source == "built-in")).', sort(builtin)) && L.Name(1) == "Default" && L.File(1) == "", ...
    'list: Default (no file) and the five built-in designs');
roles = PlotAesthetics.roles().Role;
kinds = PlotDesign.kindNames();
check(all(ismember(EphysAnalysisConfig.panelTypes().Type, kinds)) && any(kinds == "figure") && all(ismember(PlotDesign.ChronuxKinds, kinds)), ...
    'kindNames: every panel type, "figure" and the Chronux kinds');
ok = true; why = "";
for n = builtin(2:end)
    try
        D = PlotDesign.load(n);
        R = D.rules;
        for kk = string(fieldnames(D.kinds)).'; R = [R D.kinds.(kk)]; end %#ok<AGROW>
        good = all(ismember([R.role], roles)) && size(D.palette, 2) == 3 && size(D.palette, 1) >= 4 ...
            && numel(D.background) == 3 && ~isempty(D.heat) && ~isempty(D.diverging) && ~isempty(D.sequential) ...
            && D.source == "built-in" && D.description ~= "" && all(ismember(string(fieldnames(D.kinds)), kinds));
        if ~good; ok = false; why = why + " " + n; end
    catch ME
        ok = false; why = why + " " + n + ": " + ME.message;
    end
end
check(ok, "every built-in design loads, names only known roles and kinds and gives a ground, palette and colormaps" + ifText(~ok, " (" + why + ")"));
ok = true; why = "";
for n = builtin(2:end)
    D = PlotDesign.load(n);
    mw = D.rules([D.rules.role] == "memberLine" & [D.rules.property] == "LineWidth");
    dc = D.rules([D.rules.role] == "sessionDivider" & [D.rules.property] == "Color");
    if ~(isscalar(mw) && mw.value == 0.75 && isscalar(dc) && ~any([D.rules([D.rules.role] == "memberLine").property] == "Color"))
        ok = false; why = why + " " + n;
    end
end
check(ok, "every built-in design names the session roles: memberLine (LineWidth 0.75, no color: the pale series color stays) " + ...
    "and sessionDivider (its color)" + ifText(~ok, " (" + why + ")"));
D = PlotDesign.load("tufte");
check(D.name == "Tufte" && isequal(PlotDesign.load("Default"), PlotDesign.none()) && isequal(PlotDesign.load(""), PlotDesign.none()), ...
    'load: by name in any case (named by the file); Default and "" are no design');
check(strcmp(errorId(@() PlotDesign.load("Plaid")), 'PlotDesign:Unknown'), 'load: an unknown name is refused');
fonts = [D.rules([D.rules.property] == "FontName").value];
check(~isempty(fonts) && all(fonts == fonts(1)) && ~contains(fonts(1), ","), ...
    'a FontName list becomes one font (the first installed of Palatino Linotype, Palatino, Book Antiqua, Georgia)');
tl = D.rules([D.rules.role] == "axes" & [D.rules.property] == "TickLength");
check(isscalar(tl) && isequal(tl.value, [0.008 0.02]), 'a two-number value (TickLength) is a rule value');

fprintf('\n== 2. every panel type and layout draws in every design ==\n');
fig = figure('Visible', 'off', 'Position', [100 100 700 800]);
ground0 = fig.Color;   % the figure's own ground (its theme's, or the user's default), before any design
cleanFig = onCleanup(@() delete(fig(isvalid(fig))));
bad = strings(0, 1);
for n = builtin
    for i = 1:numel(cases)
        lastwarn('');
        try
            renderFigure(cases(i).F, cases(i).spec, fig, Design=n);
            [msg, wid] = lastwarn();
            if wid ~= ""; bad(end+1) = n + " / " + cases(i).id + ": " + msg; end %#ok<AGROW>
        catch ME
            bad(end+1) = n + " / " + cases(i).id + ": " + ME.message; %#ok<AGROW>
        end
    end
end
check(isempty(bad), "every panel type and layout draws in every design without an error or a refused value" + ...
    ifText(~isempty(bad), " (" + strjoin(bad, "; ") + ")"));
sessionRoles = strings(1, 0);
for id = ["sessions_combine" "sessions_members" "sessions_heatmap"]
    c = byId(id);
    hS = renderFigure(c.F, c.spec, fig, Design="Night");
    CS = PlotAesthetics.components(hS.layout);
    sessionRoles = [sessionRoles unique(CS.Role).']; %#ok<AGROW>
end
check(all(ismember(["memberLine" "sessionDivider"], sessionRoles)), ...
    'the session figures (in Night) draw the member lines and session dividers the designs style');

fprintf('\n== 3. what a design does to a figure ==\n');
tufte = PlotDesign.load("Tufte");
h = renderFigure(Cp.F, Cp.spec, fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
ax = C.Handles{find(C.Role == "axes", 1)};
check(isequal(fig.Color, tufte.background) && strcmp(ax.Box, 'off') && strcmp(ax.XGrid, 'off') && strcmp(ax.TickDir, 'out') ...
    && isequal(ax.TickLength, [0.008 0.02]) && strcmp(ax.FontName, fonts(1)), ...
    'Tufte: the off-white ground, no box or grid, short outward ticks, the serif font');
rc = arrayfun(@(k) C.Handles{find(C.Role == "rateFill" & C.Group == groups(k), 1)}(1).FaceColor, 1:2, 'UniformOutput', false);
check(isequal(vertcat(rc{:}), tufte.palette(1:2, :)), 'the trial groups take the palette''s colors, in order');
sb = C.Handles{find(C.Role == "sem" & C.Group == groups(1), 1)}(1);
check(max(abs(sb.FaceColor - (tufte.palette(1, :) + (tufte.background - tufte.palette(1, :)) * 0.75))) < 1e-9, ...
    'an SEM band is the group color paled towards the design''s ground, not white');
spec = Cp.spec; spec.style.Colormap = "turbo";
h = renderFigure(Cp.F, spec, fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
c1 = C.Handles{find(C.Role == "rateFill" & C.Group == groups(1), 1)}(1).FaceColor;
Mt = turbo(256);
check(isequal(c1, Mt(1, :)), 'a figure''s own group colors (turbo) win over the palette');
Co = byId("ordered");
nO = height(Co.F.groups);
h = renderFigure(Co.F, Co.spec, fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
M = PlotDesign.colormap(tufte.sequential, 256);
if nO > 2
    bc = arrayfun(@(k) C.Handles{find(C.Role == "bar" & C.Group == string(Co.F.groups.label(k)), 1)}(1).FaceColor, 1:nO, 'UniformOutput', false);
    check(max(abs(vertcat(bc{:}) - M(round(linspace(1, 256, nO)), :)), [], 'all') < 1e-9, ...
        sprintf('ordered groups (Depth, %d values) take the sequential colors, light to dark', nO));
else
    check(false, sprintf('the fixture''s Depth has more than two values (%d)', nO));
end
C1 = byId("one_group");
h = renderFigure(C1.F, C1.spec, fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
check(isequal(C.Handles{find(C.Role == "rateFill", 1)}(1).FaceColor, tufte.single), 'one group takes the single color (Tufte''s gray)');
Ch = byId("heatmap");
h = renderFigure(Ch.F, Ch.spec, fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
axh = C.Handles{find(C.Role == "axes", 1)};
zl = C.Handles{find(C.Role == "zeroLine", 1)}(1);
hz = tufte.kinds.heatmap([tufte.kinds.heatmap.role] == "zeroLine" & [tufte.kinds.heatmap.property] == "Color").value;
cz = tufte.rules([tufte.rules.role] == "zeroLine" & [tufte.rules.property] == "Color").value;
check(max(abs(axh.Colormap - PlotDesign.colormap(tufte.heat, 256)), [], 'all') < 1e-9 && isequal(zl.Color, hz) && ~isequal(hz, cz), ...
    'a heat map panel: the design''s heat colors, and its rules for heat maps (the zero line''s color) after the common ones');
spec = Ch.spec; spec.style.HeatColormap = "hot";
h = renderFigure(Ch.F, spec, fig, Design="Tufte");
check(max(abs(h.axes(1).Colormap - hot(256)), [], 'all') < 1e-9, 'a figure''s own heat colors (hot) win over the design''s');
Cc = byId("corrmap");
journal = PlotDesign.load("Journal");
h = renderFigure(Cc.F, Cc.spec, fig, Design="Journal");
check(max(abs(h.axes(1).Colormap - PlotDesign.colormap(journal.diverging, 256)), [], 'all') < 1e-9, ...
    'a correlation map panel takes the diverging colors');
renderFigure(Cp.F, Cp.spec, fig, Design="Default");
check(isequal(fig.Color, ground0), 'Default puts back the ground the figure had before a design');

fprintf('\n== 4. layering: the design, the user''s rules, the figure''s ==\n');
PlotAesthetics.setUserRules("psth", struct('role', "axes", 'group', "", 'property', "Box", 'value', "on"));
h = renderFigure(Cp.F, Cp.spec, fig, Design="Tufte");
check(strcmp(firstAxes(h, "axes").Box, 'on'), 'the user''s rules for PSTH panels win over the design''s (box on)');
spec = Cp.spec;
spec.aesthetics = PlotAesthetics.normalizeRules(struct('role', "axes", 'group', "", 'property', "Box", 'value', "off"));
h = renderFigure(Cp.F, spec, fig, Design="Tufte");
check(strcmp(firstAxes(h, "axes").Box, 'off'), 'the figure''s own rules win over the user''s');
PlotAesthetics.setUserRules("psth", []);
h = renderFigure(Cp.F, Cp.spec, fig, Design="Tufte", UserAesthetics=false);
check(strcmp(firstAxes(h, "axes").Box, 'off') && isequal(fig.Color, tufte.background), 'Design= is drawn with UserAesthetics=false too');

fprintf('\n== 5. choosing a design ==\n');
check(PlotDesign.currentName() == "Default" && isequal(PlotDesign.current(), PlotDesign.none()), 'nothing chosen: Default');
owner = figure('Visible', 'off');
PlotDesign.listen(owner, @() setappdata(owner, 'heard', getappdata(owner, 'heard') + 1));
setappdata(owner, 'heard', 0);
live = figure('Visible', 'off', 'Position', [100 100 700 800]);
liveGround = live.Color;
renderFigure(Cp.F, Cp.spec, live, Editable=true);
pinned = figure('Visible', 'off', 'Position', [100 100 700 800]);
cleanFigs = onCleanup(@() delete([live pinned]));
renderFigure(Cp.F, Cp.spec, pinned, Editable=true, Design="Journal");
PlotDesign.use("night");
night = PlotDesign.load("Night");
axLive = findobj(live, 'Type', 'axes', 'Tag', 'axes');
axPinned = findobj(pinned, 'Type', 'axes', 'Tag', 'axes');
check(PlotDesign.currentName() == "Night" && AppPrefs.getpref(PlotDesign.PrefGroup, "Design") == "Night", ...
    'use: the choice is a preference, named as its file');
check(~isempty(axLive) && isequal(live.Color, night.background) && all(arrayfun(@(a) isequal(a.Color, night.background), axLive)), ...
    'use: a figure on screen that follows the chosen design is redrawn in it at once');
check(~isempty(axPinned) && isequal(pinned.Color, journal.background) && all(arrayfun(@(a) isequal(a.Color, [1 1 1]), axPinned)), ...
    'a figure drawn in a named design keeps it');
check(getappdata(owner, 'heard') == 1, 'use: the listeners hear of it');
renderFigure(Cp.F, Cp.spec, fig);
check(isequal(fig.Color, night.background), 'renderFigure draws in the chosen design by default (a run''s figures too)');
check(strcmp(errorId(@() PlotDesign.use("Plaid")), 'PlotDesign:Unknown') && PlotDesign.currentName() == "Night", ...
    'use: an unknown design is refused and nothing changes');
cm = findall(live, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag);
cm = cm(1);
PlotAesthetics.fillMenu(cm);   % (its items are made when it opens)
dm = findobj(cm.Children, 'flat', 'Tag', PlotDesign.MenuTag);
PlotAesthetics.onMenuOpening(cm, []);
items = flipud(dm.Children);
check(isscalar(dm) && numel(items) == height(PlotDesign.list()) + 1 && string(items(strcmp({items.Checked}, 'on')).Text) == "Night" ...
    && string(items(end).Text) == "Save this look as a design...", ...
    'the right-click Design submenu lists every design (the chosen one ticked) and Save this look');
items(string({items.Text}) == "Tufte").MenuSelectedFcn([], []);
check(PlotDesign.currentName() == "Tufte" && isequal(live.Color, tufte.background), 'picking a design in the submenu chooses it');
delete(owner);
PlotDesign.use("Default");
check(isequal(live.Color, liveGround) && PlotDesign.currentName() == "Default", 'back to Default: the ground as it was');

fprintf('\n== 6. capturing a look, saving and listing designs ==\n');
spec = Cp.spec;
spec.panels(1).options.histStyle = "line";
spec.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 3));
renderFigure(Cp.F, spec, live, Editable=true, Design="Tufte");
D = PlotDesign.capture(live, Name="Mine", Description="Thick lines");
has = @(D, role, prop) any([D.rules.role] == role & [D.rules.property] == prop);
val = @(D, role, prop) D.rules(find([D.rules.role] == role & [D.rules.property] == prop, 1, 'last')).value;
check(isequal(val(D, "rate", "LineWidth"), 3) && val(D, "axes", "Box") == "off" && isequal(val(D, "axes", "TickLength"), [0.008 0.02]), ...
    'capture: every property all of a role''s components share becomes a rule (the figure''s own edits too)');
check(~has(D, "rate", "Color") && ~has(D, "sem", "FaceColor") && ~has(D, "legend", "Location") && ~has(D, "axes", "Colormap"), ...
    'capture: no rule for group colors, the legend''s place or a colormap');
check(isequal(D.background, tufte.background) && isequal(D.palette, tufte.palette) && D.name == "Mine", ...
    'capture: the ground and the groups'' colors (the palette, the rest kept from the design drawn in)');
PlotDesign.save(D, "Mine");
L = PlotDesign.list();
k = find(L.Name == "Mine");
check(isscalar(k) && L.Source(k) == "mine" && L.Description(k) == "Thick lines" && isfile(fullfile(folder, "Mine.json")), ...
    'save: into your designs folder, listed as yours with its description');
D2 = PlotDesign.load("Mine");
check(numel(D2.rules) == numel(D.rules) && isequal(val(D2, "rate", "LineWidth"), 3) && isequal(D2.palette, round(D.palette * 255) / 255) ...
    && isequal(val(D2, "axes", "XColor"), round(val(D, "axes", "XColor") * 255) / 255), ...
    'the file reads back as the same design (colors as #rrggbb)');
txt = fileread(fullfile(folder, "Mine.json"));
check(contains(txt, '"#FFFFF8"') && contains(txt, '"ephys-plot-design"'), 'the file holds colors as #rrggbb and its schema');
Ct = byId("tuning");
h = renderFigure(Ct.F, Ct.spec, fig, Design="Mine");
check(strcmp(firstAxes(h, "axes").Box, 'off') && isequal(fig.Color, tufte.background), 'a saved design draws other panel types too');
h = renderFigure(Cp.F, setfield(Cp.spec, 'panels', spec.panels), fig, Design="Mine"); %#ok<SFLD>
C = PlotAesthetics.components(h.layout);
check(any(C.Role == "rate") && all(arrayfun(@(i) all(arrayfun(@(o) o.LineWidth == 3, C.Handles{i})), find(C.Role == "rate"))), ...
    'a saved design gives a fresh figure the captured look (PSTH lines 3 wide)');
renderFigure(Ch.F, Ch.spec, live, Editable=true, Design="Mine");
Dh = PlotDesign.capture(live, Name="Mine heat");
check(size(Dh.heat, 2) == 3 && size(Dh.heat, 1) >= 2, 'capture from a heat map figure: its colormap as the heat colors');
axesRules = @(R) R([string.empty(1, 0) R.role] == "axes");
Dm = PlotDesign.load("Mine");
check(isfield(Dh.kinds, "heatmap") && any([Dh.kinds.heatmap.role] == "axes") && isequaln(axesRules(Dh.rules), axesRules(Dm.rules)), ...
    ['capture from a heat map figure without Spec (the right-click path: the panel types renderFigure keeps in the ' ...
    'editing context): its axes rules are kept for heat maps only (kinds.heatmap), the common ones unchanged']);
Dh2 = PlotDesign.capture(live, Spec=Ch.spec);
check(isequaln(Dh2.kinds, Dh.kinds) && isequaln(Dh2.rules, Dh.rules), 'capture with Spec= (the app''s Save design) attributes them the same way');
% panel types attributed per tile: a mixed figure, two heat maps, no map panel, and a redraw in what was captured
srcD = fx.runner.source(1);
hmFig = fx.cfg.Figures(fx.cfg.figureIndex("heatmap"));   % as stored (not resolved by figureFor)
psFig = fx.cfg.Figures(fx.cfg.figureIndex("psth"));
hmPanel = hmFig.panels(1);
psPanel = psFig.panels(1);
mixed = hmFig;
mixed.id = "mixed";
mixed.grid.rows = 2; mixed.grid.cols = 1; mixed.grid.rowHeights = []; mixed.grid.colWidths = [];
hmPanel.row = 1; hmPanel.col = 1; psPanel.row = 2; psPanel.col = 1;
mixed.panels = [hmPanel psPanel];
cfgD = fx.cfg.addFigure(mixed);
mixedSpec = cfgD.figureFor("mixed");
Tm = figureObservations(srcD, mixedSpec);
renderFigure(fx.runner.computeFigure(srcD, mixedSpec, Observation=Tm(1, :)), mixedSpec, live, Editable=true, Design="Default");
Dx = PlotDesign.capture(live);
roles = @(R) [string.empty(1, 0) R.role];
check(isfield(Dx.kinds, "heatmap") && any(roles(Dx.kinds.heatmap) == "axes") && ~any(ismember(roles(Dx.kinds.heatmap), ["rate" "rateFill" "sem"])) ...
    && any(roles(Dx.rules) == "axes") && ~any(ismember(roles(Dx.rules), ["image" "colorbar"])) && ~isfield(Dx.kinds, "psth"), ...
    'a heat map over a PSTH: the heat map''s axes rules go under kinds.heatmap only, the PSTH''s into the common rules');
two = mixed;
two.id = "two_heatmaps";
hm2 = hmPanel; hm2.id = hmPanel.id + "_b"; hm2.row = 2;
two.panels = [hmPanel hm2];
cfgD = fx.cfg.addFigure(two);
twoSpec = cfgD.figureFor("two_heatmaps");
T2 = figureObservations(srcD, twoSpec);
renderFigure(fx.runner.computeFigure(srcD, twoSpec, Observation=T2(1, :)), twoSpec, live, Editable=true, Design="Default");
D2h = PlotDesign.capture(live);
check(isfield(D2h.kinds, "heatmap") && any(roles(D2h.kinds.heatmap) == "axes") && ~any(roles(D2h.rules) == "axes"), ...
    'two heat-map panels: their axes rules under kinds.heatmap, no axes rule among the common ones');
renderFigure(Cp.F, Cp.spec, live, Editable=true, Design="Default");
Dn = PlotDesign.capture(live);
check(isempty(fieldnames(Dn.kinds)) && any(roles(Dn.rules) == "axes"), 'a figure without a map panel adds no kinds: its rules are all common');
heatSpec = Ch.spec;
heatSpec.aesthetics = PlotAesthetics.normalizeRules(struct('role', "axes", 'group', "", 'property', "LineWidth", 'value', 2.5));
renderFigure(Ch.F, heatSpec, live, Editable=true, Design="Default");
Dk = PlotDesign.capture(live, Name="Heat lines");
PlotDesign.save(Dk, "Heat lines", Overwrite=true);
hk = renderFigure(Ch.F, Ch.spec, fig, Design="Heat lines");
heatWidth = hk.axes(1).LineWidth;   % read before the next drawing replaces it
hpk = renderFigure(Cp.F, Cp.spec, fig, Design="Heat lines");
check(isfield(Dk.kinds, "heatmap") && heatWidth == 2.5 && hpk.axes(1).LineWidth ~= 2.5, ...
    'redrawn in the saved design, a heat map''s axes come back as captured (2.5 wide); a PSTH''s do not take the heat map''s rule');
PlotDesign.remove("Heat lines");
if nO > 2
    renderFigure(Co.F, Co.spec, live, Editable=true, Design="Default");
    Do = PlotDesign.capture(live);
    check(size(Do.sequential, 1) == nO && isempty(Do.palette), 'capture of ordered groups: their colors become the sequential colors');
end
check(strcmp(errorId(@() PlotDesign.save(D, "Tufte")), 'PlotDesign:BadName') && strcmp(errorId(@() PlotDesign.save(D, "a/b")), 'PlotDesign:BadName') ...
    && strcmp(errorId(@() PlotDesign.save(D, "default")), 'PlotDesign:BadName') && strcmp(errorId(@() PlotDesign.save(D, "Mine")), 'PlotDesign:Exists'), ...
    'save: a built-in name, a name with / and one of yours (without Overwrite) are refused');
PlotDesign.save(D2, " Mine ", Overwrite=true);
check(isfile(fullfile(folder, "Mine.json")), 'save Overwrite=true replaces yours (the name trimmed)');
src = fullfile(tempdir, "shared_" + string(feature('getpid')) + ".json");
writeJsonFile(src, setfield(PlotDesign.toStruct(D2), 'name', "Lab look")); %#ok<SFLD>
nm = PlotDesign.import(src);
delete(src);
check(nm == "Lab look" && any(PlotDesign.list().Name == "Lab look"), 'import: a design file is copied in under its own name');
PlotDesign.use("Mine");
PlotDesign.remove("Mine");
check(~any(PlotDesign.list().Name == "Mine") && PlotDesign.currentName() == "Default", 'remove: yours is deleted; Default is chosen if it was');
check(strcmp(errorId(@() PlotDesign.remove("Tufte")), 'PlotDesign:BuiltIn'), 'remove: a built-in design stays');

fprintf('\n== 7. refused files ==\n');
bad = @(s) errorId(@() PlotDesign.normalize(s));
check(strcmp(bad(struct('rules', struct('role', "axes", 'property', "Wobble", 'value', 1))), 'PlotAesthetics:BadRule') ...
    && strcmp(bad(struct('rules', struct('role', "axes", 'property', "XColor", 'value', "plaid"))), 'PlotDesign:Bad') ...
    && strcmp(bad(struct('palette', {{"#ff0000", "plaid"}})), 'PlotDesign:Bad') ...
    && strcmp(bad(struct('heat', "notAColormap")), 'PlotDesign:Bad') ...
    && strcmp(bad(struct('heat', {{"#ff0000"}})), 'PlotDesign:Bad') ...
    && strcmp(bad([struct('a', 1) struct('a', 2)]), 'PlotDesign:Bad'), ...
    'normalize refuses an unknown property, a bad color, a bad palette, an unknown or one-color colormap and a list');
retired = struct('kinds', struct('behavior', struct('role', "axes", 'property', "Box", 'value', "off"), ...
    'pie', struct('role', "axes", 'property', "Box", 'value', "off"), 'figure', struct('role', "axes", 'property', "Box", 'value', "on")));
lastwarn('');
w = warning('off', 'PlotDesign:UnknownKind');
Dr = PlotDesign.normalize(retired);
[wmsg, wid] = lastwarn();
warning(w);
check(strcmp(wid, 'PlotDesign:UnknownKind') && contains(wmsg, '"pie"') && isfield(Dr.kinds, 'figure') ...
    && ~isfield(Dr.kinds, 'behavior') && ~isfield(Dr.kinds, 'pie'), ...
    'normalize drops an unknown kind (a retired plot kind too) with a warning, PlotDesign:UnknownKind; the design stays usable');
writeJsonFile(fullfile(folder, "Retired.json"), setfield(PlotDesign.toStruct(PlotDesign.none()), 'kinds', retired.kinds)); %#ok<SFLD>
w = warning('off', 'PlotDesign:UnknownKind');
L = PlotDesign.list();
Dl = PlotDesign.load("Retired");
warning(w);
check(any(L.Name == "Retired") && ~startsWith(L.Description(L.Name == "Retired"), "Not readable") ...
    && isfield(Dl.kinds, 'figure') && ~isfield(Dl.kinds, 'behavior'), ...
    'a design file with a retired kind''s rules is listed and loads, without them');
delete(fullfile(folder, "Retired.json"));
ok3 = PlotDesign.normalize(struct('kinds', struct('figure', struct('role', "axes", 'property', "Box", 'value', "off"), ...
    'spectrum', struct('role', "axes", 'property', "Box", 'value', "on"), 'chronuxSpectrum', struct('role', "axes", 'property', "Box", 'value', "on"))));
check(isfield(ok3.kinds, 'figure') && isfield(ok3.kinds, 'spectrum') && isfield(ok3.kinds, 'chronuxSpectrum'), ...
    'normalize takes rules kept for "figure", a panel type and a Chronux kind');
check(strcmp(errorId(@() PlotAesthetics.normalizeRules(struct('role', "axes", 'property', "TickLength", 'value', [1 2 3 4]))), ...
    'PlotAesthetics:BadRule'), 'a value of four numbers is refused');
fid = fopen(fullfile(folder, "Broken.json"), 'w'); fprintf(fid, '{ not json'); fclose(fid);
L = PlotDesign.list();
check(startsWith(L.Description(L.Name == "Broken"), "Not readable"), 'list: a broken file of yours is listed with why it cannot be read');
AppPrefs.setpref(PlotDesign.PrefGroup, "Design", 'Broken');
w = warning('off', 'PlotDesign:Unusable');
lastwarn('');
D = PlotDesign.current();
[~, wid] = lastwarn();
warning(w);
check(isequal(D, PlotDesign.none()) && strcmp(wid, 'PlotDesign:Unusable'), 'an unreadable chosen design draws as Default, with a warning');
AppPrefs.rmpref(PlotDesign.PrefGroup, "Design");

fprintf('\n== 8. the editor offers what designs set ==\n');
h = renderFigure(Cp.F, Cp.spec, live, Editable=true);
d = PlotAestheticsDialog(getappdata(live, PlotAesthetics.ContextKey), firstAxes(h, "axes"), Visible=false);
cleanDlg = onCleanup(@() delete(d(isvalid(d))));
P = PlotAesthetics.editableProperties(firstAxes(h, "axes"));
d.setProperty("TickLength", [0.03 0.05]);
check(any([P.Name] == "TickLength") && isequal(firstAxes(h, "axes").TickLength, [0.03 0.05]), ...
    'the editor offers an axes'' tick length and sets it');
d.cancel();
lg = findobj(live, 'Type', 'legend');
P = PlotAesthetics.editableProperties(lg(1));
check(any([P.Name] == "FontName"), 'the editor offers a legend''s font');

fx.src.outputs.clearCache();
fprintf('\n%d passed, %d failed\n', nPass, nFail);
if nFail > 0
    error('test_PlotDesign:Failed', '%d check(s) failed.', nFail);
end
end


function ax = firstAxes(h, role)
%firstAxes  The first axes of role ROLE in the figure H drew.
C = PlotAesthetics.components(h.layout);
ax = C.Handles{find(C.Role == role, 1)};
end


function s = ifText(cond, s)
if ~cond; s = ""; end
end


function removeFolder(f)
if isfolder(f)
    try
        rmdir(f, 's');
    catch
    end
end
end
