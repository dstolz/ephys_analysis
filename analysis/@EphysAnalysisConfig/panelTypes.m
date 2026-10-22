function T = panelTypes()
%panelTypes  The panel types of a figure: the data each draws and its options.
%   T = EphysAnalysisConfig.panelTypes() has one row per type of the
%   panels of a figure (the Figures section):
%     Type            "raster" | "psth" | "continuous" | "heatmap" |
%                     "waveforms" | "probemap" | "corrmap" | "rate" |
%                     "tuning" | "spectrum" | "spectrogram" | "coherence" |
%                     "eventTrace"
%     Label           name shown in the app
%     Short           one word: the type's part of an automatic figure id
%                     (autoFigureId: "Raster+PSTH units")
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
%   different axes; a figure's Style.YLim / Style.CLim are not used. Every
%   type with a y axis of values (PSTH, continuous, waveforms, rate,
%   tuning, spectrum, coherence) takes options.yLimMode, one vocabulary
%   (EphysAnalysisConfig.YLimModes):
%     "auto"   (default) each axis fits its data (the type's own: an auROC
%              and a coherence 0 to 1); in a stack each row fits itself,
%              scaled to its own reach (its top named on the right axis)
%     "rows"   a stack's rows share one scale, the reach of them all (an
%              axis without rows: as "auto", its groups share it already)
%     "batch"  one range for every observation of a run of the figure
%              (EphysAnalysisRunner.run: Generate, Export): the union of
%              their extents (figureYExtents, figureBatchYLim), a stack's
%              rows on that one scale; drawn alone (the preview) a panel
%              takes its own range, as "rows"
%     "fixed"  options.yLim ([lo hi]; a stack: every row's range)
%
%   A PSTH or a heat map of spikes takes baseline Mode "auroc" (each bin's
%   auROC against the baseline window, spikePSTH's BaselineMode "auroc")
%   with its auroc settings (defaults("Auroc")).
%   Stacks, one vocabulary for every type that takes them
%   (EphysAnalysisConfig.stackModes): a PSTH, continuous, heat map (rows
%   "items"), tuning, spectrum, spectrogram or coherence panel with stack
%   "groups" draws one row per trial group (a tuning panel's series), the
%   first on top as a raster lists its groups, instead of the groups
%   overlaid (a heat map, a spectrogram, a coherogram: instead of the one
%   group options.group names); a continuous panel's stack "items" draws a
%   row per channel (or layer mean), the groups overlaid in each.
%   stackSpacing is the row step as a multiple of the row height, the
%   tallest row's (1: the rows touch; below 1 they overlap; an image's
%   rows never overlap). Line rows name their groups on the left axis and
%   each row's top (a PSTH's peak) on the right; image rows (a
%   spectrogram's, a coherogram's, a heat map's block of units) share the
%   time axis and one color scale and color bar, each with its group's
%   color strip at the left. A raster panel above a stacked PSTH draws
%   the rasters (a raster lists its groups in blocks already: it takes no
%   stack). A raster's firstSpike (defaults("FirstSpike")) marks each
%   epoch's first spike in a latency window, a PSTH's latencyBox
%   (defaults("LatencyBox")) draws a box plot of those latencies per
%   trial group in a band above its traces (in each row when stacked,
%   outside every row's y range whatever its yLimMode); both read
%   firstSpikeLatency. A rasterSort "latency" (a raster, a heat map of
%   trials; an event trace has no spikes: time order) orders the epochs by
%   their first spike's latency (a raster: in firstSpike's window, else
%   from the event to the window's end; epochs with no spike last).
%   A PSTH's trialCount says how many trials each group holds: "text"
%   writes "n = 24" per group in the group's color (a stack: at the right
%   end of each row; a heat map: beside each row), "legend" appends
%   "(n = 24)" to the group's legend entry (a heat map: to its row label).
%   A PSTH's display "heatmap"
%   draws its first item (unit or mean) as an image instead: a row per
%   trial group, the first on top, colored on that item's own range
%   (cLim, else its rows' range; an auROC: 0 to 1) in colormap ("" = the
%   design's heat colormap); histStyle, fill, fillAlpha, stack,
%   stackSpacing and yLim are not used then. A rate panel shows each epoch window's rate per
%   trial group (firingRate), a tuning panel the rate against a trial
%   parameter (tuningCurve: param, "" = the figure's first groupBy
%   parameter, else the trials' first numeric one; seriesParam, "" = one
%   curve). Their baseline Modes are firingRate's: none, subtract, ratio,
%   zscore. A waveforms panel's layout "probe" draws every unit of its
%   first layer at its place on the probe; a further layer (e.g. one
%   following the observation) rings its units there.
%   A raster, PSTH, rate or tuning panel's waveform (defaults("Waveform"),
%   EphysAnalysisConfig.WaveformInsetTypes) with a mode other than "off"
%   draws its first unit's waveform as an inset (waveformInset): its time
%   span (timeMs), width and height, amplitude scale (ampScale, ampLim),
%   place, box and label; a waveforms panel's waveform is the panel's own
%   drawing (its mode never "off"; width and height size its probe glyphs).
%   A continuous panel draws each epoch's trace with trials "faint"
%   (behind the mean, pale and thin) or "only" (no mean), at most
%   maxTrials epochs (default 100; Inf = every one) picked evenly over
%   their order. A heat map's rows
%   "trials" draw one unit's epochs (a layer following the observation, or
%   fixed to one unit), binned as its PSTH, sorted as a raster
%   (rasterSort, rasterSortOrder, rasterByGroup); its group is not used.
%   Every aligned panel may take a trial selection of its own
%   (Panel.selection): its own groups, colors and legend.
%   The spectral types draw Chronux analyses (Chronux must be on the
%   MATLAB path: toolboxes/chronux; without it they are skipped with
%   "Chronux is not on the path"). Their options are chronuxSettings'
%   (figureChronuxSettings builds the settings from them; none is a shared
%   option, sharedFieldsOf). A "spectrum" panel draws each layer's power spectra
%   (chronuxSpectrum of a signal's channels, chronuxSpikeSpectrum of spike
%   trains), the groups overlaid. A "spectrogram" draws one channel's or
%   unit's power over time and frequency (chronuxSpecgram of a signal,
%   chronuxSpikeSpecgram of a spike train) for one trial group, on the
%   figure's time axis; its baseline Modes are chronuxNormalize's (none,
%   db, percent, zscore, ratio), its Window inside the panel's window. A
%   "coherence" panel takes exactly two layers, the seed then its partner,
%   and pairs the seed's first item with each partner item: signal x
%   signal (chronuxCoherence), spikes x signal or signal x spikes
%   (chronuxSpikeField) or spikes x spikes (chronuxUnitCoherence); with
%   overTime a coherogram over the moving window,
%   which on the epochs shares the figure's time axis; showPhase draws the
%   phase under the magnitude. Spectrum and coherence take timeBase "range":
%   segments of the whole recording clear of its artifact periods, not
%   the figure's epochs.
%   An "eventTrace" panel draws digital or derived lines as a logic
%   analyzer does, on the figure's time axis: each events layer (one line)
%   a row of its own, its intervals from onset to offset, clipped at the
%   window's edges, as solid bars or a logic-level trace (display "bars" |
%   "line"); every epoch overlaid in the row, translucent (trials
%   "overlay"), or a sub-row per epoch sorted as a raster's rows (trials
%   "rows": rasterSort, rasterSortOrder, rasterByGroup, as a heat map of
%   trials sorts them); colored per line (colorBy "layer": the layer's
%   color, else a palette color) or by trial group; with a baseline per
%   row. A bar narrower than minWidth points (a zero-length interval too)
%   also gets a tick minWidth wide through its middle, so it shows at any
%   size. It takes events layers only (categoryOf) and their eventsAs is
%   not used. A session figure draws every session's epochs in it, as a
%   raster does, its series (sessions, subjects or all) as the groups.
%
%   See also EphysAnalysisConfig.sourceCategories, EphysAnalysisConfig.categoryOf,
%   EphysAnalysisConfig.defaultLayer.

