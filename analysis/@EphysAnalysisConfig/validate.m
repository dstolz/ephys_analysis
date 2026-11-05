function issues = validate(obj, opts)
%validate  Check an analysis config for problems before it runs.
%   ISSUES = cfg.validate() returns a table (Section, Field, Severity,
%   Message); Severity "error" means the run cannot start, "warning" that
%   part of it may not do what is meant. An empty table means clean.
%
%   Checked
%     Source    Mode; Root exists (project) or every folder does (folders);
%               NamePattern parses; a "list" selection names datasets;
%               Filter.TagMode is "any" or "all"
%     Defaults  the event reference, window and selection are valid (a
%               filter that does not parse is a warning: it is checked
%               against each dataset's trials when it runs)
%     Figures   at least one figure or session figure enabled ("No figure
%               is enabled.", Field "enabled"); (Field "<figure>.<field>",
%               "<figure>.<panel>.<field>" or
%               "<figure>.<panel>.layers(<j>).<field>") ids distinct as file
%               names ({Plot} replaces characters outside A-Z a-z 0-9 _ - .
%               by "_", and Windows ignores case) and file-name safe; the
%               figure's ref, window and
%               selection (groupBy <= 2); observe: data (ObserveData),
%               channels, maxUnits, on a figure observing units an enabled units.response test (test,
%               param, windows, direction, correction, alpha, test
%               "auroc"'s settings, and the Statistics and Machine Learning
%               Toolbox it needs; each spike layer's units.response alike),
%               no layer following a "dataset" observation, a
%               warning when a unit / channel observation has no
%               following layer, a warning for perGroup while the figure's
%               selection groups by nothing (not on a session or probe
%               figure, which ignore it); size: source and units, an own
%               width and height above 0; layout: boxesMean (BoxesMeans),
%               padding a finite number >= 0 (cm);
%               latency ("<figure>.latency.<field>": method, baseline and
%               baselineRate known values, the window minSec <= maxSec --
%               a warning when it misses the figure's window --, the
%               baseline window lo < hi, alpha in (0, 1), surprise > 0,
%               whole minSpikes >= 2, the CUSUM's bin and threshold > 0,
%               drift and sustain >= 0; a warning when a rule that needs a
%               baseline rate has none in the figure's window);
%               panels: a known type, a rect of 4 finite numbers inside
%               0-1 of the page (x, y >= 0, width and height > 0, x +
%               width and y + height <= 1), ids of their own, one legend
%               panel at most (warnings: no panels, two panels whose
%               rects overlap by more than RectTol each way, rectOverlaps:
%               the later one is drawn on top); a legend panel's
%               orientation, align, valign and whole columns >= 0 (a
%               warning for layers on it: it draws none); a panel's own ref /
%               window / selection only on aligned types (a selection on
%               a trial panel too; its selection checked as the
%               figure's), a "between" window only on a
%               unit correlation, firing rate or tuning curve panel;
%               layers: a source the type draws
%               (categoryOf), the binding ("observation" only for spikes
%               and signals, never on heatmap / probemap / corrmap but a
%               heat map of trials' spike layer; AUX
%               cannot follow a unit; a warning for a signal following
%               another signal's channel), aggregate ("magnitude" only
%               where aggregates() offers it, on a fixed layer), maxUnits (a
%               warning above 8 units drawn each in a raster / PSTH /
%               rate / tuning panel),
%               channels, events layers only on time panels, a train only
%               on raster / psth / heatmap, the mark's event reference,
%               marker, size and color, a span's style, width and
%               opacity, events layers only on an event-trace panel, a
%               layer's color and line style, a
%               raster of marks alone (an error: no rows); warnings for a
%               panel without enabled layers and for several layers on a
%               one-layer type (but a waveforms panel in the probe
%               layout, whose further layers ring their units); the
%               type's options (bins, measure, baseline modes and window
%               -- "auroc" only on a PSTH or a heat map of spikes, its
%               auroc settings (method, windows, whole-bin window and step,
%               modulation window, cutoff, threshold, test, nResamples,
%               correction, alpha, modulatedOnly with a cutoff, the
%               toolbox); a signal's baseline, in a
%               continuous panel or a heat map of a signal, overlapping
%               the panel's window --, histStyle, normalize, fillAlpha,
%               a PSTH's display (trace / heatmap),
%               colormap (a warning for no colormap function) and color
%               limits, the raster sort, a raster's first-spike marks
%               and a PSTH's latency box plot while enabled (marker,
%               size, color -- a warning for not groups or a color --, the
%               box's line style and width, boxHeight 0.02-0.5, fillAlpha,
%               the outliers), a raster's or PSTH's onsetLine (off, unit,
%               groups), continuous
%               statistic / transform / errorType and its
%               toolbox, trials (off / faint / only) and
%               maxTrials (whole, >= 1), heatmap rows (items / trials:
%               one unit's epochs -- a spike or train layer, following
%               the observation or fixed to one unit, no auROC baseline,
%               the raster sort --), order ("modulation" only
%               with the auROC baseline), group, the waveforms layout (a
%               warning for a probe layout whose first layer follows the
%               observation), probemap value, corrmap metric /
%               correlation, the rate display, the tuning param /
%               seriesParam (names, not the same one), a PSTH's,
%               rate's or tuning panel's errorType (PanelErrorTypes; ci95
%               with the Statistics and Machine Learning Toolbox), every
%               panel's errorResamples (whole, >= 1) and band (faceAlpha
%               0-1 or NaN, edgeStyle, edgeWidth > 0; a faceColor or
%               edgeColor that is not a color is a warning), the waveform
%               settings (a raster's, PSTH's, rate's or tuning panel's
%               inset, a waveforms panel's own: mode; while drawn its
%               location, width and height, maxSpikes, time span, and
%               ampLim with the fixed amplitude scale), y / color limits, the stack (stackModes:
%               off, groups, a continuous panel's items; a warning on a
%               heat map of trials, which does not use it) and a
%               positive stackSpacing on every type that stacks, the
%               yLimMode (YLimModes; "fixed" needs a yLim) on every type
%               with y limits; the spectral panels'
%               (spectrum, spectrogram, coherence) options by
%               chronuxSettings' rules (figureChronuxSettings: tapers,
%               fpass, err, errP, detrend, scale, spikeFs, the moving
%               window, the range time base's range and segment, a
%               spectrogram's baseline Mode and its window inside the
%               panel's), a coherence panel's two enabled layers (seed,
%               partner; a warning for a fixed seed of several items), a
%               spectrogram's signal or spike layer; an event-trace
%               panel's display, trials, colorBy,
%               height, alpha, line styles and positive widths and
%               rowSpacing, with warnings for an edge or baseline color
%               that is not one); the trial panels (TrialPanelTypes:
%               trials layers only, and a trials layer only there, always
%               fixed; a selection of their own though not aligned): each
%               layer's measure ("<...>.layers(<j>).measure.<field>", a
%               scatter's xMeasure too: kind, from and -- delay, count --
%               to as event references, direction, maxGapSec > 0, a
%               param kind's parameter name, unit ms / s, the label's
%               variables; a warning for a scatter's delay to "all" B
%               events, which pairs the first value per trial) and
%               options (categories / series: TrialGroupings, a
%               "param" one naming its parameter, not the same grouping
%               twice, bins [] / a whole count / ascending edges;
%               display, summary, errorType (AuxErrorTypes), test
%               (TrialTests), testPairs, adjust, testShow (brackets on a
%               distribution only), bracketPairs, showN, normalization,
%               binMode, fit (TrialFits), corr, the scales; testAlpha in
%               (0, 1), alpha (opacity) and jitter 0-1, markerSize, binWidth > 0,
%               whole binCount >= 1 and fitWindow >= 2, marginalSize
%               0.1-0.5, x / y limits; the Statistics and Machine
%               Learning Toolbox for a test other than none); each panel's text note
%               ("<figure>.<panel>.note.<field>": placement, alignment,
%               rotation, font size and interpreter; a color that is not
%               one is a warning) and overlays
%               ("<figure>.<panel>.overlays(<k>).<field>": shape, axis,
%               finite position (line) or edges (region, which must
%               differ), layer, line style and width, opacities (0-1),
%               colors (one that is not a color is a warning); two
%               overlays of one name anywhere in the figure warn); a
%               warning for a name in braces in the figure's title, a
%               panel's title, xLabel, yLabel or note text or a layer's
%               name that is no label variable (figureLabelVariables;
%               it is drawn as typed), saying the variable it likely
%               meant (one differing only in case; in a TeX note only
%               such a one is reported); the
%               style; sessions
%               (a session figure, "<figure>.sessions.<field>"): datasets,
%               facet, series, colorOrder, error, match (site / mapping)
%               and trialGroups known values, minSessions a whole number
%               >= 1, match "mapping" a mapping file that exists
%               (CheckPaths), reads and has a cell column (a listed dataset
%               key without a column is a warning) and a unit observation (a channel observation matches by
%               recording channel, a dataset one needs no match); with
%               sessions.enabled no probe map, unit
%               correlation or spectral panel and no auROC baseline
%               (combineSessions merges neither). Warnings: "list"
%               without keys; showMembers with series "session";
%               trialGroups "pool" while the selection groups trials;
%               "combine" with a PSTH panel drawn as bars (drawn as
%               lines); a heat map of trials (not merged: skipped); a
%               trial panel grouped by "groups" (its categories or
%               series) under trialGroups "pool"; probe
%               (a probe figure, "<figure>.probe.<field>"): layout
%               (ProbeLayouts), overlap (ProbeOverlaps) and labels
%               (ProbeTileLabels) known values, lanes, maxTiles and
%               maxPerSite whole numbers >= 1, tileWidth and tileHeight in
%               (0, 1], tileScale finite and > 0, shanks and channels
%               whole numbers (channels >= 1; [] = all), depthRange [] or
%               [lo hi] with lo < hi; with probe.enabled not also
%               sessions.enabled and not a dataset observation (errors at
%               probe.enabled). Warnings: perGroup on a probe figure
%               (ignored), a probe map panel or a waveforms panel in the
%               probe layout (a probe drawn inside each tile)
%     Export   formats are png / eps / svg / pdf; Dpi, FigureSizeCm; the
%               folder and file-name patterns use known tokens; a warning
%               when the files of two enabled figures, or of two datasets,
%               would get the same names (no {Plot}: every figure's {Kind}
%               is "figure"; no {Name} / {OutputFolder});
%               SessionsFolder and Data.Folder (folder patterns; a warning
%               for {OutputFolder}), Data.FilenamePattern (a file pattern)
%               and Data.MatVersion (-v7.3 or -v7)
%     Report    Format html / pdf / both; EmbedFormat png / svg; Order
%               figure / unit; FiguresPerPage a whole number 1-16;
%               PageSize letter / a4; PageOrientation auto / portrait /
%               landscape; Dpi; FileName; the folder pattern
%
%   Options: CheckPaths (default true) also checks that folders exist.
%
%   See also EphysAnalysisConfig, EphysAnalysisRunner.plan, figureFileName.

arguments
    obj (1,1) EphysAnalysisConfig
    opts.CheckPaths (1,1) logical = true
end

Section = strings(0, 1); Field = strings(0, 1); Severity = strings(0, 1); Message = strings(0, 1);
    function add(sec, field, sev, msg)
        Section(end+1, 1) = sec; Field(end+1, 1) = field; Severity(end+1, 1) = sev; Message(end+1, 1) = msg;
    end

% --- Source ------------------------------------------------------------------------
S = obj.Source;
if ~ismember(S.Mode, ["project" "folders"])
    add("Source", "Mode", "error", "Mode must be ""project"" or ""folders"".");
elseif S.Mode == "project"
    if S.Root == ""
        add("Source", "Root", "error", "The project root is empty.");
    elseif opts.CheckPaths && ~isfolder(S.Root)
        add("Source", "Root", "error", "The project root does not exist: " + S.Root);
    end
    if S.OutputRoot ~= "" && opts.CheckPaths && ~isfolder(S.OutputRoot)
        add("Source", "OutputRoot", "warning", "The output root does not exist: " + S.OutputRoot);
    end
    if ~ismember(S.Selection, ["all" "list"])
        add("Source", "Selection", "error", "Selection must be ""all"" or ""list"".");
    elseif S.Selection == "list" && isempty(S.Datasets)
        add("Source", "Datasets", "warning", "Selection is ""list"" but no datasets are listed; nothing will run.");
    end
    try
        parseNameTokens("", S.NamePattern);
    catch ME
        add("Source", "NamePattern", "error", string(ME.message));
    end
    if ~ismember(S.Recordings, ["concatenate" "separate" "single"])
        add("Source", "Recordings", "error", "Recordings must be ""concatenate"", ""separate"" or ""single"".");
    end
else
    if isempty(S.Folders)
        add("Source", "Folders", "error", "Mode is ""folders"" but no folders are listed.");
    elseif opts.CheckPaths
        for f = S.Folders
            if ~isfolder(f); add("Source", "Folders", "error", "Folder not found: " + f); end
        end
    end
end
if ~ismember(S.Filter.TagMode, ["any" "all"])
    add("Source", "Filter.TagMode", "error", "Filter.TagMode must be ""any"" or ""all"".");
end

% --- Defaults ------------------------------------------------------------------------
D = obj.Defaults;
checkRef(D.EventRef, "Defaults", "EventRef");
checkWindow(D.Window, "Defaults", "Window");
checkSelection(D.Selection, "Defaults", "Selection");

% --- Figures ------------------------------------------------------------------------------
% Fields: "<figure>.<field>" for the figure's own settings, "<figure>.<panel>.<field>" for a panel's,
% "<figure>.<panel>.layers(<j>).<field>" for a layer's.
if isempty(obj.enabledFigures()) && isempty(obj.enabledSessionFigures())
    add("Figures", "enabled", "error", "No figure is enabled.");
