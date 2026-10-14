function T = panelTypes()
%panelTypes  The panel types of a figure: the data each draws and its options.
%   T = EphysAnalysisConfig.panelTypes() has one row per type, the analog
%   of plotKinds for the panels of a figure (the Figures section):
%     Type            "raster" | "psth" | "continuous" | "heatmap" |
%                     "waveforms" | "probemap" | "corrmap"
%     Label           name shown in the app
%     Categories      the source categories its layers draw
%                     (sourceCategories: point, continuous, unit)
%     Aligned         true when it is cut into epochs around events (its
%                     ref and window are used)
%     SharesTime      its x axis is time from the event: while its ref and
%                     window are "default" it takes the figure's time axis,
%                     and it takes events layers (marks or a train)
%     OneGroup        it draws one trial group (options.group)
%     MultiLayer      it draws every enabled layer (else the first only)
%     DefaultBinding  what a new layer of the type binds to: "observation"
%                     (the previewed / generated unit or channel) or
%                     "fixed" (the units / channels / line it names)
%     Description     one line
%     DefaultOptions  the type's options struct (Panel.options): the
%                     fields and defaults normalizePanel coerces to. Field
%                     names repeat the Plot's where the meaning is the same
%                     (bins, measure, baseline, histStyle, rasterSort, ...)
%
%   Per-panel y and color limits (options.yLim, options.cLim: [] =
%   automatic, else [lo hi]) live in the options because one figure holds
%   different axes; a figure's Style.YLim / Style.CLim are not used.
%
%   See also EphysAnalysisConfig.sourceCategories, EphysAnalysisConfig.categoryOf,
%   EphysAnalysisConfig.plotKinds, EphysAnalysisConfig.defaultLayer.

bins = struct('BinSec', 0.01, 'SmoothSec', 0.01);              % SmoothSec: Gaussian SD (0 = none)
baseline = struct('Mode', "none", 'Window', [-0.2 0]);
waveform = EphysAnalysisConfig.defaults("Waveform");           % raster / psth: the unit's waveform inset ("off" = none)
waveformsOwn = waveform;
waveformsOwn.mode = "both";                                    % a waveforms panel: the mean over a subsample

opts = struct();
opts.raster = struct( ...
    'rasterSort',      "", ...          % "" (trial order) | "stop" | "event" (rasterSortEvent's latency) | a trial parameter
    'rasterSortEvent', [], ...          % rasterSort "event": [] or an EventRef
    'rasterSortOrder', "ascending", ... % "ascending" | "descending" (missing values last)
    'rasterByGroup',   true, ...        % rows by group first, on bands (false: one block)
    'maskAfterStop',   false, ...       % drop the ticks after each epoch's stop event
    'waveform',        waveform);       % the unit's waveform inset
opts.psth = struct( ...
    'bins',          bins, ...
    'measure',       "rate", ...        % "rate" (spikes/s) | "count" | "probability"
    'baseline',      baseline, ...      % Mode "none" | "subtract" | "zscore" | "percent"
    'histStyle',     "bar", ...         % "bar" | "line"
    'fill',          true, ...          % filled bars / area under the line
    'fillAlpha',     NaN, ...           % fill opacity 0-1 (NaN: 0.5 where groups overlap, else 1)
    'normalize',     "none", ...        % "none" | "unitPeak" | "groupPeak" | "allPeak"
    'maskAfterStop', false, ...
    'yLim',          [], ...            % [] = automatic, else [lo hi]
    'waveform',      waveform);
opts.continuous = struct( ...
    'baseline',     baseline, ...       % Mode "none" | "subtract"
    'display',      "lines", ...        % "lines" (a trace each) | "stacked" (a row of its own per channel)
    'statistic',    "mean", ...         % "mean" | "median" over the epochs, at each sample
    'transform',    "none", ...         % "none" | "rectify" (each epoch's absolute value, before the statistic)
    'errorType',    "sem", ...          % the band: "off" | "sem" | "std" | "ci95" | "iqr"
    'stackSpacing', NaN, ...            % stacked: the offset between channels (NaN = automatic)
    'yLim',         []);
opts.heatmap = struct( ...
    'bins',          bins, ...
    'measure',       "rate", ...
    'baseline',      baseline, ...
    'order',         "probe", ...       % rows: "probe" (the style's SortDepth / SortShank) | "peak"
    'group',         1, ...             % the trial group drawn
    'cLim',          [], ...
    'maskAfterStop', false);
opts.waveforms = struct( ...
    'waveform', waveformsOwn, ...       % mode "mean" | "subsample" | "both" (never "off")
    'yLim',     []);
opts.probemap = struct( ...
    'value', "rate", ...                % "rate" | "nSpikes" | "nUnits"
    'cLim',  []);
opts.corrmap = struct( ...
    'metric',      "mean", ...          % each epoch's "mean" or "peak" (binned) rate
    'correlation', "pearson", ...       % "pearson" | "spearman"
    'fisherZ',     false, ...
    'bins',        bins, ...
    'baseline',    baseline, ...        % Mode "none" | "subtract"
    'group',       1, ...
    'cLim',        []);

%   Type          Label                Categories               Aligned SharesTime OneGroup MultiLayer DefaultBinding  Description
rows = {
    "raster",     "Raster",            "point",                 true,   true,      false,   true,      "observation",  "Spike rasters: a row per epoch, by group; events as marks on the rows or as rows of their own"
    "psth",       "PSTH",              "point",                 true,   true,      false,   true,      "observation",  "Peri-event firing rate, groups overlaid; events as latency lines or as a PSTH of their own"
    "continuous", "Continuous signal", "continuous",            true,   true,      false,   true,      "observation",  "The epochs' mean of LFP / MUA / SPIKE / AUX channels, with an error band"
    "heatmap",    "Heat map",          ["point" "continuous"],  true,   true,      true,    false,     "fixed",        "Units or channels by time in color, one trial group"
    "waveforms",  "Unit waveforms",    "unit",                  false,  false,     false,   false,     "observation",  "A unit's mean waveform and a sample of its spikes"
    "probemap",   "Probe map",         "unit",                  false,  false,     false,   false,     "fixed",        "A per-channel value (rate, spikes, units) drawn on the probe sites"
    "corrmap",    "Unit correlation",  "unit",                  true,   false,     true,    false,     "fixed",        "Pairwise correlation of the units' per-epoch rates, one trial group"
    };
n = size(rows, 1);
Type = strings(n, 1); Label = strings(n, 1); DefaultBinding = strings(n, 1); Description = strings(n, 1);
Categories = cell(n, 1); DefaultOptions = cell(n, 1);
Aligned = false(n, 1); SharesTime = false(n, 1); OneGroup = false(n, 1); MultiLayer = false(n, 1);
for k = 1:n
    Type(k) = rows{k, 1};
    Label(k) = rows{k, 2};
    Categories{k} = rows{k, 3};
    Aligned(k) = rows{k, 4};
    SharesTime(k) = rows{k, 5};
    OneGroup(k) = rows{k, 6};
    MultiLayer(k) = rows{k, 7};
    DefaultBinding(k) = rows{k, 8};
    Description(k) = rows{k, 9};
    DefaultOptions{k} = opts.(Type(k));
end
T = table(Type, Label, Categories, Aligned, SharesTime, OneGroup, MultiLayer, DefaultBinding, Description, DefaultOptions);
end