bins = struct('BinSec', 0.01, 'SmoothSec', 0.01);              % SmoothSec: Gaussian SD (0 = none)
baseline = struct('Mode', "none", 'Window', [-0.2 0]);
waveform = EphysAnalysisConfig.defaults("Waveform");           % raster / psth / rate / tuning: the unit's waveform inset ("off" = none)
waveformsOwn = waveform;
waveformsOwn.mode = "both";                                    % a waveforms panel: the mean over a subsample
firstSpike = EphysAnalysisConfig.defaults("FirstSpike");       % raster: the first-spike latency marks (enabled false = none)
latencyBox = EphysAnalysisConfig.defaults("LatencyBox");       % psth: the box plot of the first-spike latencies (enabled false = none)
auroc = EphysAnalysisConfig.defaults("Auroc");                % psth / heatmap of spikes: baseline Mode "auroc"

opts = struct();
opts.raster = struct( ...
    'rasterSort',      "", ...          % "" (trial order) | "stop" | "event" (rasterSortEvent's latency) | "latency" (first-spike latency, firstSpike's window) | a trial parameter
    'rasterSortEvent', [], ...          % rasterSort "event": [] or an EventRef
    'rasterSortOrder', "ascending", ... % "ascending" | "descending" (missing values last)
    'rasterByGroup',   true, ...        % rows by group first (false: one block)
    'maskAfterStop',   false, ...       % drop the ticks after each epoch's stop event
    'tickColor',       "groups", ...    % the ticks' color: "groups" (each group's) | a color name or hex code (every tick)
    'tickWidth',       0, ...           % the ticks' line width, points (0: the plot design's)
    'backColor',       "none", ...      % bands behind the rows: "none" | "groups" (each group's pale band) | a color name or hex code (every band)
    'yTicks',         false, ...       % show the y axis' tick marks and labels (the epoch numbers; a further block's name stays)
    'firstSpike',      firstSpike, ...  % a mark on each epoch's first spike in [minSec, maxSec]: marker, size, color, filled
    'waveform',        waveform);       % the unit's waveform inset
