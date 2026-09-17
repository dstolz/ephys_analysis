function [html, summary] = flowChartHTML(obj)
%flowChartHTML  Flow chart of the working config as a standalone HTML page.
%   [HTML, SUMMARY] = app.flowChartHTML() draws one tree per step that reads
%   the raw recording -- Artifacts, Sorting (SpikeInterface + Kilosort4),
%   Signals (LFP / MUA / SPIKE / AUX / digital events) and Spikes (threshold
%   detection) -- from the recording through each stage, with its filter,
%   reference and detection parameters, to what the step writes. The steps
%   that read those outputs instead of the recording (sorted units for the
%   Spikes file, Export) follow as downstream trees. Stages the config leaves
%   off are drawn dashed; disabled steps are faded. Artifact periods feeding
%   Sorting / Spikes are marked in the Artifacts colour.
%
%   It reads only obj.Config and the active dataset (for the recording's
%   rate, channel count, probe and exclusions), so it mirrors what
%   EphysPipeline would run. SUMMARY is a one-line description for the tab.
%
%   See also EphysDataset.deriveSignals, EphysDataset.detectSpikes,
%   EphysDataset.detectArtifacts, EphysDataset.runSpikeInterface.

cfg = obj.Config;
d = obj.currentDataset();
raw = rawNode(d);

cards = [ ...
    card("artifacts", "Artifacts", cfg.Artifacts.Enabled, artifactsTree(cfg, raw), ...
        ternary(cfg.Artifacts.Enabled, "", "Detection is off: only the manual periods reach Sorting / Spikes.")), ...
    card("sorting", "Sorting", cfg.Sorting.Enabled, sortingTree(cfg, raw, d), sortingNote(cfg.Sorting)), ...
    card("signals", "Signals", cfg.Signals.Enabled, signalsTree(cfg, raw), ""), ...
    card("spikes", "Spikes", cfg.Spikes.Enabled && cfg.Spikes.Source ~= "sorted", spikesTree(cfg, raw), ...
        ternary(cfg.Spikes.Source == "sorted", "Source is 'sorted': no threshold detection runs.", ""))];
down = [ ...
    card("spikes", "Spikes: sorted units", cfg.Spikes.Enabled && cfg.Spikes.Source ~= "detect", unitsTree(cfg), ...
        ternary(cfg.Spikes.Source == "detect", "Source is 'detect': sorted units are not read.", "")), ...
    card("export", "Export", cfg.Export.Enabled, exportTree(cfg), "")];

nOn = sum([cards.enabled]);
summary = sprintf("%d of %d raw-data step(s) enabled", nOn, numel(cards));
if ~isempty(d)
    summary = summary + " | recording: " + d.Name;
end

pageTitle = "Preprocessing flow: " + cfg.Name;
body = "<h1>" + esc(pageTitle) + "</h1>" + legendHTML() ...
    + "<h2>From the raw recording</h2><div class=""cards"">" + joinHTML(arrayfun(@cardHTML, cards, "UniformOutput", false)) + "</div>" ...
    + "<h2>Downstream (reads step outputs)</h2><div class=""cards"">" + joinHTML(arrayfun(@cardHTML, down, "UniformOutput", false)) + "</div>";
html = "<!DOCTYPE html><html><head><meta charset=""utf-8""><title>" + esc(pageTitle) + "</title><style>" ...
    + css() + "</style></head><body>" + body + "</body></html>";
end


% =========================================================================
% trees
% =========================================================================

function n = rawNode(d)
if isempty(d)
    n = node("src", "Raw recording", "amplifier channels (no active dataset)");
    return
end
info = string(d.RecordingFormat);
if isfinite(d.Fs); info = sprintf("%g kHz, ", d.Fs / 1000) + info; end
if isfinite(d.NumChannels); info = sprintf("%d ch, ", d.NumChannels) + info; end
n = node("src", "Raw recording", [d.Name, info]);
end


