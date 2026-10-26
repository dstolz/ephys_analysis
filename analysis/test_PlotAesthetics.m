function test_PlotAesthetics()
%test_PlotAesthetics  Verification suite for remembered aesthetics and their editor, on figures.
%   On makeAnalysisFixture's "clean" dataset (figureTestCases: one figure
%   per panel type and per layout that matters -- a stack, the auROC
%   baseline, waveforms on the probe, stacked signals, boxes, a heat map
%   of trials, notes and overlays, ordered groups, one group, first-spike
%   marks and a latency box plot). Checks the
%   rules (normalizeRules, mergeRules, colors as text), that renderFigure
%   tags everything every figure draws with a known role (the parts of a
%   note and of the overlays too, listed by the editor; the first-spike
%   marks and the box plot's parts on one dataset and on rows merged
%   across sessions), that it applies
%   the user's rules for a panel's type and then the figure's own (and
%   UserAesthetics=false skips the user's; a refused value only warns),
%   the right-click menu (only in a visible figure, or with
%   Editable=true; made with "Edit aesthetics..." alone, its other items
%   when it opens: menuOf, fillMenu), the editor (PlotAestheticsDialog: live edits, Apply to
%   one / same / role / ticked, Reset, Cancel, OK remembering for the
%   figure or the user -- as "figure" rules --, forgetting, edits put back
%   after a redraw), the config's aesthetics field on a figure (JSON round
%   trip, a bad property refused) and the generated script's literal for a
%   list of rules. The preferences are a temporary store
%   (AppPrefs.useTemporary).
%
%   Usage:  test_PlotAesthetics

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
addpath(genpath(fullfile(repo, 'vendor')));   % Chronux, for the spectral panels
restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU>
root = fullfile(tempdir, sprintf('PlotAesthetics_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
cleanRoot = onCleanup(@() rmdirQuiet(root));

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

fprintf('\n== 1. rules ==\n');
r1 = struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2);
J = jsondecode(jsonencode([r1 struct('role', "sem", 'group', "Depth = 1", 'property', "FaceColor", 'value', [1 0 0])]));
R = PlotAesthetics.normalizeRules(J);
check(numel(R) == 2 && isequal(R(2).value, [1 0 0]) && R(2).group == "Depth = 1" && isstring(R(1).role), ...
    'normalizeRules: decoded JSON (a color column) becomes rows of string fields and a row color');
check(isempty(PlotAesthetics.normalizeRules([])) && isempty(PlotAesthetics.normalizeRules(struct('role', {}, 'property', {}, 'value', {}))), ...
    'no rules: [] and an empty struct');
check(strcmp(errorId(@() PlotAesthetics.normalizeRules(struct('role', "rate", 'property', "Wobble", 'value', 1))), 'PlotAesthetics:BadRule') ...
    && strcmp(errorId(@() PlotAesthetics.normalizeRules(struct('role', "", 'property', "Color", 'value', 1))), 'PlotAesthetics:BadRule') ...
    && strcmp(errorId(@() PlotAesthetics.normalizeRules(struct('role', "rate", 'property', "Color", 'value', {{1}}))), 'PlotAesthetics:BadRule'), ...
    'an unknown property, an empty role and a cell value are refused');
M = PlotAesthetics.mergeRules(R, struct('role', "sem", 'group', "Depth = 1", 'property', "FaceColor", 'value', [0 0 1]));
check(numel(M) == 2 && isequal(M(2).value, [0 0 1]), 'mergeRules: a rule replaces the one for its role, group and property');
M = PlotAesthetics.mergeRules(M, struct('role', "sem", 'group', "", 'property', "FaceColor", 'value', [0 1 0]));
check(numel(M) == 2 && M(2).group == "" && isequal(M(2).value, [0 1 0]), 'mergeRules: an every-group rule replaces that role''s group rules');
[c1, ok1] = PlotAesthetics.parseColor("#FF8000");
[c2, ok2] = PlotAesthetics.parseColor("255 0 0");
[c3, ok3] = PlotAesthetics.parseColor("none");
[~, ok4] = PlotAesthetics.parseColor("plaid");
check(ok1 && max(abs(c1 - [1 128/255 0])) < 1e-9 && ok2 && isequal(c2, [1 0 0]) && ok3 && c3 == "none" && ~ok4, ...
    'parseColor: hex, r g b in 0-255, a word kept as text, nonsense refused');
check(PlotAesthetics.valueText([1 0 0]) == "#FF0000" && PlotAesthetics.valueText(2.5) == "2.5", 'valueText: colors as hex');

fprintf('\n== 2. renderFigure names everything it draws ==\n');
fig = figure('Visible', 'off', 'Position', [100 100 700 800]);
roles = PlotAesthetics.roles().Role;
allTagged = true; untagged = strings(0, 1);
for i = 1:numel(cases)
    try
        h = renderFigure(cases(i).F, cases(i).spec, fig, UserAesthetics=false);
        C = PlotAesthetics.components(h.layout);
        bad = C.Role == "" | ~ismember(C.Role, roles);
        if any(bad)
            allTagged = false;
            untagged(end+1) = cases(i).id + ": " + strjoin(C.Type(bad) + " " + C.Role(bad), ", "); %#ok<AGROW>
        end
    catch ME
        allTagged = false;
        untagged(end+1) = cases(i).id + ": " + ME.message; %#ok<AGROW>
    end
end
check(allTagged, "every component of every panel type and layout has a known role (" + strjoin([cases.id], ", ") + ")" ...
    + ifText(~allTagged, " (" + strjoin(untagged, "; ") + ")"));
okFS = true;
whyFS = strings(0, 1);
for Ck = [byId("first_spike") byId("sessions_first_spike")]
    h = renderFigure(Ck.F, Ck.spec, fig, UserAesthetics=false);
    C = PlotAesthetics.components(h.layout);
    need = ["firstSpike" "latencyBox" "latencyMedian" "latencyWhisker"];
    miss = need(~ismember(need, C.Role));
    if ~isempty(miss)
        okFS = false;
        whyFS(end+1) = Ck.id + ": no " + strjoin(miss, ", "); %#ok<AGROW>
    end
end
check(okFS, "the first-spike marks and the latency box plot are components of their own roles, on one dataset and on " + ...
    "rows merged across sessions" + ifText(~okFS, " (" + strjoin(whyFS, "; ") + ")"));
Cn = byId("notes_overlays");
h = renderFigure(Cn.F, Cn.spec, fig, UserAesthetics=false);
C = PlotAesthetics.components(h.layout);
check(any(C.Role == "note" & C.TileName == "raster_1") && any(C.Role == "overlayLine" & C.Group == "Stim") ...
    && any(C.Role == "overlayRegion" & C.Group == "Window") && ~any(C.Role == ""), ...
    'a panel''s note and overlays are components of their own roles, in that panel''s tile, the overlays by name, for the editor''s list');
Cp = byId("rasterPsth");
h = renderFigure(Cp.F, Cp.spec, fig, UserAesthetics=false);
C = PlotAesthetics.components(h.layout);
groups = string(Cp.F.groups.label);
check(numel(unique(C.Key)) == height(C) && any(C.Role == "plotTitle") && sum(C.Role == "rasterAxes" | C.Role == "axes") >= 2 ...
    && all(ismember(groups, C.Group(C.Role == "rate" | C.Role == "rateFill"))) && any(C.Role == "legend"), ...
    'a raster over a PSTH: one row per component, role and group; the title, both panels'' axes, a PSTH per trial group, a legend');

fprintf('\n== 3. the rules applied: the user''s for a panel''s type, then the figure''s own ==\n');
red = [1 0 0]; blue = [0 0 1];
PlotAesthetics.setUserRules("psth", [struct('role', "rateFill", 'group', "", 'property', "FaceColor", 'value', blue) ...
    struct('role', "sem", 'group', "", 'property', "Visible", 'value', "off")]);
spec = Cp.spec;
spec.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rateFill", 'group', groups(2), 'property', "FaceColor", 'value', red));
h = renderFigure(Cp.F, spec, fig);
C = PlotAesthetics.components(h.layout);
fc = @(C, grp) arrayfun(@(i) faces(C.Handles{i}), find(C.Role == "rateFill" & C.Group == grp), 'UniformOutput', false);
check(~isempty(fc(C, groups(2))) && all(cellfun(@(x) isequal(x, red), fc(C, groups(2)))) && all(cellfun(@(x) isequal(x, blue), fc(C, groups(1)))), ...
    'the figure''s rule (one group red) wins over the user''s PSTH rule (every group blue)');
semOff = any(C.Role == "sem") && all(arrayfun(@(i) all(strcmp(get(C.Handles{i}, 'Visible'), 'off')), find(C.Role == "sem")));
check(semOff, 'the user''s PSTH rule hides every SEM band of the figure''s PSTH panel');
h = renderFigure(Cp.F, spec, fig, UserAesthetics=false);
C = PlotAesthetics.components(h.layout);
check(all(cellfun(@(x) ~isequal(x, blue), fc(C, groups(1)))) && all(cellfun(@(x) isequal(x, red), fc(C, groups(2)))), ...
    'UserAesthetics=false: only the figure''s rules');
PlotAesthetics.setUserRules("psth", []);
check(isempty(PlotAesthetics.userRules("psth")) && ~AppPrefs.ispref(PlotAesthetics.PrefGroup, "psth"), 'setUserRules(kind, []) forgets them');
PlotAesthetics.setUserRules("figure", struct('role', "plotTitle", 'group', "", 'property', "FontSize", 'value', 17));
h = renderFigure(Cp.F, Cp.spec, fig);
check(findall(h.layout, 'Type', 'axes', 'Tag', 'titleHost').Title.FontSize == 17, 'the user''s "figure" rules dress every figure');
PlotAesthetics.setUserRules("figure", []);
w = warning('off', 'PlotAesthetics:BadValue');
lastwarn('');
spec = Cp.spec;
spec.aesthetics = PlotAesthetics.normalizeRules(struct('role', "zeroLine", 'group', "", 'property', "LineStyle", 'value', "zigzag"));
h = renderFigure(Cp.F, spec, fig);
[~, wid] = lastwarn();
warning(w);
check(~isempty(h.layout) && strcmp(wid, 'PlotAesthetics:BadValue'), 'a value the object refuses warns and the figure is still drawn');

fprintf('\n== 4. the right-click menu ==\n');
inv = figure('Visible', 'off');   % a new figure, as a run's export is
renderFigure(Cp.F, Cp.spec, inv);
check(~isappdata(inv, PlotAesthetics.ContextKey) && isempty(findall(inv, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag)), ...
    'an invisible figure (a run''s export) gets no editor menu (MATLAB''s own legend menu aside)');
delete(inv);
h = renderFigure(Cp.F, Cp.spec, fig, Editable=true, OnRemember=@(r) setappdata(0, 'aestheticsGot', r));
ctx = getappdata(fig, PlotAesthetics.ContextKey);
cms = findall(fig, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag);
C = PlotAesthetics.components(h.layout);
withMenu = cellfun(@(x) all(arrayfun(@(o) ~isprop(o, 'ContextMenu') || (isa(o.ContextMenu, 'matlab.ui.container.ContextMenu') ...
    && isequal(o.ContextMenu.UserData, o)), x)), C.Handles);
check(~isempty(cms) && isstruct(ctx) && ctx.kind == "figure" && ctx.id == Cp.spec.id && isequal(ctx.root, h.layout) && all(withMenu), ...
    'Editable=true: every component has a menu that knows it; the context (kind "figure", the figure''s id, root) is kept on the target');
first = arrayfun(@(cm) numel(cm.Children) == 1 && string(cm.Children.Text) == "Edit aesthetics..." ...
    && isappdata(cm, PlotAesthetics.ItemsKey), cms);
cm1 = PlotAesthetics.menuOf(C.Handles{find(C.Role == "axes" & C.Tile > 0, 1)}(1));
n1 = numel(cm1.Children);
PlotAesthetics.fillMenu(cm1);
check(all(first) && n1 > 1 && numel(cm1.Children) == n1 && ~isappdata(cm1, PlotAesthetics.ItemsKey) ...
    && ~isempty(findobj(cm1.Children, 'flat', 'Tag', PlotDesign.MenuTag)) && string(cm1.Children(end).Text) == "Edit aesthetics...", ...
    'each menu is made with "Edit aesthetics..." alone; its other items are made once, when it opens (menuOf / fillMenu), after it');
renderFigure(Cp.F, Cp.spec, fig, Editable=true);
check(numel(findall(fig, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag)) == numel(cms), 'redrawing leaves no stale menus');
C = PlotAesthetics.components(getappdata(fig, PlotAesthetics.ContextKey).root);
lg = C.Handles{find(C.Role == "legend", 1)};
[c2, holder] = PlotAesthetics.contextOf(lg);
check(isstruct(c2) && isequal(holder, fig), 'a legend finds its figure''s context');
check(strcmp(errorId(@() PlotAesthetics.edit(axes(figure('Visible', 'off')))), 'PlotAesthetics:NotEditable'), ...
    'edit on something renderFigure did not draw: PlotAesthetics:NotEditable');

% Go to setting: only when the caller says where to go
check(isempty(findall(fig, 'Type', 'uimenu', 'Tag', PlotAesthetics.GotoTag)), 'no OnGoto: no "Go to setting" item');
setappdata(0, 'aestheticsGoto', {});
h = renderFigure(Cp.F, Cp.spec, fig, Editable=true, OnGoto=@(role, panel) setappdata(0, 'aestheticsGoto', {role, panel}));
C = PlotAesthetics.components(h.layout);
cms = findall(fig, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag);
arrayfun(@PlotAesthetics.fillMenu, cms);   % (made when each opens)
items = findall(fig, 'Type', 'uimenu', 'Tag', PlotAesthetics.GotoTag);
check(numel(items) == numel(cms), 'OnGoto: every component menu has "Go to setting"');
k = find(C.Role ~= "" & C.Tile > 0, 1);
PlotAesthetics.onMenuGoto(findobj(PlotAesthetics.menuOf(C.Handles{k}(1)).Children, 'Tag', PlotAesthetics.GotoTag), []);
got = getappdata(0, 'aestheticsGoto');
check(numel(got) == 2 && got{1} == C.Role(k) && got{2} == C.TileName(k), 'it reports the part''s role and its panel''s id');
k = find(C.Role ~= "" & C.Tile == 0, 1);
PlotAesthetics.onMenuGoto(findobj(PlotAesthetics.menuOf(C.Handles{k}(1)).Children, 'Tag', PlotAesthetics.GotoTag), []);
got = getappdata(0, 'aestheticsGoto');
check(~isempty(k) && got{1} == C.Role(k) && got{2} == "", 'the figure''s own parts have no panel');
if isappdata(0, 'aestheticsGoto'); rmappdata(0, 'aestheticsGoto'); end
rx = figureRoleSettings("xlabel");
ry = figureRoleSettings("ylabel");
check(rx(1) == "panelXLabel" && ry(1) == "panelYLabel", 'Go to setting on an x or y label: the panel''s X axis or Y axis row first');

% a panel's x and y labels: "Edit label text..." and "Move to ..." in their menus, through OnAxisEdit
setappdata(0, 'aestheticsAxis', {});
h = renderFigure(Cp.F, Cp.spec, fig, Editable=true, OnAxisEdit=@(panel, change) setappdata(0, 'aestheticsAxis', {panel, change}));
C = PlotAesthetics.components(h.layout);
kx = find(C.Role == "xlabel" & C.Tile > 0, 1);
ky = find(C.Role == "ylabel" & C.Tile > 0, 1);
itemsOf = @(C, k) string({PlotAesthetics.menuOf(C.Handles{k}(1)).Children.Text});   % (C given: a handle captures it when made)
check(~isempty(kx) && ~isempty(ky) && all(ismember(["Edit label text..." "Move to top"], itemsOf(C, kx))) ...
    && all(ismember(["Edit label text..." "Move to right"], itemsOf(C, ky))) && ~any(ismember("Move to right", itemsOf(C, kx))), ...
    'an x label''s menu edits its text and moves it to the top; a y label''s to the right');
check(all(ismember(["Move every panel's X axis to top"], itemsOf(C, kx))) && all(ismember(["Move every panel's Y axis to right"], itemsOf(C, ky))), ...
    'a label''s menu also moves that axis of every panel');
k = find(~ismember(C.Role, ["" "axes" "rasterAxes" "xlabel" "ylabel" "ylabelRight" "tileTitle" "tileSubtitle" "legend" "colorbar"]) ...
    & C.Tile > 0, 1);   % a line, band or tick drawn in a panel
check(~isempty(k) && ~any(startsWith(itemsOf(C, k), ["Edit label text" "Edit X label" "Move "])), 'a data part has no axis items');
ka = find(C.Role == "axes" & C.Tile > 0, 1);
check(~isempty(ka) && all(ismember(["Edit X label text..." "Edit Y label text..." "Move X axis to top" "Move Y axis to right" ...
    "Move every panel's X axis to top" "Move every panel's Y axis to right" "Edit aesthetics..."], itemsOf(C, ka))) ...
    && ~any(ismember(["Edit label text..." "Move to top"], itemsOf(C, ka))), ...
    'a panel''s axes: both labels'' text, both sides, the every-panel moves, beside its aesthetics');
PlotAesthetics.onMenuSide(findobj(PlotAesthetics.menuOf(C.Handles{kx}(1)).Children, 'Text', 'Move to top'), []);
got = getappdata(0, 'aestheticsAxis');
check(numel(got) == 2 && got{1} == C.TileName(kx) && isequal(got{2}, struct('xSide', "top")), ...
    '"Move to top" hands OnAxisEdit the label''s panel and its new xSide');
PlotAesthetics.onMenuSide(findobj(PlotAesthetics.menuOf(C.Handles{ka}(1)).Children, 'Text', 'Move Y axis to right'), []);
got = getappdata(0, 'aestheticsAxis');
check(numel(got) == 2 && got{1} == C.TileName(ka) && isequal(got{2}, struct('ySide', "right")), ...
    '"Move Y axis to right" on the axes hands OnAxisEdit the axes'' panel and its new ySide');
PlotAesthetics.onMenuSideAll(findobj(PlotAesthetics.menuOf(C.Handles{ka}(1)).Children, 'Text', "Move every panel's X axis to top"), []);
got = getappdata(0, 'aestheticsAxis');
check(numel(got) == 2 && isequal(got{1}, [Cp.spec.panels.id]) && isequal(got{2}, struct('xSide', "top")), ...
    '"Move every panel''s X axis to top" hands OnAxisEdit every panel of the figure at once');
PlotAesthetics.axisEdit(C.Handles{ky}(1), struct('yLabel', "Spikes"));
got = getappdata(0, 'aestheticsAxis');
check(numel(got) == 2 && got{1} == C.TileName(ky) && isequal(got{2}, struct('yLabel', "Spikes")), ...
    'a label''s new text goes to OnAxisEdit for its own panel');
if isappdata(0, 'aestheticsAxis'); rmappdata(0, 'aestheticsAxis'); end
h = renderFigure(Cp.F, Cp.spec, fig, Editable=true);   % no OnAxisEdit: the figure is drawn again here with the change
C = PlotAesthetics.components(h.layout);
ky = find(C.Role == "ylabel" & C.Tile > 0, 1);
pid = C.TileName(ky);
PlotAesthetics.onMenuSide(findobj(PlotAesthetics.menuOf(C.Handles{ky}(1)).Children, 'Text', 'Move to right'), []);
PlotAesthetics.axisEdit(findTile(fig, pid).YLabel, struct('yLabel', "Spikes"));
ax = findTile(fig, pid);
m = string({PlotAesthetics.menuOf(ax.YLabel).Children.Text});
check(strcmp(ax.YAxisLocation, 'right') && string(ax.YLabel.String) == "Spikes" && ismember("Move to left", m), ...
    'without OnAxisEdit the figure is drawn again with each change; the moved label''s menu offers the way back');
Cs = byId("psth_stack");
h = renderFigure(Cs.F, Cs.spec, fig, Editable=true);
C = PlotAesthetics.components(h.layout);
ky = [];
tr = C.Tile(find(C.Role == "ylabelRight" & C.Tile > 0, 1));   % the stacked PSTH's tile: its right axis names the peaks
if ~isempty(tr); ky = find(C.Role == "ylabel" & C.Tile == tr, 1); end
check(~isempty(ky) && ~any(startsWith(itemsOf(C, ky), "Move to")) && ismember("Edit label text...", itemsOf(C, ky)), ...
    'a stacked PSTH''s y label (a y axis each side) has no side to move to');

% every panel type with its axes on the other sides and labels of its own
moved = true; why = strings(0, 1);
for i = 1:numel(cases)
    s = cases(i).spec;
    [s.panels.xSide] = deal("top");
    [s.panels.ySide] = deal("right");
    [s.panels.xLabel] = deal("The x");
    [s.panels.yLabel] = deal("The y");
    try
        h = renderFigure(cases(i).F, s, fig, UserAesthetics=false);
        drawnow;
        for q = 1:numel(h.panels)
            A = [h.panels(q).axes reshape(h.panels(q).extraAxes, 1, [])];
            if isempty(A); continue; end
            lab = strjoin(string(A(1).XLabel.String), "");
            bad = ~strcmp(A(1).XAxisLocation, 'top') || string(A(1).YAxis(1).Label.String) ~= "The y" ...
                || any(arrayfun(@(a) isscalar(a.YAxis) && ~strcmp(a.YAxisLocation, 'right'), A)) ...
                || ~(lab == "The x" || (s.panels(q).sharesTime && lab == "")) ...
                || any(arrayfun(@(a) ~isempty(a.Colorbar) && string(a.Colorbar.Location) == "eastoutside", A)) ...
                || (numel(A) > 1 && ~isempty(A(end).XTickLabel));
            if bad
                moved = false;
                why(end+1) = cases(i).id + "." + h.panels(q).id; %#ok<AGROW>
            end
        end
        Cm = PlotAesthetics.components(h.layout);
        if any(Cm.Role == "" | ~ismember(Cm.Role, roles))
            moved = false;
            why(end+1) = cases(i).id + ": untagged"; %#ok<AGROW>
        end
    catch ME
        moved = false;
        why(end+1) = cases(i).id + ": " + ME.message; %#ok<AGROW>
    end
end
check(moved, "every panel type takes its x axis on top, its y axis on the right (a yyaxis keeps both), its own " + ...
    "labels (a time stack's inner ones dropped) and its color bar out of their way" + ...
    ifText(~moved, ": " + strjoin(why, "; ")));
R = PlotAesthetics.roles().Role;
check(all(arrayfun(@(r) ~isempty(figureRoleSettings(r)), R)) && isequal(figureRoleSettings("nonsense"), "@style"), ...
    'every role has settings to go to; an unknown one goes to Appearance');

fprintf('\n== 5. the editor: live edits, Apply to, Reset, Cancel ==\n');
fig2 = figure('Visible', 'off', 'Position', [100 100 700 800]);
spec2 = Cp.spec;
spec2.panels(2).options.histStyle = "line";
spec2.panels(2).options.fill = false;
h = renderFigure(Cp.F, spec2, fig2, Editable=true, OnRemember=@(r) setappdata(0, 'aestheticsGot', r));
ctx = getappdata(fig2, PlotAesthetics.ContextKey);
C = PlotAesthetics.components(h.layout);
rows1 = find(C.Role == "rate" & C.Group == groups(1));
rows2 = find(C.Role == "rate" & C.Group == groups(2));
line1 = C.Handles{rows1(1)};
other = C.Handles{rows2(1)};
lw0 = line1(1).LineWidth;
d = PlotAestheticsDialog(ctx, line1(1), Visible=false);
check(d.Selected == rows1(1) && d.Components.Role(d.Selected) == "rate", 'it opens on the component clicked');
d.setProperty("LineWidth", 4);
check(line1(1).LineWidth == 4 && other(1).LineWidth == lw0, 'Apply to "this one": only that line changes, at once');
d.setApplyTo("role");
check(other(1).LineWidth == 4, 'Apply to "role": every group too');
d.setApplyTo("one");
check(line1(1).LineWidth == 4 && other(1).LineWidth == lw0, 'back to "this one": the others are put back');
d.setProperty("Color", "#00FF00");
check(isequal(line1(1).Color, [0 1 0]), 'a color typed as #rrggbb');
ax1 = find(C.Role == "axes" | C.Role == "rasterAxes", 2);
d.select(ax1(1));
d.setProperty("FontSize", 15);
check(C.Handles{ax1(1)}.FontSize == 15 && line1(1).LineWidth == 4, 'selecting another component keeps the earlier edit');
d.tick(ax1, true);
check(d.ApplyTo == "ticked" && C.Handles{ax1(2)}.FontSize == 15, 'ticking rows switches Apply to to them');
d.tickLike("none");
check(d.ApplyTo == "one" && C.Handles{ax1(2)}.FontSize ~= 15, 'unticking all goes back to this one');
d.reset();
check(line1(1).LineWidth == lw0 && ~isequal(line1(1).Color, [0 1 0]) && C.Handles{ax1(1)}.FontSize ~= 15, 'Reset puts everything back');
d.select(rows1(1));
d.setProperty("LineWidth", 6);
d.cancel();
check(line1(1).LineWidth == lw0 && ~isvalid(d.Fig), 'Cancel puts it back and closes');

% the list sorts by its headers and filters by tile title, component and type; hidden rows keep their ticks
d = PlotAestheticsDialog(ctx, line1(1), Visible=false);
lists = findall(d.Fig, 'Type', 'uitable');
lst = lists(arrayfun(@(t) iscell(t.ColumnName) && numel(t.ColumnName) == 4 && string(t.ColumnName{2}) == "Tile", lists));
words = findall(d.Fig, 'Type', 'uieditfield');
words = words(arrayfun(@(e) startsWith(string(e.Placeholder), "Filter"), words));
drops = findall(d.Fig, 'Type', 'uidropdown');
typeDrop = drops(arrayfun(@(x) string(x.Items{1}) == "All types", drops));
allRows = height(d.Components);
check(isscalar(lst) && all(lst.ColumnSortable) && height(lst.Data) == allRows, 'the list is sortable by every column and shows every component');
typ = d.Components.Type(d.Selected);
typeDrop.Value = char(typ);
typeDrop.ValueChangedFcn(typeDrop, []);
check(height(lst.Data) == nnz(d.Components.Type == typ) && all(string(lst.Data.Type) == typ), 'the type filter keeps the components of that type');
lst.CellEditCallback(lst, struct('Indices', [1 1], 'NewData', true));
shownFirst = find(d.Components.Type == typ, 1);
check(d.Ticked(shownFirst) && nnz(d.Ticked) == 1, 'a tick in the filtered list lands on its own component');
typeDrop.Value = '';
typeDrop.ValueChangedFcn(typeDrop, []);
words.Value = char(lower(d.Components.Label(d.Selected)));
words.ValueChangedFcn(words, []);
check(height(lst.Data) >= 1 && height(lst.Data) < allRows && all(contains(lower(string(lst.Data.Component)), lower(d.Components.Label(d.Selected)))), 'the text filter keeps the components whose label has it');
words.Value = '';
words.ValueChangedFcn(words, []);
check(height(lst.Data) == allRows && nnz(lst.Data.Tick) == 1 && lst.Data.Tick(shownFirst), 'with the filters cleared every component is back, the tick kept');
d.cancel();

fprintf('\n== 6. the editor: OK, Remember, Forget ==\n');
d = PlotAestheticsDialog(ctx, line1(1), Visible=false);
d.setApplyTo("same");
d.setProperty("LineWidth", 3);
d.setRemember(true, "plot");
setappdata(0, 'aestheticsGot', []);
d.ok();
got = getappdata(0, 'aestheticsGot');
check(isstruct(got) && isscalar(got) && got.role == "rate" && got.group == groups(1) && got.property == "LineWidth" && got.value == 3, ...
    'OK with Remember for this figure: one rule (role, group) goes to OnRemember');
ctx = getappdata(fig2, PlotAesthetics.ContextKey);
C = PlotAesthetics.components(ctx.root);
lws = arrayfun(@(r) C.Handles{r}(1).LineWidth, find(C.Role == "rate" & C.Group == groups(1)));
check(~isvalid(h.axes(1)) && all(lws == 3) && numel(ctx.plotRules) == 1, ...
    'the figure is redrawn with its new rule, and the context knows it');
d = PlotAestheticsDialog(ctx, C.Handles{find(C.Role == "sem", 1)}, Visible=false);
d.setApplyTo("role");
d.setProperty("FaceAlpha", 0.3);
d.setRemember(true, "user");
d.ok();
U = PlotAesthetics.userRules("figure");
check(isscalar(U) && U.role == "sem" && U.group == "" && U.property == "FaceAlpha" && U.value == 0.3, ...
    'OK with Remember for every figure: a rule for every group in the preferences ("figure")');
f3 = figure('Visible', 'off');
h3 = renderFigure(Cp.F, Cp.spec, f3);
C3 = PlotAesthetics.components(h3.layout);
check(any(C3.Role == "sem") && all(arrayfun(@(i) all([C3.Handles{i}.FaceAlpha] == 0.3), find(C3.Role == "sem"))), 'the next figure is drawn that way');
ctx = getappdata(fig2, PlotAesthetics.ContextKey);
d = PlotAestheticsDialog(ctx, [], Visible=false);
Tr = d.remembered();
check(height(Tr) == 2 && Tr.KeptFor(1) == "This figure" && Tr.KeptFor(2) == "My figures" && startsWith(string(d.Fig.Name), "Figure aesthetics"), ...
    'the Remembered tab lists the figure''s ("This figure") and the user''s rules ("My figures"); the dialog is "Figure aesthetics"');
C = PlotAesthetics.components(ctx.root);
d.select(find(C.Role == "axes", 1));
d.setProperty("Color", [1 1 0.8]);
d.forget(1:2);
d.setRemember(false);
setappdata(0, 'aestheticsGot', 'unset');
d.ok();
got = getappdata(0, 'aestheticsGot');
ctx = getappdata(fig2, PlotAesthetics.ContextKey);
C = PlotAesthetics.components(ctx.root);
lws = arrayfun(@(r) C.Handles{r}(1).LineWidth, find(C.Role == "rate" & C.Group == groups(1)));
ax1 = C.Handles{find(C.Role == "axes", 1)};
check(isstruct(got) && isempty(got) && isempty(PlotAesthetics.userRules("figure")) && all(lws == lw0), ...
    'Forget: both rules gone (OnRemember gets none; the preference is removed) and the figure redrawn without them');
check(isequal(ax1.Color, [1 1 0.8]), 'an edit not remembered is put back on the redrawn figure');
ctxNo = ctx; ctxNo.onRemember = [];
d = PlotAestheticsDialog(ctxNo, [], Visible=false);
check(d.Scope == "user" && strcmp(errorId(@() d.setRemember(true, "plot")), 'PlotAesthetics:BadScope'), ...
    'a figure outside a config can only be remembered for the user');
d.cancel();

fprintf('\n== 7. the config and the generated script ==\n');
rules = [struct('role', "rate", 'group', "Depth = 0", 'property', "Color", 'value', [0.2 0.4 0.6]) ...
    struct('role', "plotTitle", 'group', "", 'property', "FontWeight", 'value', "bold")];
cfg = EphysAnalysisConfig();
cfg = cfg.addFigure(struct('id', "look", 'aesthetics', rules));
f = string(tempname) + ".json";
cfg.save(f);
back = EphysAnalysisConfig.load(f);
delete(f);
p = back.Figures(back.figureIndex("look"));
check(numel(p.aesthetics) == 2 && isequal(p.aesthetics(1).value, [0.2 0.4 0.6]) && p.aesthetics(2).value == "bold" ...
    && back.isequalConfig(cfg), 'a figure''s aesthetics survive the JSON file');
check(strcmp(errorId(@() cfg.addFigure(struct('aesthetics', struct('role', "rate", 'property', "Nope", 'value', 1)))), ...
    'EphysAnalysisConfig:BadValue'), 'a rule with an unknown property is refused (EphysAnalysisConfig:BadValue)');
check(isempty(EphysAnalysisConfig.defaults("Figure").aesthetics), 'a new figure has no rules');
lit = EphysPipelineScript.literal(p.aesthetics);
again = eval(lit);
lit0 = EphysPipelineScript.literal(PlotAesthetics.emptyRules());
none = eval(lit0);
check(isequaln(again, p.aesthetics) && isempty(none) && isfield(none, 'property'), 'the script literal of a rule list (and of none) evaluates back');
L = EphysPipelineScript.structLiteral("spec", cfg.figureFor("look"));
spec = struct(); %#ok<NASGU>
eval(strjoin(L, newline));
check(isequaln(spec.aesthetics, p.aesthetics), 'a figure spec written out in full keeps its rules');

close([fig fig2 f3]);
fx.src.outputs.clearCache();
fprintf('\n%d passed, %d failed\n', nPass, nFail);
if nFail > 0
    error('test_PlotAesthetics:Failed', '%d check(s) failed.', nFail);
end
end


function c = faces(p)
%faces  The fill color shared by patches P ([] when they differ).
c = p(1).FaceColor;
for k = 2:numel(p)
    if ~isequal(p(k).FaceColor, c); c = []; return; end
end
end


function s = ifText(c, s)
if ~c; s = ""; end
end


function ax = findTile(fig, panel)
%findTile  The axes of panel PANEL in the figure renderFigure last drew into FIG (its tagged tile).
ctx = getappdata(fig, PlotAesthetics.ContextKey);
C = PlotAesthetics.components(ctx.root);
k = find(ismember(C.Role, ["axes" "rasterAxes"]) & C.TileName == panel, 1);
ax = C.Handles{k}(1);
end


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
