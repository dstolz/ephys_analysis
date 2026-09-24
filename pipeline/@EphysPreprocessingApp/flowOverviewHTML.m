function [html, summary, model] = flowOverviewHTML(obj)
%flowOverviewHTML  The Diagram's overview: how data flows through the pipeline.
%   [HTML, SUMMARY] = app.flowOverviewHTML() draws every pipeline step
%   (Probe check, Behavior, Artifacts, Sorting, Signals, Spikes, Export) as
%   one box, with the files it writes hung under it, below the inputs (the
%   raw recording with its manifest, the Epsych2 sessions, the probe map).
%   An arrow runs from each input or written file to every step that reads
%   it, in the colour of whatever wrote it. An arrow the working config
%   leaves off is dashed (Signals without BlankArtifacts does not read the
%   artifact periods, Export reads the sorted units only with
%   IncludeUnits, ...); a disabled step, and every arrow into it, is faded.
%   The parameters themselves are on the "Every parameter" view
%   (flowChartHTML). Hovering a box lights its arrows and the boxes at
%   their other ends, in the app and in a saved page.
%
%   The page is one SVG laid out here rather than by the browser, drawn at
%   its own size in a viewport that opens fitted to it and zooms and pans
%   (flowZoom). The boxes
%   sit on a fixed grid of five columns, a row per stage of the flow, and
%   the arrows are routed at right angles through the gaps between rows and
%   columns: none runs through a box, and no two sources share a line
%   (they may cross). Each gap between rows gives every source leaving it,
%   and every target reached through a side lane, a track of its own; the
%   tracks are ordered to cross as few arrows as they can.
%
%   Each box names the control(s) behind it (data-nav), as on the detail
%   view, so a click in the app opens them (onFlowNavigate). It reads only
%   obj.Config and the active dataset. SUMMARY is a one-line description
%   for the tab. MODEL holds the geometry the page draws, for tests:
%     nodes  id, title, target, rect [x y w h] (the box and the files hung
%            under it)
%     edges  from, to (node ids), on (read under this config), dim (into a
%            disabled step), points ([n x 2] polyline, ending on the top of
%            the target box)
%
%   See also flowChartHTML, onFlowNavigate, flowNavControls.

cfg = obj.Config;
d = obj.currentDataset();
dsName = ternary(isempty(d), "<Name>", d.Name);

N = [inputNodes(cfg, d), stepNodes(cfg, dsName)];
E = edgeList(cfg);
for k = 1:numel(E)   % an arrow into a disabled step fades with it
    E(k).dim = N([N.id] == E(k).to).dim;
end
[N, E, W, H] = place(N, E);

steps = N([N.kind] == "step");
nOn = nnz(~[steps.dim]);
summary = sprintf("%d of %d steps enabled", nOn, numel(steps));
if ~isempty(d)
    summary = summary + " | recording: " + d.Name;
end

pageTitle = "Preprocessing data flow: " + cfg.Name;
svg = sprintf("<svg class=""flow"" xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 %g %g"" width=""%g"" height=""%g"" role=""img"" aria-label=""%s"">", ...
    W, H, W, H, esc(pageTitle)) ...
    + joinHTML([arrayfun(@edgeSVG, E, "UniformOutput", false), arrayfun(@nodeSVG, N, "UniformOutput", false)]) ...
    + "</svg>";
zoom = flowZoom("overview", "fit");
body = "<h1>" + esc(pageTitle) + "</h1>" + legendHTML() ...
    + "<div class=""note"">Arrows carry data in the colour of what wrote it. Hover a box to trace what it reads and writes. Scroll to zoom, drag to pan.</div>" ...
    + "<div class=""hint"">Click any box to open the setting it draws.</div>" ...
    + zoom.open + svg + zoom.close ...
    + "<script>" + zoom.js + newline + js() + "</script>";
html = "<!DOCTYPE html><html><head><meta charset=""utf-8""><title>" + esc(pageTitle) + "</title><style>" ...
    + zoom.css + css() + "</style></head><body>" + body + "</body></html>";

model = struct('nodes', struct('id', {N.id}, 'title', {N.title}, 'target', {N.target}, ...
    'rect', arrayfun(@(n) [n.x n.y n.w n.h], N, "UniformOutput", false)), ...
    'edges', struct('from', {E.from}, 'to', {E.to}, 'on', {E.on}, 'dim', {E.dim}, 'points', {E.points}));
end


% =========================================================================
% boxes
% =========================================================================

function N = inputNodes(cfg, d)
%inputNodes  What the pipeline starts from, in the top row.
B = cfg.Behavior;
if ~B.Search
    % No search: the session associated by hand (or in the recording folder).
    if isempty(d)
        where = "no active dataset";
    elseif d.BehaviorFile == ""
        where = "none associated with " + d.Name;
    else
        where = fileName(d.BehaviorFile);
    end
    epsych = node("epsych", "epsych", "in", 0, 0, "Epsych2 sessions", ...
        ["associated by hand; no search", where], "BehSearchCheckBox,BehAssociateButton");
else
    if isempty(B.SearchDirs)
        where = "no search folder set";
    elseif isscalar(B.SearchDirs)
        where = "in " + fileName(B.SearchDirs);
    else
        where = sprintf("in %d folders", numel(B.SearchDirs));
    end
    switch B.Match
        case "prefix"; how = "matched by name prefix";
        case "time";   how = sprintf("matched by start time (%g min)", B.MaxStartOffsetMin);
        otherwise;     how = "matched by name, then start time";
    end
    epsych = node("epsych", "epsych", "in", 0, 0, "Epsych2 sessions", [where, how], ...
        "BehSearchCheckBox,BehSearchDirsField,BehMatchDropDown,BehMaxOffsetField");