end
FT = EphysAnalysisConfig.panelTypes();
isWhole = @(x) isscalar(x) && isfinite(x) && x >= 1 && x == round(x);
fids = obj.figureIds();
if numel(fids) > 1
    fkey = lower(regexprep(fids, '[^\w\-\.]', '_'));   % the id as {Plot} writes it, case-blind
    for u = unique(fkey)
        same = fids(fkey == u);
        if numel(same) > 1
            add("Figures", same(end) + ".id", "error", "Figure ids " + strjoin("""" + same + """", " and ") + ...
                " name the same files: {Plot} replaces characters outside A-Z a-z 0-9 _ - . by ""_"", and Windows ignores case.");
        end
    end
end
for k = 1:numel(obj.Figures)
    fg = obj.Figures(k);
    f0 = fg.id;
    if ~isempty(regexp(fg.id, '[\\/:*?"<>|]', 'once')) || strtrim(fg.id) == ""
        add("Figures", f0 + ".id", "error", "A figure id names its files: no \ / : * ? "" < > |, and not empty.");
    end
    checkLabelText(fg.title, f0 + ".title", false);

    % the figure's alignment
    if isstruct(fg.ref); checkRef(fg.ref, "Figures", f0 + ".ref"); end
    if isstruct(fg.window); checkWindow(fg.window, "Figures", f0 + ".window"); end
    if isstruct(fg.selection); checkSelection(fg.selection, "Figures", f0 + ".selection"); end
    fw = fg.window;
    if isequal(fw, "default"); fw = D.Window; end

    % its page
    zs = fg.size;
    if ~ismember(zs.source, EphysAnalysisConfig.FigureSizeSources)
        add("Figures", f0 + ".size.source", "error", "size.source is export or own.");
    end
    if ~ismember(zs.units, EphysAnalysisConfig.FigureSizeUnits)
        add("Figures", f0 + ".size.units", "error", "size.units is px, in or cm.");
    end
    if zs.source == "own" && ~(isscalar(zs.width) && isscalar(zs.height) && isfinite(zs.width) && isfinite(zs.height) && zs.width > 0 && zs.height > 0)
        add("Figures", f0 + ".size", "error", "An own size needs a width and a height above 0.");
    end

    % what it is drawn for
    ob = fg.observe;
    kind = "";
    if ~ismember(ob.data, EphysAnalysisConfig.ObserveData)
        add("Figures", f0 + ".observe.data", "error", "observe.data is one of " + strjoin(EphysAnalysisConfig.ObserveData, ", ") + ...
            ", not """ + ob.data + """.");
    else
        kind = EphysAnalysisConfig.observeKind(fg);
    end
    if ~isempty(ob.channels) && ~all(arrayfun(isWhole, ob.channels))
        add("Figures", f0 + ".observe.channels", "error", "The observed channels are columns of the extract: whole numbers, at least 1 ([] = all).");
    end
    if ~(ob.units.maxUnits >= 1)
        add("Figures", f0 + ".observe.units.maxUnits", "error", "maxUnits must be >= 1 (Inf = all).");
    end
    if kind == "unit"   % the observed units' filter is read only when the figure observes units
        checkResponse(ob.units.response, f0 + ".observe.units.response");
    end
    fs = fg.selection;
    if isequal(fs, "default"); fs = D.Selection; end
    checkFigureSessions(fg, k, kind, fs, f0);
    checkFigureProbe(fg, kind, f0);
    if ob.perGroup && ~fg.sessions.enabled && ~fg.probe.enabled && (~isstruct(fs) || ~isfield(fs, 'groupBy') || isempty(fs.groupBy))   % a session or probe figure ignores perGroup
        add("Figures", f0 + ".observe.perGroup", "warning", "perGroup draws each observation once per trial group, but the " + ...
            "figure's trial selection groups by nothing (groupBy): one figure per observation, as without it.");
    end
    nFollow = 0;
    for j = 1:numel(fg.panels)
        Lj = fg.panels(j).layers;
        if ~isempty(Lj); nFollow = nFollow + nnz([Lj.enabled] & [Lj.binding] == "observation"); end
    end
    if kind == "dataset" && nFollow > 0
        add("Figures", f0 + ".observe.data", "error", "A layer follows the observation, but the figure is drawn for the dataset: " + ...
            "observe units, detections or a signal's channels, or bind the layer to fixed items.");
    elseif ismember(kind, ["unit" "channel"]) && nFollow == 0
        add("Figures", f0 + ".observe.data", "warning", "No layer follows the observation: the figure is the same for every " + kind + ".");
    end

    % how the panels' rects are read
    lay = fg.layout;
    if ~ismember(lay.boxesMean, EphysAnalysisConfig.BoxesMeans)
        add("Figures", f0 + ".layout.boxesMean", "error", "layout.boxesMean is plot (a rect is the panel's plot area) or outer " + ...
            "(a rect holds the panel with its labels).");
    end
    if ~(isnumeric(lay.padding) && isscalar(lay.padding) && isfinite(lay.padding) && lay.padding >= 0)
        add("Figures", f0 + ".layout.padding", "error", "layout.padding is a length in cm, at least 0.");
    end
    if isempty(fg.panels)
        add("Figures", f0 + ".panels", "warning", "The figure has no panels: it draws nothing.");
    end
    checkFigureLatency(fg, f0, fw);

    % the panels' places: ids, rects, overlaps, one legend panel
    pids = strings(1, 0);
    if ~isempty(fg.panels); pids = [fg.panels.id]; end
    rectOk = true;
    for j = 1:numel(fg.panels)
        pj = fg.panels(j);
        p0 = f0 + "." + pj.id;
        if pj.id == "" || nnz(pids == pj.id) > 1
            add("Figures", p0 + ".id", "error", "Each panel of a figure needs an id of its own.");
        end
        r = pj.rect;
        if ~(isnumeric(r) && numel(r) == 4 && all(isfinite(r)) && r(1) >= 0 && r(2) >= 0 && r(3) > 0 && r(4) > 0 ...
                && r(1) + r(3) <= 1 + 1e-9 && r(2) + r(4) <= 1 + 1e-9)
            add("Figures", p0 + ".rect", "error", "A panel's rect is [x y width height], inside 0-1 of the page, with a " + ...
                "positive width and height.");
            rectOk = false;
        end
    end
    if rectOk && numel(fg.panels) > 1
        over = EphysAnalysisConfig.rectOverlaps(fg);
        for j = 1:size(over, 1)
            add("Figures", f0 + "." + pids(over(j, 2)) + ".rect", "warning", "Panels """ + pids(over(j, 1)) + """ and """ + ...
                pids(over(j, 2)) + """ overlap: the later one is drawn on top.");
        end
    end
    legends = pids([string.empty(1, 0) fg.panels.type] == "legend");
    if numel(legends) > 1
        add("Figures", f0 + "." + legends(2) + ".type", "error", "A figure has one legend panel at most (" + ...
            strjoin(legends, ", ") + ").");
    end

    % each panel: type, alignment, layers, options
    ovNames = strings(1, 0);   % the overlays' names over every panel of the figure (one aesthetics rule reaches each name)
    for j = 1:numel(fg.panels)
        pj = fg.panels(j);
        p0 = f0 + "." + pj.id;
        % the panel's text note and overlays (an overlay is drawn on the panel's own axes)
        checkNote(pj.note, "Figures", p0 + ".note", "panel");
        % its texts' label variables ({Line}, ...): a name in braces that is none of them is likely a typo
        checkLabelText(pj.title, p0 + ".title", false);
        checkLabelText(pj.xLabel, p0 + ".xLabel", false);
        checkLabelText(pj.yLabel, p0 + ".yLabel", false);
        checkLabelText(pj.note.text, p0 + ".note.text", pj.note.interpreter == "tex");
        for i = 1:numel(pj.layers)
            checkLabelText(pj.layers(i).name, p0 + ".layers(" + i + ").name", false);
        end
        ovNames = checkOverlays(pj.overlays, "Figures", p0, ovNames);
        if ~ismember(pj.box, ["auto" "on" "off"])
            add("Figures", p0 + ".box", "error", "A panel's box is auto (the design's), on or off.");
        end
        if ~ismember(pj.xSide, EphysAnalysisConfig.PanelXSides)
            add("Figures", p0 + ".xSide", "error", "A panel's xSide is bottom or top.");
        end
        if ~ismember(pj.ySide, EphysAnalysisConfig.PanelYSides)
            add("Figures", p0 + ".ySide", "error", "A panel's ySide is left or right.");
        end
        trow = FT.Type == pj.type;
        if ~any(trow)
            add("Figures", p0 + ".type", "error", "Unknown panel type """ + pj.type + """ (types: " + strjoin(FT.Type, ", ") + ").");
            continue
        end
        tr = FT(trow, :);
        label = tr.Label;
        if label ~= "PSTH"; label = lower(label); end
        A = "A " + label + " panel";
        if startsWith(label, "event"); A = "An " + label + " panel"; end

        isTrial = ismember(pj.type, EphysAnalysisConfig.TrialPanelTypes);   % one value per trial: no events to align to, but trials to select
        for af = ["ref" "window" "selection"]
            if ~isstruct(pj.(af)); continue; end
            if af == "selection" && isTrial
                checkSelection(pj.selection, "Figures", p0 + ".selection");
            elseif ~tr.Aligned
                add("Figures", p0 + "." + af, "error", A + " is not aligned to events: its " + af + " must be ""default"".");
            elseif af == "ref"
                checkRef(pj.ref, "Figures", p0 + ".ref");
            elseif af == "window"
                checkWindow(pj.window, "Figures", p0 + ".window");
            else
                checkSelection(pj.selection, "Figures", p0 + ".selection");
            end
        end
        pw = pj.window;
        if isequal(pw, "default"); pw = fw; end
        onRange = isfield(pj.options, 'timeBase') && pj.options.timeBase == "range";   % a spectral panel on segments of the recording
        if tr.Aligned && pw.mode == "between" && ~ismember(pj.type, ["corrmap" "rate" "tuning"]) && ~onRange
            add("Figures", p0 + ".window", "error", A + " needs a fixed window (""between"" windows are for unit correlation, " + ...
                "firing rate and tuning curve panels).");
        end

        % layers
        Lp = pj.layers;
        on = false(1, 0);
        if ~isempty(Lp); on = [Lp.enabled]; end
        if isempty(tr.Categories{1})   % a legend panel: no layers to draw
            if any(on)
                add("Figures", p0 + ".layers", "warning", A + " draws no layers: they are not drawn.");
            end
            on = false(size(on));
        elseif ~any(on)
            add("Figures", p0 + ".layers", "warning", "The panel has no enabled layer: it draws nothing.");
        elseif nnz(on) > 1 && ~tr.MultiLayer && ~(pj.type == "waveforms" && isfield(pj.options, 'layout') && pj.options.layout == "probe")
            add("Figures", p0 + ".layers", "warning", A + " draws one layer: only the first enabled one is drawn.");
        end
        for i = find(on)
            L = Lp(i);
            l0 = p0 + ".layers(" + i + ")";
            if ~ismember(L.source, EphysAnalysisConfig.FigureSources)
                add("Figures", l0 + ".source", "error", "A layer's source is one of " + strjoin(EphysAnalysisConfig.FigureSources, ", ") + ...
                    ", not """ + L.source + """.");
                continue
            end
            isEvents = L.source == "events";
            isTrials = L.source == "trials";
            if isTrial && ~isTrials
                add("Figures", l0 + ".source", "error", A + " draws trials layers only (a trial measure each), not " + L.source + ".");
                continue
            elseif isTrials && ~isTrial
                add("Figures", l0 + ".source", "error", "Trials layers (one value per trial) go on trial distribution, " + ...
                    "histogram and scatter panels, not on " + lower(A) + ".");
                continue
            end
            if isEvents && ~tr.SharesTime
                add("Figures", l0 + ".source", "error", "Events layers go on panels that share the time axis (raster, PSTH, " + ...
                    "continuous signal, heat map), not on " + lower(A) + ".");
                continue
            end
            if ~isEvents && pj.type == "eventTrace"
                add("Figures", l0 + ".source", "error", A + " draws events layers only (a digital or derived line each), not " + ...
                    L.source + ".");
                continue
            end
            if ~isEvents && EphysAnalysisConfig.categoryOf(L.source, pj.type) == ""
                add("Figures", l0 + ".source", "error", A + " draws " + categoryWords(tr.Categories{1}) + " layers, not " + L.source + ".");
                continue
            end
            if ~ismember(L.binding, ["observation" "fixed"])
                add("Figures", l0 + ".binding", "error", "A layer's binding is observation (it follows the observed unit or channel) or fixed, not """ + ...
                    L.binding + """.");
            elseif L.binding == "observation"
                if isEvents
                    add("Figures", l0 + ".binding", "error", "An events layer is always fixed: it names its line (event).");
                elseif isTrials
                    add("Figures", l0 + ".binding", "error", "A trials layer is always fixed: its measure names its events or parameter.");
                elseif ismember(pj.type, ["heatmap" "probemap" "corrmap"]) ...
                        && ~(pj.type == "heatmap" && isfield(pj.options, 'rows') && pj.options.rows == "trials" ...
                        && ismember(L.source, EphysAnalysisConfig.SpikeSources))   % a heat map of one unit's trials may follow it
                    add("Figures", l0 + ".binding", "error", A + " draws fixed layers: bind the layer to fixed units or channels.");
                elseif kind == "unit" && L.source == "AUX"
                    add("Figures", l0 + ".binding", "error", "AUX has no recording channel to follow the observed unit's: bind it to fixed channels.");
                elseif kind == "channel" && ismember(L.source, EphysAnalysisConfig.SignalSources) && L.source ~= ob.data
                    % as figureLayerItems resolves it: AUX records no amplifier channel, either way
                    if L.source == "AUX"
                        add("Figures", l0 + ".binding", "error", "AUX has no recording channel: bind it to fixed channels.");
                    elseif ob.data == "AUX"
                        add("Figures", l0 + ".binding", "error", "The observed AUX channel has no recording channel for " + ...
                            L.source + " to follow.");
                    else
                        add("Figures", l0 + ".source", "warning", "This " + L.source + " layer follows a " + ob.data + " channel: it takes the " + ...
                            "observed channel's number in its own extract.");
                    end
                end
            end
            if ~ismember(L.aggregate, ["each" "mean" "magnitude"])
                add("Figures", l0 + ".aggregate", "error", "A layer's aggregate is each (a trace or block per item), mean " + ...
                    "or magnitude (a spectral panel's signal channels as one).");
            elseif L.aggregate == "magnitude" && ~ismember("magnitude", EphysAnalysisConfig.aggregates(pj.type, L.source))
                add("Figures", l0 + ".aggregate", "error", "The magnitude aggregate (the channels' vector magnitude) is for a " + ...
                    "signal layer (LFP, MUA, SPIKE, AUX) of a spectrum, spectrogram or coherence panel.");
            elseif L.aggregate == "magnitude" && L.binding == "observation"
                add("Figures", l0 + ".binding", "error", "A magnitude layer makes its fixed channels one: bind it to fixed " + ...
                    "channels (none listed = every one).");
            end
            if ismember(L.source, EphysAnalysisConfig.SpikeSources)
                if ~(L.units.maxUnits >= 1)
                    add("Figures", l0 + ".units.maxUnits", "error", "maxUnits must be >= 1 (Inf = all).");
                elseif L.binding == "fixed" && ismember(pj.type, ["raster" "psth" "rate" "tuning"]) && L.aggregate == "each"
                    nU = L.units.maxUnits;
                    if ~isempty(L.units.ids); nU = min(nU, numel(L.units.ids)); end
                    if nU > 8
                        add("Figures", l0 + ".units.maxUnits", "warning", "This fixed layer may keep more than 8 units, each drawn in " + ...
                            "the one panel: limit units.maxUnits or ids, or aggregate them (mean).");
                    end
                end
                checkResponse(L.units.response, l0 + ".units.response");
            end
            if ismember(L.source, EphysAnalysisConfig.SignalSources) && ~isempty(L.channels) && ~all(arrayfun(isWhole, L.channels))
                add("Figures", l0 + ".channels", "error", "A layer's channels are columns of its extract: whole numbers, at least 1 ([] = all).");
            end
            if isEvents
                if ~ismember(L.eventsAs, ["marks" "train" "span"])
                    add("Figures", l0 + ".eventsAs", "error", "An events layer is drawn as marks, as a train or as a span (onset to offset).");
                elseif L.eventsAs == "train" && ~ismember(pj.type, ["raster" "psth" "heatmap" "eventTrace"])   % an event-trace panel does not use eventsAs
                    add("Figures", l0 + ".eventsAs", "error", "Events drawn as a train go on a raster, PSTH or heat map panel; " + ...
                        lower(A) + " draws them as latency lines (marks).");
                end
                mk = L.event;
                checkRef(eventMarkRef(mk), "Figures", l0 + ".event");
                markers = PlotAesthetics.catalog().Marker.Choices;
                if ~ismember(mk.marker, markers)
                    add("Figures", l0 + ".event.marker", "error", "An event mark's marker is one of " + strjoin(markers, ", ") + ".");
                end
                if ~(mk.size > 0 && isfinite(mk.size))
                    add("Figures", l0 + ".event.size", "error", "An event mark's size must be positive (points).");
                end
                if mk.color ~= "" && ~isColor(mk.color)
                    add("Figures", l0 + ".event.color", "warning", "No color """ + mk.color + """; the mark gets its automatic color.");
                end
                if ~ismember(mk.spanStyle, EphysAnalysisConfig.OverlayLineStyles)
                    add("Figures", l0 + ".event.spanStyle", "error", "A span's line style is one of " + ...
                        strjoin(EphysAnalysisConfig.OverlayLineStyles, "  ") + ".");
                end
                if ~(isscalar(mk.spanWidth) && isfinite(mk.spanWidth) && mk.spanWidth > 0)
                    add("Figures", l0 + ".event.spanWidth", "error", "A span's line width must be positive (points).");
                end
                if ~(isscalar(mk.spanAlpha) && mk.spanAlpha >= 0 && mk.spanAlpha <= 1)
                    add("Figures", l0 + ".event.spanAlpha", "error", "A span's opacity is from 0 to 1.");
                end
            end
            if L.color ~= "" && ~isColor(L.color)
                add("Figures", l0 + ".color", "warning", "No color """ + L.color + """; the layer takes its group's color.");
            end
            if L.lineStyle ~= "" && ~ismember(L.lineStyle, EphysAnalysisConfig.OverlayLineStyles)
                add("Figures", l0 + ".lineStyle", "error", "A layer's line style is """" (by layer order) or one of " + ...
                    strjoin(EphysAnalysisConfig.OverlayLineStyles, "  ") + ".");
            end
            if isTrials
                checkMeasure(L.measure, l0 + ".measure", pj.type == "trialScatter");
                if pj.type == "trialScatter"; checkMeasure(L.xMeasure, l0 + ".xMeasure", true); end
            end
        end
        if pj.type == "raster" && any(on)
            Lon = Lp(on);
            if all([Lon.source] == "events" & [Lon.eventsAs] ~= "train")
                add("Figures", p0 + ".layers", "error", "A raster's marks need rows: add a units, detected or train layer.");
            end
        end

        % options
        op = pj.options;
        o0 = p0 + ".options";
        firstSignal = false;
        firstSrc = "";
        if any(on)
            firstOn = Lp(find(on, 1));
            firstSrc = firstOn.source;
            firstSignal = ismember(firstSrc, EphysAnalysisConfig.SignalSources);
        end
        switch pj.type
            case "raster"
                checkRasterSort(op, o0);
                if op.tickColor ~= "groups" && ~isColor(op.tickColor)
                    add("Figures", o0 + ".tickColor", "warning", "Not groups or a color: """ + op.tickColor + """; the ticks keep their groups' colors.");
                end
                if ~(isnumeric(op.tickWidth) && isscalar(op.tickWidth) && isfinite(op.tickWidth) && op.tickWidth >= 0)
                    add("Figures", o0 + ".tickWidth", "error", "tickWidth is a line width in points, 0 or more (0 = the plot design's).");
                end
                if ~ismember(op.backColor, ["" "none" "groups"]) && ~isColor(op.backColor)
                    add("Figures", o0 + ".backColor", "warning", "Not none, groups or a color: """ + op.backColor + """; the raster has no bands.");
                end
                checkLatency(op.firstSpike, o0 + ".firstSpike", false);
                checkOnsetLine(op, o0);
                checkFigWaveform(op.waveform, o0 + ".waveform", false);
            case "psth"
                checkFigBins(op.bins, o0);
                checkFigMeasure(op.measure, o0);
                checkFigBaseline(op.baseline, EphysAnalysisConfig.baselineModes("psth"), o0, A);
                checkPanelAuroc(op, o0);
                if ~ismember(op.histStyle, ["bar" "line"])
                    add("Figures", o0 + ".histStyle", "error", "A PSTH is drawn as bar or line.");
                end
                if ~ismember(op.normalize, ["none" "unitPeak" "groupPeak" "allPeak"])
                    add("Figures", o0 + ".normalize", "error", "A PSTH's normalize is none, unitPeak, groupPeak or allPeak.");
                end
                if ~(isnan(op.fillAlpha) || (op.fillAlpha >= 0 && op.fillAlpha <= 1))
                    add("Figures", o0 + ".fillAlpha", "error", "fillAlpha is an opacity from 0 to 1 (NaN = automatic).");
                end
                if ~ismember(op.display, ["trace" "heatmap"])
                    add("Figures", o0 + ".display", "error", "A PSTH's display is trace (bars or a line per group) or heatmap (a row per group).");
                end
                if op.colormap ~= "" && ~ismember(exist(char(op.colormap)), [2 5]) %#ok<EXIST>
                    add("Figures", o0 + ".colormap", "warning", "No colormap function """ + op.colormap + """; the heat map takes the design's.");
                end
                checkFigLim(op.cLim, o0 + ".cLim", "color");
                checkFigLim(op.yLim, o0 + ".yLim", "y");
                checkLatency(op.latencyBox, o0 + ".latencyBox", true);
                checkOnsetLine(op, o0);
                if ~ismember(op.trialCount, ["off" "text" "legend"])
                    add("Figures", o0 + ".trialCount", "error", "A PSTH's trialCount is off, text (n = 24 per group) or legend (in the legend entries).");
                end
                checkFigWaveform(op.waveform, o0 + ".waveform", false);
            case "continuous"
                checkFigBaseline(op.baseline, EphysAnalysisConfig.baselineModes("continuous"), o0, A);
                checkSignalBaseline(op.baseline, pw, o0);
                if ~ismember(op.statistic, EphysAnalysisConfig.AuxStatistics)
                    add("Figures", o0 + ".statistic", "error", "The statistic is one of " + strjoin(EphysAnalysisConfig.AuxStatistics, ", ") + ".");
                end
                if ~ismember(op.transform, EphysAnalysisConfig.AuxTransforms)
                    add("Figures", o0 + ".transform", "error", "The transform is one of " + strjoin(EphysAnalysisConfig.AuxTransforms, ", ") + ".");
                end
                if ~ismember(op.errorType, EphysAnalysisConfig.AuxErrorTypes)
                    add("Figures", o0 + ".errorType", "error", "The errorType is one of " + strjoin(EphysAnalysisConfig.AuxErrorTypes, ", ") + ...
                        " (off: no band; sem: +/- SEM; std: +/- SD; ci95: bootstrap 95% CI; iqr: 25th to 75th percentile).");
                elseif op.errorType == "ci95" && ~(license('test', 'Statistics_Toolbox') && exist('bootci', 'file'))
                    add("Figures", o0 + ".errorType", "error", "The bootstrap 95% CI needs the Statistics and Machine Learning Toolbox (bootci).");
                elseif op.errorType == "iqr" && ~(license('test', 'Statistics_Toolbox') && exist('prctile', 'file'))
                    add("Figures", o0 + ".errorType", "error", "The interquartile range needs the Statistics and Machine Learning Toolbox (prctile).");
                end
                if ~ismember(op.trials, ["off" "faint" "only"])
                    add("Figures", o0 + ".trials", "error", "A continuous signal panel's trials are off, faint (each epoch's trace " + ...
                        "behind the mean) or only (the traces, no mean).");
                end
                if ~(isscalar(op.maxTrials) && op.maxTrials >= 1 && (isinf(op.maxTrials) || op.maxTrials == round(op.maxTrials)))
                    add("Figures", o0 + ".maxTrials", "error", "maxTrials is a whole number of epochs, at least 1 (Inf = every one).");
                end
                checkFigLim(op.yLim, o0 + ".yLim", "y");
            case "heatmap"
                if ~ismember(op.rows, ["items" "trials"])
                    add("Figures", o0 + ".rows", "error", "A heat map's rows are items (the layer's units or channels) or trials " + ...
                        "(one unit's epochs).");
                elseif op.rows == "trials"
                    checkTrialRows(Lp, find(on), op, o0, p0, o0 + ".baseline.Mode");
                end
                if ~firstSignal
                    checkFigBins(op.bins, o0);
                    checkFigMeasure(op.measure, o0);
                    checkFigBaseline(op.baseline, EphysAnalysisConfig.baselineModes("heatmap", firstSrc), o0, A);
                    checkPanelAuroc(op, o0);
                else
                    if op.baseline.Mode == "auroc"
                        add("Figures", o0 + ".baseline.Mode", "error", "The auROC baseline is for spikes: a heat map of a signal takes baseline Mode none or subtract.");
                    else
                        checkFigBaseline(op.baseline, EphysAnalysisConfig.baselineModes("heatmap", firstSrc), o0, A);
                    end
                    checkSignalBaseline(op.baseline, pw, o0);
                end
                if ~ismember(op.order, ["probe" "peak" "modulation"])
                    add("Figures", o0 + ".order", "error", "A heat map orders its rows by probe (the style's sort options), peak or modulation.");
                elseif op.order == "modulation" && (firstSignal || op.baseline.Mode ~= "auroc")
                    add("Figures", o0 + ".order", "error", "A heat map's rows go in modulation order only with the auROC baseline (baseline Mode ""auroc"").");
                end
                checkFigGroup(op.group, o0);
                checkFigLim(op.cLim, o0 + ".cLim", "color");
            case "waveforms"
                checkFigWaveform(op.waveform, o0 + ".waveform", true);
                if ~ismember(op.layout, ["grid" "probe"])
                    add("Figures", o0 + ".layout", "error", "A unit waveforms panel's layout is grid or probe.");
                elseif op.layout == "probe" && any(on) && Lp(find(on, 1)).binding == "observation"
                    add("Figures", o0 + ".layout", "warning", "The probe layout draws every unit of the first layer at its " + ...
                        "place, but that layer follows the observed unit: bind it to fixed units (and ring the observed one with a following layer).");
                end
                checkFigLim(op.yLim, o0 + ".yLim", "y");
            case "rate"
                checkFigMeasure(op.measure, o0);
                checkFigBaseline(op.baseline, EphysAnalysisConfig.baselineModes("rate"), o0, A);
                if ~ismember(op.display, ["bar" "box" "points"])
                    add("Figures", o0 + ".display", "error", "A firing rate panel's display is bar, box or points.");
                end
                checkFigLim(op.yLim, o0 + ".yLim", "y");
                checkFigWaveform(op.waveform, o0 + ".waveform", false);
            case "tuning"
                checkFigMeasure(op.measure, o0);
                checkFigBaseline(op.baseline, EphysAnalysisConfig.baselineModes("tuning"), o0, A);
                if ~isvarname(op.param) && op.param ~= ""
                    add("Figures", o0 + ".param", "error", "The tuning parameter """ + op.param + """ is not a trial parameter's name " + ...
                        "(empty: the figure's first groupBy parameter, else the first numeric one).");
                end
                if ~isvarname(op.seriesParam) && op.seriesParam ~= ""
                    add("Figures", o0 + ".seriesParam", "error", "The series parameter """ + op.seriesParam + """ is not a trial parameter's name (empty: one curve).");
                elseif op.seriesParam ~= "" && op.seriesParam == op.param
                    add("Figures", o0 + ".seriesParam", "error", "The series parameter is the tuning parameter itself: pick another, or none.");
                end
                checkFigLim(op.yLim, o0 + ".yLim", "y");
                checkFigWaveform(op.waveform, o0 + ".waveform", false);
            case "probemap"
                if ~ismember(op.value, ["rate" "nSpikes" "nUnits"])
                    add("Figures", o0 + ".value", "error", "A probe map shows rate, nSpikes or nUnits.");
                end
                checkFigLim(op.cLim, o0 + ".cLim", "color");
                checkFigWaveform(op.waveform, o0 + ".waveform", false);
                if ~(islogical(op.waveColor) && isscalar(op.waveColor))
                    add("Figures", o0 + ".waveColor", "error", "Color waveforms by value is on or off.");
                end
            case "corrmap"
                if ~ismember(op.metric, ["mean" "peak"])
                    add("Figures", o0 + ".metric", "error", "A unit correlation map correlates each epoch's mean or peak rate.");
                elseif op.metric == "peak"
                    checkFigBins(op.bins, o0);
                end
                if ~ismember(op.correlation, ["pearson" "spearman"])
                    add("Figures", o0 + ".correlation", "error", "A unit correlation map's correlation is pearson or spearman.");
                end
                checkFigBaseline(op.baseline, EphysAnalysisConfig.baselineModes("corrmap"), o0, A);
                checkFigGroup(op.group, o0);
                checkFigLim(op.cLim, o0 + ".cLim", "color");
            case {"spectrum" "spectrogram" "coherence"}
                checkSpectral(pj, op, pw, Lp(on), o0, p0, find(on));
            case "eventTrace"
                checkEventTrace(op, o0);
            case {"trialDist" "trialHist" "trialScatter"}
                checkTrialOptions(op, o0, A, pj.type);
            case "legend"
                if ~ismember(op.orientation, ["auto" "vertical" "horizontal"])
                    add("Figures", o0 + ".orientation", "error", "A legend panel's orientation is auto, vertical or horizontal.");
                end
                if ~ismember(op.align, ["left" "center" "right"])
                    add("Figures", o0 + ".align", "error", "A legend panel's align is left, center or right.");
                end
                if ~ismember(op.valign, ["top" "middle" "bottom"])
                    add("Figures", o0 + ".valign", "error", "A legend panel's valign is top, middle or bottom.");
                end
                if ~(isscalar(op.columns) && isfinite(op.columns) && op.columns >= 0 && op.columns == round(op.columns))
                    add("Figures", o0 + ".columns", "error", "A legend panel's columns is a whole number, 0 (automatic) or more.");
                end
        end
        if isfield(op, 'stack'); checkStack(pj.type, op, o0); end
        if isfield(op, 'yLimMode'); checkYLimMode(op, o0); end
        checkPanelError(pj.type, op, o0);
    end

    % the style
    checkStyle(fg.style, "Figures", f0);
end

% --- Export -----------------------------------------------------------------------------
X = obj.Export;
if X.Enabled && isempty(X.Formats)
    add("Export", "Formats", "error", "Export is enabled but no format is chosen (png, eps, svg, pdf).");
end
bad = setdiff(X.Formats, ["png" "eps" "svg" "pdf"]);
if ~isempty(bad)
    add("Export", "Formats", "error", "Unknown format(s) " + strjoin(bad, ", ") + " (png, eps, svg, pdf).");
end
if ~(X.Dpi > 0); add("Export", "Dpi", "error", "Dpi must be positive."); end
if ~(numel(X.FigureSizeCm) == 2 && all(X.FigureSizeCm > 0))
    add("Export", "FigureSizeCm", "error", "FigureSizeCm must be [width height] > 0.");
end
checkPattern(X.FilenamePattern, "file", "Export", "FilenamePattern");
checkPattern(X.Folder, "folder", "Export", "Folder");
nFig = numel(obj.enabledFigures());   % every figure's {Kind} is "figure": only {Plot} (its id) tells them apart
if nFig > 1 && ~contains(X.FilenamePattern, "{Plot}")
    add("Export", "FilenamePattern", "warning", sprintf("The file-name pattern has no {Plot}, so the %d enabled figures' files overwrite each other.", nFig));
end
if ~contains(X.Folder, ["{OutputFolder}" "{Name}"]) && ~contains(X.FilenamePattern, "{Name}") ...
        && ~(S.Mode == "folders" && numel(S.Folders) <= 1)
    add("Export", "Folder", "warning", "Neither the export folder nor the file-name pattern names the dataset ({OutputFolder} or {Name}), so the datasets' files overwrite each other.");
end
checkPattern(X.SessionsFolder, "folder", "Export", "SessionsFolder");
if contains(X.SessionsFolder, "{OutputFolder}")
    add("Export", "SessionsFolder", "warning", "{OutputFolder} is one dataset's folder; the session figures' files go to the first dataset's.");
end
XD = X.Data;
checkPattern(XD.Folder, "folder", "Export", "Data.Folder");
checkPattern(XD.FilenamePattern, "file", "Export", "Data.FilenamePattern");
if contains(XD.Folder, "{OutputFolder}")
    add("Export", "Data.Folder", "warning", "{OutputFolder} is one dataset's folder; the session figures' data files go to the first dataset's.");
end
if ~ismember(XD.MatVersion, ["-v7.3" "-v7"])
    add("Export", "Data.MatVersion", "error", "MatVersion is -v7.3 or -v7.");
end

% --- Report -------------------------------------------------------------------------------
P = obj.Report;
if ~ismember(P.Format, ["html" "pdf" "both"])
    add("Report", "Format", "error", "Format must be html, pdf or both.");
end
if ~ismember(P.EmbedFormat, ["png" "svg"])
    add("Report", "EmbedFormat", "error", "EmbedFormat must be png or svg.");
end
if ~ismember(P.Order, ["figure" "unit"])
    add("Report", "Order", "error", "Order must be figure or unit.");
end
if ~(P.FiguresPerPage >= 1 && P.FiguresPerPage <= 16 && P.FiguresPerPage == round(P.FiguresPerPage))
    add("Report", "FiguresPerPage", "error", "FiguresPerPage must be a whole number from 1 to 16.");
end
if ~ismember(P.PageSize, ["letter" "a4"])
    add("Report", "PageSize", "error", "PageSize must be letter or a4.");
end
if ~ismember(P.PageOrientation, ["auto" "portrait" "landscape"])
    add("Report", "PageOrientation", "error", "PageOrientation must be auto, portrait or landscape.");
end
if ~(P.Dpi > 0); add("Report", "Dpi", "error", "Dpi must be positive."); end
if strtrim(P.FileName) == "" || ~isempty(regexp(P.FileName, '[\\/:*?"<>|]', 'once'))
    add("Report", "FileName", "error", "FileName must be a plain file name (no folder, no \ / : * ? "" < > |).");
end
checkPattern(P.Folder, "folder", "Report", "Folder");
if ~P.PerDataset && contains(P.Folder, "{OutputFolder}")
    add("Report", "Folder", "warning", "{OutputFolder} is one dataset's folder; a report over every dataset goes to the first dataset's.");
end

issues = table(Section, Field, Severity, Message);

    function checkRef(r, sec, field)
        try
            eventRef(r);
        catch ME
            add(sec, field, "error", string(ME.message));
        end
    end

    function checkWindow(w, sec, field)
        try
            epochWindow(w);
        catch ME
            add(sec, field, "error", string(ME.message));
        end
    end

    function checkRasterSort(hOp, hO0)
        %checkRasterSort  A raster panel's sort options.
        if ~ismember(hOp.rasterSortOrder, ["ascending" "descending"])
            add("Figures", hO0 + ".rasterSortOrder", "error", "The raster sort order is ascending or descending.");
        end
        if hOp.rasterSort == "event"
            if isempty(hOp.rasterSortEvent)
                add("Figures", hO0 + ".rasterSortEvent", "error", "rasterSort ""event"" sorts the raster by an event's " + ...
                    "latency from each epoch's event: give rasterSortEvent, e.g. Platform offset.");
            else
                checkRef(hOp.rasterSortEvent, "Figures", hO0 + ".rasterSortEvent");
            end
        end
    end

    function checkTrialRows(hL, hOn, hOp, hO0, hP0, hB0)
        %checkTrialRows  A heat map of trials: one unit's epochs (its map layer follows the observation, is one fixed unit or a train), sorted as a raster.
        %   HL the panel's layers, HON the enabled ones' indices, HB0 where its baseline is reported.
        hI = hOn(~([hL(hOn).source] == "events" & [hL(hOn).eventsAs] ~= "train"));
        if ~isempty(hI)
            hM = hL(hI(1));
            hF = hP0 + ".layers(" + hI(1) + ")";
            if ismember(hM.source, EphysAnalysisConfig.SignalSources)
                add("Figures", hO0 + ".rows", "error", "A heat map of trials draws one unit's epochs: its layer is units, " + ...
                    "detected or an events train, not " + hM.source + ".");
            elseif ismember(hM.source, EphysAnalysisConfig.SpikeSources) && hM.binding == "fixed"
                hN = hM.units.maxUnits;
                if ~isempty(hM.units.ids); hN = min(hN, numel(hM.units.ids)); end
                if ~(hN == 1)
                    add("Figures", hF + ".units", "error", "A heat map of trials draws one unit's epochs: bind its layer to " + ...
                        "the observation, or fix it to one unit (one id, or maxUnits 1).");
                end
            elseif ismember(hM.source, EphysAnalysisConfig.SpikeSources) && hM.binding == "observation" ...
                    && kind ~= "dataset" && hM.source ~= ob.data
                % it follows the observation through a channel: every unit on it (figureLayerItems), not one
                add("Figures", hF + ".binding", "error", "A heat map of trials draws one unit's epochs, but this layer " + ...
                    "follows the observation through its channel (every " + hM.source + " unit on it): observe " + ...
                    hM.source + " units, or fix the layer to one unit.");
            end
        end
        if hOp.baseline.Mode == "auroc"
            add("Figures", hB0, "error", "A heat map of trials draws each epoch's rate: the auROC baseline " + ...
                "(a curve over the epochs) does not apply. Take none, subtract, zscore or percent.");
        end
        checkRasterSort(hOp, hO0);
    end

    function checkEventTrace(hOp, hO0)
        %checkEventTrace  An event-trace panel's options.
        hPos = @(x) isscalar(x) && isfinite(x) && x > 0;
        if ~ismember(hOp.display, ["bars" "line"])
            add("Figures", hO0 + ".display", "error", "An event-trace panel draws its intervals as bars or a line (a logic level).");
        end
        if ~ismember(hOp.trials, ["overlay" "rows"])
            add("Figures", hO0 + ".trials", "error", "An event-trace panel's trials are overlay (every epoch in the line's row) " + ...
                "or rows (a sub-row per epoch).");
        end
        if ~ismember(hOp.colorBy, ["layer" "group"])
            add("Figures", hO0 + ".colorBy", "error", "An event-trace panel colors by layer (each line's color) or by group (each trial group's).");
        end
        if ~(hPos(hOp.height) && hOp.height <= 1)
            add("Figures", hO0 + ".height", "error", "height is the bars' share of a row: above 0, at most 1.");
        end
        if ~(isnan(hOp.alpha) || (hOp.alpha >= 0 && hOp.alpha <= 1))
            add("Figures", hO0 + ".alpha", "error", "alpha is an opacity from 0 to 1 (NaN = automatic).");
        end
        if ~ismember(lower(hOp.edgeColor), ["none" "auto"]) && ~isColor(hOp.edgeColor)
            add("Figures", hO0 + ".edgeColor", "warning", "No color """ + hOp.edgeColor + """; the bars get no outline.");
        end
        if hOp.baselineColor ~= "" && ~isColor(hOp.baselineColor)
            add("Figures", hO0 + ".baselineColor", "warning", "No color """ + hOp.baselineColor + """; the baseline is gray.");
        end
        for hF = ["lineStyle" "baselineStyle"]
            if ~ismember(hOp.(hF), EphysAnalysisConfig.OverlayLineStyles)
                add("Figures", hO0 + "." + hF, "error", hF + " is one of " + strjoin(EphysAnalysisConfig.OverlayLineStyles, "  ") + ".");
            end
        end
        for hF = ["edgeWidth" "lineWidth" "baselineWidth" "rowSpacing"]
            if ~hPos(hOp.(hF))
                add("Figures", hO0 + "." + hF, "error", hF + " must be positive.");
            end
        end
        if ~(isscalar(hOp.minWidth) && isfinite(hOp.minWidth) && hOp.minWidth >= 0)
            add("Figures", hO0 + ".minWidth", "error", "minWidth is the narrowest a bar is drawn, points: 0 or more (0 = no minimum).");
        end
        if hOp.trials == "rows"   % the sub-rows sorted as a raster's rows
            checkRasterSort(hOp, hO0);
            if hOp.rasterSort == "latency"
                add("Figures", hO0 + ".rasterSort", "warning", "An event trace has no spikes to take a first-spike latency from: " + ...
                    "the sub-rows stay in time order.");
            end
        end
    end

    function checkMeasure(hM, hM0, hScatter)
        %checkMeasure  A trials layer's TrialMeasure (HM0: its field, "<...>.layers(<i>).measure" or ".xMeasure").
        %   HSCATTER: on a trial scatter, whose x and y pair one value per trial (a "which all" B gives several).
        hKinds = EphysAnalysisConfig.TrialMeasureKinds;
        if ~ismember(hM.kind, hKinds)
            add("Figures", hM0 + ".kind", "error", "A trial measure's kind is " + strjoin(hKinds, ", ") + ...
                " (delay: A to B; duration: A's interval; count: B events after A; param: a trial parameter), not """ + hM.kind + """.");
        end
        checkRef(hM.from, "Figures", hM0 + ".from");
        if ismember(hM.kind, ["delay" "count"])
            checkRef(hM.to, "Figures", hM0 + ".to");
        end
        if ~ismember(hM.direction, ["after" "before"])
            add("Figures", hM0 + ".direction", "error", "A delay's direction is after (the first B at or after A) or before " + ...
                "(the last B at or before A).");
        end
        if ~(isscalar(hM.maxGapSec) && hM.maxGapSec > 0)
            add("Figures", hM0 + ".maxGapSec", "error", "maxGapSec is above 0 s (Inf = no limit).");
        end
        if hM.kind == "param" && ~isvarname(hM.param)
            add("Figures", hM0 + ".param", "error", "A param measure names a numeric trial parameter, not """ + hM.param + """.");
        end
        if ~ismember(hM.unit, ["ms" "s"])
            add("Figures", hM0 + ".unit", "error", "A trial measure's unit is ms or s (a time's; a count and a parameter keep their own).");
        end
        checkLabelText(hM.label, hM0 + ".label", false);
        if hScatter && hM.kind == "delay" && hM.to.which == "all"
            add("Figures", hM0 + ".to.which", "warning", "Every B after A gives several values per trial, but a scatter " + ...
                "pairs one x with one y per trial: the first value of each trial is paired.");
        end
    end

    function checkTrialOptions(hOp, hO0, hWho, hType)
        %checkTrialOptions  A trial distribution's, histogram's or scatter's options (HWHO: "A trial ... panel").
        hEnums = struct('categories', EphysAnalysisConfig.TrialGroupings, 'series', EphysAnalysisConfig.TrialGroupings, ...
            'summary', ["mean" "median"], 'errorType', EphysAnalysisConfig.AuxErrorTypes, ...
            'test', EphysAnalysisConfig.TrialTests, 'testPairs', ["all" "first"], 'adjust', ["holm" "bh" "bonferroni" "none"], ...
            'testShow', ["text" "off"], 'bracketPairs', ["significant" "all"], 'showN', ["off" "ticks"], ...
            'normalization', ["count" "probability" "pdf"], 'binMode', ["auto" "count" "width"], ...
            'fit', EphysAnalysisConfig.TrialFits, 'corr', ["pearson" "spearman" "none"], ...
            'xScale', ["linear" "log"], 'yScale', ["linear" "log"]);
        if hType == "trialDist"
            hEnums.display = ["swarm" "box" "violin" "points" "line"];
            hEnums.testShow = ["brackets" "text" "off"];
        elseif hType == "trialHist"
            hEnums.display = ["bars" "outline" "ecdf"];
        end
        for hF = string(fieldnames(hEnums)).'
            if isfield(hOp, hF) && ~ismember(hOp.(hF), hEnums.(hF))
                add("Figures", hO0 + "." + hF, "error", hWho + "'s " + hF + " is one of " + strjoin(hEnums.(hF), ", ") + ...
                    ", not """ + hOp.(hF) + """.");
            end
        end
        % a parameter's levels: the parameter named, binned by nothing, a count or edges
        for hD = ["category" "series"]
            hDim = hD;
            if hD == "category"; hDim = "categories"; end
            if ~isfield(hOp, hDim); continue; end
            hP = hOp.(hD + "Param");
            if hOp.(hDim) == "param" && ~isvarname(hP)
                hNot = ".";
                if hP ~= ""; hNot = ", not """ + hP + """."; end
                add("Figures", hO0 + "." + hD + "Param", "error", hDim + " ""param"" groups by a trial parameter: name it in " + ...
                    hD + "Param" + hNot);
            elseif hP ~= "" && ~isvarname(hP)
                add("Figures", hO0 + "." + hD + "Param", "error", """" + hP + """ is not a trial parameter's name.");
            end
            hB = hOp.(hD + "Bins");
            hWhole = isscalar(hB) && isfinite(hB) && hB >= 1 && hB == round(hB);
            hEdges = numel(hB) >= 2 && all(isfinite(hB)) && all(diff(hB) > 0);
            if ~(isempty(hB) || hWhole || hEdges)
                add("Figures", hO0 + "." + hD + "Bins", "error", hD + "Bins is [] (each value a level), a whole number of " + ...
                    "equal-width bins, or two or more ascending edges.");
            end
        end
        if isfield(hOp, 'categories') && hOp.categories == hOp.series ...
                && ~(hOp.categories == "param" && hOp.categoryParam ~= hOp.seriesParam)
            add("Figures", hO0 + ".series", "error", "The series group the values as the categories do (" + hOp.series + ...
                "): pick another series (a series per category tells nothing apart).");
        end
        if ~(isscalar(hOp.testAlpha) && hOp.testAlpha > 0 && hOp.testAlpha < 1)
            add("Figures", hO0 + ".testAlpha", "error", "testAlpha, the tests' significance level, is between 0 and 1 (e.g. 0.05).");
        end
        if isfield(hOp, 'alpha') && ~(isscalar(hOp.alpha) && hOp.alpha >= 0 && hOp.alpha <= 1)
            add("Figures", hO0 + ".alpha", "error", "alpha, the opacity, is from 0 to 1.");
        end
        if isfield(hOp, 'markerSize') && ~(isscalar(hOp.markerSize) && isfinite(hOp.markerSize) && hOp.markerSize > 0)
            add("Figures", hO0 + ".markerSize", "error", "markerSize must be positive (points).");
        end
        if isfield(hOp, 'jitter') && ~(isscalar(hOp.jitter) && hOp.jitter >= 0 && hOp.jitter <= 1)
            add("Figures", hO0 + ".jitter", "error", "jitter is a share of the category's slot, from 0 to 1.");
        end
        if isfield(hOp, 'binCount') && ~isWhole(hOp.binCount)
            add("Figures", hO0 + ".binCount", "error", "binCount is a whole number of bins, at least 1.");
        end
        if isfield(hOp, 'binWidth') && ~(isscalar(hOp.binWidth) && isfinite(hOp.binWidth) && hOp.binWidth > 0)
            add("Figures", hO0 + ".binWidth", "error", "binWidth must be positive (in the measure's unit).");
        end
        if isfield(hOp, 'fitWindow') && ~(isWhole(hOp.fitWindow) && hOp.fitWindow >= 2)
            add("Figures", hO0 + ".fitWindow", "error", "fitWindow is a whole number of points, at least 2.");
        end
        if isfield(hOp, 'marginalSize') && ~(isscalar(hOp.marginalSize) && hOp.marginalSize >= 0.1 && hOp.marginalSize <= 0.5)
            add("Figures", hO0 + ".marginalSize", "error", "marginalSize is the strips' share of the panel's box, from 0.1 to 0.5.");
        end
        if isfield(hOp, 'xLim'); checkFigLim(hOp.xLim, hO0 + ".xLim", "x"); end
        if isfield(hOp, 'yLim'); checkFigLim(hOp.yLim, hO0 + ".yLim", "y"); end
        hStats = license('test', 'Statistics_Toolbox');
        if ismember(hOp.test, EphysAnalysisConfig.TrialTests) && hOp.test ~= "none" && ~hStats
            add("Figures", hO0 + ".test", "error", "The group tests need the Statistics and Machine Learning Toolbox (ranksum, " + ...
                "ttest2, kruskalwallis, anova1): take test none without it.");
        end
        if hOp.errorType == "ci95" && ~(hStats && exist('bootci', 'file'))
            add("Figures", hO0 + ".errorType", "error", "The bootstrap 95% CI needs the Statistics and Machine Learning Toolbox (bootci).");
        elseif hOp.errorType == "iqr" && ~(hStats && exist('prctile', 'file'))
            add("Figures", hO0 + ".errorType", "error", "The interquartile range needs the Statistics and Machine Learning Toolbox (prctile).");
        end
    end

    function checkFigBins(hBins, hO0)
        %checkFigBins  A panel's bins.
        if ~(hBins.BinSec > 0); add("Figures", hO0 + ".bins.BinSec", "error", "BinSec must be positive."); end
        if ~(hBins.SmoothSec >= 0); add("Figures", hO0 + ".bins.SmoothSec", "error", "SmoothSec must be >= 0."); end
    end

    function checkFigMeasure(hMeasure, hO0)
        %checkFigMeasure  A panel's measure of spikes.
        if ~ismember(hMeasure, ["rate" "count" "probability"])
            add("Figures", hO0 + ".measure", "error", "The measure is rate, count or probability.");
        end
    end

    function checkFigBaseline(hB, hModes, hO0, hWho)
        %checkFigBaseline  A panel's baseline: its Mode one of HMODES, and its window [b0 b1] with b0 < b1.
        if ~ismember(hB.Mode, hModes)
            add("Figures", hO0 + ".baseline.Mode", "error", sprintf("%s's baseline Mode is one of %s, not ""%s"".", ...
                hWho, strjoin(hModes, ", "), hB.Mode));
        elseif hB.Mode ~= "none" && ~(numel(hB.Window) == 2 && all(isfinite(hB.Window)) && hB.Window(2) > hB.Window(1))
            add("Figures", hO0 + ".baseline.Window", "error", "The baseline window must be [b0 b1] with b0 < b1.");
        end
    end

    function checkSignalBaseline(hB, hW, hO0)
        %checkSignalBaseline  A signal's baseline is taken from the samples it cuts: its window must overlap the panel's [pre post].
        %   (evokedPotential subtracts each epoch's mean over the baseline's samples inside the epoch's window.)
        if hB.Mode == "none" || ~(numel(hB.Window) == 2 && all(isfinite(hB.Window)) && hB.Window(2) > hB.Window(1)) ...
                || ~isstruct(hW) || ~(isfinite(hW.pre) && isfinite(hW.post))
            return
        end
        if hB.Window(2) < hW.pre || hB.Window(1) > hW.post
            add("Figures", hO0 + ".baseline", "error", sprintf(['The baseline window [%g %g] s has no sample in the ' ...
                'panel''s window [%g %g] s: a signal''s baseline is cut from the epoch, so it must overlap it.'], ...
                hB.Window(1), hB.Window(2), hW.pre, hW.post));
        end
    end

    function checkPanelAuroc(hOp, hO0)
        %checkPanelAuroc  A PSTH's or a spike heat map's auROC settings under baseline Mode "auroc", against its bins.
        if hOp.baseline.Mode == "auroc"
            checkAuroc(hOp.auroc, hOp.bins.BinSec, "Figures", hO0 + ".auroc", true);
        end
    end

    function checkStack(hType, hOp, hO0)
        %checkStack  A panel's stack and stackSpacing: one vocabulary for every type that stacks (stackModes).
        hModes = EphysAnalysisConfig.stackModes(hType);
        hWho = "A " + hType + " panel";
        if ~ismember(hOp.stack, hModes)
            add("Figures", hO0 + ".stack", "error", sprintf("%s's stack is one of %s, not ""%s"" (off: overlaid; groups: a row " + ...
                "per trial group; items: a continuous panel's row per channel).", hWho, strjoin(hModes, ", "), hOp.stack));
        elseif hType == "heatmap" && hOp.stack ~= "off" && isfield(hOp, 'rows') && hOp.rows == "trials"
            add("Figures", hO0 + ".stack", "warning", "A heat map of one unit's epochs draws every trial group in blocks " + ...
                "already (rasterByGroup): its stack is not used.");
        end
        if ~(isscalar(hOp.stackSpacing) && isfinite(hOp.stackSpacing) && hOp.stackSpacing > 0)
            add("Figures", hO0 + ".stackSpacing", "error", "stackSpacing must be positive: the row step x the row height " + ...
                "(1: the rows touch; below 1 they overlap).");
        end
    end

    function checkYLimMode(hOp, hO0)
        %checkYLimMode  A panel's yLimMode: one of YLimModes; "fixed" needs its yLim.
        if ~ismember(hOp.yLimMode, EphysAnalysisConfig.YLimModes)
            add("Figures", hO0 + ".yLimMode", "error", "yLimMode is auto (each axis or stacked row fits itself), rows (a " + ...
                "stack's rows share one scale), batch (one range for every observation of a run) or fixed (yLim), not """ + ...
                hOp.yLimMode + """.");
        elseif hOp.yLimMode == "fixed" && isempty(hOp.yLim)
            add("Figures", hO0 + ".yLim", "error", "yLimMode fixed draws the y axis at yLim: give [lo hi] with lo < hi.");
        end
    end

    function checkFigLim(hLim, hField, hWhat)
        %checkFigLim  A panel's y or color limits: [] (automatic) or an ascending pair.
        if ~(isempty(hLim) || (numel(hLim) == 2 && all(isfinite(hLim)) && hLim(2) > hLim(1)))
            add("Figures", hField, "error", "The " + hWhat + " limits are [] (automatic) or [lo hi] with lo < hi.");
        end
    end

    function checkSpectral(hP, hOp, hW, hL, hO0, hP0, hIdx)
        %checkSpectral  A Chronux panel (spectrum, spectrogram, coherence): its options by chronuxSettings' rules, and its layers.
        %   HL: its enabled layers, HIDX their indices in the panel. The options go through figureChronuxSettings (with
        %   the panel's fixed window, which a spectrogram's baseline window must lie inside); what chronuxSettings
        %   throws is reported with its message. A coherence panel takes exactly two enabled layers (the seed, then
        %   its partner); a spectrogram a signal or spike layer.
        hRange = isfield(hOp, 'timeBase') && hOp.timeBase == "range";
        hWin = [];
        if isstruct(hW) && isfield(hW, 'mode') && hW.mode == "fixed" && isfinite(hW.pre) && isfinite(hW.post) && hW.post > hW.pre
            hWin = [hW.pre hW.post];
        end
        if ~isempty(hWin) || hRange
            try
                figureChronuxSettings(hP.type, hOp, hWin);
            catch hME
                if ~startsWith(string(hME.identifier), "chronuxSettings:"); rethrow(hME); end
                add("Figures", hO0, "error", string(hME.message));
            end
        end
        if isfield(hOp, 'yLim'); checkFigLim(hOp.yLim, hO0 + ".yLim", "y"); end
        if isfield(hOp, 'cLim'); checkFigLim(hOp.cLim, hO0 + ".cLim", "color"); end
        if isfield(hOp, 'group'); checkFigGroup(hOp.group, hO0); end
        hSrc = strings(1, 0);
        if ~isempty(hL); hSrc = [hL.source]; end
        switch hP.type
            case "spectrogram"
                if ~isempty(hL) && ~any(ismember(hSrc, [EphysAnalysisConfig.SignalSources EphysAnalysisConfig.SpikeSources]))
                    add("Figures", hP0 + ".layers", "error", "A spectrogram draws a signal or spike layer (LFP, MUA, SPIKE, " + ...
                        "AUX, units or detected).");
                end
            case "coherence"
                if numel(hL) ~= 2
                    add("Figures", hP0 + ".layers", "error", sprintf(['A coherence panel takes exactly two enabled layers, ' ...
                        'the seed (first) then its partner; it has %d.'], numel(hL)));
                    return
                end
                hS = hL(1);
                hMany = (ismember(hS.source, EphysAnalysisConfig.SignalSources) && numel(hS.channels) ~= 1 ...
                    && hS.aggregate ~= "magnitude") ...   % a magnitude is one item, whatever its channels
                    || (ismember(hS.source, EphysAnalysisConfig.SpikeSources) && numel(hS.units.ids) ~= 1);
                if hS.binding == "fixed" && hMany
                    add("Figures", hP0 + ".layers(" + hIdx(1) + ")", "warning", "The seed is its layer's first channel " + ...
                        "or unit only: fix the seed layer to one.");
                end
        end
    end

    function checkFigGroup(hG, hO0)
        %checkFigGroup  The trial group a one-group panel draws.
        if ~isWhole(hG)
            add("Figures", hO0 + ".group", "error", "group is the trial group drawn: a whole number, at least 1.");
        end
    end

    function checkFigWaveform(hW, hW0, hOwn)
        %checkFigWaveform  A raster / PSTH / rate / tuning panel's waveform inset, a probe map's glyphs, or (HOWN) a waveforms panel's settings.
        %   Its mode always; while drawn, its place, size, spikes, time span and amplitude scale (ampLim with "fixed").
        if ~ismember(hW.ampScale, EphysAnalysisConfig.WaveformAmpScales)
            add("Figures", hW0 + ".ampScale", "error", "The waveform amplitude scale is unit, common or fixed.");
        end
        if ~ismember(hW.band, EphysAnalysisConfig.WaveformBands)
            add("Figures", hW0 + ".band", "error", "The waveform's error band is off, std or sem.");
        end
        if ~ismember(hW.mode, EphysAnalysisConfig.WaveformModes)
            add("Figures", hW0 + ".mode", "error", "The waveform mode is off, mean, subsample, both or template.");
        elseif hOwn && hW.mode == "off"
            add("Figures", hW0 + ".mode", "error", "A unit waveforms panel shows the mean, a subsample, both or the template: its waveform mode cannot be off.");
        elseif hW.mode ~= "off"
            if ~ismember(hW.location, EphysAnalysisConfig.WaveformLocations)
                add("Figures", hW0 + ".location", "error", "The waveform location is one of " + ...
                    strjoin(EphysAnalysisConfig.WaveformLocations, ", ") + ".");
            end
            for hF = ["width" "height"]
                if ~(hW.(hF) > 0 && hW.(hF) <= 3)
                    add("Figures", hW0 + "." + hF, "error", "The waveform's " + hF + " is above 0 and at most 3 (1 = its default: " + ...
                        "an inset a third of the tile's).");
                end
            end
            if ~(hW.maxSpikes >= 1 && hW.maxSpikes == round(hW.maxSpikes))
                add("Figures", hW0 + ".maxSpikes", "error", "maxSpikes is a whole number of spikes, at least 1.");
            end
            if ~(isempty(hW.timeMs) || (numel(hW.timeMs) == 2 && ~any(isnan(hW.timeMs)) && hW.timeMs(2) > hW.timeMs(1)))
                add("Figures", hW0 + ".timeMs", "error", "The waveform's time span is [] (the whole cut) or [from to] ms " + ...
                    "from the spike with from < to (-Inf / Inf: the cut's edge).");
            end
            if hW.ampScale == "fixed" && ~(numel(hW.ampLim) == 2 && all(isfinite(hW.ampLim)) && hW.ampLim(2) > hW.ampLim(1))
                add("Figures", hW0 + ".ampLim", "error", "A fixed waveform amplitude scale needs ampLim, [lo hi] with lo < hi.");
            end
        end
    end

    function checkFigureLatency(hFg, hF0, hW)
        %checkFigureLatency  A figure's latency block (latency: how its panels' first-spike latencies and onsets are found), against its window HW.
        %   The method, baseline and baselineRate known values; the window
        %   (minSec <= maxSec, both numbers; one that misses the figure's
        %   [pre post] warns, as nothing can be found there); the baseline
        %   window [lo hi] with lo < hi; alpha in (0, 1), surprise above 0,
        %   minSpikes a whole number of at least 2; the CUSUM's bin (above
        %   0), threshold (above 0), drift and sustain (0 or more). A
        %   warning when a rule that needs a baseline rate ("surprise",
        %   "poisson", or a panel that draws the onset) takes it from
        %   before the event but the figure's window starts at or after the
        %   event, and when the baseline window misses the figure's window.
        %   The window warnings only on a figure with a raster, PSTH or heat
        %   map and a fixed window (pre and post from the event).
        hL = hFg.latency;
        hL0 = hF0 + ".latency";
        hTypes = strings(1, 0);
        if ~isempty(hFg.panels); hTypes = [hFg.panels.type]; end
        if ~(isstruct(hW) && isfield(hW, 'mode') && hW.mode == "fixed" && any(ismember(hTypes, ["raster" "psth" "heatmap"])))
            hW = [];   % no panel that can read it, or a window from event to event: its place in the window is not checked
        end
        if ~ismember(hL.method, EphysAnalysisConfig.LatencyMethods)
            add("Figures", hL0 + ".method", "error", "The latency method is " + strjoin(EphysAnalysisConfig.LatencyMethods, ", ") + ...
                ", not " + hL.method + ".");
        end
        if ~ismember(hL.baseline, EphysAnalysisConfig.LatencyBaselines)
            add("Figures", hL0 + ".baseline", "error", "The latency baseline is pre (before the event) or window (baselineWindow).");
        end
        if ~ismember(hL.baselineRate, EphysAnalysisConfig.LatencyRates)
            add("Figures", hL0 + ".baselineRate", "error", "The latency baseline rate is unit (every epoch's) or trial (each epoch's own).");
        end
        if isnan(hL.minSec) || isnan(hL.maxSec) || ~(hL.minSec <= hL.maxSec) || hL.minSec == Inf || hL.maxSec == -Inf
            add("Figures", hL0 + ".minSec", "error", sprintf(['The latency window [%g %g] s needs minSec <= ' ...
                'maxSec (maxSec Inf = the window''s end).'], hL.minSec, hL.maxSec));
        elseif isstruct(hW) && isfinite(hW.pre) && isfinite(hW.post) && (hL.minSec >= hW.post || hL.maxSec < hW.pre)
            add("Figures", hL0 + ".minSec", "warning", sprintf(['The latency window [%g %g] s misses the ' ...
                'figure''s window [%g %g] s: no first spike or onset can be found.'], hL.minSec, hL.maxSec, hW.pre, hW.post));
        end
        bw = hL.baselineWindow;
        if ~(numel(bw) == 2 && all(isfinite(bw)) && bw(1) < bw(2))
            add("Figures", hL0 + ".baselineWindow", "error", "The latency baseline window is [lo hi] s with lo < hi.");
        end
        if ~(hL.alpha > 0 && hL.alpha < 1)
            add("Figures", hL0 + ".alpha", "error", "The latency alpha is above 0 and below 1.");
        end
        if ~(isfinite(hL.surprise) && hL.surprise > 0)
            add("Figures", hL0 + ".surprise", "error", "The least Poisson surprise is above 0 (-log10 of a probability).");
        end
        if ~(isscalar(hL.minSpikes) && isfinite(hL.minSpikes) && hL.minSpikes >= 2 && hL.minSpikes == round(hL.minSpikes))
            add("Figures", hL0 + ".minSpikes", "error", "A burst starts with a whole number of spikes, at least 2.");
        end
        if ~(isfinite(hL.cusumBinSec) && hL.cusumBinSec > 0)
            add("Figures", hL0 + ".cusumBinSec", "error", "The onset's bins (cusumBinSec) are above 0 s.");
        end
        if ~(isfinite(hL.cusumThreshold) && hL.cusumThreshold > 0)
            add("Figures", hL0 + ".cusumThreshold", "error", "The onset's CUSUM threshold is above 0 baseline SDs.");
        end
        if ~(isfinite(hL.cusumDrift) && hL.cusumDrift >= 0)
            add("Figures", hL0 + ".cusumDrift", "error", "The onset's CUSUM allowance (cusumDrift) is 0 or more baseline SDs.");
        end
        if ~(isfinite(hL.cusumSustainSec) && hL.cusumSustainSec >= 0)
            add("Figures", hL0 + ".cusumSustainSec", "error", "The onset's sustain (cusumSustainSec) is 0 s or more.");
        end
        if ~ismember(hL.cusumDirection, ["up" "down" "both"])
            add("Figures", hL0 + ".cusumDirection", "error", "The onset's direction (cusumDirection) is up, down or both.");
        end
        if ~ismember(hL.cusumGate, ["evoked" "none"])
            add("Figures", hL0 + ".cusumGate", "error", "The onset's gate (cusumGate) is evoked or none.");
        end
        if ~(isfinite(hL.cusumGateAlpha) && hL.cusumGateAlpha > 0 && hL.cusumGateAlpha < 1)
            add("Figures", hL0 + ".cusumGateAlpha", "error", "The onset gate's p value (cusumGateAlpha) is above 0 and below 1.");
        end
        onset = false;
        for hP = reshape(hFg.panels, 1, [])
            onset = onset || (isfield(hP.options, 'onsetLine') && hP.options.onsetLine ~= "off");
        end
        if ~(ismember(hL.method, ["surprise" "poisson"]) || onset) || ~isstruct(hW); return; end
        if hL.baseline == "pre" && isfinite(hW.pre) && hW.pre >= 0
            add("Figures", hL0 + ".baseline", "warning", sprintf(['The baseline rate is taken before the event, but the ' ...
                'figure''s window starts at %g s: there is no baseline, and no latency or onset is found (give the window ' ...
                'time before the event, or a baseline window).'], hW.pre));
        elseif hL.baseline == "window" && numel(bw) == 2 && isfinite(hW.pre) && isfinite(hW.post) && (bw(2) <= hW.pre || bw(1) >= hW.post)
            add("Figures", hL0 + ".baselineWindow", "warning", sprintf(['The baseline window [%g %g] s misses the ' ...
                'figure''s window [%g %g] s: the raster rows hold no baseline.'], bw(1), bw(2), hW.pre, hW.post));
        end
    end

    function checkOnsetLine(hOp, hO0)
        %checkOnsetLine  A raster's or PSTH's onsetLine: off, unit or groups.
        if isfield(hOp, 'onsetLine') && ~ismember(hOp.onsetLine, EphysAnalysisConfig.OnsetLines)
            add("Figures", hO0 + ".onsetLine", "error", "onsetLine is off, unit (one line) or groups (each group's).");
        end
    end

    function checkLatency(hL, hL0, hBox)
        %checkLatency  A raster's first-spike marks (firstSpike) or, HBOX, a PSTH's latency box plot (latencyBox): their look.
        %   Checked only while enabled: the color ("groups" or a color:
        %   else a warning, and the groups' colors are used), the marker and
        %   its size, and the box's line, lane height, opacity and outliers.
        %   How the latencies are found is the figure's (checkFigureLatency).
        if ~hL.enabled; return; end
        markers = PlotAesthetics.catalog().Marker.Choices;
        if hL.color ~= "groups" && ~isColor(hL.color)
            add("Figures", hL0 + ".color", "warning", "Not groups or a color: """ + hL.color + """; the groups' colors are used.");
        end
        if ~hBox
            if ~ismember(hL.marker, markers(2:end))
                add("Figures", hL0 + ".marker", "error", "The first-spike marker is one of " + strjoin(markers(2:end), ", ") + ".");
            end
            if ~(isfinite(hL.size) && hL.size > 0)
                add("Figures", hL0 + ".size", "error", "The first-spike marker's size is above 0 points.");
            end
            return
        end
        if ~ismember(hL.lineStyle, EphysAnalysisConfig.OverlayLineStyles)
            add("Figures", hL0 + ".lineStyle", "error", "The box's line style is one of " + ...
                strjoin(EphysAnalysisConfig.OverlayLineStyles, ", ") + ".");
        end
        if ~(isfinite(hL.lineWidth) && hL.lineWidth > 0)
            add("Figures", hL0 + ".lineWidth", "error", "The box's line width is above 0 points.");
        end
        if ~(hL.boxHeight >= 0.02 && hL.boxHeight <= 0.5)
            add("Figures", hL0 + ".boxHeight", "error", "boxHeight, each box's lane as a share of the PSTH's height, is from 0.02 to 0.5.");
        end
        if ~(hL.fillAlpha >= 0 && hL.fillAlpha <= 1)
            add("Figures", hL0 + ".fillAlpha", "error", "The box's fillAlpha is an opacity from 0 to 1.");
        end
        if ~ismember(hL.outlierMarker, markers)
            add("Figures", hL0 + ".outlierMarker", "error", "The outliers' marker is one of " + strjoin(markers, ", ") + ".");
        end
        if ~(isfinite(hL.outlierSize) && hL.outlierSize > 0)
            add("Figures", hL0 + ".outlierSize", "error", "The outliers' size is above 0 points.");
        end
    end

    function checkPanelError(hType, hO, hO0)
        %checkPanelError  A panel's own error: its errorType (a continuous or trial panel's is checked with its other options), errorResamples and band.
        if isfield(hO, 'errorType') && ~ismember(hType, ["continuous" EphysAnalysisConfig.TrialPanelTypes])
            if ~ismember(hO.errorType, EphysAnalysisConfig.PanelErrorTypes)
                add("Figures", hO0 + ".errorType", "error", "The errorType is one of " + strjoin(EphysAnalysisConfig.PanelErrorTypes, ", ") + ...
                    " (off: none; sem: +/- SEM; std: +/- SD; ci95: bootstrap 95% CI).");
            elseif hO.errorType == "ci95" && ~(license('test', 'Statistics_Toolbox') && exist('bootci', 'file'))
                add("Figures", hO0 + ".errorType", "error", "The bootstrap 95% CI needs the Statistics and Machine Learning Toolbox (bootci).");
            end
        end
        if isfield(hO, 'errorResamples')
            hR = hO.errorResamples;
            if ~(isscalar(hR) && isfinite(hR) && hR >= 1 && hR == round(hR))
                add("Figures", hO0 + ".errorResamples", "error", "errorResamples is a whole number of bootstrap resamples, at least 1.");
            end
        end
        if ~isfield(hO, 'band'); return; end
        hB = hO.band;
        hB0 = hO0 + ".band";
        if ~(isnan(hB.faceAlpha) || (hB.faceAlpha >= 0 && hB.faceAlpha <= 1))
            add("Figures", hB0 + ".faceAlpha", "error", "The band's faceAlpha is an opacity from 0 to 1 (NaN = opaque, the trace's color paled).");
        end
        if hB.faceColor ~= "" && ~isColor(hB.faceColor)
            add("Figures", hB0 + ".faceColor", "warning", "No color """ + hB.faceColor + """; the bands take their trace's color.");
        end
        if ~ismember(lower(strtrim(hB.edgeColor)), ["none" "auto"]) && ~isColor(hB.edgeColor)
            add("Figures", hB0 + ".edgeColor", "warning", "No color """ + hB.edgeColor + """; the bands have no edge.");
        end
        if ~ismember(hB.edgeStyle, EphysAnalysisConfig.OverlayLineStyles)
            add("Figures", hB0 + ".edgeStyle", "error", "The band's edgeStyle is one of " + strjoin(EphysAnalysisConfig.OverlayLineStyles, "  ") + ".");
        end
        if ~(isfinite(hB.edgeWidth) && hB.edgeWidth > 0)
            add("Figures", hB0 + ".edgeWidth", "error", "The band's edgeWidth must be positive (points).");
        end
    end

    function checkStyle(st, sec, id)
        %checkStyle  A figure's Style.
        if ~(st.MaxTiles >= 1); add(sec, id + ".style.MaxTiles", "error", "MaxTiles must be >= 1."); end
        if ~ismember(st.TileSpacing, ["loose" "compact" "tight" "none"])
            add(sec, id + ".style.TileSpacing", "error", "TileSpacing is loose, compact, tight or none.");
        end
        if ~ismember(st.LegendLocation, ["auto" "inside" "none"])
            add(sec, id + ".style.LegendLocation", "error", "LegendLocation is auto (the legend panel, else free space, " + ...
                "else inside the first panel), inside or none.");
        end
        if ~ismember(st.LegendOrientation, ["auto" "vertical" "horizontal"])
            add(sec, id + ".style.LegendOrientation", "error", "LegendOrientation is auto, vertical or horizontal.");
        end
        if ~(st.FontSize > 0);  add(sec, id + ".style.FontSize", "error", "FontSize must be positive."); end
        if ~(st.LineWidth > 0); add(sec, id + ".style.LineWidth", "error", "LineWidth must be positive."); end
        if ~(st.SiteSize > 0);  add(sec, id + ".style.SiteSize", "error", "SiteSize must be positive."); end
        for cm = ["Colormap" "HeatColormap"]
            if ~(cm == "Colormap" && (st.(cm) == "lines" || isColor(st.(cm)))) && ~(cm == "HeatColormap" && st.(cm) == "") ...
                    && ~ismember(exist(char(st.(cm))), [2 5]) %#ok<EXIST>
                what = "colormap function";
                if cm == "Colormap"; what = "colormap function or color"; end
                add(sec, id + ".style." + cm, "warning", "No " + what + " """ + st.(cm) + """; the default is used.");
            end
        end
    end

    function checkLabelText(hTxt, hKey, hTex)
        %checkLabelText  A figure's text (title, axis label, layer name, note) that names a label variable not on figureLabelVariables' list: a warning, with the name it likely meant.
        %   A name in braces that is none of them is drawn as typed. With
        %   HTEX (a TeX note: braces group, as in x^{2} or \bf{word}) only
        %   a name that differs from a variable's in case is reported.
        hTxt = string(hTxt);
        if ~contains(hTxt, "{"); return; end
        hFound = regexp(hTxt, '\{(\w+)\}', 'tokens');
        if isempty(hFound); return; end
        hNames = figureLabelVariables().Name;
        for hName = reshape(unique(string(cellfun(@(c) c{1}, hFound, 'UniformOutput', false)), 'stable'), 1, [])
            if ismember(hName, hNames); continue; end
            hMeant = hNames(lower(hNames) == lower(hName));
            if hTex && isempty(hMeant); continue; end
            hMsg = "{" + hName + "} is no label variable, so it is drawn as typed";
            if ~isempty(hMeant)
                hMsg = hMsg + ": did you mean {" + hMeant(1) + "}? (Names are case-sensitive.)";
            else
                hMsg = hMsg + ". Help > Label variables lists them.";
            end
            add("Figures", hKey, "warning", hMsg);
        end
    end

    function checkNote(hNt, hSec, hN0, hWhere)
        %checkNote  A figure panel's text note (drawNote), unless it has no text; HWHERE: what it sits on ("panel").
        if strtrim(hNt.text) == ""; return; end
        if ~ismember(hNt.placement, EphysAnalysisConfig.NotePlacements)
            add(hSec, hN0 + ".placement", "error", "The note placement is one of " + strjoin(EphysAnalysisConfig.NotePlacements, ", ") + ".");
        elseif hNt.placement == "custom" && ~(isfinite(hNt.x) && isfinite(hNt.y))
            add(hSec, hN0 + ".x", "error", "A custom note needs a finite x and y (0-1 across and up the " + hWhere + ").");
        end
        if ~ismember(hNt.align, ["left" "center" "right"])
            add(hSec, hN0 + ".align", "error", "The note alignment is left, center or right.");
        end
        if ~ismember(hNt.valign, ["top" "middle" "bottom"])
            add(hSec, hN0 + ".valign", "error", "The note vertical alignment is top, middle or bottom.");
        end
        if ~ismember(hNt.interpreter, ["none" "tex"])
            add(hSec, hN0 + ".interpreter", "error", "The note interpreter is none or tex.");
        end
        if ~isfinite(hNt.rotation)
            add(hSec, hN0 + ".rotation", "error", "The note rotation is a number of degrees.");
        end
        if ~(isnan(hNt.fontSize) || (isfinite(hNt.fontSize) && hNt.fontSize > 0))
            add(hSec, hN0 + ".fontSize", "error", "The note font size is positive (NaN: the figure's).");
        end
        for hCf = ["color" "background"]
            if hNt.(hCf) ~= "" && ~isColor(hNt.(hCf))
                add(hSec, hN0 + "." + hCf, "warning", "No color """ + hNt.(hCf) + """; the note's " + hCf + " is left to the design.");
            end
        end
    end

    function hNames = checkOverlays(hOvs, hSec, hF0, hNames)
        %checkOverlays  A figure panel's overlays (drawOverlays), drawn on its own axes (panel "all", normalizePanel).
        %   HNAMES: the names met so far (a figure's other panels': an
        %   aesthetics rule on a name reaches every panel's overlay of that
        %   name), returned with these added.
        for hQ = 1:numel(hOvs)
            hOv = hOvs(hQ);
            hO0 = hF0 + ".overlays(" + hQ + ")";
            if ~ismember(hOv.shape, ["line" "region"])
                add(hSec, hO0 + ".shape", "error", "An overlay is a line or a region.");
            elseif hOv.shape == "line" && ~isfinite(hOv.value)
                add(hSec, hO0 + ".value", "error", "An overlay line needs a finite position (data units).");
            elseif hOv.shape == "region"
                if ~(isfinite(hOv.from) && isfinite(hOv.to))
                    add(hSec, hO0 + ".from", "error", "An overlay region needs finite edges, from and to (data units).");
                elseif hOv.from == hOv.to
                    add(hSec, hO0 + ".to", "error", "An overlay region's edges must differ (from and to are both " + hOv.from + ").");
                end
            end
            if ~ismember(hOv.axis, ["x" "y"])
                add(hSec, hO0 + ".axis", "error", "An overlay's axis is x (vertical line, patch between x values) or y.");
            end
            if ~ismember(hOv.layer, EphysAnalysisConfig.OverlayLayers)
                add(hSec, hO0 + ".layer", "error", "An overlay's layer is over or under the data.");
            end
            if ~ismember(hOv.lineStyle, EphysAnalysisConfig.OverlayLineStyles)
                add(hSec, hO0 + ".lineStyle", "error", "An overlay's line style is one of " + strjoin(EphysAnalysisConfig.OverlayLineStyles, "  ") + ".");
            end
            if ~(isfinite(hOv.lineWidth) && hOv.lineWidth > 0)
                add(hSec, hO0 + ".lineWidth", "error", "An overlay's line width must be positive (points).");
            end
            for hAf = ["alpha" "faceAlpha"]
                if ~(hOv.(hAf) >= 0 && hOv.(hAf) <= 1)
                    add(hSec, hO0 + "." + hAf, "error", "An overlay's " + hAf + " is an opacity from 0 to 1.");
                end
            end
            for hCf = ["color" "faceColor" "edgeColor"]
                if ~(hCf == "edgeColor" && lower(strtrim(hOv.(hCf))) == "none") && ~isColor(hOv.(hCf))
                    add(hSec, hO0 + "." + hCf, "warning", "No color """ + hOv.(hCf) + """; the overlay keeps its default " + hCf + ".");
                end
            end
            if strtrim(hOv.name) ~= "" && ismember(strtrim(hOv.name), hNames)
                add(hSec, hO0 + ".name", "warning", "Another overlay of this figure is also named """ + strtrim(hOv.name) + ...
                    """; a change in the aesthetics editor reaches both.");
            end
            hNames(end+1) = strtrim(hOv.name); %#ok<AGROW>
        end
    end

    function checkAuroc(a, binSec, sec, field, isPlot)
        %checkAuroc  A panel's auroc settings (ISPLOT) or a response test's.
        if ~ismember(a.method, ["psth" "epochs"]); add(sec, field + ".method", "error", "The auROC method is psth or epochs."); end
        if ~ismember(a.windows, ["tiled" "sliding"]); add(sec, field + ".windows", "error", "The auROC windows are tiled or sliding."); end
        whole = @(x) binSec > 0 && x / binSec >= 1 - 1e-6 && abs(x / binSec - round(x / binSec)) < 1e-6;
        if ~whole(a.windowSec)
            add(sec, field + ".windowSec", "error", sprintf("The auROC window (%g s) must be a whole number of %g s bins.", a.windowSec, binSec));
        end
        if a.windows == "sliding" && ~whole(a.stepSec)
            add(sec, field + ".stepSec", "error", sprintf("The sliding step (%g s) must be a whole number of %g s bins.", a.stepSec, binSec));
        end
        if ~ismember(a.cutoff, ["ci" "fixed" "shuffle" "test" "none"])
            add(sec, field + ".cutoff", "error", "The auROC cutoff is ci, fixed, shuffle, test or none.");
        elseif ~isPlot && a.cutoff == "none"
            add(sec, field + ".cutoff", "error", "The auROC response test needs a cutoff (ci, fixed, shuffle or test) to call units modulated.");
        end
        if a.cutoff == "fixed" && ~(a.threshold >= 0 && a.threshold < 0.5)
            add(sec, field + ".threshold", "error", "The threshold is |auROC - 0.5|, from 0 up to (not including) 0.5.");
        end
        if a.cutoff == "shuffle" && ~(a.nResamples >= 1 && a.nResamples == round(a.nResamples))
            add(sec, field + ".nResamples", "error", "nResamples must be a whole number >= 1.");
        end
        if a.cutoff == "test"
            if ~ismember(a.test, ["bootstrap" "ranksum" "shuffle"])
                add(sec, field + ".test", "error", "The auROC test is bootstrap, ranksum or shuffle.");
            elseif a.test ~= "ranksum" && ~(a.nResamples >= 1 && a.nResamples == round(a.nResamples))
                add(sec, field + ".nResamples", "error", "nResamples must be a whole number >= 1.");
            end
        end
        if isPlot
            m = a.modulationWindow;
            if ~(numel(m) == 2 && all(isfinite(m)) && m(2) > m(1))
                add(sec, field + ".modulationWindow", "error", "The modulation window must be [m0 m1] with m0 < m1 (s from the event).");
            end
            if a.cutoff == "test"
                if ~ismember(a.correction, ["bh" "holm" "bonferroni" "none"])
                    add(sec, field + ".correction", "error", "The correction is bh, holm, bonferroni or none.");
                end
                if ~(a.alpha > 0 && a.alpha <= 1); add(sec, field + ".alpha", "error", "alpha must be in (0, 1]."); end
            end
            if a.cutoff == "shuffle" && ~(a.alpha > 0 && a.alpha <= 1)
                add(sec, field + ".alpha", "error", "alpha must be in (0, 1].");
            end
            if a.modulatedOnly && a.cutoff == "none"
                add(sec, field + ".modulatedOnly", "error", "Modulated units only needs a cutoff (ci, fixed, shuffle or test) to call units modulated.");
            end
        end
        if ~(license('test', 'Statistics_Toolbox') && exist('tiedrank', 'file'))
            add(sec, field, "error", "auROC needs the Statistics and Machine Learning Toolbox (tiedrank, tinv, ranksum).");
        end
    end

    function checkResponse(rs, r0)
        %checkResponse  An enabled unit-response test (UnitSelection.response) at field R0 of the Figures section.
        if ~rs.enabled; return; end
        if ~ismember(rs.test, ["evoked" "tuning" "either" "both" "auroc"])
            add("Figures", r0 + ".test", "error", "The response test is evoked, tuning, either, both or auroc.");
        elseif rs.test == "auroc"
            checkAuroc(rs.auroc, rs.auroc.binSec, "Figures", r0 + ".auroc", false);
        elseif rs.test ~= "evoked" && rs.param == ""
            add("Figures", r0 + ".param", "error", "The tuning test needs the trial parameter (param).");
        end
        for hWf = ["baseline" "window"]
            if ~(numel(rs.(hWf)) == 2 && all(isfinite(rs.(hWf))) && rs.(hWf)(2) > rs.(hWf)(1))
                add("Figures", r0 + "." + hWf, "error", "The response test's " + hWf + " must be [from to] with from < to (s from the event).");
            end
        end
        if ~ismember(rs.direction, ["any" "excited" "suppressed"])
            add("Figures", r0 + ".direction", "error", "The response direction is any, excited or suppressed.");
        end
        if ~ismember(rs.correction, ["bh" "holm" "bonferroni" "none"])
            add("Figures", r0 + ".correction", "error", "The correction is bh, holm, bonferroni or none.");
        end
        if ~(rs.alpha > 0 && rs.alpha <= 1)
            add("Figures", r0 + ".alpha", "error", "alpha must be in (0, 1].");
        end
        if ~(license('test', 'Statistics_Toolbox') && exist('signrank', 'file'))
            add("Figures", r0 + ".enabled", "error", "The response test needs the Statistics and Machine Learning Toolbox (signrank, kruskalwallis).");
        end
    end

    function checkSelection(s, sec, field)
        try
            trialSelection(s);
        catch ME
            if ME.identifier == "trialSelection:BadFilter"
                add(sec, field + ".filter", "warning", string(ME.message));
            else
                add(sec, field, "error", string(ME.message));
            end
        end
    end

    function checkMapping(sp, f0, sec)
        %checkMapping  A unit-mapping CSV: readable, a cell column, a column per listed dataset key.
        %   Read with readUnitMapping, the reader the run uses
        %   (figureSessionObservations). SEC: the section the issues go to
        %   (default "Figures").
        if nargin < 3; sec = "Figures"; end
        try
            M = readUnitMapping(sp.mappingFile);
        catch ME
            switch ME.identifier
                case 'readUnitMapping:NoFile'
                    add(sec, f0 + ".mappingFile", "error", "The mapping file does not exist: " + sp.mappingFile);
                case 'readUnitMapping:NoCell'
                    add(sec, f0 + ".mappingFile", "error", "The mapping file has no ""cell"" column: " + sp.mappingFile);
                otherwise
                    add(sec, f0 + ".mappingFile", "error", "The mapping file cannot be read (" + string(ME.message) + "): " + sp.mappingFile);
            end
            return
        end
        cols = string(M.Properties.VariableNames);
        if sp.datasets == "list"
            missingKeys = setdiff(sp.datasetKeys, cols, 'stable');
            if ~isempty(missingKeys)
                add(sec, f0 + ".mappingFile", "warning", "The mapping file has no column for " + ...
                    strjoin(missingKeys, ", ") + ": those sessions cannot be matched.");
            end
        end
    end

    function checkFigureSessions(fg, k, kind, fs, f0)
        %checkFigureSessions  A figure's sessions block, and what a session figure (sessions.enabled) cannot hold.
        %   KIND: the resolved observe kind ("" when unknown); FS: the figure's
        %   selection, resolved. The field is "<figure>.sessions.<field>".
        sx = fg.sessions;
        sx0 = f0 + ".sessions";
        sxEnums = struct('datasets', ["ticked" "list"], 'facet', EphysAnalysisConfig.SessionFacets, ...
            'series', EphysAnalysisConfig.SessionSeries, 'colorOrder', EphysAnalysisConfig.SessionColorOrders, ...
            'error', EphysAnalysisConfig.SessionErrors, 'match', EphysAnalysisConfig.FigureSessionMatches, ...
            'trialGroups', EphysAnalysisConfig.SessionTrialGroups);
        for sxF = string(fieldnames(sxEnums)).'
            if ~ismember(sx.(sxF), sxEnums.(sxF))
                add("Figures", sx0 + "." + sxF, "error", "A session figure's " + sxF + " is one of " + strjoin(sxEnums.(sxF), ", ") + ...
                    ", not """ + sx.(sxF) + """.");
            end
        end
        if ~(isfinite(sx.minSessions) && sx.minSessions >= 1 && sx.minSessions == round(sx.minSessions))
            add("Figures", sx0 + ".minSessions", "error", "minSessions is a whole number of sessions, at least 1.");
        end
        if ~sx.enabled; return; end
        if sx.datasets == "list" && isempty(sx.datasetKeys)
            add("Figures", sx0 + ".datasetKeys", "warning", "datasets is ""list"" but no dataset keys are listed; the session figure draws nothing.");
        end
        if sx.showMembers && sx.series == "session"
            add("Figures", sx0 + ".showMembers", "warning", "Each session is its own series already: showMembers draws the sessions " + ...
                "faintly under a subject's or every session's summary (series subject or all).");
        end
        if sx.match == "mapping"
            if kind ~= "" && kind ~= "unit"
                add("Figures", sx0 + ".match", "error", "match ""mapping"" names units: it needs a unit observation, not a " + kind + ".");
            end
            if strtrim(sx.mappingFile) == ""
                add("Figures", sx0 + ".mappingFile", "error", "match ""mapping"" needs a mapping file (CSV: a column cell, then one per dataset key).");
            elseif ~isfile(sx.mappingFile)
                if opts.CheckPaths
                    add("Figures", sx0 + ".mappingFile", "error", "The mapping file does not exist: " + sx.mappingFile);
                end
            else
                checkMapping(sx, sx0, "Figures");
            end
        end
        if sx.trialGroups == "pool" && isstruct(fs) && isfield(fs, 'groupBy') && ~isempty(fs.groupBy)
            add("Figures", sx0 + ".trialGroups", "warning", "The figure's trial groups (" + strjoin(fs.groupBy, ", ") + ") are pooled: " + ...
                "the sessions are the series (trialGroups each or combine keeps them).");
        end
        try
            sxSpec = obj.figureFor(k);
        catch
            return   % its own errors are reported above
        end
        for sxK = 1:numel(sxSpec.panels)
            sxP = sxSpec.panels(sxK);
            sxP0 = f0 + "." + sxP.id;
            if ismember(sxP.type, EphysAnalysisConfig.FigureSessionUnmerged)
                sxL = FT.Label(FT.Type == sxP.type);
                if sxL ~= upper(sxL); sxL = lower(sxL); end
                add("Figures", sxP0 + ".type", "error", "A session figure cannot hold " + sxL + " panels: combineSessions does not " + ...
                    "merge them across sessions.");
                continue
            end
            sxO = sxP.options;
            if isfield(sxO, 'baseline') && isstruct(sxO.baseline) && isfield(sxO.baseline, 'Mode') && sxO.baseline.Mode == "auroc"
                add("Figures", sxP0 + ".baseline.Mode", "error", "A session figure cannot hold an auROC baseline: auROC curves are not " + ...
                    "merged across sessions.");
            end
            if sx.trialGroups == "combine" && sxP.type == "psth" && isfield(sxO, 'histStyle') && sxO.histStyle == "bar"
                add("Figures", sxP0 + ".histStyle", "warning", "trialGroups ""combine"" tells the trial groups apart by line style: " + ...
                    "the PSTH's bars are drawn as lines.");
            end
            if sxP.type == "heatmap" && isfield(sxO, 'rows') && sxO.rows == "trials"
                add("Figures", sxP0 + ".rows", "warning", "A heat map of trials is not merged across sessions: the session figure skips it.");
            end
            if sx.trialGroups == "pool" && ismember(sxP.type, EphysAnalysisConfig.TrialPanelTypes)
                for sxD = ["categories" "series"]
                    if isfield(sxO, sxD) && sxO.(sxD) == "groups"
                        add("Figures", sxP0 + ".options." + sxD, "warning", "trialGroups ""pool"" merges the figure's trial " + ...
                            "groups across sessions: grouped by groups, the " + sxD + " are the sessions' series (trialGroups " + ...
                            "each or combine keeps the trial groups; or group by session or a parameter).");
                    end
                end
            end
        end
    end

    function checkFigureProbe(fg, kind, f0)
        %checkFigureProbe  A figure's probe block, and what a probe figure (probe.enabled) cannot be or hold.
        %   KIND: the resolved observe kind ("" when unknown). The field is
        %   "<figure>.probe.<field>"; the warnings name the field they are of.
        px = fg.probe;
        px0 = f0 + ".probe";
        pxEnums = struct('layout', EphysAnalysisConfig.ProbeLayouts, 'overlap', EphysAnalysisConfig.ProbeOverlaps, ...
            'labels', EphysAnalysisConfig.ProbeTileLabels);
        for pxF = string(fieldnames(pxEnums)).'
            if ~ismember(px.(pxF), pxEnums.(pxF))
                add("Figures", px0 + "." + pxF, "error", "A probe figure's " + pxF + " is one of " + strjoin(pxEnums.(pxF), ", ") + ...
                    ", not """ + px.(pxF) + """.");
            end
        end
        for pxF = ["lanes" "maxTiles" "maxPerSite"]
            if ~isWhole(px.(pxF))
                add("Figures", px0 + "." + pxF, "error", "A probe figure's " + pxF + " is a whole number, at least 1.");
            end
        end
        for pxF = ["tileWidth" "tileHeight"]
            pxV = px.(pxF);
            if ~(isscalar(pxV) && isfinite(pxV) && pxV > 0 && pxV <= 1)
                add("Figures", px0 + "." + pxF, "error", "A probe figure's " + pxF + " is a share of its band or row: above 0, at most 1.");
            end
        end
        if ~(isscalar(px.tileScale) && isfinite(px.tileScale) && px.tileScale > 0)
            add("Figures", px0 + ".tileScale", "error", "A probe figure's tileScale is a finite number above 0.");
        end
        if ~isempty(px.shanks) && ~all(isfinite(px.shanks) & px.shanks == round(px.shanks))
            add("Figures", px0 + ".shanks", "error", "The probe's shanks are kcoords shank numbers: whole numbers ([] = all).");
        end
        if ~isempty(px.channels) && ~all(arrayfun(isWhole, px.channels))
            add("Figures", px0 + ".channels", "error", "The probe's channels are recording channels: whole numbers, at least 1 ([] = all).");
        end
        pxD = px.depthRange;
        if ~isempty(pxD) && ~(numel(pxD) == 2 && all(isfinite(pxD)) && pxD(1) < pxD(2))
            add("Figures", px0 + ".depthRange", "error", "The probe's depthRange is [] (all) or [lo hi] µm of probe y, lo < hi.");
        end
        if ~px.enabled; return; end
        if fg.sessions.enabled
            add("Figures", px0 + ".enabled", "error", "A figure is laid out on the probe or drawn across sessions, not both: " + ...
                "untick probe.enabled or sessions.enabled.");
        end
        if kind == "dataset"
            add("Figures", px0 + ".enabled", "error", "A probe figure lays out units or channels at their sites: observe units, " + ...
                "detections or a signal's channels, not the dataset.");
        end
        if fg.observe.perGroup
            add("Figures", f0 + ".observe.perGroup", "warning", "A probe figure draws each observation once, as its tile: " + ...
                "perGroup is ignored.");
        end
        for pxK = 1:numel(fg.panels)
            pxP = fg.panels(pxK);
            pxP0 = f0 + "." + pxP.id;
            if pxP.type == "probemap"
                add("Figures", pxP0 + ".type", "warning", "A probe map in a probe figure draws the probe again inside each " + ...
                    "tile of the probe layout.");
            elseif pxP.type == "waveforms" && isstruct(pxP.options) && isfield(pxP.options, 'layout') && pxP.options.layout == "probe"
                add("Figures", pxP0 + ".options.layout", "warning", "A waveforms panel in the probe layout draws the probe again " + ...
                    "inside each tile of the probe figure.");
            end
        end
    end

    function checkPattern(pattern, kind, sec, field)
        if kind == "file"
            t = struct('Name', "n", 'Plot', "p", 'Kind', "k", 'Group', "g", 'Unit', "u", 'Index', 1);
        else
            t = struct('OutputFolder', "o", 'OutputRoot', "r", 'Root', "r", 'Name', "n");
        end
        try
            figureFileName(pattern, t, Kind=kind);
        catch ME
            add(sec, field, "error", string(ME.message));
        end
        if kind == "file" && strtrim(pattern) == ""
            add(sec, field, "error", "The file-name pattern is empty.");
        end
    end
end


function s = categoryWords(cats)
%categoryWords  "point-process or continuous": the source categories CATS in words.
words = struct('point', "point-process", 'continuous', "continuous", 'trial', "trial-value", 'unit', "unit-summary");
s = strings(1, numel(cats));
for k = 1:numel(cats)
    s(k) = words.(cats(k));
end
s = strjoin(s, " or ");
end


function tf = isColor(name)
%isColor  True for a color name or hex code (groupPalette gives every group that color).
try
    namedColor(name);
    tf = true;
catch
    tf = false;
end
end
