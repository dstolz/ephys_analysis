function s = defaults(section)
%defaults  Default settings of one analysis-config section (config version 2).
%   S = EphysAnalysisConfig.defaults(SECTION) is the single source of truth
%   for field names, types and shapes: normalizeSection coerces every
%   assigned value to match them, and eventRef / epochWindow /
%   trialSelection / selectUnits / renderFigure fill what a caller leaves
%   out from here. (Version 1's Plot, SessionPlot and Aux sections live on
%   only to migrate a version-1 file: private/legacyPlotDefaults.)
%
%   Config sections   Source, Defaults, Export, Report, Figure (one entry
%                     of Figures)
%   Building blocks   EventRef, SequenceStep (one step of an EventRef's
%                     sequence), EpochWindow, TrialSelection, UnitSelection,
%                     Style, Auroc, Waveform, Note, Overlay (one entry of a
%                     panel's overlays), EventMark (an events layer's event:
%                     an EventRef and its mark's look);
%                     a figure's Observe (what it is drawn for),
%                     FigureSessions (drawn across datasets), Panel (one entry
%                     of its panels; options from panelTypes) and Layer
%                     (one entry of a panel's layers)
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
            'maxGroups',    12, ...
            'excludeArtifacts', true, ...           % drop the epochs that touch an artifact period
            'minArtifactSec',   0);                 % ... one at least this long (shorter periods do not count)

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
            'ShowSEM',      true, ...           % error bands (traces) and bars (means), of ErrorType
            'ErrorType',    "sem", ...          % "sem" (mean +/- SEM) | "std" (mean +/- SD) | "ci95" (bootstrap 95% CI of the mean, percentile)
            'ErrorResamples', 1000, ...         % ci95: bootstrap resamples
            'ErrorFaceColor', "", ...           % bands: "" = the trace's color; or a color
            'ErrorFaceAlpha', NaN, ...          % bands: NaN = opaque, the trace's color paled towards the ground; 0-1 = that opacity
            'ErrorEdgeColor', "none", ...       % bands: "none" | "auto" (the face color) | a color
            'ErrorEdgeStyle', "-", ...          % bands: the edge's line style ("-" | "--" | ":" | "-.")
            'ErrorEdgeWidth', 0.5, ...          % bands: the edge's width, points
            'ShowStop',     true, ...
            'ShowZeroLine', true, ...
            'ShowArtifactNote', true, ...       % a note under the title when drawn epochs touch an artifact period (excludeArtifacts off)
            'Colormap',     "lines", ...    % group colors: "lines" keeps selectTrials' colors; a colormap function; or one color ("black", "#1f77b4")
            'HeatColormap', "", ...         % heatmap / probe map / corrmap colors ("" = parula; blueWhiteRed for corrmap)
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
        % a psth / heatmap panel's baseline Mode "auroc" (aurocCurves; spikePSTH's Auroc)
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
        % a psth / raster / tuning panel's unit waveform: a box in the unit's panel (unitWaveforms; waveformInset);
        % a waveforms panel's settings: mode, maxSpikes, showPP, showCount, scale (the probe glyphs' size), ampScale, showSites, showNames
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
        % a panel's descriptive text (drawNote): one block of text, placed in or beside the panel ("the plot" below)
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
            'color',      "", ...           % "" = the design's text color; or a name / #rrggbb
            'background', "", ...           % "" = none; or a name / #rrggbb behind the text
            'box',        false, ...        % an outline round the text
            'interpreter', "none");         % "none" (as typed) | "tex" (\mu, x^2, x_i, \bf)

    case "EventMark"
        % an events layer's event (Layer.event): an event reference -- usually which "all", often with a sequence --
        % whose events are marked on each raster row (epochEvents), or drawn as latency lines or a train, and its look
        s = EphysAnalysisConfig.defaults("EventRef");
        s.which = "all";                % every event in the epoch's window ...
        s.scope = "recording";          % ... in the trials or between them
        s.marker = "diamond";           % a line marker (PlotAesthetics' list: o, square, diamond, ^, v, |, ...)
        s.size = 4;                     % marker size, points
        s.color = "";                   % "" = the mark's automatic color (rasterMarkColor); or a name / #rrggbb
        s.spanStyle = "-";              % eventsAs "span": the onset-to-offset line's style ("-" | "--" | ":" | "-.")
        s.spanWidth = 1.5;              % ... its width, points
        s.spanAlpha = 1;                % ... its opacity 0-1

    case "Overlay"
        % one graphic drawn on a panel's axes in data units (drawOverlays): a line across the axis, or a semitransparent
        % patch between two values; a panel holds any number of them (Panel.overlays), each with its own look
        s = struct( ...
            'name',      "", ...            % what the list and the aesthetics editor call it ("" = "Overlay <n>")
            'enabled',   true, ...          % unticked, it stays in the config but is not drawn
            'shape',     "line", ...        % "line" | "region" (a patch between from and to)
            'axis',      "x", ...           % "x": a vertical line, or a patch between two x values | "y": a horizontal line / a patch between two y values
            'value',     0, ...             % line: where it crosses the axis (data units)
            'from',      0, ...             % region: one edge (data units)
            'to',        0.1, ...           % region: the other edge
            'panel',     "all", ...         % always "all": a panel's overlays go on its own axes (normalizePanel)
            'layer',     "over", ...        % "over" | "under" the panel's data
            'color',     "#d62728", ...     % line: color (a name or #rrggbb)
            'alpha',     1, ...             % line: opacity 0-1
            'lineStyle', "--", ...          % line, and a region's outline: "-" | "--" | ":" | "-."
            'lineWidth', 1.5, ...           % line, and a region's outline: points
            'faceColor', "#808080", ...     % region: fill color (a name or #rrggbb)
            'faceAlpha', 0.25, ...          % region: fill opacity 0-1
            'edgeColor', "none");           % region: outline color ("none" = no outline)

    case "Export"
        s = struct( ...
            'Enabled',         true, ...
            'Formats',         ["png" "svg"], ...                     % any of png, eps, svg, pdf
            'Folder',          "{OutputFolder}" + filesep + "analysis", ...
            'FilenamePattern', "{Name}_{Plot}", ...                   % tokens: Name Plot Kind Group Unit Index Date
            'Dpi',             150, ...
            'FigureSizeCm',    [18 12], ...
            'Overwrite',       true, ...
            'SessionsFolder',  "{OutputRoot}" + filesep + "analysis" + filesep + "sessions", ...   % session figures' files (one folder for every dataset: {OutputFolder} is the first dataset's)
            'Data',            struct( ...                            % session figures' data files (.mat); Overwrite applies
                'Enabled',         false, ...
                'Folder',          "{OutputRoot}" + filesep + "analysis" + filesep + "data", ...
                'FilenamePattern', "{Name}_{Plot}", ...               % {Name} = "all"
                'MatVersion',      "-v7.3"));                         % "-v7.3" | "-v7"

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

    case "Layer"
        % one data binding of a figure panel (Panel.layers): a source, and either the observation (the previewed /
        % generated unit or channel) or the fixed items it names
        u = EphysAnalysisConfig.defaults("UnitSelection");
        s = struct( ...
            'name',        "", ...              % legend / aesthetics label ("" = automatic: the unit label, "LFP ch 3", the event label)
            'enabled',     true, ...            % unticked, it stays in the config but is not drawn
            'source',      "units", ...         % one of FigureSources: units | detected | events | LFP | MUA | SPIKE | AUX
            'binding',     "observation", ...   % "observation" (the observed unit / channel) | "fixed" (units / channels / event); events are always fixed
            'units',       rmfield(u, 'source'), ...   % fixed point / unit layers: which units (may keep several)
            'channels',    [], ...              % fixed continuous layers: the extract's columns ([] = all)
            'aggregate',   "each", ...          % several units / channels: "each" (a trace or block each) | "mean" (their mean, a band across them) | "magnitude" (a spectral panel's signal: the channels as one, their vector magnitude; aggregates())
            'event',       EphysAnalysisConfig.defaults("EventMark"), ...   % source events: the line, edge, which / scope / sequence, and the mark's look
            'eventsAs',    "marks", ...         % source events: "marks" (on raster rows; latency lines elsewhere) | "train" (the events as a spike train) | "span" (a line from each onset to its offset)
            'color',       "", ...              % "" = the group's color; else a name / #rrggbb for every trace of this layer
            'lineStyle',   "");                 % "" = by layer order (- -- : -.); else one of OverlayLineStyles

    case "Panel"
        % one panel of a figure (Figure.panels): a type, a cell of the grid and its span, optional alignment overrides,
        % the type's options and the layers it draws
        T = EphysAnalysisConfig.panelTypes();
        s = struct( ...
            'id',      "", ...                  % unique within the figure ("" = "<type>_<n>")
            'type',    "psth", ...              % one of panelTypes().Type
            'title',   "", ...                  % "" = automatic
            'box',     "auto", ...              % the axes' box: "auto" (the design's, and the looks remembered for the panel's kind) | "on" | "off" (these win over them)
            'xLabel',  "", ...                  % the x axis' label: "" = automatic (the type's, "Time (s)" on a time axis)
            'yLabel',  "", ...                  % the y axis' label: "" = automatic
            'xSide',   "bottom", ...            % where the x axis' ticks and label go: "bottom" | "top"
            'ySide',   "left", ...              % ... and the y axis': "left" | "right" (not a stacked PSTH's: it has one on each side)
            'row',     1, ...                   % the top-left cell
            'col',     1, ...
            'rowSpan', 1, ...
            'colSpan', 1, ...
            'size',    [1 1], ...               % [width height]: its share (0-1) of its cell
            'align',   "center", ...            % where it sits in its cell when narrower: "left" | "center" | "right"
            'valign',  "middle", ...            % ... and when shorter: "top" | "middle" | "bottom"
            'ref',     "default", ...           % "default" (the figure's) or an EventRef
            'window',  "default", ...           % "default" (the figure's) or an EpochWindow (own epochs, the figure's selection)
            'selection', "default", ...         % "default" (the figure's) or a TrialSelection (own epochs and groups: its own colors and legend)
            'layers',  repmat(EphysAnalysisConfig.defaults("Layer"), 1, 0), ...
            'options', T.DefaultOptions{T.Type == "psth"}, ...   % the type's options (panelTypes().DefaultOptions)
            'note',    EphysAnalysisConfig.defaults("Note"), ...   % descriptive text on or beside the panel (renderFigure; drawNote)
            'overlays', repmat(EphysAnalysisConfig.defaults("Overlay"), 1, 0));   % lines and patches on the panel's axes (drawOverlays; panel "all")

    case "Observe"
        % what a figure is drawn for: what Generate iterates and the preview picker lists
        u = EphysAnalysisConfig.defaults("UnitSelection");
        s = struct( ...
            'data',        "units", ...         % ObserveData: "units" (each sorted unit) | "detected" (each channel's detections) | a signal ("LFP" | "MUA" | "SPIKE" | "AUX": each channel of its extract) | "dataset" (one figure)
            'units',       rmfield(u, 'source'), ...   % units / detected: the filter
            'channels',    [], ...              % a signal: the extract's columns ([] = all)
            'perGroup',    false);              % true: each observation drawn once per trial group of the figure's selection (its groupBy)

    case "FigureSessions"
        % a figure drawn across several datasets (Figure.sessions): with enabled, Generate / Run draw it once over the
        % ticked (or listed) datasets, each layer's results merged across them (combineSessions), not once per dataset
        s = struct( ...
            'enabled',     false, ...               % true: a session figure
            'datasets',    "ticked", ...            % "ticked" (the run's datasets) | "list" (datasetKeys)
            'datasetKeys', string.empty(1,0), ...   % the dataset keys when "list"
            'facet',       "none", ...              % "none" | "subject" (one figure per subject)
            'series',      "session", ...           % what gets a color: "session" | "subject" | "all"
            'colorOrder',  "palette", ...           % "palette" | "sequential" (by date)
            'showMembers', false, ...               % series subject / all: each session drawn faintly under its summary
            'error',       "sem", ...               % series subject / all: the band across sessions, "sem" | "sd" | "ci95" | "none"
            'match',       "site", ...              % unit observations: "site" (the observed recording channel) | "mapping" (a cell of mappingFile)
            'mappingFile', "", ...                  % match "mapping": CSV, column cell then one per dataset key holding unit ids
            'minSessions', 1, ...                   % an observation is kept with data from at least this many sessions
            'trialGroups', "pool");                 % the figure's trial groups: "pool" | "each" (a figure each) | "combine" (line styles)

    case "Figure"
        % one figure (Figures): one observation's panels on a grid; the preview draws one observation, Generate many
        s = struct( ...
            'id',         "", ...               % unique among figures; with autoId, autoFigureId's ("" and not autoId = "figure_<n>")
            'autoId',     true, ...             % the id follows the panels and data (autoFigureId) until one of the user's own is typed
            'enabled',    true, ...
            'title',      "", ...               % "" = automatic: "<id>: <observation> - <ref label> (<n> epochs)"
            'observe',    EphysAnalysisConfig.defaults("Observe"), ...
            'grid',       struct( ...
                'rows',       1, ...
                'cols',       1, ...
                'rowHeights', [], ...           % [] = equal; else one positive relative height per row (its plot area's, exactly)
                'colWidths',  [], ...           % [] = equal; else one positive relative width per column
                'spacing',    "tight", ...      % the gap between panels' labels: "loose" | "compact" | "tight" | "none" (flush stacked time panels) | "custom"
                'gapUnits',   "px", ...         % custom gaps: "px" | "%" (of the mean row's plot height / column's plot width)
                'rowGap',     6, ...            % custom: the gap between every two rows
                'colGap',     6, ...            % custom: the gap between every two columns
                'rowGaps',    [], ...           % custom: [] = rowGap each; else rows - 1 gaps (between rows i and i + 1)
                'colGaps',    []), ...          % custom: [] = colGap each; else cols - 1 gaps
            'panels',     repmat(EphysAnalysisConfig.defaults("Panel"), 1, 0), ...
            'ref',        "default", ...        % "default" (Defaults.EventRef) or an EventRef
            'window',     "default", ...        % "default" (Defaults.Window) or an EpochWindow
            'selection',  "default", ...        % "default" (Defaults.Selection) or a TrialSelection
            'sessions',   EphysAnalysisConfig.defaults("FigureSessions"), ...   % drawn across datasets (enabled) instead of per dataset
            'style',      EphysAnalysisConfig.defaults("Style"), ...   % YLim / CLim / MaxTiles / TileSpacing unused (panel options, grid.spacing)
            'aesthetics', PlotAesthetics.emptyRules());

    otherwise
        error('EphysAnalysisConfig:BadSection', 'Unknown section "%s".', section);
end
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
a.binSec = 0.01;   % the bins counted (the panel's own bins are not used)
end