end

if isempty(d)
    rec = "no active dataset";
else
    info = string(d.RecordingFormat);
    if isfinite(d.Fs); info = sprintf("%g kHz, ", d.Fs / 1000) + info; end
    if isfinite(d.NumChannels); info = sprintf("%d ch, ", d.NumChannels) + info; end
    rec = [d.Name, info];
end
switch cfg.Artifacts.Reference
    case "car"; ref = "common reference: average (CAR)";
    case "cmr"; ref = "common reference: median (CMR)";
    otherwise;  ref = "no common reference";
end
raw = node("rec", "rec", "src", 0, 2, "Raw recording", ...
    [rec, "+ manifest: probe, exclusions, manual artifact periods", ref], "RootPathField,DatasetsTable");

if ~isempty(d) && d.ProbeFile ~= ""
    probe = fileName(d.ProbeFile);
elseif cfg.Probe.DefaultProbeFile ~= ""
    probe = "default: " + fileName(cfg.Probe.DefaultProbeFile);
else
    probe = "none set";
end
if ~isempty(d) && ~isempty(d.ExcludeChannels)
    probe(end+1) = sprintf("%d channel(s) excluded", numel(d.ExcludeChannels));
end
map = node("probemap", "probemap", "in", 0, 4, "Probe map", probe, ...
    "ProbeDatasetDropDown,ProbeDefaultField,ExcludeChannelsField");

N = [epsych, raw, map];
end


function N = stepNodes(cfg, dsName)
%stepNodes  One box per step, with the files it writes. The file an arrow
%   leaves from (port) is the last one hung under its step.

P = cfg.Probe;
probe = step("probe", 1, 4, "Probe check", true, "the assigned probe vs the channel count", ...
    "ProbeDefaultField,ProbeWriteDefaultCheckBox");
probe.badge = "always runs";
if P.WriteDefaultToManifest
    probe.outs = pill("out", "Manifest", "the default probe assigned", "ProbeWriteDefaultCheckBox", false);
else
    probe.lines(end+1) = "reports only; writes nothing";
end

B = cfg.Behavior;
lines = ternary(B.Search, "matches each recording to its session", "uses each recording's associated session");
if B.PairTrials
    lines(end+1) = "pairs its trials with the " + B.TrialLine + " line" + ternary(B.AutoApprove, ", auto-approving clean ones", "");
end
behavior = step("behavior", 1, 0, "Behavior", B.Enabled, lines, ...
    ternary(B.Search, "BehEnableCheckBox,BehSearchCheckBox,BehOverwriteCheckBox", "BehEnableCheckBox,BehSearchCheckBox"));
if B.PairTrials
    behavior.outs = pill("out", "Trial pairing", "in the manifest; review on Trials", ...
        "TrialsPairCheckBox,TrialsLineDropDown,TrialsAutoApproveCheckBox", false);
end
if B.WriteFile
    behavior.outs(end+1) = pill("out", "Behavior file", dsName + "_behavior.mat", "BehWriteFileCheckBox", true);
else
    behavior.outs(end+1) = pill("off", "Behavior file", "not written", "BehWriteFileCheckBox", true);
end

A = cfg.Artifacts;
if A.Enabled
    switch A.Method
        case "rms";        m = "running RMS";
        case "mad";        m = "robust z-score";
        case "microvolts"; m = "absolute amplitude";
        otherwise;         m = "common-mode mean";
    end
    lines = "automatic detection: " + m;
    periods = "automatic + manual";
    if A.CacheIntervals; periods(end+1) = "cached in " + dsName + "_artifacts.json"; end
else
    lines = "detection off";
    periods = "manual only";
end
artifacts = step("artifacts", 1, 2, "Artifacts", A.Enabled, lines, "ArtEnableCheckBox");
artifacts.outs = pill("link", "Artifact periods", periods, "ArtManualTable,ArtEditVizButton", true);
artifacts.outs.dim = false;   % the manual periods apply with detection off too

S = cfg.Sorting;
lines = "Kilosort4 on a .bin of the recording";
if S.Execution == "background"
    lines(end+1) = sprintf("in the background, %d at a time", S.MaxConcurrent);
else
    lines(end+1) = "waits for each sort";
end
if S.DryRun; lines(end+1) = "dry run: writes the run files only"; end
sorting = step("sorting", 2, 3, "Sorting", S.Enabled, lines, "SortEnableCheckBox,ExecModeDropDown,DryRunCheckBox");
sorting.outs = pill("out", "Sorted units", "kilosort4/ (phy-ready)", "SortDatasetDropDown,SortUseFolderButton,SortPhyButton", true);

G = cfg.Signals;
types = ["LFP" "MUA" "SPIKE" "AUX"];
types = types([G.LFP G.MUA G.SPIKE G.AUX]);
if isempty(types)
    lines = "no signal ticked: events only";
else
    lines = join(types, " + ") + " + digital events";
end
lines(end+1) = ternary(G.BlankArtifacts, "artifact periods erased first", "artifact periods left in");
signals = step("signals", 2, 1, "Signals", G.Enabled, lines, ...
    "SigEnableCheckBox,ConvLFPCheckBox,ConvMUACheckBox,ConvSPIKECheckBox,ConvAUXCheckBox");
if G.SeparateFiles && ~isempty(types)
    file = dsName + G.Suffix + "_<TYPE>.mat";
