function [html, summary, model] = overview(cfg, d, opts)
%overview  The pipeline diagram's overview: how data flows through the steps, as a standalone HTML page.
%   [HTML, SUMMARY, MODEL] = PipelineDiagram.overview(CFG, D) draws the
%   pipeline config CFG (an EphysPipelineConfig) for the dataset D (an
%   EphysDataset, or [] for none). It is the pipeline app's Diagram
%   tab, "Data flow" (EphysPipelineApp.flowOverviewHTML), and works
%   without the app.
%
%   It draws every pipeline step
%   (Probe check, Behavior, Artifacts, Sorting, Signals, Spikes, Export,
%   Analysis) as one box, with the files it writes hung under it, below the inputs (the
%   raw recording with its manifest, the Epsych2 sessions, the probe map).
%   An arrow runs from each input or written file to every step that reads
%   it, in the color of whatever wrote it. Copy outputs (the Transfer
%   section: each dataset's outputs copied or moved elsewhere, in the
%   background) is the last box, reading every file a step writes; it is
%   faded while the section is off. An arrow the working config
%   leaves off is dashed (Signals without BlankArtifacts does not read the
%   artifact periods, Export reads the sorted units only with
%   IncludeUnits, ...); a disabled step, and every arrow into it, is faded.
%   PipelineDiagram.overview(CFG, D, HideUnused=true) leaves out what the
%   config does not use: the disabled steps (an Artifacts step with detection
%   off stays while its manual periods are read), the files not written, the
%   arrows not read, and the inputs nothing then reads. The rows close up and
%   the arrows are routed afresh.
%   PipelineDiagram.overview(CFG, D, Direction="horizontal") draws it from left
%   to right, a column per stage of the flow, instead of from top to bottom.
%
%   The parameters themselves are on the "Every parameter" view
%   (PipelineDiagram.detail). Hovering a box lights its arrows and the boxes at
%   their other ends, in the app and in a saved page.
%
%   The page is one SVG laid out here rather than by the browser, drawn at
%   its own size in a viewport that opens fitted to it and zooms and pans
%   (zoomFrame). The boxes
%   sit on a fixed grid of five columns, a row per stage of the flow (the
%   Analysis step alone in the next to last one, Copy outputs in the last), and
%   the arrows are routed at right angles through the gaps between rows and
%   columns: none runs through a box, and no two sources share a line
%   (they may cross). Each gap between rows gives every source leaving it,
%   and every target reached through a side lane, a track of its own; the
%   tracks are ordered to cross as few arrows as they can.
%
%   Each box names the control(s) behind it (data-nav), as on the detail
%   view, so a click in the app opens them (onFlowNavigate). It reads only
%   CFG, the dataset D and the Analysis step's analysis config (for which
%   outputs its figures read). SUMMARY is a one-line description
%   for the tab. MODEL holds the geometry the page draws, for tests:
%     nodes  id, title, target, rect [x y w h] (the box and the files hung
%            under it)
%     edges  from, to (node ids), on (read under this config), dim (into a
%            disabled step), points ([n x 2] polyline, ending on the top of
%            the target box, or its left from left to right)
%
%   See also PipelineDiagram.detail, PipelineDiagram.zoomFrame,
%   EphysPipelineApp.flowOverviewHTML.

arguments
    cfg (1,1) EphysPipelineConfig
    d = []
    opts.HideUnused (1,1) logical = false
    opts.Direction (1,1) string {mustBeMember(opts.Direction, ["vertical" "horizontal"])} = "vertical"
end
dsName = "<Name>";
if ~isempty(d); dsName = d.Name; end

N = [inputNodes(cfg, d), stepNodes(cfg, dsName)];
E = edgeList(cfg);
for k = 1:numel(E)   % an arrow into a disabled step fades with it
    E(k).dim = N([N.id] == E(k).to).dim;
