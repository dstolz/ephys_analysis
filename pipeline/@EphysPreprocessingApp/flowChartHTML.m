function [html, summary] = flowChartHTML(obj, opts)
%flowChartHTML  Flow chart of the working config as a standalone HTML page.
%   [HTML, SUMMARY] = app.flowChartHTML() draws the Diagram tab's view
%   (FlowViewDropDown): "detail", every step with all its parameters
%   (below), or "overview", only the steps and the data that flows between
%   them (flowOverviewHTML).
%
%   The detail view draws one tree from the raw
%   recording. The common reference (Artifacts.Reference) comes right under
%   it, drawn once: every step subtracts it once from its own read of the
%   recording (the Signals it leaves out, such as the LFP, say so on their
%   own branch). The tree then branches into Artifacts, Signals (LFP / MUA /
%   SPIKE / AUX / digital events) and Spikes (threshold detection), and runs
%   each through its stages, with their filter and detection parameters, to
%   what the step writes. Sorting (Kilosort4 on a .bin), Signals and Spikes
%   hang from the artifact periods when they erase them from the recording
%   before they read it: the .bin always, the amplifier data the LFP / MUA /
%   SPIKE are derived from while Signals.BlankArtifacts, the trace spikes
%   are detected on while Spikes.ArtifactMode is "erase"; otherwise the step
%   hangs from the reference.
%   The steps that read an output rather than the recording hang from the
%   file they read: sorted units for the Spikes file under Sorting's
%   output, Export under the Signals extract.
%   Each step's branch starts with a box in its colour. Stages the config
%   leaves off are drawn dashed; disabled steps are faded. Artifact periods
%   feeding Sorting / Signals / Spikes are marked in the Artifacts colour.
%
%   Its Layout is "tree" (the one tree above) or "steps" (a tree of its own
%   for each step that reads the recording, each from the recording box,
%   then the steps hung from another step's output -- Sorting and Signals
%   from the artifact periods too -- as downstream trees, each under the box
%   it reads), as picked on the Diagram tab (FlowLayoutDropDown).
%
%   app.flowChartHTML(View=V, Layout=L) picks them instead: V "detail" or
%   "overview", L "tree" or "steps" (the detail view's only).
%
%   Each box names the control(s) that set what it shows (its node target,
%   written into the page as data-nav). In the app a click on a box sends
%   them to onFlowNavigate, which opens that control's tab; in a saved page
%   the boxes are plain, because only the app calls the page's setup().
%
%   It reads only obj.Config and the active dataset (for the recording's
%   rate, channel count, probe and exclusions), so it mirrors what
%   EphysPipeline would run. SUMMARY is a one-line description for the tab.
%
%   See also flowOverviewHTML, onFlowNavigate, flowNavControls,
%   EphysDataset.deriveSignals, EphysDataset.detectSpikes,
%   EphysDataset.detectArtifacts, EphysDataset.runKilosort.

arguments
    obj
    opts.View (1,1) string {mustBeMember(opts.View, ["" "detail" "overview"])} = ""
    opts.Layout (1,1) string {mustBeMember(opts.Layout, ["" "tree" "steps"])} = ""
end
view = pick(opts.View, obj.FlowViewDropDown, "detail");
if view == "overview"
    [html, summary] = obj.flowOverviewHTML();
    return
end
layout = pick(opts.Layout, obj.FlowLayoutDropDown, "tree");
cfg = obj.Config;
d = obj.currentDataset();
dsName = ternary(isempty(d), "<Name>", d.Name);

sorting = sortingTree(cfg, d, unitsTree(cfg, dsName));
signals = signalsTree(cfg, dsName, exportTree(cfg, dsName));
spikes = spikesTree(cfg, dsName);
% The steps that erase the artifact periods before they read the recording
% hang from them: Sorting always, Signals while BlankArtifacts is on, Spikes
% while its ArtifactMode is "erase". The others hang from the reference.
hung = {sorting};
steps = {};
if cfg.Signals.BlankArtifacts; hung{end+1} = signals; else; steps{end+1} = signals; end
if cfg.Spikes.ArtifactMode == "erase"; hung{end+1} = spikes; else; steps{end+1} = spikes; end
artifacts = artifactsTree(cfg, hung);
steps = [{artifacts}, steps];
% The recording and, once, the common reference every step's read takes.
raw = chain({rawNode(d), referenceNode(cfg)});

% Sorting and Signals read the recording too, wherever they hang.
readers = {artifacts, sorting, signals, spikes};
nOn = sum(cellfun(@(s) ~s.dim, readers));
summary = sprintf("%d of %d raw-data step(s) enabled", nOn, numel(readers));
if ~isempty(d)
    summary = summary + " | recording: " + d.Name;
end

pageTitle = "Preprocessing diagram: " + cfg.Name;
body = "<h1>" + esc(pageTitle) + "</h1>" + legendHTML() ...
    + "<div class=""hint"">Click any box to open the setting it draws.</div>" ...
    + ternary(layout == "steps", stepsHTML(raw, steps), treeHTML(raw, steps)) ...
    + "<script>" + js() + "</script>";
html = "<!DOCTYPE html><html><head><meta charset=""utf-8""><title>" + esc(pageTitle) + "</title><style>" ...
    + css() + "</style></head><body>" + body + "</body></html>";
end


% =========================================================================
% trees
% =========================================================================

function n = rawNode(d)
if isempty(d)
    n = node("src", "Raw recording", "amplifier channels (no active dataset)", "RootPathField");
    return
end
info = string(d.RecordingFormat);
if isfinite(d.Fs); info = sprintf("%g kHz, ", d.Fs / 1000) + info; end
if isfinite(d.NumChannels); info = sprintf("%d ch, ", d.NumChannels) + info; end
n = node("src", "Raw recording", [d.Name, info], "RootPathField,DatasetsTable");
end


function n = artifactsTree(cfg, readers)
%artifactsTree  The detection chain, ending in the artifact periods that
%   READERS (the steps that erase them before reading the recording:
%   Sorting's .bin, Signals' amplifier data, Spikes' detection trace) and
%   the Spikes rejection read.
A = cfg.Artifacts;
K = cfg.Spikes;
filtTarget = "ArtFilterCheckBox,ArtHighpassField";
if A.Filter
    filt = node("op", "Butterworth " + A.FilterType, ...
        [numList(A.FilterCutoff) + " Hz, order " + A.FilterOrder, "detector runs on the filtered copy"], filtTarget);
else
    filt = node("off", "Detection filter", "off (broadband)", filtTarget);
end
thr = A.Threshold;
detTarget = "ArtMethodDropDown,ArtThresholdField";
switch A.Method
    case "rms"
        det = node("op", "Running RMS", ["window " + msOrAuto(A.RmsWindowMs, "auto (~1 ms)"), ...
            "flag > " + numOr(thr, "9") + " robust SD above baseline"], detTarget + ",ArtRmsWindowField");
    case "mad"
        det = node("op", "Robust z-score", ["|x - median| / (1.4826 MAD)", "flag z > " + numOr(thr, "8")], detTarget);
    case "microvolts"
        det = node("op", "Absolute amplitude", "flag |x| > " + numOr(thr, "1500") + " uV", detTarget);
    otherwise
        det = node("op", "Common-mode mean", ["mean across channels", "flag |mean| > " + numOr(thr, "1500") + " uV", ...
            "on the recording as stored (the reference is that mean)"], detTarget);
end
if A.Method == "commonmode"
    coinc = node("off", "Channel coincidence", "n/a for commonmode", "ArtMinChannelsField");
else
    coinc = node("op", "Channel coincidence", ">= " + A.MinChannels + " channel(s) at once", "ArtMinChannelsField");
end
merge = onOff(A.MergeGapMs > 0, "Merge gaps", sprintf("gaps <= %g ms stitched", A.MergeGapMs), "off (0 ms)", "ArtMergeGapField");
pad = onOff(A.PadMs > 0, "Pad intervals", sprintf("+/- %g ms", A.PadMs), "off (0 ms)", "ArtPadField");
out = node("out", "Automatic intervals", ["[t_on t_off] s", ...
    ternary(A.CacheIntervals, "cached while recording + settings match", "recomputed by each step")], ...
    "ArtCacheCheckBox,ArtDetectButton");

% Spikes erasing the periods is one of the READERS; rejecting or ignoring
% them, it hangs from the reference and gets a box here.
switch K.ArtifactMode
    case "reject"
        readers{end+1} = linkNode(K.Enabled && K.Source ~= "sorted", A.Enabled && A.ApplyToSpikes, ...
            "Reject in Spikes", "ApplyToSpikes", "ArtApplySpikesCheckBox,SpkArtifactModeDropDown");
    case "none"
        readers{end+1} = node("off", "Spikes", "ignores the periods", "SpkArtifactModeDropDown");
end
periods = node("link", "Artifact periods", ...
    [ternary(A.Enabled, "automatic + manual", "manual only (detection off)"), "manual: marked on Visualize"], ...
    "ArtManualTable,ArtEditVizButton");
periods.children = readers;

n = step("artifacts", "Artifacts", A.Enabled, ...
    ternary(A.Enabled, "", "Detection is off: only the manual periods reach Sorting / Signals / Spikes."), ...
    "ArtEnableCheckBox", ...
    {node("op", "Read in chunks", ["one file / bounded window per chunk", parallelText(cfg.Parallel)], ...
    "RunParallelCheckBox,RunMaxWorkersField"), ...
    filt, det, coinc, merge, pad, out});
% Hung on after step(): the manual periods apply with detection off too, so
% they do not fade with it.
n = hangFromEnd(n, {periods});
end


function n = referenceNode(cfg)
%referenceNode  The common reference (Artifacts.Reference), drawn once
%   between the recording and the steps: each step subtracts it once,
%   sample by sample, from its own read of the recording - artifact
%   detection, the Kilosort4 .bin (whose own do_CAR is then off), spike
%   detection and the Signals ticked for it (EphysDataset.applyReference /
%   referenceTrace). What leaves it out is listed.
A = cfg.Artifacts;
G = cfg.Signals;
target = "ArtRefDropDown,ArtRefLowField,ArtRefHighField";
switch A.Reference
    case "car"; n = node("op", "Common average reference", "mean of the good channels, subtracted once from each", target);
    case "cmr"; n = node("op", "Common median reference", "median of the good channels, subtracted once from each", target);
    otherwise;  n = node("off", "Common reference", "none (as recorded)", target);
end
if n.kind ~= "op"
    return
end
n.target = target + ",SigRefLFPCheckBox,SigRefMUACheckBox,SigRefSPIKECheckBox";
n.detail(end+1) = "as each step reads the recording";
types = ["LFP" "MUA" "SPIKE"];
off = types([G.LFP G.MUA G.SPIKE] & ~[G.LFP_Reference G.MUA_Reference G.SPIKE_Reference]);
if ~isempty(off)
    n.detail(end+1) = "not Signals' " + join(off, " / ");
end
if A.Method == "commonmode"
    n.detail(end+1) = "not the common-mode artifact detector";
end
end


function n = linkNode(stepOn, applyAuto, title, field, target)
if ~stepOn
    n = node("off", title, "step not run", target);
elseif applyAuto
    n = node("link", title, "manual + automatic", target);
else
    n = node("link", title, "manual only (" + field + " or detection off)", target);
end
end


function n = sortingTree(cfg, d, units)
% The recording, with the common reference and the artifact periods
% erased, goes to a .bin and into Kilosort4, which crops (tmin/tmax) and,
% only when the .bin carries no common reference, references (do_CAR)
% itself. UNITS (reading the sorted units into the Spikes file) hangs from
% the sorted units.
S = cfg.Sorting; K = S.KS4;
A = cfg.Artifacts;

if K.tmin > 0 || isfinite(K.tmax)
    crop = node("op", "Crop", sprintf("%g - %s s", K.tmin, ternary(isfinite(K.tmax), sprintf("%g", K.tmax), "end")), "ks4.tmin,ks4.tmax");
else
    crop = node("off", "Crop", "whole recording", "ks4.tmin,ks4.tmax");
end

if ~isempty(d) && d.ProbeFile ~= ""
    probe = fileName(d.ProbeFile);
elseif cfg.Probe.DefaultProbeFile ~= ""
    probe = "default: " + fileName(cfg.Probe.DefaultProbeFile);
else
    probe = "per-dataset probe (none set)";
end
if ~isempty(d) && ~isempty(d.ExcludeChannels)
    probe(end+1) = "excluding " + compactList(d.ExcludeChannels);
end

blank = node("link", "Blank artifact periods", ...
    [ternary(A.Enabled && A.ApplyToSorting, "manual + automatic", "manual periods only"), ...
    ternary(A.Fill == "noise", "noise-filled", "zeroed") + " before the .bin is written"], ...
    "ArtApplySortingCheckBox,ArtFillDropDown");

hp = node("op", "KS4 high-pass", sprintf("%g Hz", K.highpass_cutoff), "ks4.highpass_cutoff");
ks4 = EphysPipelineConfig.ks4Settings(S);
if A.Reference ~= "none"
    ksCar = node("off", "KS4 CAR", ["off (do_CAR = false): the .bin", "already carries the common reference"], "ArtRefDropDown");
elseif isfield(ks4, 'do_CAR') && isequal(ks4.do_CAR, false)
    ksCar = node("off", "KS4 CAR", "off (do_CAR = false in the extra settings)", "ExtraSettingsArea");
else
    ksCar = node("op", "KS4 CAR", ["do_CAR: median across the probe's channels", "the one common reference here"], "ExtraSettingsArea");
end
art = onOff(isfinite(K.artifact_threshold), "KS4 artifact threshold", ...
    sprintf("zero batches >= %g ADC counts", K.artifact_threshold), "off", "ks4.artifact_threshold");
white = node("op", "Whitening", [sprintf("%d nearest channels", K.whitening_range), ...
    sprintf("batch %d samples", K.batch_size)], "ks4.whitening_range,ks4.batch_size,ks4.nskip");
drift = onOff(K.nblocks > 0, "Drift correction", ...
    [sprintf("nblocks %d", K.nblocks), sprintf("sig_interp %g um", K.sig_interp)], "off (nblocks = 0)", ...
    "ks4.nblocks,ks4.sig_interp,ks4.binning_depth,ks4.dmin,ks4.dminx");
det = node("op", "Template matching", [sprintf("Th_universal %g, Th_learned %g", K.Th_universal, K.Th_learned), ...
    sprintf("Th_single_ch %g, nt %d samples", K.Th_single_ch, K.nt)], ...
    "ks4.Th_universal,ks4.Th_learned,ks4.Th_single_ch,ks4.nt");
clu = node("op", "Clustering", sprintf("ACG %g, CCG %g", K.acg_threshold, K.ccg_threshold), ...
    "ks4.acg_threshold,ks4.ccg_threshold,ks4.cluster_neighbors,ks4.x_centers");
outTarget = "SortDatasetDropDown,SortUseFolderButton,SortPhyButton";
ksStage = "KSOptimizeButton,KSResetButton";

out = node("out", "Sorted units", ["kilosort4/", "phy-ready"], outTarget);
out.children = {units};

n = step("sorting", "Sorting", S.Enabled, sortingNote(S), ...
    "SortEnableCheckBox,SortSkipExistingCheckBox,ExecModeDropDown,DryRunCheckBox", ...
    {blank, ...
    node("stage", "Write .bin", ["the recording, int16, channel-interleaved", "<Name>.bin (toBin)"], "PythonExeField,CondaEnvField"), ...
    node("op", "Attach probe map", [probe, "chanMap indexes .bin rows"], "ProbeDatasetDropDown,ProbeDefaultField,ExcludeChannelsField"), ...
    node("stage", "Kilosort4", "run_kilosort", ksStage), ...
    crop, hp, ksCar, art, white, drift, det, clu, out});
end


function txt = sortingNote(S)
txt = "Kilosort4 on a .bin, runs " + S.Execution;
if S.Execution == "background"
    txt = txt + " (" + S.MaxConcurrent + " at a time)";
end
if ~isempty(S.Devices); txt = txt + ", on " + strjoin(S.Devices, " / "); end
if S.DryRun; txt = txt + ", dry run (writes run files only)"; end
if S.SkipExisting; txt = txt + ", skips datasets already sorted"; end
txt = txt + ".";
end


function n = signalsTree(cfg, dsName, export)
%signalsTree  EXPORT (reading the extract) hangs from the first signal file.
%   The channel selection comes first, and the artifact periods are erased
%   in the amplifier data LFP / MUA / SPIKE derive from. Each of those says
%   whether it takes the common reference drawn above the steps (taken over
%   every channel, before the selection); AUX and the digital inputs come
%   from the read as they are.
G = cfg.Signals;
A = cfg.Artifacts;
types = ["LFP" "MUA" "SPIKE" "AUX"];
host = types(find([G.LFP G.MUA G.SPIKE G.AUX], 1));
kids = @(type) exportUnder(host, type, export);
stage = @(type, on) node("stage", type, ternary(on && A.Reference ~= "none", ...
    ["amplifier", "common " + upper(A.Reference) + " referenced"], ["amplifier", "as recorded (no common reference)"]), ...
    "Conv" + type + "CheckBox,SigRef" + type + "CheckBox");

sel = strings(1, 0);
if G.KeepChannels ~= ""; sel(end+1) = "keep " + G.KeepChannels; end
if G.ExcludeHandling == "drop"; sel(end+1) = "drop manifest exclusions"; end
chanTarget = "ConvKeepChannelsField,ConvExcludeHandlingDropDown";
if isempty(sel)
    chan = node("off", "Channel selection", "all amplifier channels", chanTarget);
else
    chan = node("op", "Channel selection", sel, chanTarget);
end

branches = cell(1, 5);
if G.LFP
    bandTarget = "ConvLFPHighpassCheckBox,ConvLFPHighpassField,ConvLFPLowpassCheckBox,ConvLFPLowpassField";
    if G.LFP_HighpassOn && G.LFP_LowpassOn
        band = node("op", "Butterworth bandpass", [sprintf("%g - %g Hz, order 4", G.LFP_HighpassHz, G.LFP_LowpassHz), "zero-phase at LFP rate"], bandTarget);
    elseif G.LFP_HighpassOn
        band = node("op", "Butterworth high-pass", [sprintf("%g Hz, order 4", G.LFP_HighpassHz), "zero-phase at LFP rate"], bandTarget);
    elseif G.LFP_LowpassOn
        band = node("op", "Butterworth low-pass", [sprintf("%g Hz, order 4", G.LFP_LowpassHz), "zero-phase at LFP rate"], bandTarget);
    else
        band = node("off", "Band filter", "none (resample anti-aliasing only)", bandTarget);
    end
    notch = onOff(G.LFP_NotchOn, "Notch", [G.LFP_NotchHz + " Hz", sprintf("width %g Hz, order 2, zero-phase", G.LFP_NotchBW)], "off", ...
        "ConvLFPNotchCheckBox,ConvLFPNotchField,ConvLFPNotchBWField");
    branches{1} = chain([{stage("LFP", G.LFP_Reference), ...
        node("op", "Resample", sprintf("-> %g Hz (anti-aliased)", G.LFP_Fs), "ConvLFPFsField"), band, notch}, ampTail(G, "LFP", dsName, kids("LFP"))]);
else
    branches{1} = node("off", "LFP", "not computed", "ConvLFPCheckBox");
end
if G.MUA
    win = max(1, round(G.MUA_Fs / G.MUA_IntegrationHz));
    branches{2} = chain([{stage("MUA", G.MUA_Reference), ...
        node("op", "Butterworth bandpass", [sprintf("%g - %g Hz, order 4", G.MUA_bpLoHi), "zero-phase at original rate"], ...
            "ConvMUALoField,ConvMUAHiField"), ...
        node("op", "Rectify", "|x|", "ConvMUACheckBox"), ...
        node("op", "Resample", sprintf("-> %g Hz", G.MUA_Fs), "ConvMUAFsField"), ...
        node("op", "Integrate", sprintf("moving mean, %d sample(s) (%g Hz)", win, G.MUA_IntegrationHz), ...
            "ConvMUAIntegrationField")}, ampTail(G, "MUA", dsName, kids("MUA"))]);
else
    branches{2} = node("off", "MUA", "not computed", "ConvMUACheckBox");
end
if G.SPIKE
    rs = onOff(~G.SPIKE_KeepOriginal, "Resample", sprintf("-> %g Hz", G.SPIKE_Fs), "off (original rate)", ...
        "ConvSpikeOrigCheckBox,ConvSpikeFsField");
    branches{3} = chain([{stage("SPIKE", G.SPIKE_Reference), rs, ...
        node("op", "Butterworth bandpass", [sprintf("%g - %g Hz, order 4", G.SPIKE_bpLoHi), "zero-phase"], ...
            "ConvSpikeLoField,ConvSpikeHiField")}, ampTail(G, "SPIKE", dsName, kids("SPIKE"))]);
else
    branches{3} = node("off", "SPIKE", "not computed", "ConvSPIKECheckBox");
end
if G.AUX
    branches{4} = chain({node("stage", "AUX", "headstage accelerometer", "ConvAUXCheckBox"), ...
        node("op", "No processing", "volts at the aux rate", "ConvAUXCheckBox"), outNode(G, "AUX", dsName, kids("AUX"))});
else
    branches{4} = node("off", "AUX", "not computed", "ConvAUXCheckBox");
end
ev = "[t_on t_off] s per line";
if ~isempty(G.InvertedLines); ev(end+1) = "inverted: " + join(G.InvertedLines, ", "); end
named = G.LabelField + " names";
if ~isempty(G.LineNames); named = [named, numel(G.LineNames) + " renamed (Trials tab)"]; end
events = node("out", "Events", "in every extract file", "ConvLabelFieldDropDown");
if isempty(host); events.children = {export}; end
branches{5} = chain({node("stage", "Digital inputs", named, "ConvLabelFieldDropDown"), ...
    node("op", "Edge detection", ev, "TrialsLinesTable"), events});

eraseTarget = "SigBlankArtifactsCheckBox,ArtApplySignalsCheckBox";
if G.BlankArtifacts
    erase = node("link", "Erase artifact periods", ...
        [ternary(A.Enabled && A.ApplyToSignals, "manual + automatic", "manual periods only"), ...
        "a line across each, before any filter", "recorded in every file"], eraseTarget);
else
    erase = node("off", "Erase artifact periods", "off (as recorded)", eraseTarget);
end
erase.children = branches(1:3);
chan.children = {erase};
read = node("op", "Read whole recording", "single precision, uV", "SigEnableCheckBox");
read.children = [{chan}, branches(4:5)];
n = step("signals", "Signals", G.Enabled, "", "SigEnableCheckBox", {read});
end


function k = exportUnder(host, type, export)
%exportUnder  {EXPORT} under the file of signal HOST, {} under the others.
if isequal(host, type); k = {export}; else; k = {}; end
end


function tail = ampTail(G, type, dsName, kids)
%ampTail  Bad-channel interpolation, remap and the file of one amplifier signal.
lines = strings(1, 0);
switch G.BadMode
    case "manual"; lines(end+1) = "list: " + G.BadList;
    case "auto";   lines(end+1) = sprintf("auto: |z(RMS of LFP)| > %g", G.BadThreshold);
end
if G.ExcludeHandling == "interpolate"; lines(end+1) = "+ manifest exclusions"; end
badTarget = "ConvBadModeDropDown,ConvBadThresholdField,ConvBadListField";
if isempty(lines)
    bad = node("off", "Bad channels", "none interpolated", badTarget);
else
    bad = node("op", "Interpolate bad channels", [lines, "from the nearest probe sites", "(makima across columns without a probe)"], badTarget);
end
remap = onOff(G.ChannelRemap ~= "", "Channel remap", G.ChannelRemap, "off", "ConvRemapField");
tail = {bad, remap, outNode(G, type, dsName, kids)};
end


function n = outNode(G, type, dsName, kids)
if G.SeparateFiles
    f = dsName + G.Suffix + "_" + type + ".mat";
else
    f = dsName + G.Suffix + ".mat";
end
n = node("out", type + " file", [f, G.MatVersion], ...
    "ConvOutputDirField,ConvSuffixField,ConvSeparateFilesCheckBox,ConvMatVersionDropDown");
n.children = kids;
end


function n = spikesTree(cfg, dsName)
K = cfg.Spikes;
A = cfg.Artifacts;

chunk = ["max chunk " + numOr(K.MaxChunkSamples, "auto") + " samples", ...
    "edge pad " + msOrAuto(K.EdgePadMs, "auto (>= 10 ms)"), parallelText(cfg.Parallel)];
switch K.Channels
    case "all";             ch = "all";
    case "excludeManifest"; ch = "all minus manifest exclusions";
    otherwise;              ch = "list: " + K.ChannelList;
end
filtTarget = "SpkFilterCheckBox,SpkBandLoField,SpkBandHiField,SpkFilterOrderField";
if K.Filter
    filt = node("op", "Butterworth bandpass", sprintf("%g - %g Hz, order %d", K.Band, K.FilterOrder), filtTarget);
else
    filt = node("off", "Bandpass filter", "off (raw trace)", filtTarget);
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
thr = node("op", "Threshold", lines, "SpkThreshMethodDropDown,SpkThresholdField,SpkPolarityDropDown");

align = onOff(K.Align ~= "none", "Align", sprintf("to %s within %g ms", K.Align, K.AlignWindowMs), "off (first crossing)", ...
    "SpkAlignDropDown,SpkAlignWindowField");
minP = node("op", "Minimum period", sprintf("%g ms between events", K.MinPeriodMs), "SpkMinPeriodField");
maxA = onOff(isfinite(K.MaxAmplitudeUV), "Amplitude cap", sprintf("drop |amplitude| > %g uV", K.MaxAmplitudeUV), "off", "SpkMaxAmpField");
wave = onOff(K.Waveforms, "Waveforms", [sprintf("[%g %g] ms", K.WindowMs), K.WaveformSource + " trace", "edges: " + K.EdgeHandling], ...
    "off (timestamps only)", "SpkWaveformsCheckBox,SpkWinBeforeField,SpkWinAfterField,SpkWaveSourceDropDown,SpkEdgeDropDown");
% The artifact periods: erased before the filter (the step then hangs from
% them), or the events inside them rejected after detection.
artTarget = "SpkArtifactModeDropDown,ArtApplySpikesCheckBox";
periods = ternary(A.Enabled && A.ApplyToSpikes, "manual + automatic", "manual periods only");
erase = {};
switch K.ArtifactMode
    case "erase"
        erase = {node("link", "Erase artifact periods", [periods, "NaN: out of the thresholds,", "a line across each for the filter"], artTarget)};
        rej = {};
    case "reject"
        rej = {node("link", "Reject artifact periods", [periods, "events inside them dropped"], artTarget)};
    otherwise
        rej = {node("off", "Artifact periods", "ignored", artTarget)};
end
lines = [dsName + K.Suffix + ".mat", K.MatVersion];
if K.Source == "both"; lines(end+1) = "+ sorted units (under Sorting)"; end
out = node("out", "Detected spikes", lines, "SpkOutputDirField,SpkSuffixField,SpkOverwriteCheckBox,SpkMatVersionDropDown");

n = step("spikes", "Spikes", K.Enabled && K.Source ~= "sorted", ...
    ternary(K.Source == "sorted", "Source is 'sorted': no threshold detection runs.", ""), ...
    "SpkEnableCheckBox,SpkSourceDropDown", ...
    [{node("op", "Stream chunks", chunk, "SpkChunkField,SpkEdgePadField"), ...
    node("op", "Channels", ch, "SpkChannelsDropDown,SpkChannelListField")}, erase, ...
    {filt, thr, align, minP, maxA, wave}, rej, {out}]);
end


function n = unitsTree(cfg, dsName)
K = cfg.Spikes;
lines = "groups: " + joinOr(K.Groups, "every non-noise cluster");
if K.IncludeNoise; lines(end+1) = "+ noise clusters"; end
if K.Templates; lines(end+1) = "+ templates"; end
n = step("spikes", "Spikes: sorted units", K.Enabled && K.Source ~= "detect", ...
    ternary(K.Source == "detect", "Source is 'detect': sorted units are not read.", ""), "SpkSourceDropDown", ...
    {node("op", "Unit selection", lines, "SpkGroupsField,SpkIncludeNoiseCheckBox,SpkTemplatesCheckBox"), ...
    node("out", "Spikes file", [dsName + K.Suffix + ".mat", K.MatVersion], ...
        "SpkOutputDirField,SpkSuffixField,SpkOverwriteCheckBox,SpkMatVersionDropDown")});
end


function n = exportTree(cfg, dsName)
E = cfg.Export;
in = "Signals extract: " + joinOr(E.Signals, "every signal");
if E.IncludeUnits; in(end+1) = "sorted units: " + joinOr(E.Groups, "every non-noise cluster"); end
if E.IncludeDetected; in(end+1) = "detected spikes (Spikes file)"; end
if E.IncludeEvents; in(end+1) = "digital events"; end

fileTarget = "ExpOutputDirField,ExpOverwriteCheckBox,ExpMatVersionDropDown";
kids = {};
if ismember("chronux", E.Formats)
    kids{end+1} = chain({node("op", "Chronux layout", ["[samples x channels] + params", "spike times as structs"], "ExpChronuxCheckBox"), ...
        node("out", "Chronux file", [dsName + "_chronux.mat", E.MatVersion], fileTarget)});
end
if ismember("fieldtrip", E.Formats)
    kids{end+1} = chain({node("op", "FieldTrip structures", ["raw / spike / event", ...
        ternary(E.Validate, "validated when FieldTrip is on the path", "not validated")], ...
        "ExpFieldTripCheckBox,ExpValidateCheckBox"), ...
        node("out", "FieldTrip file", [dsName + "_fieldtrip.mat", E.MatVersion], fileTarget)});
end
if ismember("epochs", E.Formats)
    if E.EpochSource == "behavior"
        around = "around the paired trials";
    elseif E.EpochLine == ""
        around = "around the trial line";
    else
        around = "around " + E.EpochLine;
    end
    kids{end+1} = chain({node("op", "Event epochs", [around, ...
        sprintf("window [%g %g] s, spike times %s", E.EpochWindow(1), E.EpochWindow(2), E.EpochSpikeTimeBase), ...
        ternary(E.EpochArtifacts == "drop", "touching an artifact period: dropped", "touching an artifact period: kept, flagged")], ...
        "ExpEpochsCheckBox,ExpEpochSourceDropDown,ExpEpochLineField,ExpEpochPreField,ExpEpochPostField,ExpEpochArtifactsDropDown"), ...
        node("out", "Epoch file", [dsName + "_epochs.mat", E.MatVersion], fileTarget)});
end
if isempty(kids)
    kids = {node("off", "Formats", "none ticked", "ExpChronuxCheckBox,ExpFieldTripCheckBox,ExpEpochsCheckBox")};
end
inputs = node("data", "Export inputs", in, "ExpSignalsField,ExpUnitsCheckBox,ExpGroupsField,ExpDetectedCheckBox,ExpEventsCheckBox");
inputs.children = kids;
n = step("export", "Export", E.Enabled, "", "ExpEnableCheckBox", {inputs});
end


% =========================================================================
% node helpers
% =========================================================================

function n = node(kind, title, detail, target)
%node  One box: kind src | step | stage | op | off | link | data | out.
%   TARGET is what a click on the box opens: the app property name of a
%   control, ks4.<parameter> for a Kilosort4 field, or several of those
%   separated by commas (the first one decides the tab). "" = not clickable.
%   Set n.children afterwards to hang boxes under it.
if nargin < 3; detail = strings(1, 0); end
if nargin < 4; target = ""; end
n = struct('kind', string(kind), 'title', string(title), 'detail', {string(detail)}, ...
    'target', string(target), 'children', {{}}, 'key', "", 'dim', false);
end


function n = step(key, title, enabled, note, target, stages)
%step  One step's branch: its box (in the step's colour, with its enabled
%   badge and NOTE; TARGET is what the box opens) over the chain of STAGES.
%   A disabled step's boxes are faded, down to the next step that hangs
%   from it, which fades by its own state.
n = node("step", title, note, target);
n.key = string(key);
n = chain([{n}, stages]);
if ~enabled
    n = fade(n);
end
end


function n = fade(n)
n.dim = true;
for k = 1:numel(n.children)
    if n.children{k}.kind ~= "step"
        n.children{k} = fade(n.children{k});
    end
end
end


function n = onOff(on, title, detailOn, detailOff, target)
if nargin < 5; target = ""; end
if on
    n = node("op", title, detailOn, target);
else
    n = node("off", title, detailOff, target);
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


function n = hangFromEnd(n, kids)
%hangFromEnd  Hang KIDS under the last box of the straight run N starts
%   (chain, step), keeping their own faded state.
if isempty(n.children)
    n.children = kids;
else
    n.children{end} = hangFromEnd(n.children{end}, kids);
end
end


% =========================================================================
% rendering
% =========================================================================

function h = treeHTML(raw, steps)
%treeHTML  The "tree" layout: every step hangs from one recording box
%   (under the common reference, the last box of RAW's run).
raw = hangFromEnd(raw, steps);
h = "<div class=""card""><div class=""tree""><ul>" + nodeHTML(raw) + "</ul></div></div>";
end


function h = stepsHTML(raw, steps)
%stepsHTML  The "steps" layout: a tree per step from the recording box, then
%   the steps hung from their outputs as downstream trees, each under a box
%   for the file it reads.
top = strings(1, 0); down = strings(1, 0);
for k = 1:numel(steps)
    [s, cut] = detach(steps{k}, steps{k}.title);
    r = hangFromEnd(raw, {s});
    top(end+1) = treeCard(r); %#ok<AGROW>
    for j = 1:numel(cut)
        down(end+1) = treeCard(cut{j}); %#ok<AGROW>
    end
end
h = "<h2>From the raw recording</h2><div class=""cards"">" + join(top, "") + "</div>";
if ~isempty(down)
    h = h + "<h2>Downstream (reads step outputs)</h2><div class=""cards"">" + join(down, "") + "</div>";
end
end


function [n, cut] = detach(n, owner)
%detach  Take the step boxes hung below N off it. CUT holds each one under a
%   copy of the box it hung from, drawn as an input from step OWNER.
cut = {};
keep = true(1, numel(n.children));
for k = 1:numel(n.children)
    c = n.children{k};
    if c.kind == "step"
        in = node("data", n.title, "from " + owner, n.target);
        [c, more] = detach(c, c.title);
        in.children = {c};
        cut = [cut, {in}, more]; %#ok<AGROW>
        keep(k) = false;
    else
        [n.children{k}, more] = detach(c, owner);
        cut = [cut, more]; %#ok<AGROW>
    end
end
n.children = n.children(keep);
end


function h = treeCard(root)
h = "<div class=""card""><div class=""tree""><ul>" + nodeHTML(root) + "</ul></div></div>";
end


function h = nodeHTML(n)
%nodeHTML  One box and, below it, the boxes hung from it. A step box sets
%   its step's colour for its whole branch (class c-<key> on its <li>).
detail = "";
if ~isempty(n.detail)
    detail = "<div class=""d"">" + join(esc(n.detail), "<br>") + "</div>";
end
title = esc(n.title);
if n.kind == "step"
    title = title + ternary(n.dim, " <span class=""badge"">disabled</span>", " <span class=""badge on"">enabled</span>");
end
li = "<li>";
if n.key ~= ""; li = "<li class=""c-" + n.key + """>"; end
h = li + "<span class=""cl""></span><span class=""cr""></span><div class=""n k-" + n.kind + ternary(n.dim, " dim", "") + """" ...
    + navAttr(n.target, n.title) + "><div class=""t"">" + title + "</div>" + detail + "</div>";
if ~isempty(n.children)
    h = h + "<span class=""stem""></span><ul>" + joinHTML(cellfun(@nodeHTML, n.children, "UniformOutput", false)) + "</ul>";
end
h = h + "</li>";
end


function a = navAttr(target, title)
%navAttr  The attributes setup() looks for to make a box open its controls.
if strlength(target) == 0
    a = "";
else
    a = " data-nav=""" + esc(target) + """ data-title=""" + esc(title) + """";
end
end


function h = joinHTML(parts)
%joinHTML  Concatenate a cell array of HTML strings.
h = join([string.empty(1, 0), parts{:}], "");
if isempty(h); h = ""; end
end


function h = legendHTML()
items = [ ...
    "<span class=""n k-src"">recording</span>", ...
    "<span class=""n k-step"">step</span>", ...
    "<span class=""n k-stage"">stage</span>", ...
    "<span class=""n k-op"">processing</span>", ...
    "<span class=""n k-off"">off in this config</span>", ...
    "<span class=""n k-link"">artifact periods</span>", ...
    "<span class=""n k-data"">input from a step</span>", ...
    "<span class=""n k-out"">written</span>"];
h = "<div class=""legend"">" + join(items, "") + "</div>";
end


function s = js()
%js  Page script: make every box with a target open it in the app.
%   setup() is called only by the app's HTML component (matlab.ui.control.HTML),
%   so a saved page keeps its boxes plain: the class it adds to <body> is what
%   turns on the pointer, the hover and the hint line.
s = join([ ...
    "function setup(htmlComponent) {"
    "  document.body.classList.add('live');"
    "  var boxes = document.querySelectorAll('[data-nav]');"
    "  for (var i = 0; i < boxes.length; i++) {"
    "    (function (el) {"
    "      el.setAttribute('tabindex', '0');"
    "      el.setAttribute('role', 'button');"
    "      el.title = 'Open this setting';"
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
    ], newline);
end


function s = css()
s = join([ ...
    "body{font:12px/1.35 'Segoe UI',system-ui,sans-serif;color:#1f2328;background:#f4f5f7;margin:0;padding:10px 14px 24px}"
    "h1{font-size:15px;margin:0 0 6px}"
    "h2{font-size:13px;margin:16px 0 8px;color:#57606a;font-weight:600}"
    ".legend{--acc:#8c959f;--tint:#f0f1f3;display:flex;flex-wrap:wrap;gap:6px}"
    ".legend .n{display:inline-block;padding:2px 8px;min-width:0}"
    ".card{--acc:#8c959f;--tint:#f0f1f3;display:inline-block;min-width:100%;margin-top:12px;background:#fff;border:1px solid #d0d7de;border-radius:8px;padding:12px;box-sizing:border-box}"
    ".cards{display:flex;flex-wrap:wrap;gap:14px;align-items:flex-start}"
    ".cards .card{min-width:0;max-width:100%;margin-top:0;overflow-x:auto}"
    ".badge{font-size:11px;font-weight:400;padding:0 6px;border-radius:9px;background:#eaeef2;color:#57606a}"
    ".badge.on{background:#dafbe1;color:#116329}"
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
    ".k-step{background:var(--tint);border-color:var(--acc);border-width:2px;border-left-width:6px;font-size:13px}"
    ".k-stage{background:var(--tint);font-size:12.5px}"
    ".k-off{border-style:dashed;border-left-style:dashed;border-left-color:#afb8c1;background:#f6f8fa;color:#8c959f}"
    ".k-off .d{color:#8c959f}"
    ".k-link{border-color:#d9822b;border-left-color:#d9822b;background:#fdf0e2;border-radius:12px}"
    ".k-data{border-style:double;border-width:3px;border-left-width:4px;background:#fff}"
    ".k-out{background:var(--tint);border-color:var(--acc)}"
    ".dim{opacity:.55}"
    % Clickable only in the app: setup() adds .live to <body> (see js()).
    ".hint{display:none;font-size:11px;color:#57606a;margin:6px 0 0}"
    "body.live .hint{display:block}"
    "body.live [data-nav]{cursor:pointer}"
    "body.live .n[data-nav]:hover{border-color:var(--acc);box-shadow:0 0 0 2px rgba(31,127,191,.25)}"
    "body.live .n[data-nav]:focus-visible{outline:2px solid #1f7fbf;outline-offset:1px}"
    "body.live [data-nav].picked{box-shadow:0 0 0 3px rgba(31,127,191,.55)}"
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


function v = pick(given, dropDown, fallback)
%pick  GIVEN, else the drop-down's value, else FALLBACK (before the tab is built).
v = given;
if v == ""
    v = string(fallback);
    if ~isempty(dropDown) && isvalid(dropDown)
        v = string(dropDown.Value);
    end
end
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