function n = artifactsTree(cfg, raw)
A = cfg.Artifacts;
if A.Filter
    filt = node("op", "Butterworth " + A.FilterType, ...
        [numList(A.FilterCutoff) + " Hz, order " + A.FilterOrder, "detector runs on the filtered copy"]);
else
    filt = node("off", "Detection filter", "off (broadband)");
end
thr = A.Threshold;
switch A.Method
    case "rms"
        det = node("op", "Running RMS", ["window " + msOrAuto(A.RmsWindowMs, "auto (~1 ms)"), ...
            "flag > " + numOr(thr, "9") + " robust SD above baseline"]);
    case "mad"
        det = node("op", "Robust z-score", ["|x - median| / (1.4826 MAD)", "flag z > " + numOr(thr, "8")]);
    case "microvolts"
        det = node("op", "Absolute amplitude", "flag |x| > " + numOr(thr, "1500") + " uV");
    otherwise
        det = node("op", "Common-mode mean", ["mean across channels", "flag |mean| > " + numOr(thr, "1500") + " uV"]);
end
if A.Method == "commonmode"
    coinc = node("off", "Channel coincidence", "n/a for commonmode");
else
    coinc = node("op", "Channel coincidence", ">= " + A.MinChannels + " channel(s) at once");
end
merge = onOff(A.MergeGapMs > 0, "Merge gaps", sprintf("gaps <= %g ms stitched", A.MergeGapMs), "off (0 ms)");
pad = onOff(A.PadMs > 0, "Pad intervals", sprintf("+/- %g ms", A.PadMs), "off (0 ms)");
out = node("out", "Automatic intervals", ["[t_on t_off] s", ...
    ternary(A.CacheIntervals, "cached while recording + settings match", "recomputed by each step")]);

toSort = linkNode(cfg.Sorting.Enabled, A.Enabled && A.ApplyToSorting, "Silence in Sorting", "ApplyToSorting");
toSpk  = linkNode(cfg.Spikes.Enabled && cfg.Spikes.Source ~= "sorted" && cfg.Spikes.RejectArtifacts, ...
    A.Enabled && A.ApplyToSpikes, "Reject in Spikes", "ApplyToSpikes");
manual = node("data", "+ manual periods", "marked on Visualize; always applied", {toSort, toSpk});
out.children = {manual};

n = chain({raw, node("op", "Read in chunks", ["one file / bounded window per chunk", parallelText(cfg.Parallel)]), ...
    filt, det, coinc, merge, pad, out});
end


function n = linkNode(stepOn, applyAuto, title, field)
if ~stepOn
    n = node("off", title, "step not run");
elseif applyAuto
    n = node("link", title, "manual + automatic");
else
    n = node("link", title, "manual only (" + field + " or detection off)");
end
end


function n = sortingTree(cfg, raw, d)
S = cfg.Sorting; SI = S.SI; K = S.KS4;
A = cfg.Artifacts;

if K.tmin > 0 || isfinite(K.tmax)
    crop = node("op", "Crop", sprintf("%g - %s s", K.tmin, ternary(isfinite(K.tmax), sprintf("%g", K.tmax), "end")));
else
    crop = node("off", "Crop", "whole recording");
end

if ~isempty(d) && d.ProbeFile ~= ""
    probe = fileName(d.ProbeFile);
elseif cfg.Probe.DefaultProbeFile ~= ""
    probe = "default: " + fileName(cfg.Probe.DefaultProbeFile);
else
    probe = "per-dataset probe (none set)";
end

if SI.Filter
    bp = node("op", "Bandpass filter", sprintf("%g - %g Hz (spre.bandpass_filter)", SI.FilterFreqMin, SI.FilterFreqMax));
else
    bp = node("off", "Bandpass filter", "off (Kilosort4 filters)");
end

bad = "manifest exclusions";
if ~isempty(d) && ~isempty(d.ExcludeChannels)
    bad = bad + ": " + compactList(d.ExcludeChannels);