end
steps = N([N.kind] == "step" & [N.id] ~= "transfer");   % Copy outputs is no pipeline step
nOn = nnz(~[steps.dim]);
summary = sprintf("%d of %d steps enabled", nOn, numel(steps));
nBefore = numel(N) + numel(E) + sum(arrayfun(@(n) numel(n.outs), N));
if opts.HideUnused
    [N, E] = gridHide(N, E);
    nHidden = nBefore - (numel(N) + numel(E) + sum(arrayfun(@(n) numel(n.outs), N)));
    summary = summary + sprintf(" | %d unused item(s) hidden", nHidden);
end
[N, E, W, H] = gridPlace(N, E, Direction=opts.Direction);
if ~isempty(d)
    summary = summary + " | recording: " + d.Name;
end

pageTitle = "Preprocessing data flow: " + cfg.Name;
svg = sprintf("<svg class=""flow"" xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 %g %g"" width=""%g"" height=""%g"" role=""img"" aria-label=""%s"">", ...
    W, H, W, H, gridEsc(pageTitle)) ...
    + gridJoin([arrayfun(@(e) gridEdgeSVG(e, @nodeName), E, "UniformOutput", false), arrayfun(@gridNodeSVG, N, "UniformOutput", false)]) ...
    + "</svg>";
zoom = PipelineDiagram.zoomFrame("overview" + ternary(opts.Direction == "horizontal", "_lr", ""), "fit");
body = "<h1>" + gridEsc(pageTitle) + "</h1>" + legendHTML() ...
    + "<div class=""note"">Arrows carry data in the color of what wrote it. Hover a box to trace what it reads and writes. Scroll to zoom, drag to pan.</div>" ...
    + ternary(opts.HideUnused, "<div class=""note"">Hiding what this config does not use: disabled steps, files not written, arrows not read.</div>", "") ...
    + "<div class=""hint"">Click any box to open the setting it draws.</div>" ...
    + zoom.open + svg + zoom.close ...
    + "<script>" + zoom.js + newline + js() + "</script>";
html = "<!DOCTYPE html><html><head><meta charset=""utf-8""><title>" + gridEsc(pageTitle) + "</title><style>" ...
    + zoom.css + gridCSS() + "</style></head><body>" + body + "</body></html>";

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
switch cfg.Reference.Mode
    case "car"; ref = "common reference: average (CAR)";
    case "cmr"; ref = "common reference: median (CMR)";
    case "wcar"; ref = "common reference: weighted CAR";   % fits one line of the box
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
artifacts.outs = pill("link", "Artifact periods", periods, "ArtManualTable,ArtMarkButton", true);
artifacts.outs.dim = false;   % the manual periods apply with detection off too

S = cfg.Sorting;
lines = EphysDataset.sorterLabel(S.Sorter) + " on a .bin of the recording";
if S.Execution == "background"
    lines(end+1) = sprintf("in the background, %d at a time", S.MaxConcurrent);
else
    lines(end+1) = "waits for each sort";
end
if S.DryRun; lines(end+1) = "dry run: writes the run files only"; end
sorting = step("sorting", 2, 3, "Sorting", S.Enabled, lines, "SortEnableCheckBox,ExecModeDropDown,DryRunCheckBox");
folder = "kilosort4/";
if S.Sorter ~= "kilosort4"; folder = "si_" + S.Sorter + "/"; end
sorting.outs = pill("out", "Sorted units", folder + " (phy-ready)", "SortDatasetDropDown,SortUseFolderButton,SortPhyButton", true);

G = cfg.Signals;
types = ["LFP" "MUA" "SPIKE" "AUX"];
types = types([G.LFP G.MUA G.SPIKE G.AUX]);
if isempty(types)
    lines = "no signal ticked: events only";
else
    lines = join(types, " + ") + " + digital events";
end
lines(end+1) = ternary(G.BlankArtifacts, "artifact periods erased first", "artifact periods left in");
wcar = ["LFP" "MUA" "SPIKE"];
wcar = wcar([G.LFP G.MUA G.SPIKE] & [G.LFP_Reference G.MUA_Reference G.SPIKE_Reference]);
if cfg.Reference.Mode == "wcar" && ~isempty(wcar)
    lines(end+1) = "weighted CAR: " + join(wcar, " + ");
end
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
lines = "threshold detection";
switch K.ArtifactMode
    case "reject"; lines(end+1) = "rejects events in artifact periods";
    case "erase";  lines(end+1) = "artifact periods erased first";
    otherwise;     lines(end+1) = "ignores the artifact periods";
