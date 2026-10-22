function ch = figureEditorChoices(type, source, rows, opts)
%figureEditorChoices  What the figure editor's drop-downs offer a panel of TYPE whose first layer reads SOURCE.
%   CH = figureEditorChoices(TYPE, SOURCE, ROWS, Observed=DATA) has (ROWS,
%   default "items": a heat map's options.rows; "trials" lets its spike
%   layer follow the observation; DATA, default "": the figure's
%   observe.data, "" for any)
%     Sources        the layer sources the panel type draws, in order: those
%                    of its categories (EphysAnalysisConfig.panelTypes,
%                    sourceCategories), then "events" on a panel that
%                    shares the time axis (categoryOf; a spectrum, rate,
%                    tuning or coherence panel takes none): a spectrum or
%                    coherence panel units, detected, LFP, MUA, SPIKE, AUX;
%                    a spectrogram the signals, units, detected and events;
%                    an event-trace panel events only
%     SourceLabels   their names in the app ("units (sorted)", ...)
%     Bindable       a layer of SOURCE on this type may follow the
%                    observation (spikes or a signal, on a raster, PSTH,
%                    continuous, waveforms, rate, tuning, spectrum,
%                    spectrogram or coherence panel; spikes on a heat map
%                    of trials); otherwise it is fixed. AUX records no
%                    amplifier channel (figureLayerItems): under a figure
%                    observing units or another signal an AUX layer is
%                    fixed, and under one observing AUX so is every other
%     Aggregates, AggregateLabels  how a fixed layer of SOURCE draws its
%                    items (EphysAnalysisConfig.aggregates): "each unit" or
%                    "each channel" and "their mean" on a raster, PSTH,
%                    continuous, rate or tuning panel; "each channel" and
%                    "their vector magnitude" for a signal on a spectral
%                    panel; else "each" alone (no choice to offer)
%     BaselineModes  the options.baseline modes the type takes (auroc on a
%                    PSTH or a heat map of spikes; a heat map of a signal,
%                    SOURCE a signal: none and subtract only; rate and
%                    tuning: firingRate's none, subtract, ratio, zscore; a
%                    spectrogram chronuxNormalize's none, db, percent,
%                    zscore, ratio)
%     WaveModes, WaveLabels  options.waveform.mode: an inset may be off, a
%                    waveforms panel's waveform not ("subsample" reads
%                    "Individual spikes")
%     WaveAmps, WaveAmpLabels  options.waveform.ampScale: each unit's own
%                    range or a fixed one; a waveforms panel also one
%                    common to its units (an inset draws one unit)
%   An unknown TYPE offers no source.
%
%   See also EphysAnalysisConfig.panelTypes, EphysAnalysisConfig.categoryOf.
arguments
    type (1,1) string
    source (1,1) string = ""
    rows (1,1) string = "items"
    opts.Observed (1,1) string = ""
end
T = EphysAnalysisConfig.panelTypes();
S = EphysAnalysisConfig.sourceCategories();
row = T.Type == type;
srcs = string.empty(1, 0);
if any(row)
    for c = T.Categories{row}
        srcs = [srcs S.Sources{S.Category == c}]; %#ok<AGROW>
    end
    srcs = srcs(srcs ~= "events");   % events only where categoryOf takes them: the time panels
    if T.SharesTime(row); srcs(end+1) = "events"; end
    if type == "eventTrace"; srcs = "events"; end   % its only source (categoryOf)
end
srcs = unique(srcs, 'stable');
names = dictionary(["units" "detected" "events" "LFP" "MUA" "SPIKE" "AUX"], ...
    ["units (sorted)" "detected spikes" "events (a line)" "LFP" "MUA" "SPIKE" "AUX"]);
labels = srcs;
known = isKey(names, srcs);
labels(known) = names(srcs(known));
ch = struct('Sources', srcs, 'SourceLabels', labels, ...
    'Bindable', (ismember(source, [EphysAnalysisConfig.SpikeSources EphysAnalysisConfig.SignalSources]) ...
        && ismember(type, ["raster" "psth" "continuous" "waveforms" "rate" "tuning" "spectrum" "spectrogram" "coherence"])) ...
        || (type == "heatmap" && rows == "trials" && ismember(source, EphysAnalysisConfig.SpikeSources)), ...
    'BaselineModes', "none", 'WaveModes', ["off" "mean" "subsample" "both"], ...
    'WaveLabels', ["Off" "Mean" "Individual spikes" "Mean + individual spikes"], ...
    'WaveAmps', ["unit" "fixed"], 'WaveAmpLabels', ["Each unit's own range" "Fixed range"]);
if ismember(opts.Observed, [EphysAnalysisConfig.SpikeSources EphysAnalysisConfig.SignalSources]) ...
        && (source == "AUX") ~= (opts.Observed == "AUX")
    ch.Bindable = false;   % nothing to follow: AUX has no recording channel
end
ch.BaselineModes = EphysAnalysisConfig.baselineModes(type, source);
ch.Aggregates = EphysAnalysisConfig.aggregates(type, source);
what = "unit";
if ismember(source, EphysAnalysisConfig.SignalSources); what = "channel"; end
words = dictionary(["each" "mean" "magnitude"], ["each " + what "their mean" "their vector magnitude"]);
ch.AggregateLabels = words(ch.Aggregates);
switch type
    case "waveforms"
        ch.WaveModes = ch.WaveModes(2:end);
        ch.WaveLabels = ch.WaveLabels(2:end);
        ch.WaveAmps = EphysAnalysisConfig.WaveformAmpScales;
        ch.WaveAmpLabels = ["Each unit's own range" "One range for the units drawn" "Fixed range"];
end
end
