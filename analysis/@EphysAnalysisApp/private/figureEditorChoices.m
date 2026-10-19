function ch = figureEditorChoices(type, source, rows)
%figureEditorChoices  What the figure editor's drop-downs offer a panel of TYPE whose first layer reads SOURCE.
%   CH = figureEditorChoices(TYPE, SOURCE, ROWS) has (ROWS, default
%   "items": a heat map's options.rows; "trials" lets its spike layer
%   follow the observation)
%     Sources        the layer sources the panel type draws, in order: those
%                    of its categories (EphysAnalysisConfig.panelTypes,
%                    sourceCategories), then "events" on a panel that
%                    shares the time axis (categoryOf; a spectrum, rate,
%                    tuning or coherence panel takes none): a spectrum or
%                    coherence panel units, detected, LFP, MUA, SPIKE, AUX;
%                    a spectrogram the signals and events; an event-trace
%                    panel events only
%     SourceLabels   their names in the app ("units (sorted)", ...)
%     Bindable       a layer of SOURCE on this type may follow the
%                    observation (spikes or a signal, on a raster, PSTH,
%                    continuous, waveforms, rate, tuning, spectrum,
%                    spectrogram or coherence panel; spikes on a heat map
%                    of trials); otherwise it is fixed
%     BaselineModes  the options.baseline modes the type takes (auroc on a
%                    PSTH or a heat map of spikes; a heat map of a signal,
%                    SOURCE a signal: none and subtract only; rate and
%                    tuning: firingRate's none, subtract, ratio, zscore; a
%                    spectrogram chronuxNormalize's none, db, percent,
%                    zscore, ratio)
%     WaveModes, WaveLabels  options.waveform.mode: an inset may be off, a
%                    waveforms panel's waveform not
%   An unknown TYPE offers no source.
%
%   See also EphysAnalysisConfig.panelTypes, EphysAnalysisConfig.categoryOf.
arguments
    type (1,1) string
    source (1,1) string = ""
    rows (1,1) string = "items"
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
    'WaveLabels', ["Off" "Mean" "Subsample" "Mean + subsample"]);
switch type
    case "psth"
        ch.BaselineModes = ["none" "subtract" "zscore" "percent" "auroc"];
    case "heatmap"
        ch.BaselineModes = ["none" "subtract" "zscore" "percent" "auroc"];
        if ismember(source, EphysAnalysisConfig.SignalSources); ch.BaselineModes = ["none" "subtract"]; end
    case {"continuous" "corrmap"}
        ch.BaselineModes = ["none" "subtract"];
    case {"rate" "tuning"}
        ch.BaselineModes = ["none" "subtract" "ratio" "zscore"];
    case "spectrogram"   % chronuxNormalize's
        ch.BaselineModes = ["none" "db" "percent" "zscore" "ratio"];
    case "waveforms"
        ch.WaveModes = ch.WaveModes(2:end);
        ch.WaveLabels = ch.WaveLabels(2:end);
end
end
