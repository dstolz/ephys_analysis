function why = figureRowReason(label, key, type)
%figureRowReason  Why the figure editor hides a row, in a sentence for the status bar: "Bin (ms) is an option of PSTH, heat map and unit correlation panels: pick such a panel."
%   WHY = figureRowReason(LABEL, KEY, TYPE): LABEL is the row's label as
%   listed, KEY its first formRow key (syncFigureEditor's names), TYPE the
%   selected panel's type ("" = none). The reasons follow what
%   syncFigureEditor shows: the Observations rows by the data observed,
%   the First-spike latency rows by the figure's panels and the method,
%   the Sessions rows by Across sessions, the Probe layout rows by On the
%   probe, the selected panel's rows, the
%   picked layer's by its source and binding, the Options rows by the
%   panel's type (an option of the selected type that is still hidden says
%   what else it needs), the Waveform rows by the panel's type
%   (waveformNote: why a type draws no waveform; an inset's place, a
%   probe layout's glyphs), the overlay rows by the overlay picked, the
%   Appearance rows by the figure's panel types. A key it does not know
%   gets a plain "is not used by this figure, its selected panel or layer".
%
%   See also EphysAnalysisApp.gotoFigureRow, syncFigureEditor.
arguments
    label (1,1) string
    key (1,1) string
    type (1,1) string = ""
end
% the Options rows: the panel types that show each, and what more a row needs on one of them
if startsWith(key, "wave") && key ~= "waveLayout"   % the Waveform section's rows
    why = waveReason(label, key, type);
    return
end
T = optionTypes();
if isfield(T, key)
    o = T.(key);
    why = label + " is an option of " + typeList(o.types) + " panels";
    if ismember(type, o.types)
        if o.needs ~= ""; why = why + ", " + o.needs; end
        why = why + ".";
    elseif type == ""
        why = why + ": pick such a panel.";
    elseif ismember(key, ["stack" "stackSpacing"])   % why a type does not stack
        why = why + ", not of " + typeList(type) + " panels: " + noStack(type);
    else
        why = why + ", not of " + typeList(type) + " panels: pick such a panel.";
    end
    return
end
switch key
    case {"obsClasses" "obsQuality"}
        tail = "is for sorted units: pick Sorted units in Observe.";
    case {"obsResponse" "obsRespBaseFrom" "obsRespParam" "obsIds" "obsMaxUnits" "obsShanks" "obsUnitChannels"}
        tail = "is for sorted units and detected spikes: pick one of them in Observe.";
    case {"obsRaMethod" "obsRaWinMs" "obsRaCutoff"}
        tail = "is a setting of the auROC response test: pick auROC as the Response test.";
    case "obsRaTest"
        tail = "is a setting of the auROC response test with the per-unit test cutoff.";
    case "obsChannels"
        tail = "is for a signal: pick LFP, MUA, SPIKE or AUX in Observe.";
    case "obsPerGroup"
        tail = "is not used by a figure across sessions (its Trial groups row, Sessions, decides) or on the probe (Probe layout).";
    case {"prbLayout" "prbOverlap" "prbLanes" "prbShanks" "prbChannels" "prbDepth" "prbMaxTiles" "prbPerSite" "prbTileWidth" ...
            "prbTileHeight" "prbScale" "prbLabels" "prbSharedY" "prbScaleTile" "prbShowSites" "prbLeaders" "prbNote"}
        tail = "shows once On the probe is ticked (Probe layout).";
    case {"sesDatasets" "sesFacet" "sesSeries" "sesColorOrder" "sesTrialGroups" "sesMinSessions" "sesShowMembers" "sesError" "sesNote"}
        tail = "shows once Across sessions is ticked (Sessions).";
    case "sesKeys"
        tail = "shows with Across sessions ticked and Datasets: These datasets.";
    case {"latNote" "latMethod" "latFrom" "latBaseline" "latCusum" "latCusumSD"}
        tail = "is the figure's first-spike latency: it shows while the figure has a raster, PSTH or heat map panel.";
    case "latRate"
        tail = "is for the Poisson methods: pick Poisson surprise or Baseline Poisson count as the Method (First-spike latency).";
    case "latSurprise"
        tail = "is for the Poisson surprise method: pick it as the Method (First-spike latency).";
    case "latAlpha"
        tail = "is for the Baseline Poisson count method: pick it as the Method (First-spike latency).";
    case "sesMatch"
        tail = "is for a figure of units drawn across sessions.";
    case "sesMappingFile"
        tail = "shows when the units are matched by a mapping file (Units matched by: Mapping).";
    case {"selPanel" "rowSpan" "colSpan" "rowHeight" "colWidth" "panelButtons" "panelWidth" "panelAlign" "panelType" ...
            "panelTitle" "panelBox" "panelXLabel" "panelXSide" "panelYLabel" "panelYSide"}
        tail = "is a setting of the selected panel: pick one in the schematic.";
    case "group"
        tail = "is an option of heat map, unit correlation and spectrogram panels (and a coherence panel drawn over time); " + ...
            "a heat map of one unit's epochs and a stacked panel (Stack: one row per group) draw every group.";
    case {"layerName" "layerSource" "layerBinding"}
        tail = "is a setting of the picked layer: pick one in the Layers list.";
    case "layerFollows"
        tail = "shows for a spike or signal layer that follows the observation.";
    case "layerClasses"
        tail = "is for a fixed layer of sorted units.";
    case {"layerIds" "layerQuality" "layerMaxUnits" "layerShanks" "layerUnitChannels"}
        tail = "is for a fixed layer of sorted units or detected spikes.";
    case "layerChannels"
        tail = "is for a fixed signal layer (LFP, MUA, SPIKE or AUX).";
    case "layerAggregate"
        tail = "is for a fixed spike or signal layer of a raster, PSTH, continuous signal, firing rate or tuning curve panel.";
    case {"evLine" "evEdge" "evSeqText" "evDrawAs"}
        tail = "is for an events layer: pick one in the Layers list.";
    case "evMarker"
        tail = "is for an events layer drawn as marks.";
    case "evColor"
        tail = "is for an events layer drawn as marks or as a line from onset to offset.";
    case "evSpanStyle"
        tail = "is for an events layer drawn as a line from onset to offset.";
    case {"layerColor" "layerLineStyle"}
        tail = "is for a layer that is not drawn as event marks or spans.";
    case {"ovName" "ovKind" "ovLayer" "ovStyle"}
        tail = "is a setting of the picked overlay: add one, or pick one in the Overlays list.";
    case {"ovValue" "ovColor"}
        tail = "is for a line overlay: pick one in the Overlays list.";
    case {"ovFrom" "ovFill" "ovEdge"}
        tail = "is for a patch overlay: pick one in the Overlays list.";
    case "siteSize"
        tail = "is for a figure with a probe map panel.";
    case "heatColormap"
        tail = "is for a figure with a heat map, probe map or unit correlation panel, or a PSTH drawn as a heat map.";
    otherwise
        tail = "is not used by this figure, its selected panel or layer.";
end
why = label + " " + tail;
end


function s = noStack(type)
%noStack  Why a panel type takes no stack, in a sentence's tail.
switch type
    case "raster", s = "a raster lists its groups in blocks already.";
    case "rate", s = "a firing rate panel puts its groups along x.";
    case "eventTrace", s = "an event-trace panel has a row per line already.";
    case "corrmap", s = "a unit correlation map is a units-by-units matrix (draw a panel per group with Group shown).";
    case {"waveforms" "probemap"}, s = "it has no trial groups to stack.";
    otherwise, s = "pick such a panel.";
end
end


function T = optionTypes()
%optionTypes  The Options rows syncFigureEditor shows by panel type: the types, and what more the row needs on them ("" = nothing).
o = @(types, needs) struct('types', types, 'needs', needs);
spikesHeat = "on a heat map, of spikes";
T = struct();
T.binMs = o(["psth" "heatmap" "corrmap"], spikesHeat);
T.smoothMs = T.binMs;
T.measure = o(["psth" "heatmap" "rate" "tuning"], spikesHeat);
T.baselineMode = o(["psth" "continuous" "heatmap" "corrmap" "rate" "tuning" "spectrogram"], "");
T.baseFrom = T.baselineMode;
T.psthDisplay = o("psth", "");
T.normalize = o("psth", "");
for f = ["histStyle" "fill"]; T.(f) = o("psth", "with Display: trace"); end
T.stack = o(["psth" "continuous" "heatmap" "tuning" "spectrum" "spectrogram" "coherence"], ...
    "on a PSTH with Display: trace, on a heat map with Rows: the layer's units or channels (a raster lists its groups " + ...
    "in blocks already, a firing rate panel puts them along x; a waveforms, probe map, unit correlation or event-trace " + ...
    "panel has no groups over a shared axis to stack)");
T.stackSpacing = T.stack;
T.panelColormap = o("psth", "with Display: heat map");
T.param = o("tuning", "");
T.rateDisplay = o("rate", "");
T.waveLayout = o("waveforms", "");
for f = ["rasterSort" "sortLine" "sortSeqText" "rasterByGroup"]
    T.(f) = o(["raster" "heatmap" "eventTrace"], "on a heat map, with Rows: one unit's epochs (trials)");
end
T.yTicks = o("raster", "");
T.tickColor = T.yTicks;
T.tickWidth = T.yTicks;
T.backColor = T.yTicks;
T.firstSpike = T.yTicks;
T.latencyBox = o("psth", "with Display: trace");
T.onsetLine = o(["raster" "psth"], "");
T.trialCount = o("psth", "");
T.heatRows = o("heatmap", "");
for f = ["contTrials" "statistic" "errorType"]; T.(f) = o("continuous", ""); end
T.maskAfterStop = o(["raster" "psth" "heatmap"], spikesHeat);
T.order = o("heatmap", "with Rows: the layer's units or channels");
for f = ["etDisplay" "etTrials" "etColorBy" "etHeight" "etEdge" "etMinWidth" "etLineStyle" "etBaseline" "etBaseStyle" "etRowSpacing"]
    T.(f) = o("eventTrace", "");
end
T.value = o("probemap", "");
T.unitLabels = o("probemap", "");
T.waveColor = o("probemap", "with Waveform: Show, and Value: rate or nSpikes");
for f = ["metric" "correlation" "fisherZ"]; T.(f) = o("corrmap", ""); end
T.yLim = o(["psth" "continuous" "waveforms" "rate" "tuning" "spectrum" "coherence"], ...
    "on a PSTH with Display: trace, on a coherence panel unless drawn over time (an image's scale is its Color limits)");
T.yLimMode = T.yLim;
T.cLim = o(["psth" "heatmap" "probemap" "corrmap" "spectrogram" "coherence"], ...
    "on a PSTH with Display: heat map, on a coherence panel drawn over time");
T.spTimeBase = o(["spectrum" "coherence"], "");
T.spRangeFrom = o(["spectrum" "coherence"], "with Time base: segments of the recording");
T.spSegment = o(["spectrum" "coherence"], "with Time base: segments of the recording (a coherence panel not drawn over time)");
for f = ["spTaperMode" "spTW" "spW" "spPad" "spFmin" "spDetrend"]; T.(f) = o(["spectrum" "spectrogram" "coherence"], ""); end
T.spErr = o(["spectrum" "coherence"], "on a coherence panel, unless drawn over time");
T.spScale = o(["spectrum" "spectrogram"], "");
T.spSpikeFs = o(["spectrum" "spectrogram" "coherence"], "with a spike layer");
T.spOverTime = o("coherence", "");
T.spWin = o(["spectrogram" "coherence"], "on a coherence panel, drawn over time");
T.spShowPhase = o("coherence", "unless drawn over time");
for f = ["auMethod" "auWinMs" "auModFrom" "auCutoff" "auMarks"]
    T.(f) = o(["psth" "heatmap"], "with the auroc baseline (a heat map of spikes)");
end
T.auTest = o(["psth" "heatmap"], "with the auroc baseline and the per-unit test cutoff");
end


function why = waveReason(label, key, type)
%waveReason  Why the Waveform section hides a row: no panel, a type that draws no waveform, or a row this type's waveform does not use.
inset = "raster, PSTH, firing rate or tuning curve";   % EphysAnalysisConfig.WaveformInsetTypes
if type == ""
    why = label + " is a setting of the selected panel's unit waveform (Waveform): pick a raster, PSTH, firing " + ...
        "rate, tuning curve or unit waveforms panel.";
    return
end
[note, draws] = waveformNote(type);
if ~draws
    why = label + " is not used: " + note;
    return
end
switch key
    case {"waveLocation" "waveBox"}
        why = label + " places an inset, on a " + inset + " panel: a unit waveforms panel's waveform is the panel " + ...
            "itself, a probe map's are at the units' places.";
    case {"waveWidth" "waveHeight"}
        why = label + " sizes an inset (" + inset + " panels) or the glyphs of a probe map or of a unit waveforms " + ...
            "panel in the probe layout: in the grid layout the waveform fills its panel.";
    case {"waveSites" "waveNames"}
        why = label + " is for a unit waveforms panel in the probe layout (Options: Layout); a probe map draws its " + ...
            "sites always, and names its units with Unit labels (Options).";
    case {"wavePP" "waveCount"}
        why = label + " labels an inset or a unit waveforms panel's waveform; a probe map names its units with " + ...
            "Unit labels (Options).";
    otherwise
        why = label + " is not used by this panel's waveform.";
end
end


function s = typeList(types)
%typeList  Panel types in words: "PSTH, heat map and unit correlation".
PT = EphysAnalysisConfig.panelTypes();
w = strings(1, numel(types));
for i = 1:numel(types)
    l = PT.Label(PT.Type == types(i));
    if isempty(l); l = types(i); end
    if types(i) == "eventTrace"
        l = "event-trace";
    elseif l ~= upper(l)
        l = lower(extractBefore(l, 2)) + extractAfter(l, 1);
    end
    w(i) = l;
end
if numel(w) == 1
    s = w;
else
    s = strjoin(w(1:end-1), ", ") + " and " + w(end);
end
end