else
    file = dsName + G.Suffix + ".mat";
end
signals.outs = pill("out", "Signal files", file, ...
    "ConvOutputDirField,ConvSuffixField,ConvSeparateFilesCheckBox,ConvMatVersionDropDown", true);

K = cfg.Spikes;
switch K.Source
    case "detect"; lines = "threshold detection";
    case "sorted"; lines = "reads the sorted units";
    otherwise;     lines = "threshold detection + sorted units";
end
if K.Source ~= "sorted"
    switch K.ArtifactMode
        case "reject"; lines(end+1) = "rejects events in artifact periods";
        case "erase";  lines(end+1) = "artifact periods erased first";
        otherwise;     lines(end+1) = "ignores the artifact periods";
    end
end
spikes = step("spikes", 3, 3, "Spikes", K.Enabled, lines, "SpkEnableCheckBox,SpkSourceDropDown");
spikes.outs = pill("out", "Spikes file", dsName + K.Suffix + ".mat", ...
    "SpkOutputDirField,SpkSuffixField,SpkOverwriteCheckBox,SpkMatVersionDropDown", true);

X = cfg.Export;
lines = "signals: " + joinOr(X.Signals, "all") + ternary(X.IncludeEvents, ", with events", "");
lines(end+1) = "one file per format";
export = step("export", 4, 2, "Export", X.Enabled, lines, "ExpEnableCheckBox");
if ismember("chronux", X.Formats)
    export.outs(end+1) = pill("out", "Chronux file", dsName + "_chronux.mat", "ExpChronuxCheckBox,ExpOutputDirField", false);
end
if ismember("fieldtrip", X.Formats)
    export.outs(end+1) = pill("out", "FieldTrip file", dsName + "_fieldtrip.mat", "ExpFieldTripCheckBox,ExpValidateCheckBox", false);
end
if ismember("epochs", X.Formats)
    if X.EpochSource == "behavior"
        around = "around the paired trials";
    elseif X.EpochLine == ""
        around = "around the trial line";
    else
        around = "around " + X.EpochLine;
    end
    export.outs(end+1) = pill("out", "Epoch file", [dsName + "_epochs.mat", around], ...
        "ExpEpochsCheckBox,ExpEpochSourceDropDown,ExpEpochLineField", false);
end
if isempty(export.outs)
    export.outs = pill("off", "No format ticked", "nothing is written", ...
        "ExpChronuxCheckBox,ExpFieldTripCheckBox,ExpEpochsCheckBox", false);
end

N = [probe, behavior, artifacts, sorting, signals, spikes, export];
end


function E = edgeList(cfg)
%edgeList  Every read of an input or a written file, whether this config
%   makes it or not (ON). The arrows into one step are listed left to right
%   in the order they reach its top. LANE routes an arrow that skips a row:
%   NaN drops it straight onto its target through the empty cells above it;
%   otherwise it runs down the lane (grid units: column k's centre, or
%   k + 0.5 for the gap right of column k), then across to its target.
B = cfg.Behavior; G = cfg.Signals; K = cfg.Spikes; X = cfg.Export;
detect = K.Source ~= "sorted";
byTrial = ismember("epochs", X.Formats) && X.EpochSource == "behavior";
if ~detect
    toSpikes = "off: no threshold detection";
elseif K.ArtifactMode == "none"
    toSpikes = "off: Spikes.ArtifactMode is none";
else
    toSpikes = ternary(K.ArtifactMode == "erase", "erased before detection", "events in them rejected");
end
E = [ ...
    edge("epsych", "behavior", true, ternary(B.Search, "the session files to match", "the associated session files (no search)")), ...
    edge("rec", "behavior", B.PairTrials, ternary(B.PairTrials, "the " + B.TrialLine + " line, to pair the trials", "off: no trial pairing")), ...
    edge("rec", "artifacts", true, "the recording, and the manual periods in its manifest"), ...
    edge("rec", "probe", true, "the channel count"), ...
    edge("probemap", "probe", true, "the probe's sites"), ...
    edge("rec", "signals", true, "the recording", NaN), ...
    edge("artifacts", "signals", G.BlankArtifacts, ternary(G.BlankArtifacts, "erased before any filter", "off: Signals.BlankArtifacts is off")), ...
    edge("artifacts", "sorting", true, "blanked before the .bin is written"), ...
    edge("rec", "sorting", true, "the recording, written to the .bin", NaN), ...
    edge("probemap", "sorting", true, "the channel map", NaN), ...
    edge("artifacts", "spikes", detect && K.ArtifactMode ~= "none", toSpikes, 2), ...
    edge("sorting", "spikes", K.Source ~= "detect", ternary(K.Source ~= "detect", "the units read into the spikes file", "off: Spikes.Source is detect")), ...
    edge("rec", "spikes", detect, ternary(detect, "the recording, for threshold detection", "off: Spikes.Source is sorted"), 3.5), ...
    edge("behavior", "export", byTrial, ternary(byTrial, "the paired trials the epochs are cut around" ...
        + ternary(B.WriteFile, "", " (from the session and its recorded pairing, with no behavior file)"), ...
        "off: no epochs around the paired trials"), 0), ...
    edge("signals", "export", true, "the extract: signals and events", NaN), ...
    edge("sorting", "export", X.IncludeUnits, ternary(X.IncludeUnits, "the sorted units", "off: Export.IncludeUnits is off"), NaN), ...
    edge("spikes", "export", X.IncludeDetected, ternary(X.IncludeDetected, "the detected spikes", "off: Export.IncludeDetected is off"))];