end
if SI.DetectBadChannels
    bad(end+1) = "+ detect_bad_channels (" + SI.BadChannelMethod + ")";
    if ~SI.Filter; bad(end+1) = "  on a 300 Hz high-passed copy"; end
end
bad(end+1) = "-> " + SI.BadChannelAction;
badNode = node("op", "Bad channels", bad);

if SI.CommonReference
    car = node("op", "Common reference", "global " + SI.ReferenceOperator);
    ksCar = node("off", "KS4 CAR", "do_CAR off (already referenced)");
else
    car = node("off", "Common reference", "off (Kilosort4 CAR)");
    ksCar = node("op", "KS4 CAR", "do_CAR (common average)");
end

sil = node("link", "Silence artifact periods", ...
    ternary(A.Enabled && A.ApplyToSorting, "manual + automatic", "manual periods only"));

hp = node("op", "KS4 high-pass", sprintf("%g Hz", K.highpass_cutoff));
art = onOff(isfinite(K.artifact_threshold), "KS4 artifact threshold", ...
    sprintf("zero batches >= %g ADC counts", K.artifact_threshold), "off");
white = node("op", "Whitening", [sprintf("%d nearest channels", K.whitening_range), ...
    sprintf("batch %d samples", K.batch_size)]);
drift = onOff(K.nblocks > 0, "Drift correction", ...
    [sprintf("nblocks %d", K.nblocks), sprintf("sig_interp %g um", K.sig_interp)], "off (nblocks = 0)");
det = node("op", "Template matching", [sprintf("Th_universal %g, Th_learned %g", K.Th_universal, K.Th_learned), ...
    sprintf("Th_single_ch %g, nt %d samples", K.Th_single_ch, K.nt)]);
clu = node("op", "Clustering", sprintf("ACG %g, CCG %g", K.acg_threshold, K.ccg_threshold));
out = node("out", "Sorted units", ["kilosort4/si/sorter_output", "phy-ready"]);

n = chain({raw, ...
    node("stage", "SpikeInterface", ["read the recording", "unsigned -> signed"]), crop, ...
    node("op", "Attach probe map", probe), bp, badNode, car, sil, ...
    node("stage", "Kilosort4", "run_sorter('kilosort4')"), hp, ksCar, art, white, drift, det, clu, out});
end


function txt = sortingNote(S)
txt = "Runs " + S.Execution;
if S.DryRun; txt = txt + ", dry run (writes run files only)"; end
if S.SkipExisting; txt = txt + ", skips datasets already sorted"; end
txt = txt + ".";
end


function n = signalsTree(cfg, raw)
G = cfg.Signals;

sel = strings(1, 0);
if G.KeepChannels ~= ""; sel(end+1) = "keep " + G.KeepChannels; end
if G.ExcludeHandling == "drop"; sel(end+1) = "drop manifest exclusions"; end
if isempty(sel)
    chan = node("off", "Channel selection", "all amplifier channels");
else
    chan = node("op", "Channel selection", sel);
end

branches = cell(1, 5);
if G.LFP
    if G.LFP_HighpassOn && G.LFP_LowpassOn
        band = node("op", "Butterworth bandpass", [sprintf("%g - %g Hz, order 4", G.LFP_HighpassHz, G.LFP_LowpassHz), "zero-phase at LFP rate"]);
    elseif G.LFP_HighpassOn
        band = node("op", "Butterworth high-pass", [sprintf("%g Hz, order 4", G.LFP_HighpassHz), "zero-phase at LFP rate"]);
    elseif G.LFP_LowpassOn
        band = node("op", "Butterworth low-pass", [sprintf("%g Hz, order 4", G.LFP_LowpassHz), "zero-phase at LFP rate"]);
    else
        band = node("off", "Band filter", "none (resample anti-aliasing only)");
    end
    notch = onOff(G.LFP_NotchOn, "Notch", [G.LFP_NotchHz + " Hz", sprintf("width %g Hz, order 2, zero-phase", G.LFP_NotchBW)], "off");
    branches{1} = chain([{node("stage", "LFP", "amplifier"), ...
        node("op", "Resample", sprintf("-> %g Hz (anti-aliased)", G.LFP_Fs)), band, notch}, ampTail(G, "LFP")]);
