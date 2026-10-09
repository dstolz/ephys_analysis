function test_PlotDesign()
%test_PlotDesign  Verification suite for plot designs (PlotDesign).
%   No recording is needed: seeded Poisson spike trains make PSTH, rate,
%   tuning, heatmap, correlation, probe-map, evoked and behavior results.
%   Checks the built-in designs (they load, name known roles, and every
%   kind and layout draws in each without a refused value), what a design
%   does to a plot (ground, group colors by palette, single and sequential
%   colors, heat and diverging colormaps, rules for every plot and for one
%   kind), the layering (design, then the user's rules, then the plot's; a
%   plot's own colors win), choosing a design (the preference, redrawing
%   every plot on screen, listeners), the right-click Design submenu,
%   capturing a plot's look and saving, listing, importing and deleting
%   designs, and refused files and names. The preferences and your
%   designs folder are temporary (AppPrefs.useTemporary).
%
%   Usage:  test_PlotDesign

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU>
folder = PlotDesign.folder();
cleanFolder = onCleanup(@() removeFolder(folder));

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

rng(12, 'twister');
nE = 60;
t0 = (10:4:10 + 4 * (nE - 1)).';
g = 1 + mod((1:nE).', 3);
E = table((1:nE).', NaN(nE, 1), t0, t0, t0 + 0.3, t0 - 0.2, t0 + 0.5, repmat(0.7, nE, 1), true(nE, 1), false(nE, 1), g, "group " + g, ...
    'VariableNames', {'epoch', 'trial', 't0', 't0Continuous', 't1', 'tStart', 'tStop', 'duration', 'complete', 'artifact', 'groupIndex', 'group'});
E.Properties.UserData = struct('ref', eventRef(line="Stim"), 'window', epochWindow(pre=-0.2, post=0.5), ...
    'selection', trialSelection(), 'scope', "trial", 'nTrials', nE);
G = table((1:3).', ["Depth = 0"; "Depth = 0.5"; "Depth = 1"], lines(3), [0; 0; 0], 'VariableNames', {'index', 'label', 'color', 'n'});
Go = G;   % ordered groups: selectTrials' colors for a numeric parameter with more than two values
Go.color = groupColors(zeros(3, 1), true);
meta = table(["u1"; "u2"; "u3"; "u4"], [1; 2; 3; 4], ["su"; "mua"; "su"; "su"], [1; 5; 3; 7], ["A-000"; "A-004"; "A-002"; "A-006"], ...
    [0; 0; 1; 1], [0; 8; 200; 208], [0; 100; 50; 150], [1; 1; 1; 1], ...
    'VariableNames', {'label', 'unitId', 'class', 'channel', 'channelName', 'shank', 'x', 'y', 'nSpikes'});
T = t0(end) + 5;
trains = cell(1, 4);
for u = 1:4
    s = T * rand(round(6 * T), 1);
    for k = 1:nE
        s = [s; t0(k) + 0.05 + 0.2 * rand(3 * u, 1)]; %#ok<AGROW>
    end
    trains{u} = sort(s);
end
Rp = spikePSTH(trains, E, Window=[-0.2 0.5], BinSec=0.02, Groups=G, Meta=meta);
Rp.epochs = E; Rp.dataset = "synthetic";
Rpo = spikePSTH(trains, E, Window=[-0.2 0.5], BinSec=0.02, Groups=Go, Meta=meta);
Rpo.epochs = E;
E1 = E; E1.groupIndex(:) = 1;
Rp1 = spikePSTH(trains, E1, Window=[-0.2 0.5], BinSec=0.02, Groups=G(1, :), Meta=meta);
Rp1.epochs = E1;
Rr = firingRate(trains, E, Groups=G, Meta=meta);
Rro = firingRate(trains, E, Groups=Go, Meta=meta);
Rt = tuningCurve(Rr.rate, mod((1:nE).', 4), Param="Depth", Meta=meta);
Rc = unitCorrelation(trains, E, Groups=G, Meta=meta);
Rc.epochs = E;
probe = struct('chanMap', 0:7, 'xc', [0 8 0 8 200 208 200 208], 'yc', [0 25 50 75 0 25 50 75], 'kcoords', [0 0 0 0 1 1 1 1]);
Tu = table(["u1"; "u2"; "u3"], ["su"; "mua"; "su"], [1; 5; 3], [0; 1; 0], [0; 200; 0], [0; 0; 50], [10; 20; 30], [1; 2; 3], ...
    'VariableNames', {'label', 'class', 'channel', 'shank', 'x', 'y', 'nSpikes', 'rateHz'});
Rq = probeMapValues(Tu, probe, Value="rate");
Y = randn(800, 3, 'single');
Ev = E(1:6, :); Ev.t0 = (0.2:0.1:0.7).'; Ev.t0Continuous = Ev.t0; Ev.groupIndex = [1; 2; 3; 1; 2; 3];
Rv = evokedPotential(Y, 1000, Ev, Window=[-0.1 0.1], Groups=G);
Rv.meta = table(["c1"; "c2"; "c3"], [1; 2; 3], [0; 0; 0], [0; 0; 0], [0; 25; 50], 'VariableNames', {'label', 'channel', 'shank', 'x', 'y'});
yb = 300 + 80 * randn(nE, 1);
yb(1:5:end) = NaN;
Rb = behaviorValues(yb, mod((1:nE).', 3), Series=mod((1:nE).', 2), Param="Depth", SeriesParam="TrialType", YName="RespLatency");
tms = linspace(-0.6, 1.4, 61).';
shape = -exp(-(tms / 0.15).^2) + 0.4 * exp(-((tms - 0.5) / 0.3).^2);
Wv = struct('timeMs', {repmat({tms}, 4, 1)}, 'mean', {cell(4, 1)}, 'spikes', {cell(4, 1)}, ...
    'from', ["spikes"; "spikes"; "template"; "none"], 'units', ["uV"; "uV"; "uV"; ""], 'note', "", 'maxSpikes', 20);
for u = 1:2
    Wv.spikes{u} = 80 * u * shape + 10 * randn(61, 20);
    Wv.mean{u} = mean(Wv.spikes{u}, 2);
end
Wv.mean{3} = 60 * shape;
Rpw = Rp; Rpw.waveforms = Wv;

fprintf('\n== 1. the built-in designs ==\n');
L = PlotDesign.list();
builtin = ["Default" "Gray panel" "Journal" "Night" "Talk" "Tufte"];
check(isequal(sort(L.Name(L.Source == "built-in")).', sort(builtin)) && L.Name(1) == "Default" && L.File(1) == "", ...
    'list: Default (no file) and the five built-in designs');
roles = PlotAesthetics.roles().Role;
ok = true; why = "";
for n = builtin(2:end)
    try
        D = PlotDesign.load(n);
        R = D.rules;
        for kk = string(fieldnames(D.kinds)).'; R = [R D.kinds.(kk)]; end %#ok<AGROW>
        good = all(ismember([R.role], roles)) && size(D.palette, 2) == 3 && size(D.palette, 1) >= 4 ...
            && numel(D.background) == 3 && ~isempty(D.heat) && ~isempty(D.diverging) && ~isempty(D.sequential) ...
            && D.source == "built-in" && D.description ~= "";
        if ~good; ok = false; why = why + " " + n; end
    catch ME
        ok = false; why = why + " " + n + ": " + ME.message;
    end
end
check(ok, "every built-in design loads, names only known roles and gives a ground, palette and colormaps" + ifText(~ok, " (" + why + ")"));
D = PlotDesign.load("tufte");
check(D.name == "Tufte" && isequal(PlotDesign.load("Default"), PlotDesign.none()) && isequal(PlotDesign.load(""), PlotDesign.none()), ...
    'load: by name in any case (named by the file); Default and "" are no design');
check(strcmp(errorId(@() PlotDesign.load("Plaid")), 'PlotDesign:Unknown'), 'load: an unknown name is refused');
fonts = [D.rules([D.rules.property] == "FontName").value];
check(~isempty(fonts) && all(fonts == fonts(1)) && ~contains(fonts(1), ","), ...
    'a FontName list becomes one font (the first installed of Palatino Linotype, Palatino, Book Antiqua, Georgia)');
tl = D.rules([D.rules.role] == "axes" & [D.rules.property] == "TickLength");
check(isscalar(tl) && isequal(tl.value, [0.008 0.02]), 'a two-number value (TickLength) is a rule value');

fprintf('\n== 2. every kind and layout draws in every design ==\n');
cases = {
    "psth grid + raster", Rp,  struct('kind', "psth")
    "psth line, stack",   Rp,  struct('kind', "psth", 'histStyle', "line", 'stack', true)
    "psth overlay",       Rp,  struct('kind', "psth", 'layout', "overlay")
    "psth + waveforms",   Rpw, struct('kind', "psth", 'waveform', struct('mode', "both"))
    "raster",             Rp,  struct('kind', "raster")
    "rate bar",           Rr,  struct('kind', "rate", 'layout', "bar")
    "rate box",           Rr,  struct('kind', "rate", 'layout', "box")
    "rate points",        Rr,  struct('kind', "rate", 'layout', "points")
    "tuning",             Rt,  struct('kind', "tuning")
    "heatmap",            Rp,  struct('kind', "heatmap")
    "corrmap",            Rc,  struct('kind', "corrmap")
    "probemap",           Rq,  struct('kind', "probemap")
    "evoked stack",       Rv,  struct('kind', "evoked", 'layout', "stack", 'source', "LFP")
    "evoked butterfly",   Rv,  struct('kind', "evoked", 'layout', "butterfly", 'source', "LFP")
    "behavior points",    Rb,  struct('kind', "behavior")
    "behavior box",       Rb,  struct('kind', "behavior", 'layout', "box")
    "behavior swarm",     Rb,  struct('kind', "behavior", 'layout', "swarm")};
fig = figure('Visible', 'off');
cleanFig = onCleanup(@() delete(fig(isvalid(fig))));
bad = strings(0, 1);
for n = builtin
    for i = 1:size(cases, 1)
        lastwarn('');
        try
            renderPlot(cases{i, 2}, cases{i, 3}, fig, Design=n);
            [msg, wid] = lastwarn();
            if wid ~= ""; bad(end+1) = n + " / " + cases{i, 1} + ": " + msg; end %#ok<AGROW>
        catch ME
            bad(end+1) = n + " / " + cases{i, 1} + ": " + ME.message; %#ok<AGROW>
        end
    end
end
check(isempty(bad), "every kind and layout draws in every design without an error or a refused value" + ...
    ifText(~isempty(bad), " (" + strjoin(bad, "; ") + ")"));

fprintf('\n== 3. what a design does to a plot ==\n');
tufte = PlotDesign.load("Tufte");
h = renderPlot(Rp, struct('kind', "psth"), fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
ax = C.Handles{find(C.Role == "axes", 1)};
check(isequal(fig.Color, tufte.background) && strcmp(ax.Box, 'off') && strcmp(ax.XGrid, 'off') && strcmp(ax.TickDir, 'out') ...
    && isequal(ax.TickLength, [0.008 0.02]) && strcmp(ax.FontName, fonts(1)), ...
    'Tufte: the off-white ground, no box or grid, short outward ticks, the serif font');
rc = arrayfun(@(k) C.Handles{find(C.Role == "rateFill" & C.Group == G.label(k), 1)}(1).FaceColor, 1:3, 'UniformOutput', false);
check(isequal(vertcat(rc{:}), tufte.palette(1:3, :)), 'the groups take the palette''s colors, in order');
sb = C.Handles{find(C.Role == "sem" & C.Group == G.label(1), 1)}(1);
check(max(abs(sb.FaceColor - (tufte.palette(1, :) + (tufte.background - tufte.palette(1, :)) * 0.75))) < 1e-9, ...
    'an SEM band is the group color paled towards the design''s ground, not white');
h = renderPlot(Rp, struct('kind', "psth", 'style', struct('Colormap', "turbo")), fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
c1 = C.Handles{find(C.Role == "rateFill" & C.Group == G.label(1), 1)}(1).FaceColor;
Mt = turbo(256);
check(isequal(c1, Mt(1, :)), 'a plot''s own group colors (turbo) win over the palette');
h = renderPlot(Rro, struct('kind', "rate", 'layout', "bar"), fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
M = PlotDesign.colormap(tufte.sequential, 256);
bc = arrayfun(@(k) C.Handles{find(C.Role == "bar" & C.Group == Go.label(k), 1)}(1).FaceColor, 1:3, 'UniformOutput', false);
check(max(abs(vertcat(bc{:}) - M(round(linspace(1, 256, 3)), :)), [], 'all') < 1e-9, ...
    'ordered groups (a numeric parameter) take the sequential colors, light to dark');
h = renderPlot(Rp1, struct('kind', "psth"), fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
check(isequal(C.Handles{find(C.Role == "rateFill", 1)}(1).FaceColor, tufte.single), 'one group takes the single color (Tufte''s gray)');
h = renderPlot(Rp, struct('kind', "heatmap"), fig, Design="Tufte");
C = PlotAesthetics.components(h.layout);
axh = C.Handles{find(C.Role == "axes", 1)};
zl = C.Handles{find(C.Role == "zeroLine", 1)}(1);
hz = tufte.kinds.heatmap([tufte.kinds.heatmap.role] == "zeroLine" & [tufte.kinds.heatmap.property] == "Color").value;
cz = tufte.rules([tufte.rules.role] == "zeroLine" & [tufte.rules.property] == "Color").value;
check(max(abs(axh.Colormap - PlotDesign.colormap(tufte.heat, 256)), [], 'all') < 1e-9 && isequal(zl.Color, hz) && ~isequal(hz, cz), ...
    'a heat map: the design''s heat colors, and its rules for heat maps (the zero line''s color) after the common ones');
h = renderPlot(Rp, struct('kind', "heatmap", 'style', struct('HeatColormap', "hot")), fig, Design="Tufte");
axh = h.axes(1);
check(max(abs(axh.Colormap - hot(256)), [], 'all') < 1e-9, 'a plot''s own heat colors (hot) win over the design''s');
h = renderPlot(Rc, struct('kind', "corrmap"), fig, Design="Journal");
journal = PlotDesign.load("Journal");
check(max(abs(h.axes(1).Colormap - PlotDesign.colormap(journal.diverging, 256)), [], 'all') < 1e-9, ...
    'a correlation map takes the diverging colors');
renderPlot(Rp, struct('kind', "psth"), fig, Design="Default");
check(isequal(fig.Color, [1 1 1]), 'Default puts back the ground the figure had before a design');

fprintf('\n== 4. layering: the design, the user''s rules, the plot''s ==\n');
PlotAesthetics.setUserRules("psth", struct('role', "axes", 'group', "", 'property', "Box", 'value', "on"));
h = renderPlot(Rp, struct('kind', "psth"), fig, Design="Tufte");
check(strcmp(firstAxes(h, "axes").Box, 'on'), 'the user''s rules win over the design''s (box on)');
spec = struct('kind', "psth", 'aesthetics', struct('role', "axes", 'group', "", 'property', "Box", 'value', "off"));
h = renderPlot(Rp, spec, fig, Design="Tufte");
check(strcmp(firstAxes(h, "axes").Box, 'off'), 'the plot''s own rules win over the user''s');
PlotAesthetics.setUserRules("psth", []);
h = renderPlot(Rp, struct('kind', "psth"), fig, Design="Tufte", UserAesthetics=false);
check(strcmp(firstAxes(h, "axes").Box, 'off') && isequal(fig.Color, tufte.background), 'Design= is drawn with UserAesthetics=false too');

fprintf('\n== 5. choosing a design ==\n');
check(PlotDesign.currentName() == "Default" && isequal(PlotDesign.current(), PlotDesign.none()), 'nothing chosen: Default');
owner = figure('Visible', 'off');
PlotDesign.listen(owner, @() setappdata(owner, 'heard', getappdata(owner, 'heard') + 1));
setappdata(owner, 'heard', 0);
live = figure('Visible', 'off');
renderPlot(Rp, struct('kind', "psth"), live, Editable=true);
pinned = figure('Visible', 'off');
cleanFigs = onCleanup(@() delete([live pinned]));
renderPlot(Rp, struct('kind', "psth"), pinned, Editable=true, Design="Journal");
PlotDesign.use("night");
night = PlotDesign.load("Night");
axLive = findobj(live, 'Type', 'axes', 'Tag', 'axes');
axPinned = findobj(pinned, 'Type', 'axes', 'Tag', 'axes');
check(PlotDesign.currentName() == "Night" && AppPrefs.getpref(PlotDesign.PrefGroup, "Design") == "Night", ...
    'use: the choice is a preference, named as its file');
check(isequal(live.Color, night.background) && all(arrayfun(@(a) isequal(a.Color, night.background), axLive)), ...
    'use: a plot on screen that follows the chosen design is redrawn in it at once');
check(isequal(pinned.Color, journal.background) && all(arrayfun(@(a) isequal(a.Color, [1 1 1]), axPinned)), ...
    'a plot drawn in a named design keeps it');
check(getappdata(owner, 'heard') == 1, 'use: the listeners hear of it');
h = renderPlot(Rp, struct('kind', "psth"), fig);
check(isequal(fig.Color, night.background), 'renderPlot draws in the chosen design by default (a run''s figures too)');
check(strcmp(errorId(@() PlotDesign.use("Plaid")), 'PlotDesign:Unknown') && PlotDesign.currentName() == "Night", ...
    'use: an unknown design is refused and nothing changes');
cm = findall(live, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag);
cm = cm(1);
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
check(isequal(live.Color, [1 1 1]) && PlotDesign.currentName() == "Default", 'back to Default: the ground as it was');

fprintf('\n== 6. capturing a look, saving and listing designs ==\n');
spec = struct('kind', "psth", 'histStyle', "line", 'aesthetics', [struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 3) ...
    struct('role', "xlabel", 'group', "", 'property', "FontSize", 'value', 13)]);
renderPlot(Rp, spec, live, Editable=true, Design="Tufte");
D = PlotDesign.capture(live, Name="Mine", Description="Thick lines");
has = @(D, role, prop) any([D.rules.role] == role & [D.rules.property] == prop);
val = @(D, role, prop) D.rules(find([D.rules.role] == role & [D.rules.property] == prop, 1, 'last')).value;
check(isequal(val(D, "rate", "LineWidth"), 3) && isequal(val(D, "xlabel", "FontSize"), 13) && val(D, "axes", "Box") == "off" ...
    && isequal(val(D, "axes", "TickLength"), [0.008 0.02]), ...
    'capture: every property all of a role''s components share becomes a rule (the plot''s own edits too)');
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
h = renderPlot(Rt, struct('kind', "tuning"), fig, Design="Mine");
check(strcmp(firstAxes(h, "axes").Box, 'off') && isequal(fig.Color, tufte.background), 'a saved design draws other kinds of plot too');
h = renderPlot(Rp, struct('kind', "psth", 'histStyle', "line"), fig, Design="Mine");
C = PlotAesthetics.components(h.layout);
check(any(C.Role == "rate") && all(arrayfun(@(i) all(arrayfun(@(o) o.LineWidth == 3, C.Handles{i})), find(C.Role == "rate"))), ...
    'a saved design gives a fresh plot the captured look (PSTH lines 3 wide)');
renderPlot(Rp, struct('kind', "heatmap"), live, Editable=true, Design="Mine");
Dh = PlotDesign.capture(live, Name="Mine heat");
check(isfield(Dh.kinds, "heatmap") && numel(Dh.rules) == numel(D2.rules) && any([Dh.kinds.heatmap.role] == "axes") ...
    && size(Dh.heat, 2) == 3, 'capture from a heat map: its rules kept for heat maps only, its colormap as the heat colors');
renderPlot(Rro, struct('kind', "rate"), live, Editable=true, Design="Default");
Do = PlotDesign.capture(live);
check(size(Do.sequential, 1) == 3 && isempty(Do.palette), 'capture of ordered groups: their colors become the sequential colors');
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
    && strcmp(bad(struct('kinds', struct('pie', struct('role', "axes", 'property', "Box", 'value', "off")))), 'PlotDesign:Bad') ...
    && strcmp(bad([struct('a', 1) struct('a', 2)]), 'PlotDesign:Bad'), ...
    'normalize refuses an unknown property, a bad color, a bad palette, an unknown or one-color colormap, an unknown kind and a list');
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
h = renderPlot(Rp, struct('kind', "psth"), live, Editable=true);
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

fprintf('\n%d passed, %d failed\n', nPass, nFail);
if nFail > 0
    error('test_PlotDesign:Failed', '%d check(s) failed.', nFail);
end
end


function ax = firstAxes(h, role)
%firstAxes  The first axes of role ROLE in the plot H drew.
C = PlotAesthetics.components(h.layout);
ax = C.Handles{find(C.Role == role, 1)};
end


function s = ifText(cond, s)
if ~cond; s = ""; end
end


function removeFolder(f)
if isfolder(f); rmdir(f, 's'); end
end