end
spikes = step("spikes", 2, 4, "Spikes", K.Enabled, lines, "SpkEnableCheckBox");
spikes.outs = pill("out", "Spikes file", dsName + K.Suffix + ".mat", ...
    "SpkOutputDirField,SpkSuffixField,SpkOverwriteCheckBox,SpkMatVersionDropDown", true);

X = cfg.Export;
lines = "signals: " + joinOr(X.Signals, "all") + ternary(X.IncludeEvents, ", with events", "");
lines(end+1) = "one file per format";
export = step("export", 3, 2, "Export", X.Enabled, lines, "ExpEnableCheckBox");
if ismember("nwb", X.Formats)
    export.outs(end+1) = pill("out", "NWB file", [dsName + ".nwb", "pynwb, nwbinspector"], ...
        "ExpNWBCheckBox,ExpOutputDirField", false);
end
if isempty(export.outs)
    export.outs = pill("off", "No format ticked", "nothing is written", "ExpNWBCheckBox", false);
end

An = cfg.Analysis;
use = analysisUse(cfg);
if use.file == ""
    lines = "no analysis config chosen";
else
    lines = ["runs " + use.file, use.figures];
end
% A row of its own, bottom left: of the free cells this crosses the fewest arrows.
analysis = step("analysis", 4, 0, "Analysis", An.Enabled, lines, "AnaEnableCheckBox,AnaConfigField");
if An.Figures
    analysis.outs = pill("out", "Figure files", ["each figure's pages", "as its Export settings say"], "AnaFiguresCheckBox", false);
else
    analysis.outs = pill("off", "Figure files", "not written", "AnaFiguresCheckBox", false);
end
if An.Report
    analysis.outs(end+1) = pill("out", "Report", ["HTML / PDF over the datasets", "as its Report settings say"], "AnaReportCheckBox", false);
else
    analysis.outs(end+1) = pill("off", "Report", "not written", "AnaReportCheckBox", false);
end

% Copying the outputs elsewhere (the Transfer section): not a step but
% the last thing to read every file, a row of its own under them.
T = cfg.Transfer;
lines = ternary(T.Method == "move", "moves", "copies") + " each output " ...
    + ternary(T.When == "step", "once its step has written it", "once the run is over");
lines(end+1) = "in the background (robocopy), " + ternary(T.Verify == "hash", "SHA-256 checked", "size checked");
if T.Method == "move"; lines(end+1) = "removed here once the run is over"; end
transfer = step("transfer", 5, 2, "Copy outputs", T.Enabled, lines, ...
    "RunTransferCheckBox,RunTransferMethodDropDown,RunTransferWhenDropDown,RunTransferHashCheckBox");
dest = strtrim(T.Destination);
if dest == ""; dest = "<folder>"; end
switch T.IfExists
    case "overwrite"; there = "files already there replaced";
    case "skip";      there = "files already there kept";
    otherwise;        there = "a new <session>_v2 when it is there";
end
transfer.outs = pill("out", "Copies", [dest + "\<subject>\<session>", there], ...
    "RunTransferDestField,RunTransferIfExistsDropDown", false);

N = [probe, behavior, artifacts, sorting, signals, spikes, export, analysis, transfer];
end


function u = analysisUse(cfg)
%analysisUse  What the Analysis step's config reads, from its enabled figures and session figures:
%   units / detected (any figure that observes, or has a layer of, sorted
%   units / detected spikes; true when the config cannot be read), the
%   file's name and a line on its figures.
u = struct('file', "", 'figures', "", 'units', true, 'detected', true);
f = strtrim(cfg.Analysis.ConfigFile);
if f == ""; return; end
[~, b, x] = fileparts(f);
u.file = string(b) + string(x);
acfg = EphysPipelineConfig.loadAnalysisConfig(f);
if isempty(acfg)
    u.figures = ternary(isfile(f), "cannot be read", "not found");
    return
end
[u.units, u.detected, u.figures] = figureUse(acfg);
end