else
    branches{1} = node("off", "LFP", "not computed");
end
if G.MUA
    win = max(1, round(G.MUA_Fs / G.MUA_IntegrationHz));
    branches{2} = chain([{node("stage", "MUA", "amplifier"), ...
        node("op", "Butterworth bandpass", [sprintf("%g - %g Hz, order 4", G.MUA_bpLoHi), "zero-phase at original rate"]), ...
        node("op", "Rectify", "|x|"), ...
        node("op", "Resample", sprintf("-> %g Hz", G.MUA_Fs)), ...
        node("op", "Integrate", sprintf("moving mean, %d sample(s) (%g Hz)", win, G.MUA_IntegrationHz))}, ampTail(G, "MUA")]);
else
    branches{2} = node("off", "MUA", "not computed");
end
if G.SPIKE
    rs = onOff(~G.SPIKE_KeepOriginal, "Resample", sprintf("-> %g Hz", G.SPIKE_Fs), "off (original rate)");
    branches{3} = chain([{node("stage", "SPIKE", "amplifier"), rs, ...
        node("op", "Butterworth bandpass", [sprintf("%g - %g Hz, order 4", G.SPIKE_bpLoHi), "zero-phase"])}, ampTail(G, "SPIKE")]);
else
    branches{3} = node("off", "SPIKE", "not computed");
end
if G.AUX
    branches{4} = chain({node("stage", "AUX", "headstage accelerometer"), ...
        node("op", "No processing", "volts at the aux rate"), outNode(G, "AUX")});
else
    branches{4} = node("off", "AUX", "not computed");
end
ev = "[t_on t_off] s per line";
if ~isempty(G.InvertedLines); ev(end+1) = "inverted: " + join(G.InvertedLines, ", "); end
branches{5} = chain({node("stage", "Digital inputs", "named by " + G.LabelField), ...
    node("op", "Edge detection", ev), node("out", "Events", "in every extract file")});

chan.children = branches;
n = chain({raw, node("op", "Read whole recording", "single precision, uV"), chan});
end


function tail = ampTail(G, type)
%ampTail  Bad-channel interpolation, remap and the file of one amplifier signal.
lines = strings(1, 0);
switch G.BadMode
    case "manual"; lines(end+1) = "list: " + G.BadList;
    case "auto";   lines(end+1) = sprintf("auto: |z(RMS of LFP)| > %g", G.BadThreshold);
end
if G.ExcludeHandling == "interpolate"; lines(end+1) = "+ manifest exclusions"; end
if isempty(lines)
    bad = node("off", "Bad channels", "none interpolated");
else
    bad = node("op", "Interpolate bad channels", [lines, "spatial makima"]);
end
remap = onOff(G.ChannelRemap ~= "", "Channel remap", G.ChannelRemap, "off");
tail = {bad, remap, outNode(G, type)};
end


function n = outNode(G, type)
if G.SeparateFiles
    f = "<Name>" + G.Suffix + "_" + type + ".mat";
else
    f = "<Name>" + G.Suffix + ".mat";
end
n = node("out", type + " file", [f, G.MatVersion]);
end


function n = spikesTree(cfg, raw)
K = cfg.Spikes;
A = cfg.Artifacts;

chunk = ["max chunk " + numOr(K.MaxChunkSamples, "auto") + " samples", ...
    "edge pad " + msOrAuto(K.EdgePadMs, "auto (>= 10 ms)"), parallelText(cfg.Parallel)];
switch K.Channels
    case "all";             ch = "all";
    case "excludeManifest"; ch = "all minus manifest exclusions";
    otherwise;              ch = "list: " + K.ChannelList;