opts.psth = struct( ...
    'bins',          bins, ...
    'measure',       "rate", ...        % "rate" (spikes/s) | "count" | "probability"
    'baseline',      baseline, ...      % Mode "none" | "subtract" | "zscore" | "percent" | "auroc"
    'auroc',         auroc, ...         % baseline Mode "auroc": the auROC's settings
    'display',       "trace", ...       % "trace" (bars or a line per group) | "heatmap" (an image: a row per group, the first on top)
    'histStyle',     "bar", ...         % "bar" | "line"
    'fill',          true, ...          % filled bars / area under the line
    'fillAlpha',     NaN, ...           % fill opacity 0-1 (NaN: 0.5 where groups overlap, else 1)
    'normalize',     "none", ...        % "none" | "unitPeak" | "groupPeak" | "allPeak"
    'stack',         "off", ...         % "off" (the groups overlaid) | "groups" (a row per trial group, the first on top)
    'stackSpacing',  1.1, ...           % stack: the row step, x the row height (1: the rows touch; < 1 overlaps)
    'latencyBox',    latencyBox, ...    % a box plot of the first-spike latencies per trial group, in a band above the traces (stack "groups": in each row)
    'trialCount',    "off", ...         % the trials in each group: "off" | "text" ("n = 24" per group, in its color) | "legend" (the legend entries read "<group> (n = 24)")
    'maskAfterStop', false, ...
    'yLimMode',      "auto", ...  % "auto" (each axis, each stacked row, fits itself) | "rows" (a stack's rows share one scale) | "batch" (one range for every observation of a run) | "fixed" (yLim)
    'yLim',          [], ...            % yLimMode "fixed": [lo hi]
    'colormap',      "", ...            % display "heatmap": "" (the design's heat colormap, Style.HeatColormap) | a colormap function
    'cLim',          [], ...            % display "heatmap": [] = the unit's own range (auROC: [0 1]), else [lo hi]
    'waveform',      waveform);
opts.continuous = struct( ...
    'baseline',     baseline, ...       % Mode "none" | "subtract"
    'statistic',    "mean", ...         % "mean" | "median" over the epochs, at each sample
    'transform',    "none", ...         % "none" | "rectify" (each epoch's absolute value, before the statistic) | "magnitude" (a layer's channels as one: their vector magnitude in each epoch, after the baseline)
    'errorType',    "sem", ...          % the band: "off" | "sem" | "std" | "ci95" | "iqr"
    'stack',        "off", ...          % "off" (overlaid) | "groups" (a row per trial group, the items overlaid in it) | "items" (a row per channel or layer mean, the groups overlaid in it)
    'stackSpacing', 1.1, ...            % stack: the row step, x the row height (1: the rows touch; < 1 overlaps)
    'trials',       "off", ...          % each epoch's trace: "off" | "faint" (pale and thin, behind the mean) | "only" (the traces, no mean)
    'maxTrials',    100, ...            % trials: at most this many epochs drawn, picked evenly over their order (Inf = every one)
    'yLimMode',     "auto", ...  % as a PSTH's (EphysAnalysisConfig.YLimModes)
    'yLim',         []);
opts.heatmap = struct( ...
    'bins',          bins, ...
    'measure',       "rate", ...
    'baseline',      baseline, ...      % spikes: Mode "none" | "subtract" | "zscore" | "percent" | "auroc"; a signal: "none" | "subtract"
    'auroc',         auroc, ...         % spikes, baseline Mode "auroc": the auROC's settings
    'rows',          "items", ...       % "items" (the layer's units or channels) | "trials" (one row per epoch of one unit)
    'order',         "probe", ...       % rows "items": "probe" (the style's SortDepth / SortShank) | "peak" | "modulation" (auROC: the mean in the modulation window)
    'rasterSort',      "", ...          % rows "trials": the epochs' order, as a raster's ("" | "stop" | "event" | "latency" | a trial parameter)
    'rasterSortEvent', [], ...          % rows "trials", rasterSort "event": [] or an EventRef
    'rasterSortOrder', "ascending", ... % rows "trials": "ascending" | "descending"
    'rasterByGroup',   true, ...        % rows "trials": by group first (a color strip at the left), else one block
    'group',         1, ...             % rows "items": the trial group drawn (not with stack "groups")
    'stack',         "off", ...         % rows "items": "off" (one group) | "groups" (a block of rows per trial group, the first on top)
    'stackSpacing',  1.1, ...           % stack: the block step, x the block's height (an image never overlaps: below 1 counts as 1)
    'cLim',          [], ...
    'maskAfterStop', false);
opts.waveforms = struct( ...
    'layout',   "grid", ...             % "grid" (the unit's waveform, or several overlaid) | "probe" (every unit at its place on the probe)
    'waveform', waveformsOwn, ...       % mode "mean" | "subsample" | "both" (never "off")
    'yLimMode', "auto", ...  % as a PSTH's (EphysAnalysisConfig.YLimModes)
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
opts.rate = struct( ...
    'measure',  "rate", ...             % "rate" (spikes/s) | "count" (spikes per window) | "probability" (share of epochs with a spike)
    'baseline', baseline, ...           % Mode "none" | "subtract" | "ratio" | "zscore" (firingRate's Normalize)
    'display',  "bar", ...              % "bar" (mean, error bar) | "box" | "points" (each epoch, the mean as a bar)
    'yLimMode', "auto", ...  % as a PSTH's (EphysAnalysisConfig.YLimModes)
    'yLim',     [], ...
    'waveform', waveform);              % the unit's waveform inset
opts.tuning = struct( ...
    'param',       "", ...              % the x axis: a trial parameter ("" = the figure's first groupBy one, else the first numeric one)
    'seriesParam', "", ...              % one curve per value of this trial parameter ("" = one curve)
    'stack',       "off", ...           % "off" (the series overlaid) | "groups" (a row per series, the first on top)
    'stackSpacing', 1.1, ...            % stack: the row step, x the row height
    'measure',     "rate", ...
    'baseline',    baseline, ...        % Mode "none" | "subtract" | "ratio" | "zscore"
    'yLimMode',    "auto", ...  % as a PSTH's (EphysAnalysisConfig.YLimModes)
    'yLim',        [], ...
    'waveform',    waveform);           % the unit's waveform inset
% the Chronux spectral types (chronuxSettings' fields and defaults; none is a shared option)
opts.spectrum = struct( ...
    'timeBase',   "aligned", ...        % "aligned" (the panel's epochs) | "range" (segments of the recording, clear of artifact periods)
    'range',      [0 Inf], ...          % range: [from to] s on the continuous clock (to Inf = the end)
    'segmentSec', 2, ...                % range: each segment (a trial), s
    'taperMode',  "TWK", ...            % "TWK" (TW and K as given) | "Wp" (half bandwidth W Hz and p, over the trial)
    'TW',         3, ...
    'K',          5, ...
    'W',          4, ...
    'p',          1, ...
    'pad',        0, ...                % FFT padding (-1, 0, 1, ...)
    'fpass',      [0 100], ...          % [fmin fmax] Hz (fmax Inf = Nyquist)
    'err',        "jackknife", ...      % the band: "none" | "theoretical" | "jackknife"
    'errP',       0.05, ...             % its p (0.05: 95%)
    'detrend',    "constant", ...       % each trial's "none" | "constant" | "linear" trend removed
    'scale',      "db", ...             % "db" (10 log10) | "log" (a log y axis) | "linear"
    'spikeFs',    1000, ...             % point layers: the spike trains' time grid, Hz
    'stack',      "off", ...            % "off" (the groups overlaid) | "groups" (a row per trial group, the first on top)
    'stackSpacing', 1.1, ...            % stack: the row step, x the row height
    'yLimMode',   "auto", ...  % as a PSTH's (EphysAnalysisConfig.YLimModes)
    'yLim',       []);
opts.spectrogram = struct( ...
    'taperMode',  "TWK", ...
    'TW',         3, ...
    'K',          5, ...
    'W',          4, ...
    'p',          1, ...
    'pad',        0, ...
    'fpass',      [0 100], ...
    'detrend',    "constant", ...
    'scale',      "db", ...             % "db" and "log": the power in dB; "linear": as is (a baseline: in its own units)
    'spikeFs',    1000, ...             % a point layer: the spike train's time grid, Hz
    'movingwin',  [0.5 0.05], ...       % [window step] s
    'baseline',   struct('Mode', "none", 'Window', [-0.5 0]), ...   % Mode "none" | "db" | "percent" | "zscore" | "ratio" against Window
    'cLim',       [], ...
    'group',      1, ...                % the trial group drawn (not with stack "groups")
    'stack',      "off", ...            % "off" (one group) | "groups" (an image row per trial group, the first on top, on one time axis)
    'stackSpacing', 1.1);               % stack: the block step, x the block's height (below 1 counts as 1)
opts.coherence = struct( ...
    'timeBase',   "aligned", ...
    'range',      [0 Inf], ...
    'segmentSec', 2, ...
    'taperMode',  "TWK", ...
    'TW',         3, ...
    'K',          5, ...
    'W',          4, ...
    'p',          1, ...
    'pad',        0, ...
    'fpass',      [0 100], ...
    'err',        "jackknife", ...      % "jackknife" gives the band and the confidence level, "theoretical" the level
    'errP',       0.05, ...
    'detrend',    "constant", ...
    'spikeFs',    1000, ...
    'overTime',   false, ...            % a coherogram over the moving window: an image over time
    'movingwin',  [0.5 0.05], ...
    'showPhase',  true, ...             % the phase under the magnitude (not over time)
    'yLimMode',   "auto", ...  % as a PSTH's (EphysAnalysisConfig.YLimModes)
    'yLim',       [], ...               % [] = [0 1]
    'cLim',       [], ...               % over time: [] = [0 1]
    'group',      1, ...                % over time: the trial group drawn (not with stack "groups")
    'stack',      "off", ...            % "off" (the groups overlaid; over time one group) | "groups" (a row per trial group, the first on top)
    'stackSpacing', 1.1);               % stack: the row step, x the row height (an image's: below 1 counts as 1)
opts.eventTrace = struct( ...
    'display',       "bars", ...        % "bars" (solid, onset to offset) | "line" (a logic level: low, up at onset, down at offset)
    'trials',        "overlay", ...     % "overlay" (every epoch in the line's row, translucent) | "rows" (a sub-row per epoch, sorted as a raster)
    'rasterSort',      "", ...          % trials "rows": the epochs' order, as a raster's ("" | "stop" | "event" | "latency" | a trial parameter)
    'rasterSortEvent', [], ...          % trials "rows", rasterSort "event": [] or an EventRef
    'rasterSortOrder', "ascending", ... % trials "rows": "ascending" | "descending"
    'rasterByGroup',   true, ...        % trials "rows": by group first (on groupBands), else one block
    'colorBy',       "layer", ...       % "layer" (the layer's color, else a palette color per line) | "group" (the trial group's)
    'height',        0.6, ...           % the bar's / level's height, a share of the row (rows: of the epoch's sub-row)
    'alpha',         NaN, ...           % bars' and traces' opacity 0-1 (NaN: 0.3 overlaid, 1 in rows)
    'edgeColor',     "none", ...        % the bars' outline: "none" | "auto" (the bar's color) | a color
    'edgeWidth',     0.5, ...           % the outline's width, points
    'minWidth',      1, ...             % display "bars": a bar narrower than this (points; zero length too) also gets a tick this wide (0 = none)
    'lineWidth',     1.5, ...           % display "line": the trace's width, points
    'lineStyle',     "-", ...           % display "line": the trace's style (a layer's own lineStyle wins)
    'showBaseline',  true, ...          % a line along each row: through the bars' middle, or at the trace's low level
    'baselineColor', "", ...            % "" = gray; or a color
    'baselineStyle', ":", ...           % "-" | "--" | ":" | "-."
    'baselineWidth', 0.5, ...           % points
    'rowSpacing',    1.25, ...          % the step between the lines' rows, in row heights (1: the rows touch)
    'groupBands',    true);             % trials "rows": a pale band of each trial group's color behind its sub-rows

%   Type        Label                Short          Categories               Aligned SharesTime OneGroup MultiLayer DefaultBinding  Description
rows = {
    "raster",     "Raster",            "Raster",      "point",                 true,   true,      false,   true,      "observation",  "Spike rasters: a row per epoch, by group; events as marks on the rows or as rows of their own"
    "psth",       "PSTH",              "PSTH",        "point",                 true,   true,      false,   true,      "observation",  "Peri-event firing rate, groups overlaid (or a heat map, a row per group); events as latency lines or as a PSTH of their own"
    "continuous", "Continuous signal", "Continuous",  "continuous",            true,   true,      false,   true,      "observation",  "The epochs' mean of LFP / MUA / SPIKE / AUX channels, with an error band"
    "heatmap",    "Heat map",          "Heatmap",     ["point" "continuous"],  true,   true,      true,    false,     "fixed",        "Units or channels by time in color, one trial group"
    "waveforms",  "Unit waveforms",    "Waveforms",   "unit",                  false,  false,     false,   false,     "observation",  "A unit's mean waveform and a sample of its spikes"
    "probemap",   "Probe map",         "ProbeMap",    "unit",                  false,  false,     false,   false,     "fixed",        "A per-channel value (rate, spikes, units) drawn on the probe sites"
    "corrmap",    "Unit correlation",  "Correlation", "unit",                  true,   false,     true,    false,     "fixed",        "Pairwise correlation of the units' per-epoch rates, one trial group"
    "rate",       "Firing rate",       "Rate",        "point",                 true,   false,     false,   true,      "observation",  "Each epoch window's firing rate per trial group: bars, boxes or points"
    "tuning",     "Tuning curve",      "Tuning",      "point",                 true,   false,     false,   true,      "observation",  "Firing rate against a trial parameter, one curve per series"
    "spectrum",   "Power spectrum",    "Spectrum",    ["point" "continuous"],  true,   false,     false,   true,      "observation",  "Multitaper power spectra (Chronux) of channels or spike trains over the epochs, groups overlaid"
    "spectrogram", "Spectrogram",      "Spectrogram", ["continuous" "point"],  true,   true,      true,    false,     "observation",  "A channel's or a unit's multitaper power over time from the event and frequency (Chronux), one trial group"
    "coherence",  "Coherence",         "Coherence",   ["point" "continuous"],  true,   false,     false,   true,      "observation",  "Multitaper coherence (Chronux) of a seed layer with a partner layer: field-field, spike-field or unit-unit"
    "eventTrace", "Event traces",      "EventTraces", "point",                 true,   true,      false,   true,      "fixed",        "Digital or derived lines as a logic analyzer shows them: a row per line, a bar (or a level) from each onset to its offset, epochs overlaid or a sub-row each"
    };
n = size(rows, 1);
Type = strings(n, 1); Label = strings(n, 1); Short = strings(n, 1); DefaultBinding = strings(n, 1); Description = strings(n, 1);
Categories = cell(n, 1); DefaultOptions = cell(n, 1);
Aligned = false(n, 1); SharesTime = false(n, 1); OneGroup = false(n, 1); MultiLayer = false(n, 1);
for k = 1:n
    Type(k) = rows{k, 1};
    Label(k) = rows{k, 2};
    Short(k) = rows{k, 3};
    Categories{k} = rows{k, 4};
    Aligned(k) = rows{k, 5};
    SharesTime(k) = rows{k, 6};
    OneGroup(k) = rows{k, 7};
    MultiLayer(k) = rows{k, 8};
    DefaultBinding(k) = rows{k, 9};
    Description(k) = rows{k, 10};
    DefaultOptions{k} = opts.(Type(k));
end
T = table(Type, Label, Short, Categories, Aligned, SharesTime, OneGroup, MultiLayer, DefaultBinding, Description, DefaultOptions);
end