function E = edgeList(cfg)
%edgeList  Every read of an input or a written file, whether this config
%   makes it or not (ON). The arrows into one step are listed left to right
%   in the order they reach its top. LANE routes an arrow that skips a row:
%   NaN drops it straight onto its target through the empty cells above it;
%   otherwise it runs down the lane (grid units: column k's center, or
%   k + 0.5 for the gap right of column k), then across to its target.
B = cfg.Behavior; G = cfg.Signals; K = cfg.Spikes; X = cfg.Export;
use = analysisUse(cfg);
nwbTrials = ismember("nwb", X.Formats) && X.NWB.Trials;
if K.ArtifactMode == "none"
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
    edge("artifacts", "spikes", K.ArtifactMode ~= "none", toSpikes), ...
    edge("rec", "spikes", true, "the recording, for threshold detection", 3.5), ...
    edge("behavior", "export", nwbTrials && B.WriteFile, ternary(nwbTrials, ternary(B.WriteFile, ...
        "the behavior file's paired trials, the NWB file's trials", "off: no behavior file to take the NWB trials from"), ...
        "off: no NWB trials"), 0), ...
    edge("signals", "export", true, "the extract: signals and events", NaN), ...
    edge("sorting", "export", X.IncludeUnits, ternary(X.IncludeUnits, "the sorted units", "off: Export.IncludeUnits is off"), NaN), ...
    edge("behavior", "analysis", true, "the paired trials: alignment, selection, grouping, tuning"), ...
    edge("signals", "analysis", true, "the extract: the events, and the LFP / MUA / SPIKE / AUX the figures read"), ...
    edge("sorting", "analysis", use.units, ternary(use.units, "the sorted units", "off: no figure of the analysis config reads sorted units")), ...
    edge("spikes", "analysis", use.detected, ternary(use.detected, "the detected spikes", "off: no figure of the analysis config reads detected spikes"), 3)];

% Copy outputs reads every file written, each down a lane of its own; the
% list's order (its ports, left to right) follows where they arrive from.
T = cfg.Transfer; A = cfg.Artifacts; An = cfg.Analysis; S = cfg.Sorting;
to = ternary(T.Method == "move", ", moved to ", ", copied to ") + "<folder>\<subject>\<session>";
cached = A.Enabled && A.CacheIntervals;
E = [E, ...
    edge("analysis", "transfer", An.Figures, ternary(An.Figures, "each dataset's figure files" + to, ...
        "off: Analysis.Figures is off")), ...
    edge("behavior", "transfer", B.WriteFile, ternary(B.WriteFile, "the behavior file" + to, ...
        "off: Behavior.WriteFile is off"), 0.5), ...
    edge("signals", "transfer", true, "the signal files" + to, 1), ...
    edge("export", "transfer", ~isempty(X.Formats), ternary(~isempty(X.Formats), "the export files" + to, ...
        "off: no export format ticked")), ...
    edge("artifacts", "transfer", cached, ternary(cached, "the artifact cache" + to, ...
        "off: no detection cached (Artifacts.Enabled, CacheIntervals)"), 2.5), ...
    edge("sorting", "transfer", ~S.DryRun, ternary(~S.DryRun, "the sort folder (never the .bin), once the sort has finished" + to, ...
        "off: Sorting.DryRun sorts nothing"), 3.5), ...
    edge("spikes", "transfer", true, "the spikes file" + to, 4)];
end


% =========================================================================
% node helpers
% =========================================================================

function n = node(id, key, kind, row, col, title, lines, target)
%node  One box: kind src (the recording) | in (another input) | step.
%   KEY picks its color (c-<key>), TARGET what a click opens (see
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
% rendering
% =========================================================================

function t = nodeName(id)
names = dictionary(["epsych" "rec" "probemap" "probe" "behavior" "artifacts" "sorting" "signals" "spikes" "export" "analysis" "transfer"], ...
    ["Epsych2 sessions" "Raw recording" "Probe map" "Probe check" "Behavior file" "Artifact periods" ...
     "Sorted units" "Signal files" "Spikes file" "Export" "Analysis" "Copy outputs"]);
t = names(id);
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
    gridTraceJS()], newline);
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