end
if K.Filter
    filt = node("op", "Butterworth bandpass", sprintf("%g - %g Hz, order %d", K.Band, K.FilterOrder));
else
    filt = node("off", "Bandpass filter", "off (raw trace)");
end

switch K.Polarity
    case "negative"; pol = "x < -thr";
    case "positive"; pol = "x > thr";
    otherwise;       pol = "|x| > thr";
end
switch K.ThresholdMethod
    case "mad";        how = "thr = " + numOr(K.Threshold, "4") + " x MAD/0.6745";
    case "std";        how = "thr = " + numOr(K.Threshold, "4") + " x SD";
    case "rms";        how = "thr = " + numOr(K.Threshold, "4") + " x RMS";
    case "percentile"; how = "thr = " + numOr(K.Threshold, "99.9") + "th percentile of |x|";
    otherwise;         how = "thr = " + numOr(K.Threshold, "?") + " uV";
end
lines = [pol, how];
if K.ThresholdMethod ~= "absolute"; lines(end+1) = "per chunk and channel"; end
thr = node("op", "Threshold", lines);

align = onOff(K.Align ~= "none", "Align", sprintf("to %s within %g ms", K.Align, K.AlignWindowMs), "off (first crossing)");
minP = node("op", "Minimum period", sprintf("%g ms between events", K.MinPeriodMs));
maxA = onOff(isfinite(K.MaxAmplitudeUV), "Amplitude cap", sprintf("drop |amplitude| > %g uV", K.MaxAmplitudeUV), "off");
wave = onOff(K.Waveforms, "Waveforms", [sprintf("[%g %g] ms", K.WindowMs), K.WaveformSource + " trace", "edges: " + K.EdgeHandling], ...
    "off (timestamps only)");
if K.RejectArtifacts
    rej = node("link", "Reject artifact periods", ternary(A.Enabled && A.ApplyToSpikes, "manual + automatic", "manual periods only"));
else
    rej = node("off", "Reject artifact periods", "off");
end
lines = ["<Name>" + K.Suffix + ".mat", K.MatVersion];
if K.Source == "both"; lines(end+1) = "+ sorted units (see downstream)"; end
out = node("out", "Detected spikes", lines);

n = chain({raw, node("op", "Stream chunks", chunk), node("op", "Channels", ch), ...
    filt, thr, align, minP, maxA, wave, rej, out});
end


function n = unitsTree(cfg)
K = cfg.Spikes;
lines = "groups: " + joinOr(K.Groups, "every non-noise cluster");
if K.IncludeNoise; lines(end+1) = "+ noise clusters"; end
if K.Templates; lines(end+1) = "+ templates"; end
n = chain({node("data", "Sorted units", "from Sorting (phy folder)"), ...
    node("op", "Unit selection", lines), ...
    node("out", "Spikes file", ["<Name>" + K.Suffix + ".mat", K.MatVersion])});
end


function n = exportTree(cfg)
E = cfg.Export;
in = "Signals extract: " + joinOr(E.Signals, "every signal");
if E.IncludeUnits; in(end+1) = "sorted units: " + joinOr(E.Groups, "every non-noise cluster"); end
if E.IncludeDetected; in(end+1) = "detected spikes (Spikes file)"; end
if E.IncludeEvents; in(end+1) = "digital events"; end

kids = {};
if ismember("chronux", E.Formats)
    kids{end+1} = chain({node("op", "Chronux layout", ["[samples x channels] + params", "spike times as structs"]), ...
        node("out", "Chronux file", ["<Name>_chronux.mat", E.MatVersion])});
end
if ismember("fieldtrip", E.Formats)
    kids{end+1} = chain({node("op", "FieldTrip structures", ["raw / spike / event", ...
        ternary(E.Validate, "validated when FieldTrip is on the path", "not validated")]), ...
        node("out", "FieldTrip file", ["<Name>_fieldtrip.mat", E.MatVersion])});
