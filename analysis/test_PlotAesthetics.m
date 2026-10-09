function test_PlotAesthetics()
%test_PlotAesthetics  Verification suite for remembered plot aesthetics and their editor.
%   No recording is needed: seeded Poisson spike trains make PSTH, rate,
%   tuning, heatmap, correlation and probe-map results. Checks the rules
%   (normalizeRules, mergeRules, colours as text), that every renderer
%   tags everything it draws (no component without a role), that renderPlot
%   applies the user's rules and then the plot's (and UserAesthetics=false
%   skips the user's), the right-click menu (only in a visible figure, or
%   with Editable=true), the editor (PlotAestheticsDialog: live edits, Apply
%   to one / same / role / ticked, Reset, Cancel, OK remembering for the
%   plot or the user, forgetting, edits put back after a redraw), the
%   config's aesthetics field (JSON round trip, a bad property refused) and
%   the generated script's literal for a list of rules. The preferences
%   are a temporary store (AppPrefs.useTemporary).
%
%   Usage:  test_PlotAesthetics

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU>

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

rng(11, 'twister');
nE = 60;
t0 = (10:4:10 + 4 * (nE - 1)).';
g = 1 + mod((1:nE).', 3);
E = table((1:nE).', NaN(nE, 1), t0, t0, t0 + 0.3, t0 - 0.2, t0 + 0.5, repmat(0.7, nE, 1), true(nE, 1), false(nE, 1), g, "group " + g, ...
    'VariableNames', {'epoch', 'trial', 't0', 't0Continuous', 't1', 'tStart', 'tStop', 'duration', 'complete', 'artifact', 'groupIndex', 'group'});
E.Properties.UserData = struct('ref', eventRef(line="Stim"), 'window', epochWindow(pre=-0.2, post=0.5), ...
    'selection', trialSelection(), 'scope', "trial", 'nTrials', nE);
G = table((1:3).', ["Depth = 0"; "Depth = 0.5"; "Depth = 1"], [0 0 0.5; 0 0.5 0; 0.5 0 0], [0; 0; 0], ...
    'VariableNames', {'index', 'label', 'color', 'n'});
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
Rr = firingRate(trains, E, Groups=G, Meta=meta);
Rt = tuningCurve(Rr.rate, mod((1:nE).', 4), Param="Depth", Meta=meta);
Rc = unitCorrelation(trains, E, Groups=G, Meta=meta);
Rc.epochs = E; Rc.dataset = "synthetic";
probe = struct('chanMap', 0:7, 'xc', [0 8 0 8 200 208 200 208], 'yc', [0 25 50 75 0 25 50 75], 'kcoords', [0 0 0 0 1 1 1 1]);
Tu = table(["u1"; "u2"; "u3"], ["su"; "mua"; "su"], [1; 5; 3], [0; 1; 0], [0; 200; 0], [0; 0; 50], [10; 20; 30], [1; 2; 3], ...
    'VariableNames', {'label', 'class', 'channel', 'shank', 'x', 'y', 'nSpikes', 'rateHz'});
Rq = probeMapValues(Tu, probe, Value="rate");
Y = randn(800, 3, 'single');
Ev = E(1:6, :); Ev.t0 = (0.2:0.1:0.7).'; Ev.t0Continuous = Ev.t0; Ev.groupIndex = [1; 2; 3; 1; 2; 3];
Rv = evokedPotential(Y, 1000, Ev, Window=[-0.1 0.1], Groups=G);
Rv.meta = table(["c1"; "c2"; "c3"], [1; 2; 3], [0; 0; 0], [0; 0; 0], [0; 25; 50], 'VariableNames', {'label', 'channel', 'shank', 'x', 'y'});

fprintf('\n== 1. rules ==\n');
r1 = struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2);
J = jsondecode(jsonencode([r1 struct('role', "sem", 'group', "Depth = 1", 'property', "FaceColor", 'value', [1 0 0])]));
R = PlotAesthetics.normalizeRules(J);
check(numel(R) == 2 && isequal(R(2).value, [1 0 0]) && R(2).group == "Depth = 1" && isstring(R(1).role), ...
    'normalizeRules: decoded JSON (a colour column) becomes rows of string fields and a row colour');
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
check(PlotAesthetics.valueText([1 0 0]) == "#FF0000" && PlotAesthetics.valueText(2.5) == "2.5", 'valueText: colours as hex');

tms = linspace(-0.6, 1.4, 61).';                    % unit waveforms (unitWaveforms' shape): spikes, spikes, a template, none
shape = -exp(-(tms / 0.15).^2) + 0.4 * exp(-((tms - 0.5) / 0.3).^2);
Wv = struct('timeMs', {repmat({tms}, 4, 1)}, 'mean', {cell(4, 1)}, 'spikes', {cell(4, 1)}, ...
    'from', ["spikes"; "spikes"; "template"; "none"], 'units', ["uV"; "uV"; "uV"; ""], 'note', "", 'maxSpikes', 20);
for u = 1:2
    Wv.spikes{u} = 80 * u * shape + 10 * randn(61, 20);
    Wv.mean{u} = mean(Wv.spikes{u}, 2);
end
Wv.mean{3} = 60 * shape;
Rpw = Rp; Rpw.waveforms = Wv;
Rtw = Rt; Rtw.waveforms = Wv;
Rwf = struct('kind', "waveforms", 'meta', meta, 'labels', meta.label, 'n', height(meta), 'probe', probe, 'waveforms', Wv, ...
    'groups', table(1, "all", [0.15 0.15 0.15], height(meta), 'VariableNames', {'index', 'label', 'color', 'n'}));   % the waveforms plot's result
Rpm = Rp;   % a raster with event marks (epochEvents' shape): two per epoch of a line's onsets
Rpm.rasterEvents = struct('line', "Beam", 'edge', "onset", 'label', "Beam onset", ...
    'epoch', repelem((1:nE).', 2), 't', repmat([0.1; 0.3], nE, 1));
yb = 300 + 80 * randn(nE, 1);
yb(1:5:end) = NaN;
Rb = behaviorValues(yb, mod((1:nE).', 3), Series=mod((1:nE).', 2), Param="Depth", SeriesParam="TrialType", YName="RespLatency");

fprintf('\n== 2. every renderer names what it draws ==\n');
ovs = repmat(EphysAnalysisConfig.defaults("Overlay"), 1, 4);   % a line at x, one at y under the data, a patch in x, one in y under the data
ovs(1).name = "Stim";
ovs(2).name = "Level"; ovs(2).axis = "y"; ovs(2).value = 1; ovs(2).layer = "under";
ovs(3).name = "Window"; ovs(3).shape = "region"; ovs(3).from = 0.05; ovs(3).to = 0.15;
ovs(4).name = "Band"; ovs(4).shape = "region"; ovs(4).axis = "y"; ovs(4).from = 0; ovs(4).to = 1; ovs(4).layer = "under";
cases = {
    "psth grid + raster", "psth",    struct('kind', "psth")
    "psth line, no fill", "psth",    struct('kind', "psth", 'histStyle', "line", 'fill', false)
    "psth stack",         "psth",    struct('kind', "psth", 'stack', true)
    "psth overlay",       "psth",    struct('kind', "psth", 'layout', "overlay")
    "raster",             "psth",    struct('kind', "raster")
    "rate bar",           "rate",    struct('kind', "rate", 'layout', "bar")
    "rate box",           "rate",    struct('kind', "rate", 'layout', "box")
    "rate points",        "rate",    struct('kind', "rate", 'layout', "points")
    "tuning",             "tuning",  struct('kind', "tuning")
    "heatmap",            "psth",    struct('kind', "heatmap")
    "corrmap",            "corrmap", struct('kind', "corrmap")
    "probemap",           "probemap", struct('kind', "probemap")
    "evoked stack",       "evoked",  struct('kind', "evoked", 'layout', "stack", 'source', "LFP")
    "evoked butterfly",   "evoked",  struct('kind', "evoked", 'layout', "butterfly", 'source', "LFP")
    "evoked grid",        "evoked",  struct('kind', "evoked", 'layout', "grid", 'source', "LFP")
    "psth + waveforms",   "psthW",   struct('kind', "psth", 'waveform', struct('mode', "both"))
    "raster + waveforms", "psthW",   struct('kind', "raster", 'waveform', struct('mode', "subsample", 'box', false))
    "tuning + waveforms", "tuningW", struct('kind', "tuning", 'waveform', struct('mode', "mean", 'location', "southwest"))
    "waveforms grid",     "waveforms", struct('kind', "waveforms", 'waveform', struct('mode', "both", 'showCount', true))
    "waveforms common",   "waveforms", struct('kind', "waveforms", 'waveform', struct('mode', "mean", 'ampScale', "common"))
    "waveforms probe",    "waveforms", struct('kind', "waveforms", 'layout', "probe", 'waveform', struct('mode', "both", 'showNames', true))
    "waveforms probe common", "waveforms", struct('kind', "waveforms", 'layout', "probe", 'waveform', struct('mode', "both", 'ampScale', "common"))
    "raster + marks",     "psthM",   struct('kind', "raster", 'rasterByGroup', false)
    "psth + marks",       "psthM",   struct('kind', "psth")
    "behavior points",    "behavior", struct('kind', "behavior")
    "behavior line",      "behavior", struct('kind', "behavior", 'layout', "line")
    "behavior box",       "behavior", struct('kind', "behavior", 'layout', "box")
    "behavior swarm",     "behavior", struct('kind', "behavior", 'layout', "swarm")
    "psth + overlays",    "psth",    struct('kind', "psth", 'overlays', ovs)
    "psth stack + overlays", "psth", struct('kind', "psth", 'stack', true, 'overlays', ovs)
    "raster + overlays",  "psthM",   struct('kind', "raster", 'overlays', ovs)
    "rate bar + overlays", "rate",   struct('kind', "rate", 'layout', "bar", 'overlays', ovs)
    "tuning + overlays",  "tuning",  struct('kind', "tuning", 'overlays', ovs)
    "heatmap + overlays", "psth",    struct('kind', "heatmap", 'overlays', ovs)
    "corrmap + overlays", "corrmap", struct('kind', "corrmap", 'overlays', ovs)
    "probemap + overlays", "probemap", struct('kind', "probemap", 'overlays', ovs)
    "evoked grid + overlays", "evoked", struct('kind', "evoked", 'layout', "grid", 'source', "LFP", 'overlays', ovs)
    "behavior + overlays", "behavior", struct('kind', "behavior", 'overlays', ovs)
    "waveforms probe + overlays", "waveforms", struct('kind', "waveforms", 'layout', "probe", 'waveform', struct('mode', "both"), 'overlays', ovs)};
if exist('violinplot', 'file')   % MATLAB R2024b or later
    cases(end+1, :) = {"behavior violin", "behavior", struct('kind', "behavior", 'layout', "violin")};
end
results = struct('psth', Rp, 'rate', Rr, 'tuning', Rt, 'corrmap', Rc, 'probemap', Rq, 'evoked', Rv, 'psthW', Rpw, 'tuningW', Rtw, ...
    'psthM', Rpm, 'behavior', Rb, 'waveforms', Rwf);
fig = figure('Visible', 'off');
allTagged = true; untagged = strings(0, 1);
for i = 1:size(cases, 1)
    h = renderPlot(results.(cases{i, 2}), cases{i, 3}, fig);
    C = PlotAesthetics.components(h.layout);
    bad = C.Role == "";
    if any(bad)
        allTagged = false;
        untagged(end+1) = cases{i, 1} + ": " + strjoin(C.Type(bad), ", "); %#ok<AGROW>
    end
    known = all(ismember(C.Role, PlotAesthetics.roles().Role));
    allTagged = allTagged && known;
end
check(allTagged, "every component of every kind and layout has a known role" + ifText(~allTagged, " (" + strjoin(untagged, "; ") + ")"));
h = renderPlot(Rpw, struct('kind', "psth", 'waveform', struct('mode', "both")), fig);
C = PlotAesthetics.components(h.layout);
lg = findobj(fig, 'Type', 'legend');
check(all(ismember(["waveBox" "waveSpikes" "waveMean" "waveLabel"], C.Role)) && ~isempty(lg) && numel(lg(1).String) == 3, ...
    'the waveform boxes'' parts are components the editor lists, and stay out of the legend');
note = struct('text', "Condition A" + newline + "n = 12", 'placement', "below", 'bold', true, 'italic', true, 'fontSize', 14, ...
    'color', "#CC0000", 'fontName', "Courier New", 'background', "yellow", 'box', true);
h = renderPlot(Rp, struct('kind', "psth", 'note', note), fig);
C = PlotAesthetics.components(h.layout);
tx = findall(fig, 'Type', 'text', 'Tag', 'note');
check(isscalar(tx) && isequal(h.note, tx) && sum(C.Role == "note") == 1 && C.Tile(C.Role == "note") == 0 ...
    && isscalar(findall(fig, 'Tag', 'noteHost')) && all(ismember(C.Role, PlotAesthetics.roles().Role)) && ~any(C.Role == ""), ...
    'a note is one text of role "note", drawn in a hidden axes beside the layout; the editor lists it as part of the plot');
check(numel(tx.String) == 2 && tx.FontWeight == "bold" && tx.FontAngle == "italic" && tx.FontSize == 14 && tx.FontName == "Courier New" ...
    && max(abs(tx.Color - [0.8 0 0])) < 1e-9 && isequal(tx.BackgroundColor, [1 1 0]) && isequal(tx.EdgeColor, tx.Color), ...
    'the note''s lines, bold, italic, size, font, colour, ground and outline are drawn');
op = h.layout.OuterPosition;
check(op(2) > 0 && op(2) < 0.25 && abs(op(2) + op(4) - 1) < 1e-9 && op(1) == 0 && op(3) == 1, ...
    'below the plot, the layout gives up a band at the bottom for the note');
nt = findall(fig, 'Type', 'text', 'Tag', 'note');
pos = nt.Position;
check(pos(1) < 0.1 && pos(2) > 0 && pos(2) < op(2) && nt.HorizontalAlignment == "left", ...
    'a left-aligned note below the plot sits at the left, in the band');
for pl = ["above" "left" "right"]
    n2 = note; n2.placement = pl;
    h = renderPlot(Rp, struct('kind', "psth", 'note', n2), fig);
    o2 = h.layout.OuterPosition;
    switch pl
        case "above", okp = o2(2) == 0 && o2(4) < 1;
        case "left",  okp = o2(1) > 0 && o2(3) < 1 && o2(2) == 0;
        case "right", okp = o2(1) == 0 && o2(3) < 1;
    end
    if ~okp; break; end
end
check(okp, 'above, left and right of the plot, the layout gives up that side');
n2 = note; n2.placement = "northeast"; n2.align = "right"; n2.valign = "top";
h = renderPlot(Rp, struct('kind', "psth", 'note', n2), fig);
check(isequal(h.layout.OuterPosition, [0 0 1 1]), 'over the plot, the layout keeps all its room');
n2 = note; n2.placement = "custom"; n2.x = 0.25; n2.y = 0.75; n2.align = "center"; n2.valign = "top";
h = renderPlot(Rp, struct('kind', "psth", 'note', n2), fig);
check(isequal(h.note.Position(1:2), [0.25 0.75]) && h.note.HorizontalAlignment == "center" && h.note.VerticalAlignment == "top", ...
    'a custom note''s anchor is at x, y of the plot, with its alignment');
n3 = struct('text', "plain");
h = renderPlot(Rp, struct('kind', "psth", 'note', n3), fig, Design="Night");
check(max(abs(h.note.Color - [216 222 233] / 255)) < 1e-9, 'a note without a colour takes its design''s text colour');
h = renderPlot(Rp, struct('kind', "psth", 'note', struct('text', "plain", 'color', "red")), fig, Design="Night");
check(isequal(h.note.Color, [1 0 0]), 'a note''s own colour wins over its design''s');
h = renderPlot(Rp, struct('kind', "psth", 'note', struct('text', "plain", 'color', "red"), ...
    'aesthetics', struct('role', "note", 'group', "", 'property', "Color", 'value', [0 0 1])), fig);
check(isequal(h.note.Color, [0 0 1]), 'the plot''s own aesthetics rule for the note wins over the note''s colour');
h = renderPlot(Rp, struct('kind', "psth", 'note', struct('text', "x", 'placement', "below")), fig);
h = renderPlot(Rp, struct('kind', "psth"), h.layout);
check(isequal(h.layout.OuterPosition, [0 0 1 1]) && isempty(h.note) && isempty(findall(fig, 'Tag', 'noteHost')) ...
    && isempty(findall(fig, 'Tag', 'note')), 'drawing the layout again without a note takes the old note and its band away');
h = renderPlot(Rp, struct('kind', "psth", 'note', struct('text', "   ")), fig);
check(isempty(h.note) && isempty(findall(fig, 'Tag', 'noteHost')), 'a note of blanks draws nothing');

fprintf('\n== 2b. overlays: lines and patches on the axes ==\n');
ovL = EphysAnalysisConfig.defaults("Overlay"); ovL.name = "Stim"; ovL.value = 0.1;
h = renderPlot(Rp, struct('kind', "psth", 'overlays', ovL), fig);
g = h.overlays;
perAxes = arrayfun(@(a) numel(findall(a, 'Tag', 'overlayLine')), [h.axes h.rasterAxes]);
check(numel(h.axes) == 4 && numel(h.rasterAxes) == 4 && numel(g) == 8 && all(perAxes == 1) ...
    && all(arrayfun(@(x) isa(x, 'matlab.graphics.chart.decoration.ConstantLine'), g)) && all([g.Value] == 0.1) ...
    && all(arrayfun(@(x) string(getappdata(x, 'PlotGroup')) == "Stim", g)), ...
    'an overlay line is drawn once in every rate and raster panel of a PSTH grid, at its value, named by its group');
check(max(abs(g(1).Color - validatecolor("#d62728"))) < 1e-6 && string(g(1).LineStyle) == "--" && g(1).LineWidth == 1.5 && g(1).Alpha == 1, ...
    'a default overlay is a dashed red line, 1.5 points wide, opaque');
for pn = ["data" "raster"]
    o2 = ovL; o2.panel = pn;
    h = renderPlot(Rp, struct('kind', "psth", 'overlays', o2), fig);
    want = ifText(pn == "data", "axes") + ifText(pn == "raster", "rasterAxes");
    okp = numel(h.overlays) == 4 && all(arrayfun(@(x) string(x.Parent.Tag) == want, h.overlays));
    if ~okp; break; end
end
check(okp, 'the panel picks the axes: the data panels, or the rasters above them');
o2 = ovL; o2.panel = "data";
h = renderPlot(Rpm, struct('kind', "raster", 'overlays', o2), fig);
o3 = ovL; o3.panel = "raster";
h3 = renderPlot(Rpm, struct('kind', "raster", 'overlays', o3), fig);
check(isempty(h.overlays) && numel(h3.overlays) == numel(h3.axes) && numel(h3.axes) > 0, ...
    'a raster plot''s axes are raster panels: a data-panel overlay draws nothing on it, a raster-panel one on every tile');
oy = ovL; oy.name = "Level"; oy.axis = "y"; oy.value = 5; oy.panel = "data";
orx = ovL; orx.name = "Window"; orx.shape = "region"; orx.from = 0.3; orx.to = 0.1; orx.panel = "data";
ory = orx; ory.name = "Band"; ory.axis = "y"; ory.from = 2; ory.to = 4;
h = renderPlot(Rp, struct('kind', "psth", 'overlays', [oy orx ory]), fig);
ln = findall(h.axes(1), 'Tag', 'overlayLine');
rgx = findall(h.axes(1), 'Tag', 'overlayRegion');
isX = arrayfun(@(x) string(getappdata(x, 'PlotGroup')) == "Window", rgx);
check(isscalar(ln) && ln.Value == 5 && (~isprop(ln, 'InterceptAxis') || string(ln.InterceptAxis) == "y") && numel(rgx) == 2 ...
    && all(arrayfun(@(x) isa(x, 'matlab.graphics.chart.decoration.ConstantRegion'), rgx)) ...
    && isequal(rgx(isX).Value, [0.1 0.3]) && isequal(rgx(~isX).Value, [2 4]), ...
    'a horizontal line is at a y value; a patch lies between its two edges, in either order, in x or in y');
check(max(abs(rgx(1).FaceColor - validatecolor("#808080"))) < 1e-6 && rgx(1).FaceAlpha == 0.25 && string(rgx(1).EdgeColor) == "none" ...
    && all(arrayfun(@(x) string(x.PickableParts) == "none", rgx)) && string(ln.PickableParts) ~= "none", ...
    'a default patch is a grey fill at 25 % opacity without an outline, and does not take clicks (a line does)');
o2 = ovL; o2.color = "#336699"; o2.alpha = 0.4; o2.lineStyle = ":"; o2.lineWidth = 3;
p2 = orx; p2.faceColor = "green"; p2.faceAlpha = 0.6; p2.edgeColor = "black"; p2.lineStyle = "-."; p2.lineWidth = 2;
h = renderPlot(Rp, struct('kind', "psth", 'overlays', [o2 p2]), fig);
ln = findall(h.axes(1), 'Tag', 'overlayLine'); rg = findall(h.axes(1), 'Tag', 'overlayRegion');
check(max(abs(ln.Color - [0.2 0.4 0.6])) < 1e-9 && ln.Alpha == 0.4 && string(ln.LineStyle) == ":" && ln.LineWidth == 3 ...
    && max(abs(rg.FaceColor - validatecolor("green"))) < 1e-9 && rg.FaceAlpha == 0.6 && isequal(rg.EdgeColor, [0 0 0]) ...
    && string(rg.LineStyle) == "-." && rg.LineWidth == 2, ...
    'each overlay has its own colour, opacity, line style and width; a patch its fill, fill opacity and outline');
under = ovL; under.name = "Back"; under.layer = "under"; under.panel = "data";
over = ovL; over.name = "Front"; over.value = 0.2; over.panel = "data";
h = renderPlot(Rp, struct('kind', "psth", 'overlays', [under over]), fig);
ax = h.axes(1);
gs = findall(ax, 'Tag', 'overlayLine');
names = arrayfun(@(x) string(getappdata(x, 'PlotGroup')), gs);
kids = allKids(ax);
check(find(kids == gs(names == "Front")) == 1 && find(kids == gs(names == "Back")) == numel(kids) && numel(kids) > 2 ...
    && string(ax.SortMethod) == "childorder", ...
    'an overlay over the data is first in the axes'' draw order, one under it last (the axes draw in child order)');
two = [over over]; two(2).name = "Later"; two(2).value = 0.3;
h = renderPlot(Rp, struct('kind', "psth", 'overlays', two), fig);
ax = h.axes(1); gs = findall(ax, 'Tag', 'overlayLine'); names = arrayfun(@(x) string(getappdata(x, 'PlotGroup')), gs);
kids = allKids(ax);
check(find(kids == gs(names == "Later")) < find(kids == gs(names == "Front")), 'of two overlays over the data, the later one is on top');
h = renderPlot(Rp, struct('kind', "psth"), fig);
check(string(h.axes(1).SortMethod) == "depth" && isempty(h.overlays), 'a plot without overlays keeps its axes'' draw order as it was');
red = [1 0 0];
orr = ovL; orr.color = "red";
D = PlotDesign.none(); D.rules = struct('role', "overlayLine", 'group', "", 'property', "Color", 'value', [0 1 0]);
h = renderPlot(Rp, struct('kind', "psth", 'overlays', orr), fig, Design=D);
c0 = h.overlays(1).Color;
PlotAesthetics.setUserRules("psth", struct('role', "overlayLine", 'group', "", 'property', "Color", 'value', [0 0 1]));
h = renderPlot(Rp, struct('kind', "psth", 'overlays', orr), fig);
c1 = h.overlays(1).Color;
PlotAesthetics.setUserRules("psth", []);
check(isequal(c0, red) && isequal(c1, red), 'an overlay''s own colour wins over its design''s and the user''s rules');
h = renderPlot(Rp, struct('kind', "psth", 'overlays', orr, 'aesthetics', ...
    struct('role', "overlayLine", 'group', "Stim", 'property', "Color", 'value', [0 0 1])), fig);
h2 = renderPlot(Rp, struct('kind', "psth", 'overlays', orr, 'aesthetics', ...
    struct('role', "overlayLine", 'group', "Other", 'property', "Color", 'value', [0 0 1])), fig);
check(isequal(h.overlays(1).Color, [0 0 1]) && isequal(h2.overlays(1).Color, red), ...
    'the plot''s own aesthetics rule for an overlay''s name wins over the overlay''s colour; another name''s does not reach it');
off = ovL; off.enabled = false;
nan = ovL; nan.value = NaN;
same = ovL; same.shape = "region"; same.from = 0.2; same.to = 0.2;
h = renderPlot(Rp, struct('kind', "psth", 'overlays', [off nan same]), fig);
check(isempty(h.overlays) && isempty(findall(fig, 'Tag', 'overlayLine')) && isempty(findall(fig, 'Tag', 'overlayRegion')), ...
    'a disabled overlay, one without a finite position and a patch with equal edges draw nothing');
h = renderPlot(Rp, struct('kind', "psth", 'overlays', struct('value', 0.3)), fig);
check(numel(h.overlays) == 8 && all([h.overlays.Value] == 0.3), 'an overlay given only its position is completed from the defaults');
h = renderPlot(Rp, struct('kind', "psth", 'overlays', ovL), fig);
h = renderPlot(Rp, struct('kind', "psth"), h.layout);
check(isempty(findall(fig, 'Tag', 'overlayLine')), 'drawing the plot again without the overlay takes it away');
h = renderPlot(Rp, struct('kind', "psth", 'stack', true, 'overlays', oy), fig);
ax = h.axes(1);
check(numel(h.overlays) == 4 && numel(ax.YAxis) == 2 && string(ax.YAxisLocation) == "left", ...
    'a y overlay on a stacked PSTH is drawn without leaving the axes on its right-hand side');
h = renderPlot(Rp, struct('kind', "psth", 'overlays', [ovL orx]), fig, Editable=true);
C = PlotAesthetics.components(h.layout);
lbl = C.Label(C.Role == "overlayLine");
check(sum(C.Role == "overlayLine") == 8 && sum(C.Role == "overlayRegion") == 4 && all(ismember(C.Role, PlotAesthetics.roles().Role)) ...
    && ~any(C.Role == "") && all(lbl == "Overlay line · Stim") && any(C.Label == "Overlay region · Window") ...
    && ~isempty(h.overlays(1).ContextMenu), ...
    'the aesthetics editor lists each overlay by its role and name, per tile, with its right-click menu');
P = PlotAesthetics.editableProperties(h.overlays(1));
Q = PlotAesthetics.editableProperties(findall(h.axes(1), 'Tag', 'overlayRegion'));
check(isequal([P.Name], ["Visible" "Color" "Alpha" "LineStyle" "LineWidth"]) ...
    && isequal([Q.Name], ["Visible" "FaceColor" "FaceAlpha" "EdgeColor" "LineStyle" "LineWidth"]), ...
    'the editor offers a line''s colour, opacity, style and width, and a patch''s fill, opacity, outline, style and width');
Dc = PlotDesign.capture(fig);
check(~any(ismember([Dc.rules.role], ["overlayLine" "overlayRegion"])), 'a design saved from a plot leaves its overlays out');
h = renderPlot(Rp, struct('kind', "psth"), fig);
C = PlotAesthetics.components(h.layout);
check(numel(unique(C.Key)) == height(C) && any(C.Role == "plotTitle") && sum(C.Role == "rasterAxes") == 4 ...
    && sum(C.Role == "axes") == 4 && sum(C.Role == "rate" | C.Role == "rateFill") == 12 && any(C.Role == "legend"), ...
    'a PSTH grid: one row per tile, role and group; title, 4 raster and 4 rate axes, a PSTH per unit and group, a legend');
xl = find(C.Role == "xlabel"); yl = find(C.Role == "ylabel");
check(isscalar(xl) && isscalar(yl) && C.Tile(xl) == 0 && C.Tile(yl) == 0 && C.Handles{xl} == h.layout.XLabel ...
    && C.Handles{yl} == h.layout.YLabel, 'a grid''s x and y labels: one component each, the layout''s (the plot''s own, tile 0)');
h = renderPlot(Rp, struct('kind', "psth", 'aesthetics', [struct('role', "xlabel", 'group', "", 'property', "FontSize", 'value', 13) ...
    struct('role', "ylabel", 'group', "", 'property', "Color", 'value', [1 0 0])]), fig);
check(h.layout.XLabel.FontSize == 13 && isequal(h.layout.YLabel.Color, [1 0 0]), 'a rule for the x or y label reaches the grid''s');
h = renderPlot(Rp, struct('kind', "psth"), fig);
C = PlotAesthetics.components(h.layout);
k = find(C.Role == "rateFill" & C.Group == "Depth = 0.5" & C.Tile == C.Tile(find(C.Role == "axes", 1)), 1);
check(~isempty(k) && all(arrayfun(@(p) isa(p, 'matlab.graphics.primitive.Patch'), C.Handles{k})) && C.TileName(k) ~= "", ...
    'a filled PSTH is one component per group (its patches together), named by its tile''s unit');

fprintf('\n== 3. renderPlot applies the rules: the user''s, then the plot''s ==\n');
red = [1 0 0]; blue = [0 0 1];
PlotAesthetics.setUserRules("psth", [struct('role', "rateFill", 'group', "", 'property', "FaceColor", 'value', blue) ...
    struct('role', "sem", 'group', "", 'property', "Visible", 'value', "off")]);
spec = struct('kind', "psth", 'aesthetics', struct('role', "rateFill", 'group', "Depth = 0.5", 'property', "FaceColor", 'value', red));
h = renderPlot(Rp, spec, fig);
C = PlotAesthetics.components(h.layout);
fc = @(C, grp) arrayfun(@(i) faces(C.Handles{i}), find(C.Role == "rateFill" & C.Group == grp), 'UniformOutput', false);
check(all(cellfun(@(x) isequal(x, red), fc(C, "Depth = 0.5"))) && all(cellfun(@(x) isequal(x, blue), fc(C, "Depth = 0"))) ...
    && all(cellfun(@(x) isequal(x, blue), fc(C, "Depth = 1"))), ...
    'the plot''s rule (group Depth = 0.5 red) wins over the user''s (every group blue) in every tile');
semOff = all(arrayfun(@(i) all(strcmp(get(C.Handles{i}, 'Visible'), 'off')), find(C.Role == "sem")));
check(semOff, 'the user''s rule hides every SEM band');
h = renderPlot(Rp, spec, fig, UserAesthetics=false);
C = PlotAesthetics.components(h.layout);
check(all(cellfun(@(x) ~isequal(x, blue), fc(C, "Depth = 0"))) && all(cellfun(@(x) isequal(x, red), fc(C, "Depth = 0.5"))), ...
    'UserAesthetics=false: only the plot''s rules');
PlotAesthetics.setUserRules("psth", []);
check(isempty(PlotAesthetics.userRules("psth")) && ~AppPrefs.ispref(PlotAesthetics.PrefGroup, "psth"), 'setUserRules(kind, []) forgets them');
w = warning('off', 'PlotAesthetics:BadValue');
lastwarn('');
h = renderPlot(Rp, struct('kind', "psth", 'aesthetics', struct('role', "zeroLine", 'group', "", 'property', "LineStyle", 'value', "zigzag")), fig);
[~, wid] = lastwarn();
warning(w);
check(~isempty(h.layout) && strcmp(wid, 'PlotAesthetics:BadValue'), 'a value the object refuses warns and the plot is still drawn');

fprintf('\n== 4. the right-click menu ==\n');
h = renderPlot(Rp, struct('kind', "psth"), fig);
check(~isappdata(fig, PlotAesthetics.ContextKey) && isempty(findall(fig, 'Type', 'uicontextmenu')), ...
    'an invisible figure (a run''s export) gets no menu');
h = renderPlot(Rp, struct('kind', "psth", 'id', "p1"), fig, Editable=true, OnRemember=@(r) setappdata(0, 'aestheticsGot', r));
ctx = getappdata(fig, PlotAesthetics.ContextKey);
cms = findall(fig, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag);
C = PlotAesthetics.components(h.layout);
withMenu = cellfun(@(x) all(arrayfun(@(o) ~isprop(o, 'ContextMenu') || (isa(o.ContextMenu, 'matlab.ui.container.ContextMenu') ...
    && isequal(o.ContextMenu.UserData, o)), x)), C.Handles);
check(~isempty(cms) && isstruct(ctx) && ctx.kind == "psth" && ctx.id == "p1" && isequal(ctx.root, h.layout) && all(withMenu), ...
    'Editable=true: every component has a menu that knows it; the context (kind, id, root) is kept on the target');
renderPlot(Rp, struct('kind', "psth", 'id', "p1"), fig, Editable=true);
check(numel(findall(fig, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag)) == numel(cms), 'redrawing leaves no stale menus');
C = PlotAesthetics.components(getappdata(fig, PlotAesthetics.ContextKey).root);
lg = C.Handles{find(C.Role == "legend", 1)};
[c2, holder] = PlotAesthetics.contextOf(lg);
check(isstruct(c2) && isequal(holder, fig), 'a legend finds its plot''s context');
check(strcmp(errorId(@() PlotAesthetics.edit(axes(figure('Visible', 'off')))), 'PlotAesthetics:NotEditable'), ...
    'edit on something renderPlot did not draw: PlotAesthetics:NotEditable');

fprintf('\n== 5. the editor: live edits, Apply to, Reset, Cancel ==\n');
fig2 = figure('Visible', 'off');
h = renderPlot(Rp, struct('kind', "psth", 'id', "p1", 'histStyle', "line", 'fill', false), fig2, Editable=true, ...
    OnRemember=@(r) setappdata(0, 'aestheticsGot', r));
ctx = getappdata(fig2, PlotAesthetics.ContextKey);
C = PlotAesthetics.components(h.layout);
rows = find(C.Role == "rate" & C.Group == "Depth = 0");
line1 = C.Handles{rows(1)};
lw0 = line1.LineWidth;
d = PlotAestheticsDialog(ctx, line1, Visible=false);
check(d.Selected == rows(1) && d.Components.Role(d.Selected) == "rate", 'it opens on the component clicked');
d.setProperty("LineWidth", 4);
lws = arrayfun(@(r) C.Handles{r}.LineWidth, rows);
check(lws(1) == 4 && all(lws(2:end) == lw0), 'Apply to "this one": only that line changes, at once');
d.setApplyTo("same");
lws = arrayfun(@(r) C.Handles{r}.LineWidth, rows);
other = C.Handles{find(C.Role == "rate" & C.Group == "Depth = 1", 1)};
check(all(lws == 4) && other.LineWidth == lw0, 'Apply to "same": the same group''s line in every tile, not the other groups');
d.setApplyTo("role");
check(other.LineWidth == 4, 'Apply to "role": every group too');
d.setApplyTo("one");
lws = arrayfun(@(r) C.Handles{r}.LineWidth, rows);
check(lws(1) == 4 && all(lws(2:end) == lw0) && other.LineWidth == lw0, 'back to "this one": the others are put back');
d.setProperty("Color", "#00FF00");
check(isequal(line1.Color, [0 1 0]), 'a colour typed as #rrggbb');
t1 = find(C.Role == "tileTitle", 2);
d.select(t1(1));
d.setProperty("FontSize", 15);
check(C.Handles{t1(1)}.FontSize == 15 && line1.LineWidth == 4, 'selecting another component keeps the earlier edit');
d.tick(t1, true);
check(d.ApplyTo == "ticked" && C.Handles{t1(2)}.FontSize == 15, 'ticking rows switches Apply to to them');
d.tickLike("none");
check(d.ApplyTo == "one" && C.Handles{t1(2)}.FontSize ~= 15, 'unticking all goes back to this one');
d.reset();
check(line1.LineWidth == lw0 && ~isequal(line1.Color, [0 1 0]) && C.Handles{t1(1)}.FontSize ~= 15, 'Reset puts everything back');
d.select(rows(1));
d.setProperty("LineWidth", 6);
d.cancel();
check(line1.LineWidth == lw0 && ~isvalid(d.Fig), 'Cancel puts it back and closes');

fprintf('\n== 6. the editor: OK, Remember, Forget ==\n');
d = PlotAestheticsDialog(ctx, line1, Visible=false);
d.setApplyTo("same");
d.setProperty("LineWidth", 3);
d.setRemember(true, "plot");
setappdata(0, 'aestheticsGot', []);
d.ok();
got = getappdata(0, 'aestheticsGot');
check(isstruct(got) && isscalar(got) && got.role == "rate" && got.group == "Depth = 0" && got.property == "LineWidth" && got.value == 3, ...
    'OK with Remember for this plot: one rule (role, group) goes to OnRemember');
ctx = getappdata(fig2, PlotAesthetics.ContextKey);
C = PlotAesthetics.components(ctx.root);
lws = arrayfun(@(r) C.Handles{r}.LineWidth, find(C.Role == "rate" & C.Group == "Depth = 0"));
check(~isequal(ctx.root, h.layout) && all(lws == 3) && numel(ctx.plotRules) == 1, ...
    'the plot is redrawn with its new rule (every tile), and the context knows it');
d = PlotAestheticsDialog(ctx, C.Handles{find(C.Role == "sem", 1)}, Visible=false);
d.setApplyTo("role");
d.setProperty("FaceAlpha", 0.3);
d.setRemember(true, "user");
d.ok();
U = PlotAesthetics.userRules("psth");
check(isscalar(U) && U.role == "sem" && U.group == "" && U.property == "FaceAlpha" && U.value == 0.3, ...
    'OK with Remember for every plot of the kind: a rule for every group in the preferences');
f3 = figure('Visible', 'off');
h3 = renderPlot(Rp, struct('kind', "psth"), f3);
C3 = PlotAesthetics.components(h3.layout);
check(all(arrayfun(@(i) all([C3.Handles{i}.FaceAlpha] == 0.3), find(C3.Role == "sem"))), 'the next plot of the kind is drawn that way');
ctx = getappdata(fig2, PlotAesthetics.ContextKey);
d = PlotAestheticsDialog(ctx, [], Visible=false);
Tr = d.remembered();
check(height(Tr) == 2 && Tr.KeptFor(1) == "This plot" && startsWith(Tr.KeptFor(2), "My "), 'the Remembered tab lists the plot''s and the user''s rules');
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
lws = arrayfun(@(r) C.Handles{r}.LineWidth, find(C.Role == "rate" & C.Group == "Depth = 0"));
ax1 = C.Handles{find(C.Role == "axes", 1)};
check(isstruct(got) && isempty(got) && isempty(PlotAesthetics.userRules("psth")) && all(lws == lw0), ...
    'Forget: both rules gone (OnRemember gets none; the preference is removed) and the plot redrawn without them');
check(isequal(ax1.Color, [1 1 0.8]), 'an edit not remembered is put back on the redrawn plot');
ctxNo = ctx; ctxNo.onRemember = [];
d = PlotAestheticsDialog(ctxNo, [], Visible=false);
check(d.Scope == "user" && strcmp(errorId(@() d.setRemember(true, "plot")), 'PlotAesthetics:BadScope'), ...
    'a plot outside a config can only be remembered for the user');
d.cancel();

fprintf('\n== 7. the config and the generated script ==\n');
rules = [struct('role', "rate", 'group', "Depth = 0", 'property', "Color", 'value', [0.2 0.4 0.6]) ...
    struct('role', "tileTitle", 'group', "", 'property', "FontWeight", 'value', "bold")];
cfg = EphysAnalysisConfig();
cfg = cfg.addPlot(struct('kind', "psth", 'id', "look", 'aesthetics', rules));
f = string(tempname) + ".json";
cfg.save(f);
back = EphysAnalysisConfig.load(f);
delete(f);
p = back.Plots(back.plotIndex("look"));
check(numel(p.aesthetics) == 2 && isequal(p.aesthetics(1).value, [0.2 0.4 0.6]) && p.aesthetics(2).value == "bold" ...
    && back.isequalConfig(cfg), 'a plot''s aesthetics survive the JSON file');
check(strcmp(errorId(@() cfg.addPlot(struct('kind', "psth", 'aesthetics', struct('role', "rate", 'property', "Nope", 'value', 1)))), ...
    'EphysAnalysisConfig:BadValue'), 'a rule with an unknown property is refused (EphysAnalysisConfig:BadValue)');
check(isempty(EphysAnalysisConfig.defaults("Plot").aesthetics), 'a new plot has no rules');
lit = EphysPipelineScript.literal(p.aesthetics);
again = eval(lit);
lit0 = EphysPipelineScript.literal(PlotAesthetics.emptyRules());
none = eval(lit0);
check(isequaln(again, p.aesthetics) && isempty(none) && isfield(none, 'property'), 'the script literal of a rule list (and of none) evaluates back');
L = EphysPipelineScript.structLiteral("spec", cfg.plotFor("look"));
spec = struct(); %#ok<NASGU>
eval(strjoin(L, newline));
check(isequaln(spec.aesthetics, p.aesthetics), 'a plot spec written out in full keeps its rules');

close([fig fig2 f3]);
fprintf('\n%d passed, %d failed\n', nPass, nFail);
if nFail > 0
    error('test_PlotAesthetics:Failed', '%d check(s) failed.', nFail);
end
end


function kids = allKids(ax)
%allKids  The children of AX in draw order (first on top), those with no handle visibility too.
shown = get(groot, 'ShowHiddenHandles');
set(groot, 'ShowHiddenHandles', 'on');
kids = ax.Children;
set(groot, 'ShowHiddenHandles', shown);
end


function c = faces(p)
%faces  The fill colour shared by patches P ([] when they differ).
c = p(1).FaceColor;
for k = 2:numel(p)
    if ~isequal(p(k).FaceColor, c); c = []; return; end
end
end


function s = ifText(c, s)
if ~c; s = ""; end
end
