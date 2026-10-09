function s = defaults(section)
%defaults  Default settings of one analysis-config section (schema v1).
%   S = EphysAnalysisConfig.defaults(SECTION) is the single source of truth
%   for field names, types and shapes: normalizeSection coerces every
%   assigned value to match them, and eventRef / epochWindow /
%   trialSelection / selectUnits / renderPlot fill what a caller leaves out
%   from here.
%
%   Config sections   Source, Defaults, Export, Report, Plot (one entry of
%                     Plots)
%   Building blocks   EventRef, SequenceStep (one step of an EventRef's
%                     sequence), EpochWindow, TrialSelection, UnitSelection,
%                     Style, Auroc, Waveform, Note
%
%   See also EphysAnalysisConfig, EphysAnalysisConfig.normalizeSection.

arguments
    section (1,1) string
end

switch section
    case "Source"
        s = struct( ...
            'Mode',        "project", ...           % "project" (a pipeline project root) | "folders"
            'Root',        "", ...                  % project root (Mode "project")
            'OutputRoot',  "", ...                  % "" = outputs next to each recording
            'NamePattern', EphysDataset.DefaultNamePattern, ...
            'Recordings',  "concatenate", ...       % Open Ephys sessions with several recordings: "concatenate" | "separate" | "single" (the pipeline config's Acquisition.OpenEphys.Recordings)
            'Selection',   "all", ...               % "all" | "list"
            'Datasets',    string.empty(1,0), ...   % root-relative keys when "list"
            'Folders',     string.empty(1,0));      % output folders (Mode "folders")

    case "Defaults"
        s = struct( ...
            'EventRef',  EphysAnalysisConfig.defaults("EventRef"), ...
            'Window',    EphysAnalysisConfig.defaults("EpochWindow"), ...
            'Selection', EphysAnalysisConfig.defaults("TrialSelection"));

    case "EventRef"
        s = struct( ...
            'line',           "Stim", ...      % digital line; "Trial" = the paired trial line
            'edge',           "onset", ...     % "onset" | "offset"
            'which',          "first", ...     % "first" | "last" | "all" | "nth"
            'n',              1, ...           % which = "nth"
            'scope',          "auto", ...      % "trial" | "recording" | "auto" (trial when paired)
            'minDurationSec', 0, ...           % keep intervals at least this long
            'maxDurationSec', Inf, ...         % ... and at most this long
            'timeRange',      [-Inf Inf], ...  % s from trial onset (trial scope) or recording start
            'offsetSec',      0, ...           % added to every event time
            'offsetParam',    "", ...          % "" | a trial parameter: its value on the event's trial is added too (e.g. RespLatency)
            'offsetParamUnit', "ms", ...       % offsetParam's unit: "ms" | "s"
            'sequence',       repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0), ...  % steps that must (or must not) follow each event (followSequence)
            'alignStep',      Inf);            % the step aligned to: 0 = the line's own event, k = sequence(k), Inf = the last "followedBy" step

    case "SequenceStep"
        % one step of an EventRef's sequence: an event that must (or must not) follow the one before
        s = struct( ...
            'relation',       "followedBy", ... % "followedBy" | "notFollowedBy"
            'line',           "", ...          % digital line; "Trial" = the paired trial line
            'edge',           "onset", ...     % "onset" | "offset"
            'n',              1, ...           % followedBy: the nth such event after the one before
            'maxGapSec',      Inf, ...         % at most this long after the event before (never past the next trial's onset)
            'minDurationSec', 0, ...           % count intervals at least this long
            'maxDurationSec', Inf);            % ... and at most this long

    case "EpochWindow"
        s = struct( ...
            'mode', "fixed", ...   % "fixed": [t0+pre, t0+post]; "between": [t0+pre, t1+post]
            'pre',  -0.2, ...
            'post', 0.8, ...
            'stop', []);           % [] or an EventRef: the event that ends each epoch (t1)

    case "TrialSelection"
        s = struct( ...
            'filter',       "", ...                 % expression over the trials table
            'response',     string.empty(1,0), ...  % any of respCodeBits' words
            'pairingFlags', "ok", ...               % PairingFlag values kept ([] = all)
            'trials',       [], ...                 % explicit trial rows ([] = all)
            'groupBy',      string.empty(1,0), ...  % 0-2 trial parameters
            'groupOrder',   "ascending", ...        % "ascending" | "descending" | "appearance"
            'maxGroups',    12);

    case "UnitSelection"
        s = struct( ...
            'source',   "units", ...            % "units" (sorted) | "detected" (threshold, per channel)
            'classes',  ["su" "mua"], ...       % sorted-unit classes kept ([] = all)
            'groups',   string.empty(1,0), ...  % phy groups kept ([] = all)
            'ids',      [], ...                 % unit ids kept ([] = all)
            'channels', [], ...                 % 1-based recording channels kept ([] = all)
            'shanks',   [], ...                 % shanks kept ([] = all)
            'maxUnits', Inf, ...
            'quality',  qualityDefaults(), ...  % keep the sorted units that meet good-unit criteria (unitQualityPass)
            'response', responseDefaults());    % keep the units that respond to the event (responseStats)

    case "Style"
        s = struct( ...
            'LineWidth',    1.2, ...
            'ShowSEM',      true, ...
            'ShowStop',     true, ...
            'ShowZeroLine', true, ...
            'Colormap',     "lines", ...    % group colours: "lines" keeps selectTrials' colours; a colormap function; or one colour ("black", "#1f77b4")
            'HeatColormap', "", ...         % heatmap / probe map / corrmap colours ("" = parula; blueWhiteRed for corrmap)
            'FontSize',     9, ...
            'SiteSize',     8, ...          % probe map: site marker size (points)
            'YLim',        [], ...
            'XLim',         [], ...
            'CLim',         [], ...
            'Grid',         true, ...
            'Legend',       true, ...
            'LegendLocation',    "auto", ...  % "auto" (a grid's east of it, a single plot's its own) | "inside" (in the first tile) | "north" | "south" | "east" | "west" (outside the grid of plots)
            'LegendOrientation', "auto", ...  % "auto" (horizontal north / south of the grid, else vertical) | "vertical" | "horizontal"
            'LegendBox',         false, ...   % the legend's outline and background
            'SortDepth',   true, ...       % units / channels: top of the probe first (probe y)
            'SortShank',    false, ...      % ... grouped by shank first (depth then orders within a shank)
            'LabelDepth',   false, ...      % append the probe depth (y, µm) to unit / channel labels
            'LabelShank',   false, ...      % append the shank to unit / channel labels
            'MaxTiles',     16, ...         % tiles per page in grid layouts
            'TileSpacing',  "compact", ...  % space between the tiles of a grid: "loose" | "compact" | "tight" | "none"
            'StackSpacing', NaN);           % evoked "stack" offset (NaN = automatic)

    case "Auroc"
        % a psth / heatmap plot's baseline Mode "auroc" (aurocCurves; spikePSTH's Auroc)
        s = struct( ...
            'method',           "psth", ...      % "psth": the trial-averaged PSTH's bins (the paper) | "epochs": each epoch's count
            'windows',          "tiled", ...     % "tiled": back to back, edged at the event | "sliding": one every stepSec
            'windowSec',        0.1, ...         % the auROC window: a whole number of bins
            'stepSec',          0.01, ...        % sliding: the step, a whole number of bins
            'modulationWindow', [0 0.5], ...     % s from the event: the windows inside it decide each unit's call
            'cutoff',           "ci", ...        % "ci" (the paper's 95% CI) | "fixed" (threshold) | "test" (a p per unit) | "none"
            'threshold',        0.1, ...         % fixed: modulated when |mean auROC - 0.5| is above this
            'test',             "bootstrap", ... % test: "bootstrap" (epochs) | "ranksum" | "shuffle" (circular time shift)
            'nResamples',       1000, ...        % bootstrap / shuffle
            'correction',       "bh", ...        % test: over the units and groups (pAdjust)
            'alpha',            0.05, ...        % test: modulated when the adjusted p is at most alpha
            'marks',            true, ...        % draw each unit's call (PSTH titles, heatmap rows)
            'modulatedOnly',    false);          % keep only the units modulated in some group

    case "Waveform"
        % a psth / raster / tuning plot's unit waveform: a box in each unit's tile (unitWaveforms; renderers' Waveform);
        % a waveforms plot's settings: mode, maxSpikes, showPP, showCount, scale (the probe glyphs' size), ampScale, showSites, showNames
        s = struct( ...
            'mode',      "off", ...         % "off" | "mean" | "subsample" | "both" (the mean over the subsample)
            'location',  "northeast", ...   % compass point of the tile: north, south, east, west, northeast, northwest, southeast, southwest
            'box',       true, ...          % the box's outline and pale ground (false: the waveform alone)
            'showPP',    true, ...          % the mean's peak-to-peak amplitude in the box's label
            'showCount', false, ...         % the unit's total spike count, in the box's label
            'scale',     1, ...             % size: 1 = a third of the tile's width and height (at most 3)
            'maxSpikes', 100, ...           % the subsample: spikes per unit, at random (the same each time); a sorted unit's mean is over them
            'ampScale',  "unit", ...        % waveforms plot: "unit" (each waveform fills its own tile / glyph) | "common" (one amplitude scale for all units of the same kind of value)
            'showSites', true, ...          % waveforms plot, probe layout: the probe's sites behind the waveforms
            'showNames', false);            % waveforms plot, probe layout: each unit's name beside its waveform

    case "Note"
        % a plot's descriptive text (drawNote): one block of text, placed in or beside the plot
        s = struct( ...
            'text',       "", ...           % the words; new lines break the lines ("" = no note)
            'placement',  "below", ...      % outside the plot: below | above | right | left; over it: northwest | north | northeast | west | center | east | southwest | south | southeast; or custom (x, y)
            'x',          0.5, ...          % custom: the anchor point, 0-1 across the plot (0 = left edge)
            'y',          0.5, ...          % custom: 0-1 up the plot (0 = bottom edge)
            'align',      "left", ...       % the text's horizontal alignment: left | center | right (below / above: where it sits across the plot)
            'valign',     "middle", ...     % vertical alignment: top | middle | bottom (right / left: where it sits up the plot)
            'rotation',   0, ...            % degrees, counter-clockwise
            'fontName',   "", ...           % "" = the design's / the plot's font
            'fontSize',   NaN, ...          % points (NaN = the plot's font size)
            'bold',       false, ...
            'italic',     false, ...
            'color',      "", ...           % "" = the design's text colour; or a name / #rrggbb
            'background', "", ...           % "" = none; or a name / #rrggbb behind the text
            'box',        false, ...        % an outline round the text
            'interpreter', "none");         % "none" (as typed) | "tex" (\mu, x^2, x_i, \bf)

    case "Export"
        s = struct( ...
            'Enabled',         true, ...
            'Formats',         ["png" "svg"], ...                     % any of png, eps, svg, pdf
            'Folder',          "{OutputFolder}" + filesep + "analysis", ...
            'FilenamePattern', "{Name}_{Plot}", ...                   % tokens: Name Plot Kind Group Unit Index Date
            'Dpi',             150, ...
            'FigureSizeCm',    [18 12], ...
            'Overwrite',       true);

    case "Report"
        s = struct( ...
            'Enabled',           true, ...
            'Format',            "html", ...    % "html" | "pdf" | "both"
            'Title',             "{Name}", ...      % {Name} = the config's name, {Date} = today
            'Folder',            "{OutputRoot}" + filesep + "analysis", ...
            'FileName',          "analysis_report", ...
            'PerDataset',        false, ...     % one report per dataset (Folder may use {OutputFolder})
            'EmbedFormat',       "png", ...     % HTML images: "png" | "svg"
            'Dpi',               110, ...
            'IncludeSummary',    true, ...
            'IncludeParameters', true, ...
            'IncludeConfig',     true);

    case "Plot"
        u = EphysAnalysisConfig.defaults("UnitSelection");
        s = struct( ...
            'id',            "", ...
            'kind',          "psth", ...        % one of EphysAnalysisConfig.Kinds
            'enabled',       true, ...
            'title',         "", ...            % "" = automatic
            'source',        "units", ...       % units | detected | LFP | MUA | SPIKE | AUX
            'units',         rmfield(u, 'source'), ...
            'channels',      [], ...            % signal channels (LFP / MUA / SPIKE / AUX; [] = all)
            'ref',           "default", ...     % "default" (Defaults.EventRef) or an EventRef
            'window',        "default", ...     % "default" (Defaults.Window) or an EpochWindow
            'selection',     "default", ...     % "default" (Defaults.Selection) or a TrialSelection
            'bins',          struct('BinSec', 0.01, 'SmoothSec', 0.01), ...  % SmoothSec: Gaussian SD (0 = none)
            'measure',       "rate", ...        % psth / heatmap of spikes / rate / tuning: "rate" (spikes/s) | "count" (spikes per bin or window) | "probability" (P(spike) per bin, or share of epochs with a spike)
            'baseline',      struct('Mode', "none", 'Window', [-0.2 0]), ...
            'auroc',         EphysAnalysisConfig.defaults("Auroc"), ...   % psth / heatmap of spikes, baseline Mode "auroc"
            'layout',        "", ...            % "" = the kind's default layout
            'withRaster',    true, ...          % psth
            'rasterSort',    "", ...            % psth / raster: epochs of a group in time order ("") | by stop latency ("stop") | by rasterSortEvent's latency ("event") | by a trial parameter (its name)
            'rasterSortEvent', [], ...          % psth / raster, rasterSort "event": [] or an EventRef, e.g. Platform offset, whose latency from each epoch's event sorts the rows (eventLatency)
            'rasterSortOrder', "ascending", ... % psth / raster: the sort key's direction, "ascending" | "descending" (missing values last)
            'rasterByGroup', true, ...          % psth / raster: rows by group first, on bands (false: every epoch sorted as one block)
            'rasterEvents',  rasterEventsDefaults(), ...   % psth / raster: marks on each row at a digital line's onsets / offsets (epochEvents)
            'histStyle',     "bar", ...         % psth: "bar" | "line"
            'fill',          true, ...          % psth: filled bars / area under the line (false: outline / line only)
            'fillAlpha',     NaN, ...           % psth: fill opacity 0-1 (NaN: 0.5 where groups overlap, else 1)
            'normalize',     "none", ...        % psth: "none" | "unitPeak" (a unit's PSTHs / its largest peak) | "groupPeak" (each PSTH / its own peak)
            'stack',         false, ...         % psth: one row per group, stacked upwards, instead of overlaid
            'stackSpacing',  1.1, ...           % psth stack: row step, x the tallest PSTH of the panel (< 1 overlaps)
            'maskAfterStop', false, ...         % psth, raster, heatmap of spikes: drop what follows each epoch's stop event
            'param',         "", ...            % tuning / behavior: trial parameter on the x axis
            'seriesParam',   "", ...            % tuning / behavior: one curve (series) per value of this parameter
            'yParam',        "", ...            % behavior: the y axis: a numeric trial parameter, or "stop" (each epoch's stop latency, ms)
            'jitter',        true, ...          % behavior "points": spread the points sideways (a fixed, repeatable jitter)
            'xScale',        "category", ...    % behavior: "category" (the x values evenly spaced) | "linear" (at their values; numeric x)
            'value',         "rate", ...        % probemap: "rate" | "nSpikes" | "nUnits"
            'order',         "probe", ...       % heatmap rows: "probe" (the style's SortDepth / SortShank) | "peak" | "modulation" (auROC: the first group's mean in the modulation window)
            'metric',        "mean", ...        % corrmap: each epoch's "mean" or "peak" (binned) rate
            'correlation',   "pearson", ...     % corrmap: "pearson" | "spearman"
            'waveform',      EphysAnalysisConfig.defaults("Waveform"), ...   % psth / raster / tuning grids: each unit's waveform in its tile; waveforms: the plot's own settings
            'note',          EphysAnalysisConfig.defaults("Note"), ...       % descriptive text on the plot (renderPlot's drawNote)
            'style',         EphysAnalysisConfig.defaults("Style"), ...
            'aesthetics',   PlotAesthetics.emptyRules());   % remembered looks of components: role, group, property, value (PlotAesthetics)

    otherwise
        error('EphysAnalysisConfig:BadSection', 'Unknown section "%s".', section);
end
end


function e = rasterEventsDefaults()
%rasterEventsDefaults  Plot.rasterEvents: none; how the marks look.
e = struct( ...
    'lines',  string.empty(1,0), ... % digital lines ("Trial" = the trial line) whose events are marked on each row
    'sequences', repmat(EphysAnalysisConfig.defaults("EventRef"), 1, 0), ...   % event references (with sequences) whose events are marked too
    'edge',   "onset", ...           % "onset" | "offset" | "both" (of lines)
    'scope',  "window", ...          % "window": every event in the epoch's window | "trial": only those in the epoch's own trial
    'marker', "diamond", ...         % a line marker (PlotAesthetics' list: o, square, diamond, ^, v, |, ...)
    'size',   4, ...                 % marker size, points
    'color',  "");                   % "" = a colour per line and edge; or one colour (a name or #rrggbb)
end


function q = qualityDefaults()
%qualityDefaults  UnitSelection.quality: off, with unitQualityCriteria's thresholds.
q = struct('enabled', false);
c = unitQualityCriteria();
for f = string(fieldnames(c)).'
    q.(f) = c.(f);
end
end


function r = responseDefaults()
%responseDefaults  UnitSelection.response: off; the tests of responseStats.
r = struct( ...
    'enabled',    false, ...
    'test',       "evoked", ...   % "evoked" (response vs baseline, signrank) | "tuning" (across param's levels, kruskalwallis) | "either" | "both" | "auroc" (aurocCurves)
    'baseline',   [-0.2 0], ...   % s from the event
    'window',     [0 0.2], ...    % the response window, s from the event
    'param',      "", ...         % the trial parameter of the tuning test
    'direction',  "any", ...      % evoked: "any" | "excited" | "suppressed"
    'correction', "bh", ...       % over the units tested: "bh" | "holm" | "bonferroni" | "none" (pAdjust)
    'alpha',      0.05, ...       % a unit passes when its adjusted p is at most alpha
    'auroc',      aurocTestDefaults());   % test "auroc": window = the modulation window; correction and alpha above
end


function a = aurocTestDefaults()
%aurocTestDefaults  UnitSelection.response.auroc: Auroc's settings of the auROC itself and its call, and its own bins.
a = EphysAnalysisConfig.defaults("Auroc");
a = rmfield(a, ["modulationWindow" "correction" "alpha" "marks" "modulatedOnly"]);
a.binSec = 0.01;   % the bins counted (the plot's own bins are not used)
end