end
if isempty(kids)
    kids = {node("off", "Formats", "none ticked")};
end
n = node("data", "Export inputs", in, kids);
end


% =========================================================================
% node helpers
% =========================================================================

function n = node(kind, title, detail, children)
%node  One box: kind src | stage | op | off | link | data | out.
if nargin < 3; detail = strings(1, 0); end
if nargin < 4; children = {}; end
n = struct('kind', string(kind), 'title', string(title), 'detail', {string(detail)}, 'children', {children});
end


function n = onOff(on, title, detailOn, detailOff)
if on
    n = node("op", title, detailOn);
else
    n = node("off", title, detailOff);
end
end


function n = chain(list)
%chain  Nest LIST{k+1} under LIST{k}: a straight run of stages.
n = list{end};
for k = numel(list) - 1:-1:1
    p = list{k};
    p.children = [p.children, {n}];
    n = p;
end
end


function c = card(key, title, enabled, root, note)
c = struct('key', string(key), 'title', string(title), 'enabled', logical(enabled), ...
    'root', root, 'note', string(note));
end


% =========================================================================
% rendering
% =========================================================================

function h = cardHTML(c)
cls = "card c-" + c.key;
if ~c.enabled; cls = cls + " disabled"; end
badge = ternary(c.enabled, "<span class=""badge on"">enabled</span>", "<span class=""badge"">disabled</span>");
note = "";
if c.note ~= ""; note = "<div class=""note"">" + esc(c.note) + "</div>"; end
h = "<section class=""" + cls + """><header><span class=""dot""></span><b>" + esc(c.title) + "</b>" ...
    + badge + "</header>" + note + "<div class=""tree""><ul>" + nodeHTML(c.root) + "</ul></div></section>";
end


function h = nodeHTML(n)
detail = "";
if ~isempty(n.detail)
    detail = "<div class=""d"">" + join(esc(n.detail), "<br>") + "</div>";
end
h = "<li><span class=""cl""></span><span class=""cr""></span><div class=""n k-" + n.kind + """><div class=""t"">" + esc(n.title) + "</div>" + detail + "</div>";
if ~isempty(n.children)
    h = h + "<span class=""stem""></span><ul>" + joinHTML(cellfun(@nodeHTML, n.children, "UniformOutput", false)) + "</ul>";
end
h = h + "</li>";
end


function h = joinHTML(parts)
%joinHTML  Concatenate a cell array of HTML strings.
h = join([string.empty(1, 0), parts{:}], "");
if isempty(h); h = ""; end
end


function h = legendHTML()
items = [ ...
    "<span class=""n k-src"">recording</span>", ...
    "<span class=""n k-stage"">stage</span>", ...
    "<span class=""n k-op"">processing</span>", ...
    "<span class=""n k-off"">off in this config</span>", ...
    "<span class=""n k-link"">artifact periods</span>", ...
    "<span class=""n k-data"">input from a step</span>", ...
    "<span class=""n k-out"">written</span>"];
h = "<div class=""legend"">" + join(items, "") + "</div>";
end