end


% =========================================================================
% node helpers
% =========================================================================

function n = node(id, key, kind, row, col, title, lines, target)
%node  One box: kind src (the recording) | in (another input) | step.
%   KEY picks its colour (c-<key>), TARGET what a click opens (see
%   flowChartHTML's node helper). ROW / COL place it on the grid.
n = struct('id', string(id), 'key', string(key), 'kind', string(kind), 'row', row, 'col', col, ...
    'title', string(title), 'lines', {string(lines)}, 'target', string(target), 'badge', "", ...
    'dim', false, 'outs', {emptyPills()}, 'x', 0, 'y', 0, 'w', 0, 'h', 0, 'boxH', 0);
end


function n = step(key, row, col, title, enabled, lines, target)
%step  A step's box, faded when the step is disabled.
n = node(key, key, "step", row, col, title, lines, target);
n.badge = ternary(enabled, "enabled", "disabled");
n.dim = ~enabled;
end


function p = pill(kind, title, lines, target, port)
%pill  A file a step writes: kind out | link (the artifact periods) | off.
%   PORT: the arrows to its readers leave from it. DIM follows the step
%   unless set afterwards.
p = struct('kind', string(kind), 'title', string(title), 'lines', {string(lines)}, ...
    'target', string(target), 'port', port, 'dim', [], 'x', 0, 'y', 0, 'w', 0, 'h', 0);
end


function p = emptyPills()
p = pill("out", "", "", "", false);
p(1) = [];
end


function e = edge(from, to, on, note, lane)
if nargin < 5; lane = NaN; end
e = struct('from', string(from), 'to', string(to), 'on', logical(on), 'note', string(note), ...
    'lane', lane, 'dim', false, 'portX', NaN, 'points', zeros(0, 2));
end


% =========================================================================
% layout and routing
% =========================================================================

function L = geometry()
L = struct('margin', 16, 'top', 10, 'bottom', 12, 'colW', 206, 'gapX', 34, ...
    'track', 9, 'gapMin', 30, 'wireGap', 16, 'pillGap', 8, 'pillInset', 12);
end


function x = colX(L, c)
x = L.margin + c * (L.colW + L.gapX);
end


function x = laneX(L, u)
%laneX  A lane's x: column u's centre, or the middle of the gap right of it.
if u == round(u)
    x = colX(L, u) + L.colW / 2;
else
    x = colX(L, floor(u)) + L.colW + L.gapX / 2;
end
end


function [N, E, W, H] = place(N, E)
%place  Size the boxes, put them on the grid and route the arrows.
L = geometry();
for k = 1:numel(N)
    N(k) = sizeNode(N(k), L);
end
ids = [N.id];
at = @(id) find(ids == id, 1);
nRows = max([N.row]) + 1;
rowH = zeros(1, nRows);
for r = 0:nRows - 1
    rowH(r + 1) = max([N([N.row] == r).h]);
end

% The tracks of each gap between rows: one per source leaving the row above
% ("x:<id>") and one per target in the row below reached through a lane
% ("a:<id>").
from = arrayfun(@(e) N(at(e.from)).row, E);
to = arrayfun(@(e) N(at(e.to)).row, E);
viaLane = to > from + 1 & ~isnan([E.lane]);
nets = cell(1, nRows - 1);
for g = 0:nRows - 2
    nets{g + 1} = [reshape("x:" + unique([E(from == g).from], "stable"), 1, []), ...
        reshape("a:" + unique([E(viaLane & to == g + 1).to], "stable"), 1, [])];
end
gapH = cellfun(@(c) max(L.gapMin, L.track * (numel(c) + 1)), nets);
rowY = L.top + [0, cumsum(rowH(1:end-1) + gapH)];
for k = 1:numel(N)
    N(k) = moveNode(N(k), colX(L, N(k).col), rowY(N(k).row + 1), L);
end
% Ports: the arrows into a box spread over its top, in the list's order.
for t = unique([E.to], "stable")
    k = find([E.to] == t);
    n = N(at(t));
    for j = 1:numel(k)
        E(k(j)).portX = n.x + n.w * j / (numel(k) + 1);
    end
end
gapTop = rowY(1:end-1) + rowH(1:end-1);

% Order each gap's tracks to cross (and never overlap) as little as they
% can: every order of one gap at a time, the current one kept on a tie.
route = @(order) routeAll(N, E, at, from, viaLane, order, gapTop, L);
order = nets;
best = score(route(order));
for pass = 1:2
    for g = 1:numel(order)
        cur = order{g};
        P = perms(1:numel(cur));
        for p = 1:size(P, 1)
            trial = order;
            trial{g} = cur(P(p, :));
            s = score(route(trial));
            if s < best
                best = s;
                order = trial;
            end
        end
    end
end
E = route(order);
W = 2 * L.margin + 5 * L.colW + 4 * L.gapX;
H = rowY(end) + rowH(end) + L.bottom;
end


function n = sizeNode(n, L)
%sizeNode  Wrap the text to the box width and size the box and its files.
n.w = L.colW;
bw = 0;
if n.badge ~= ""; bw = textWidth(n.badge, 10) + 12; end
n.title = fitLine(n.title, n.w - 22 - bw - 6, 12.5 * 1.07);
n.lines = wrapLines(n.lines, n.w - 22, 11);
n.boxH = 27 + 14 * numel(n.lines);
n.h = n.boxH;
for j = 1:numel(n.outs)
    p = n.outs(j);
    p.w = n.w - 2 * L.pillInset;
    p.title = fitLine(p.title, p.w - 18, 11.5 * 1.07);
    p.lines = wrapLines(p.lines, p.w - 18, 10.5);
    p.h = 21 + 13 * numel(p.lines);
    if isempty(p.dim); p.dim = n.dim; end
    gap = L.pillGap;
    if j == 1; gap = L.wireGap; end
    n.h = n.h + gap + p.h;
    n.outs(j) = p;
end
end


function n = moveNode(n, x, y, L)
n.x = x;
n.y = y;
py = y + n.boxH + L.wireGap;
for j = 1:numel(n.outs)
    n.outs(j).x = x + L.pillInset;
    n.outs(j).y = py;
    py = py + n.outs(j).h + L.pillGap;
end
end


function E = routeAll(N, E, at, from, viaLane, order, gapTop, L)
%routeAll  Every arrow's polyline under one order of the gaps' tracks:
%   down from the bottom of its source (or the file it leaves from) to its
%   source's track, across, and down onto its port -- or, through a lane,
%   across to the lane, down it to its target's track, across and down.
trackY = @(net, g) gapTop(g + 1) + L.track * find(order{g + 1} == net, 1);
for k = 1:numel(E)
    s = N(at(E(k).from));
    t = N(at(E(k).to));
    sx = s.x + s.w / 2;
    yx = trackY("x:" + s.id, from(k));
    px = E(k).portX;
    if viaLane(k)
        lx = laneX(L, E(k).lane);
        ya = trackY("a:" + t.id, t.row - 1);
        pts = [sx, s.y + s.h; sx, yx; lx, yx; lx, ya; px, ya; px, t.y];
    else
        pts = [sx, s.y + s.h; sx, yx; px, yx; px, t.y];
    end
    E(k).points = simplify(pts);
end
end


function p = simplify(p)
%simplify  Drop repeated points and the middle of straight runs.
keep = [true; any(abs(diff(p)) > 1e-6, 2)];
p = p(keep, :);
k = 2;
while k < size(p, 1)
    a = p(k, :) - p(k - 1, :);
    b = p(k + 1, :) - p(k, :);
    if abs(a(1) * b(2) - a(2) * b(1)) < 1e-6
        p(k, :) = [];
    else
        k = k + 1;
    end
end
end


function s = score(E)
%score  Crossings between arrows from different sources, plus a heavy
%   penalty for each stretch two of them would share. A source's arrows
%   share their first stretch, so a crossing is counted once per point.
[h, v] = segments(E);
tol = 0.5;
[i, j] = find(v.x' > h.x1 + tol & v.x' < h.x2 - tol & h.y > v.y1' + tol & h.y < v.y2' - tol & h.src ~= v.src');
at = unique(round([v.x(j), h.y(i), min(h.src(i), v.src(j)), max(h.src(i), v.src(j))]), "rows");
s = size(at, 1) + 100 * (overlaps(h.y, h.x1, h.x2, h.src) + overlaps(v.x, v.y1, v.y2, v.src));
end


function n = overlaps(at, lo, hi, src)
%overlaps  Pairs of collinear segments from different sources sharing a stretch.
M = abs(at - at') < 0.5 & min(hi, hi') - max(lo, lo') > 0.5 & src ~= src';
n = nnz(triu(M, 1));
end


function [h, v] = segments(E)
%segments  The horizontal and vertical pieces of every arrow, each with
%   its source (as a number) and its end points in increasing order.
H = zeros(0, 4); V = zeros(0, 4);
srcs = unique([E.from]);
for k = 1:numel(E)
    p = E(k).points;
    id = find(srcs == E(k).from);
    for j = 1:size(p, 1) - 1
        a = p(j, :); b = p(j + 1, :);
        if abs(a(2) - b(2)) < 1e-6
            H(end+1, :) = [a(2), min(a(1), b(1)), max(a(1), b(1)), id]; %#ok<AGROW>
        else
            V(end+1, :) = [a(1), min(a(2), b(2)), max(a(2), b(2)), id]; %#ok<AGROW>
        end
    end
end
h = struct('y', H(:, 1), 'x1', H(:, 2), 'x2', H(:, 3), 'src', H(:, 4));
v = struct('x', V(:, 1), 'y1', V(:, 2), 'y2', V(:, 3), 'src', V(:, 4));
end


% =========================================================================
% rendering
% =========================================================================

function h = edgeSVG(e)
%edgeSVG  One arrow: its path with rounded corners, a head on its target and
%   a tooltip saying what it carries.
cls = "edge c-" + keyOf(e.from) + ternary(e.on, "", " off") + ternary(e.dim, " dim", "");
p = e.points;
x = p(end, 1); y = p(end, 2);
h = "<g class=""" + cls + """ data-from=""" + e.from + """ data-to=""" + e.to + """><title>" ...
    + esc(nodeName(e.from) + " -> " + nodeName(e.to) + ": " + e.note) + "</title>" ...
    + "<path class=""ln"" d=""" + roundedPath(p, 7) + """/>" ...
    + sprintf("<path class=""head"" d=""M%.1f %.1fL%.1f %.1fL%.1f %.1fZ""/>", x - 4.5, y - 8, x + 4.5, y - 8, x, y) ...
    + "</g>";
end


function k = keyOf(id)
%keyOf  The colour of an arrow: the step (or input) it leaves from.
k = id;
end


function t = nodeName(id)
names = dictionary(["epsych" "rec" "probemap" "probe" "behavior" "artifacts" "sorting" "signals" "spikes" "export"], ...
    ["Epsych2 sessions" "Raw recording" "Probe map" "Probe check" "Behavior file" "Artifact periods" ...
     "Sorted units" "Signal files" "Spikes file" "Export"]);
t = names(id);
end


function d = roundedPath(p, r)
%roundedPath  SVG path through the points P, each corner rounded (radius
%   up to R, less where the pieces around it are short).
d = sprintf("M%.1f %.1f", p(1, 1), p(1, 2));
for k = 2:size(p, 1) - 1
    a = p(k, :) - p(k - 1, :); b = p(k + 1, :) - p(k, :);
    rr = min([r, norm(a) / 2, norm(b) / 2]);
    in = p(k, :) - rr * a / norm(a);
    out = p(k, :) + rr * b / norm(b);
    d = d + sprintf("L%.1f %.1fQ%.1f %.1f %.1f %.1f", in, p(k, :), out);
end
d = d + sprintf("L%.1f %.1f", p(end, 1), p(end, 2));
end


function h = nodeSVG(n)
%nodeSVG  One box (with its badge and text) and the files hung under it.
x = n.x; y = n.y; w = n.w;
isSrc = n.kind == "src";
tc = ternary(isSrc, "t src", "t");
dc = ternary(isSrc, "d src", "d");
parts = sprintf("<rect class=""box %s"" x=""%.1f"" y=""%.1f"" width=""%.1f"" height=""%.1f"" rx=""7""/>", n.kind, x, y, w, n.boxH);
if ~isSrc
    parts = parts + sprintf("<path class=""bar"" d=""M%.1f %.1fh-0.5a6.5 6.5 0 0 0 -6.5 6.5v%.1fa6.5 6.5 0 0 0 6.5 6.5h0.5z""/>", ...
        x + 7, y, n.boxH - 13);
end
parts = parts + sprintf("<text class=""%s"" x=""%.1f"" y=""%.1f"">%s</text>", tc, x + 14, y + 17, esc(n.title));
if n.badge ~= ""
    bw = textWidth(n.badge, 10) + 12;
    parts = parts + sprintf("<rect class=""badge%s"" x=""%.1f"" y=""%.1f"" width=""%.1f"" height=""15"" rx=""7.5""/>", ...
        ternary(n.dim, "", " on"), x + w - 8 - bw, y + 6, bw) ...
        + sprintf("<text class=""bt%s"" x=""%.1f"" y=""%.1f"" text-anchor=""middle"">%s</text>", ...
        ternary(n.dim, "", " on"), x + w - 8 - bw / 2, y + 17, esc(n.badge));
end
for j = 1:numel(n.lines)
    parts = parts + sprintf("<text class=""%s"" x=""%.1f"" y=""%.1f"">%s</text>", dc, x + 14, y + 18 + 14 * j, esc(n.lines(j)));
end
h = "<g class=""node c-" + n.key + """ data-id=""" + n.id + """>" ...
    + "<g class=""hit" + ternary(n.dim, " dim", "") + """" + navAttr(n.target, n.title) + ">" + parts + "</g>";

if ~isempty(n.outs)
    cx = x + w / 2;
    P = n.outs;
    h = h + "<g class=""wire" + ternary(n.dim, " dim", "") + """>" ...
        + sprintf("<path class=""ln"" d=""M%.1f %.1fV%.1f""/>", cx, y + n.boxH, P(end).y) ...
        + joinHTML(arrayfun(@(p) sprintf("<path class=""head"" d=""M%.1f %.1fL%.1f %.1fL%.1f %.1fZ""/>", ...
            cx - 4.5, p.y - 8, cx + 4.5, p.y - 8, cx, p.y), P, "UniformOutput", false)) + "</g>";
    for j = 1:numel(P)
        p = P(j);
        body = sprintf("<rect class=""pbox"" x=""%.1f"" y=""%.1f"" width=""%.1f"" height=""%.1f"" rx=""9""/>", p.x, p.y, p.w, p.h) ...
            + sprintf("<text class=""pt"" x=""%.1f"" y=""%.1f"">%s</text>", p.x + 9, p.y + 14, esc(p.title));
        for i = 1:numel(p.lines)
            body = body + sprintf("<text class=""pd"" x=""%.1f"" y=""%.1f"">%s</text>", p.x + 9, p.y + 14 + 13 * i, esc(p.lines(i)));
        end
        cls = "hit pill" + ternary(p.kind == "out", "", " " + p.kind) + ternary(p.dim, " dim", "");
        h = h + "<g class=""" + cls + """" + navAttr(p.target, p.title) + ">" + body + "</g>";
    end
end
h = h + "</g>";
end


function h = joinHTML(parts)
%joinHTML  Concatenate a cell array of HTML strings.
h = join([string.empty(1, 0), parts{:}], "");
if isempty(h); h = ""; end
end


function a = navAttr(target, title)
%navAttr  The attributes setup() looks for to make a box open its controls.
if strlength(target) == 0
    a = "";
else
    a = " data-nav=""" + esc(target) + """ data-title=""" + esc(title) + """";
end
end


function h = legendHTML()
items = [ ...
    "<span class=""lg lg-src"">recording</span>", ...
    "<span class=""lg lg-in"">input</span>", ...
    "<span class=""lg lg-step"">step</span>", ...
    "<span class=""lg lg-out"">file written</span>", ...
    "<span class=""lg lg-link"">artifact periods</span>", ...
    "<span class=""lg lg-off"">off in this config</span>", ...
    "<span class=""lg lg-step lg-dim"">disabled step</span>", ...
    "<span class=""la""><i></i>read</span>", ...
    "<span class=""la off""><i></i>not read with this config</span>"];
h = "<div class=""legend"">" + join(items, "") + "</div>";
end


function s = js()
%js  Page script. setup() is called only by the app's HTML component, so
%   only there does a click open a box's controls (as on the detail view),
%   and is the zoom kept (flowZoom). The tracing on hover or focus runs in a
%   saved page too.
s = join([ ...
    "function setup(htmlComponent) {"
    "  document.body.classList.add('live');"
    "  flowZoom.restore(htmlComponent.Data);"
    "  flowZoom.onChange(function (v) { htmlComponent.sendEventToMATLAB('zoom', v); });"
    "  var boxes = document.querySelectorAll('[data-nav]');"
    "  for (var i = 0; i < boxes.length; i++) {"
    "    (function (el) {"
    "      el.setAttribute('tabindex', '0');"
    "      el.setAttribute('role', 'button');"
    "      var open = function (e) {"
    "        e.preventDefault();"
    "        el.classList.add('picked');"
    "        window.setTimeout(function () { el.classList.remove('picked'); }, 500);"
    "        htmlComponent.sendEventToMATLAB('navigate', {"
    "          nav: el.getAttribute('data-nav'), title: el.getAttribute('data-title')});"
    "      };"
    "      el.addEventListener('click', open);"
    "      el.addEventListener('keydown', function (e) {"
    "        if (e.key === 'Enter' || e.key === ' ') { open(e); }"
    "      });"
    "    })(boxes[i]);"
    "  }"
    "}"
    "(function () {"
    "  var edges = document.querySelectorAll('.edge'), nodes = document.querySelectorAll('.node');"
    "  function trace(id) {"
    "    var lit = {}; lit[id] = true;"
    "    for (var i = 0; i < edges.length; i++) {"
    "      var a = edges[i].getAttribute('data-from'), b = edges[i].getAttribute('data-to');"
    "      var on = a === id || b === id;"
    "      if (on) { lit[a] = true; lit[b] = true; }"
    "      edges[i].classList.toggle('lit', on);"
    "    }"
    "    for (var j = 0; j < nodes.length; j++) {"
    "      nodes[j].classList.toggle('lit', !!lit[nodes[j].getAttribute('data-id')]);"
    "    }"
    "    document.body.classList.add('trace');"
    "  }"
    "  function untrace() { document.body.classList.remove('trace'); }"
    "  for (var k = 0; k < nodes.length; k++) {"
    "    (function (n) {"
    "      var id = n.getAttribute('data-id');"
    "      n.addEventListener('mouseenter', function () { trace(id); });"
    "      n.addEventListener('mouseleave', untrace);"
    "      n.addEventListener('focusin', function () { trace(id); });"
    "      n.addEventListener('focusout', untrace);"
    "    })(nodes[k]);"
    "  }"
    "})();"
    ], newline);
end


function s = css()
s = join([ ...
    "body{font:12px/1.35 'Segoe UI',system-ui,sans-serif;color:#1f2328;background:#f4f5f7;margin:0;padding:10px 14px}"
    "h1{font-size:15px;margin:0 0 6px}"
    ".legend{display:flex;flex-wrap:wrap;align-items:center;gap:6px}"
    ".lg{display:inline-block;padding:2px 8px;border:1px solid #afb8c1;border-radius:6px;background:#fff;font-size:11.5px}"
    ".lg-src{background:#24292f;border-color:#24292f;color:#fff}"
    ".lg-in{border-left:4px solid #8c959f}"
    ".lg-step{background:#e3f0fa;border:2px solid #1f7fbf;border-left-width:6px;font-weight:600}"
    ".lg-out{border-color:#1f7fbf;border-radius:10px}"
    ".lg-link{border-color:#d9822b;background:#fdf0e2;border-radius:10px}"
    ".lg-off{border-style:dashed;background:#f6f8fa;color:#8c959f}"
    ".lg-dim{opacity:.5}"
    ".la{display:inline-flex;align-items:center;gap:5px;font-size:11.5px;color:#57606a;margin-left:4px}"
    ".la i{display:inline-block;width:26px;border-top:2px solid #57606a}"
    ".la.off i{border-top:2px dashed #afb8c1}"
    ".note{font-size:11px;color:#57606a;margin:6px 0 0}"
    ".zoomview{margin-top:10px;background:#fff;border:1px solid #d0d7de;border-radius:8px}"
    ".zoomstage{width:max-content;padding:0}"
    ".flow{display:block}"
    % Colours: the step (or input) each box and arrow belongs to, as on the
    % detail view and the Run tab's diagram.
    ".c-rec{--acc:#57606a;--tint:#24292f}"
    ".c-epsych{--acc:#8c959f;--tint:#fff}"
    ".c-probemap{--acc:#1b7c83;--tint:#fff}"
    ".c-probe{--acc:#1b7c83;--tint:#e1f3f4}"
    ".c-behavior{--acc:#bf3989;--tint:#fbe9f3}"
    ".c-artifacts{--acc:#d9822b;--tint:#fdf0e2}"
    ".c-sorting{--acc:#8250df;--tint:#f1eafd}"
    ".c-signals{--acc:#1f7fbf;--tint:#e3f0fa}"
    ".c-spikes{--acc:#2e9e5b;--tint:#e3f5ea}"
    ".c-export{--acc:#6e7781;--tint:#eef0f2}"
    ".flow text{font-family:'Segoe UI',system-ui,sans-serif}"
    ".box.src{fill:#24292f;stroke:#24292f}"
    ".box.in{fill:#fff;stroke:#afb8c1;stroke-width:1.2}"
    ".box.step{fill:var(--tint);stroke:var(--acc);stroke-width:1.8}"
    ".bar{fill:var(--acc)}"
    ".t{font-size:12.5px;font-weight:600;fill:#1f2328}"
    ".d{font-size:11px;fill:#57606a}"
    ".t.src{fill:#fff}"
    ".d.src{fill:#d0d7de}"
    ".badge{fill:#eaeef2}"
    ".badge.on{fill:#dafbe1}"
    ".bt{font-size:10px;fill:#57606a}"
    ".bt.on{fill:#116329}"
    ".pbox{fill:#fff;stroke:var(--acc);stroke-width:1.3}"
    ".pt{font-size:11.5px;font-weight:600;fill:#1f2328}"
    ".pd{font-size:10.5px;fill:#57606a}"
    ".pill.link .pbox{fill:#fdf0e2;stroke:#d9822b}"
    ".pill.off .pbox{fill:#f6f8fa;stroke:#afb8c1;stroke-dasharray:4 3}"
    ".pill.off .pt,.pill.off .pd{fill:#8c959f}"
    ".ln{fill:none;stroke:var(--acc);stroke-width:1.8}"
    ".head{fill:var(--acc);stroke:none}"
    ".edge.off .ln{stroke:#afb8c1;stroke-dasharray:5 4}"
    ".edge.off .head{fill:#afb8c1}"
    ".dim{opacity:.45}"
    % Hover / focus a box: its arrows and the boxes at their other ends stay lit.
    "body.trace .edge{opacity:.12}"
    "body.trace .edge.lit{opacity:1}"
    "body.trace .edge.lit .ln{stroke-width:2.8}"
    "body.trace .node{opacity:.3}"
    "body.trace .node.lit{opacity:1}"
    % Clickable only in the app: setup() adds .live to <body> (see js()).
    ".hint{display:none;font-size:11px;color:#57606a;margin:2px 0 0}"
    "body.live .hint{display:block}"
    "body.live .hit[data-nav]{cursor:pointer}"
    ".hit:focus{outline:none}"
    "body.live .hit[data-nav]:hover .box,body.live .hit[data-nav]:hover .pbox{stroke-width:3}"
    ".hit:focus-visible .box,.hit:focus-visible .pbox{stroke:#1f7fbf;stroke-width:3}"
    ".hit.picked .box,.hit.picked .pbox{stroke:#1f7fbf;stroke-width:3.5}"
    ], "");
end


% =========================================================================
% text helpers
% =========================================================================

function out = wrapLines(lines, maxW, px)
%wrapLines  Break each line at spaces to fit MAXW pixels (at PX font size);
%   a word too long for a line of its own breaks after a _ - / . where it can.
out = strings(1, 0);
for s = reshape(string(lines), 1, [])
    cur = "";
    for word = reshape(split(s, " "), 1, [])
        cand = ternary(cur == "", word, cur + " " + word);
        if textWidth(cand, px) <= maxW
            cur = cand;
            continue
        end
        if cur ~= ""; out(end+1) = cur; end %#ok<AGROW>
        rest = word;
        while textWidth(rest, px) > maxW
            [head, rest] = breakWord(rest, maxW, px);
            out(end+1) = head; %#ok<AGROW>
        end
        cur = rest;
    end
    if cur ~= ""; out(end+1) = cur; end %#ok<AGROW>
end
end


function [head, rest] = breakWord(w, maxW, px)
c = char(w);
n = 1;
while n < numel(c) && textWidth(c(1:n + 1), px) <= maxW
    n = n + 1;
end
cut = find(ismember(c(1:n), '_-/.\'), 1, "last");
if ~isempty(cut) && cut > n / 2; n = cut; end
head = string(c(1:n));
rest = string(c(n + 1:end));
end


function s = fitLine(s, maxW, px)
%fitLine  S, cut short with an ellipsis if it is wider than MAXW.
if textWidth(s, px) <= maxW; return; end
c = char(s);
while ~isempty(c) && textWidth(string(c) + "...", px) > maxW
    c(end) = [];
end
s = string(c) + "...";
end


function w = textWidth(s, px)
%textWidth  Rough width of S in Segoe UI at PX pixels (a little generous).
c = char(s);
em = 0.53 * ones(1, numel(c));
em(isstrprop(c, "upper")) = 0.64;
em(isstrprop(c, "digit")) = 0.56;
em(ismember(c, 'mwMW@%')) = 0.86;
em(ismember(c, 'ijlt.,:;''|!()[] ')) = 0.3;
em(ismember(c, 'frs-/_')) = 0.42;
w = sum(em) * px;
end


function s = esc(s)
%esc  HTML-escape, then typeset the ASCII arrows / comparisons / units.
s = string(s);
s = replace(s, "&", "&amp;");
s = replace(s, "<", "&lt;");
s = replace(s, ">", "&gt;");
s = replace(s, """", "&quot;");
s = replace(s, "-&gt;", "&rarr;");
s = replace(s, "&gt;=", "&ge;");
s = replace(s, "&lt;=", "&le;");
s = replace(s, "+/-", "&plusmn;");
s = regexprep(s, " u([Vm])\>", " &micro;$1");
end


function t = joinOr(v, fallback)
if isempty(v); t = string(fallback); else; t = join(string(v), ", "); end
end


function t = fileName(p)
[~, b, e] = fileparts(p);
t = string(b) + string(e);
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
