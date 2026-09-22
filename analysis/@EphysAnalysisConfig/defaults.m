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
%   Building blocks   EventRef, EpochWindow, TrialSelection, UnitSelection,
%                     Style
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
            'offsetSec',      0);              % added to every event time

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
            'maxUnits', Inf);

    case "Style"
        s = struct( ...
            'LineWidth',    1.2, ...
            'ShowSEM',      true, ...
            'ShowStop',     true, ...
            'ShowZeroLine', true, ...
            'Colormap',     "lines", ...    % group colours: "lines" keeps selectTrials' colours; a colormap function; or one colour ("black", "#1f77b4")
            'HeatColormap', "", ...         % heatmap / probe map / corrmap colours ("" = parula; blueWhiteRed for corrmap)
            'FontSize',     9, ...
            'YLim',         [], ...
            'XLim',         [], ...
            'CLim',         [], ...
            'Grid',         true, ...
            'Legend',       true, ...
            'MaxTiles',     16, ...         % tiles per page in grid layouts
            'StackSpacing', NaN);           % evoked "stack" offset (NaN = automatic)

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
            'Title',             "{Name} quick look", ...
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
            'baseline',      struct('Mode', "none", 'Window', [-0.2 0]), ...
            'layout',        "", ...            % "" = the kind's default layout
            'withRaster',    true, ...          % psth
            'histStyle',     "bar", ...         % psth: "bar" | "line"
            'fill',          true, ...          % psth: filled bars / area under the line (false: outline / line only)
            'fillAlpha',     NaN, ...           % psth: fill opacity 0-1 (NaN: 0.5 where groups overlap, else 1)
            'normalize',     "none", ...        % psth: "none" | "unitPeak" (a unit's PSTHs / its largest peak) | "groupPeak" (each PSTH / its own peak)
            'stack',         false, ...         % psth: one row per group, stacked upwards, instead of overlaid
            'stackSpacing',  1.1, ...           % psth stack: row step, x the tallest PSTH of the panel (< 1 overlaps)
            'maskAfterStop', false, ...         % psth: drop bins after each epoch's stop event
            'param',         "", ...            % tuning: trial parameter on the x axis
            'seriesParam',   "", ...            % tuning: one curve per value of this parameter
            'value',         "rate", ...        % probemap: "rate" | "nSpikes" | "nUnits"
            'order',         "depth", ...       % heatmap rows: "depth" | "channel" | "peak"; corrmap: "depth" | "channel"
            'metric',        "mean", ...        % corrmap: each epoch's "mean" or "peak" (binned) rate
            'correlation',   "pearson", ...     % corrmap: "pearson" | "spearman"
            'style',         EphysAnalysisConfig.defaults("Style"));

    otherwise
        error('EphysAnalysisConfig:BadSection', 'Unknown section "%s".', section);
end
end