function s = css()
s = join([ ...
    "body{font:12px/1.35 'Segoe UI',system-ui,sans-serif;color:#1f2328;background:#f4f5f7;margin:0;padding:10px 14px 24px}"
    "h1{font-size:15px;margin:0 0 6px}"
    "h2{font-size:13px;margin:16px 0 8px;color:#57606a;font-weight:600}"
    ".legend{--acc:#8c959f;--tint:#f0f1f3;display:flex;flex-wrap:wrap;gap:6px}"
    ".legend .n{display:inline-block;padding:2px 8px;min-width:0}"
    ".cards{display:flex;flex-wrap:wrap;gap:14px;align-items:flex-start}"
    ".card{--acc:#8c959f;--tint:#f0f1f3;background:#fff;border:1px solid #d0d7de;border-radius:8px;padding:8px 12px 12px;max-width:100%;overflow-x:auto;box-sizing:border-box}"
    ".card.disabled{opacity:.55}"
    ".card header{display:flex;align-items:center;gap:8px;font-size:13px;margin-bottom:4px}"
    ".dot{width:10px;height:10px;border-radius:50%;background:var(--acc)}"
    ".badge{font-size:11px;padding:0 6px;border-radius:9px;background:#eaeef2;color:#57606a}"
    ".badge.on{background:#dafbe1;color:#116329}"
    ".note{font-size:11px;color:#57606a;margin:0 0 6px}"
    ".c-artifacts{--acc:#d9822b;--tint:#fdf0e2}"
    ".c-sorting{--acc:#8250df;--tint:#f1eafd}"
    ".c-signals{--acc:#1f7fbf;--tint:#e3f0fa}"
    ".c-spikes{--acc:#2e9e5b;--tint:#e3f5ea}"
    ".c-export{--acc:#6e7781;--tint:#eef0f2}"
    ".tree ul{display:flex;justify-content:center;margin:0;padding:0}"
    ".tree li{list-style:none;position:relative;display:flex;flex-direction:column;align-items:center;padding:14px 5px 0}"
    ".tree li:only-child{padding-top:0}"
    ".tree .stem{width:2px;height:14px;background:#9aa4ae;flex:none}"
    ".tree .cl,.tree .cr{position:absolute;top:0;width:50%;height:14px;box-sizing:border-box;border-top:2px solid #9aa4ae}"
    ".tree .cl{left:0}"
    ".tree .cr{left:50%;margin-left:-1px;border-left:2px solid #9aa4ae}"
    ".tree li:first-child>.cl,.tree li:last-child>.cr{border-top:0 none}"
    ".tree li:only-child>.cl,.tree li:only-child>.cr{display:none}"
    ".n{box-sizing:border-box;min-width:120px;max-width:220px;padding:4px 8px;border:1px solid #d0d7de;border-left:4px solid var(--acc);border-radius:6px;background:#fff;text-align:left}"
    ".n .t{font-weight:600}"
    ".n .d{color:#57606a;font-size:11px}"
    ".k-src{background:#24292f;border-color:#24292f;color:#fff}"
    ".k-src .d{color:#d0d7de}"
    ".k-stage{background:var(--tint);font-size:12.5px}"
    ".k-off{border-style:dashed;border-left-style:dashed;border-left-color:#afb8c1;background:#f6f8fa;color:#8c959f}"
    ".k-off .d{color:#8c959f}"
    ".k-link{border-color:#d9822b;border-left-color:#d9822b;background:#fdf0e2;border-radius:12px}"
    ".k-data{border-style:double;border-width:3px;border-left-width:4px;background:#fff}"
    ".k-out{background:var(--tint);border-color:var(--acc)}"
    ], "");
end


% =========================================================================
% text helpers
% =========================================================================

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


function t = numOr(v, fallback)
if isempty(v) || ~isfinite(v)
    t = string(fallback);
else
    t = sprintf("%g", v);
end
end


function t = msOrAuto(v, fallback)
if isfinite(v); t = sprintf("%g ms", v); else; t = string(fallback); end
end


function t = numList(v)
t = join(compose("%g", v(:).'), " - ");
end


function t = compactList(v)
v = sort(v(:).');
if numel(v) > 8
    t = join(compose("%d", v(1:8)), ", ") + sprintf(", ... (%d)", numel(v));
else
    t = join(compose("%d", v), ", ");
end
end


function t = joinOr(v, fallback)
if isempty(v); t = string(fallback); else; t = join(string(v), ", "); end
end


function t = parallelText(P)
if ~P.Enabled
    t = "serial";
elseif isfinite(P.MaxWorkers)
    t = sprintf("process pool, <= %g workers", P.MaxWorkers);
else
    t = "process pool, workers from free memory";
end
end


function t = fileName(p)
[~, b, e] = fileparts(p);
t = string(b) + string(e);
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
