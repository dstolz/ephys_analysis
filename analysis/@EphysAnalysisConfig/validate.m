function issues = validate(obj, opts)
%validate  Check an analysis config for problems before it runs.
%   ISSUES = cfg.validate() returns a table (Section, Field, Severity,
%   Message); Severity "error" means the run cannot start, "warning" that
%   part of it may not do what is meant. An empty table means clean.
%
%   Checked
%     Source    Mode; Root exists (project) or every folder does (folders);
%               NamePattern parses; a "list" selection names datasets
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
%               selection groups by nothing; grid: whole rows and cols >= 1,
%               rowHeights / colWidths [] or one positive size each,
%               spacing, gapUnits, rowGap / colGap >= 0, rowGaps / colGaps
%               [] or one gap >= 0 between every two rows / columns;
%               panels: a known type, whole row / col / spans inside the
%               grid, a size in (0, 1] each way, align and valign, no
%               overlaps, ids of their own (warnings:
%               no panels, cells no panel covers); a panel's own ref /
%               window / selection only on aligned types (its selection
%               checked as the figure's), a "between" window only on a
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
%               the PSTH's stackSpacing, display (trace / heatmap),
%               colormap (a warning for no colormap function) and color
%               limits, the raster sort, a raster's first-spike marks
%               and a PSTH's latency box plot while enabled (the latency
%               window: minSec <= maxSec, a warning when it misses the
%               panel's window; marker, size, color -- a warning for not
%               groups or a color --, the box's line style and width,
%               boxHeight 0.02-0.5, fillAlpha, the outliers), continuous
%               display / statistic / transform / errorType and its
%               toolbox, stackSpacing, trials (off / faint / only) and
%               maxTrials (whole, >= 1), heatmap rows (items / trials:
%               one unit's epochs -- a spike or train layer, following
%               the observation or fixed to one unit, no auROC baseline,
%               the raster sort --), order ("modulation" only
%               with the auROC baseline), group, the waveforms layout (a
%               warning for a probe layout whose first layer follows the
%               observation), probemap value, corrmap metric /
%               correlation, the rate display, the tuning param /
%               seriesParam (names, not the same one), the waveform
%               settings, y / color limits; the spectral panels'
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
%               that is not one); each panel's text note
%               ("<figure>.<panel>.note.<field>": placement, alignment,
%               rotation, font size and interpreter; a color that is not
%               one is a warning) and overlays
%               ("<figure>.<panel>.overlays(<k>).<field>": shape, axis,
%               finite position (line) or edges (region, which must
%               differ), layer, line style and width, opacities (0-1),
%               colors (one that is not a color is a warning); two
%               overlays of one name anywhere in the figure warn); the
%               style (the error: ErrorType sem / std / ci95, ci95 with
%               the Statistics and Machine Learning Toolbox where a PSTH,
%               rate or tuning panel draws it, whole ErrorResamples >= 1,
%               the bands' opacity (0-1 or NaN), edge style and width; a
%               face or edge color that is not one is a warning); sessions
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
%               lines); a heat map of trials (not merged: skipped)
%     Export   formats are png / eps / svg / pdf; Dpi, FigureSizeCm; the
%               folder and file-name patterns use known tokens; a warning
%               when the files of two enabled figures, or of two datasets,
%               would get the same names (no {Plot}: every figure's {Kind}
%               is "figure"; no {Name} / {OutputFolder});
%               SessionsFolder and Data.Folder (folder patterns; a warning
%               for {OutputFolder}), Data.FilenamePattern (a file pattern)
%               and Data.MatVersion (-v7.3 or -v7)
%     Report    Format html / pdf / both; EmbedFormat png / svg; Dpi;
%               FileName; the folder pattern
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

    % the figure's alignment
    if isstruct(fg.ref); checkRef(fg.ref, "Figures", f0 + ".ref"); end
    if isstruct(fg.window); checkWindow(fg.window, "Figures", f0 + ".window"); end
    if isstruct(fg.selection); checkSelection(fg.selection, "Figures", f0 + ".selection"); end
    fw = fg.window;
    if isequal(fw, "default"); fw = D.Window; end

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
    if ob.perGroup && ~fg.sessions.enabled && (~isstruct(fs) || ~isfield(fs, 'groupBy') || isempty(fs.groupBy))   % a session figure ignores perGroup
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

    % the grid
    G = fg.grid;
    gridOk = true;
    for gf = ["rows" "cols"]
        if ~isWhole(G.(gf))
            add("Figures", f0 + ".grid." + gf, "error", "The grid's " + gf + " is a whole number, at least 1.");
            gridOk = false;
        end
    end
    for gf = ["rowHeights" "colWidths"]
        nWant = G.rows;
        sizeWhat = "height per row";
        if gf == "colWidths"; nWant = G.cols; sizeWhat = "width per column"; end
        v = G.(gf);
        if ~isempty(v) && ~(numel(v) == nWant && all(isfinite(v) & v > 0))
            add("Figures", f0 + ".grid." + gf, "error", gf + " is [] (all equal) or one positive relative " + sizeWhat + ...
                " (" + nWant + ").");
        end
    end
    if ~ismember(G.spacing, EphysAnalysisConfig.GridSpacings)
        add("Figures", f0 + ".grid.spacing", "error", "The grid's spacing is loose, compact, tight, none or custom.");
    end
    if ~ismember(G.gapUnits, EphysAnalysisConfig.GridGapUnits)
        add("Figures", f0 + ".grid.gapUnits", "error", "The grid's gap units are px or %.");
    end
    for gf = ["rowGap" "colGap"]
        if ~(isscalar(G.(gf)) && isfinite(G.(gf)) && G.(gf) >= 0)
            add("Figures", f0 + ".grid." + gf, "error", "The grid's " + gf + " is a number, at least 0.");
        end
    end
    for gf = ["rowGaps" "colGaps"]
        nWant = G.rows - 1;
        between = "rows";
        if gf == "colGaps"; nWant = G.cols - 1; between = "columns"; end
        v = G.(gf);
        if ~isempty(v) && ~(numel(v) == nWant && all(isfinite(v) & v >= 0))
            add("Figures", f0 + ".grid." + gf, "error", gf + " is [] (each the one gap) or a gap of at least 0 between " + ...
                "every two " + between + " (" + max(nWant, 0) + ").");
        end
    end
    if isempty(fg.panels)
        add("Figures", f0 + ".panels", "warning", "The figure has no panels: it draws nothing.");
    end

    % the panels' places
    pids = strings(1, 0);
    if ~isempty(fg.panels); pids = [fg.panels.id]; end
    placed = true;
    for j = 1:numel(fg.panels)
        pj = fg.panels(j);
        p0 = f0 + "." + pj.id;
        if pj.id == "" || nnz(pids == pj.id) > 1
            add("Figures", p0 + ".id", "error", "Each panel of a figure needs an id of its own.");
        end
        for pf = ["row" "col" "rowSpan" "colSpan"]
            if ~isWhole(pj.(pf))
                add("Figures", p0 + "." + pf, "error", "A panel's " + pf + " is a whole number, at least 1.");
                placed = false;
            end
        end
        if gridOk && isWhole(pj.row) && isWhole(pj.rowSpan) && pj.row + pj.rowSpan - 1 > G.rows
            add("Figures", p0 + ".row", "error", sprintf("Panel ""%s"" reaches row %d; the grid has %d.", pj.id, pj.row + pj.rowSpan - 1, G.rows));
        end
        if gridOk && isWhole(pj.col) && isWhole(pj.colSpan) && pj.col + pj.colSpan - 1 > G.cols
            add("Figures", p0 + ".col", "error", sprintf("Panel ""%s"" reaches column %d; the grid has %d.", pj.id, pj.col + pj.colSpan - 1, G.cols));
        end
        if ~(numel(pj.size) == 2 && all(isfinite(pj.size) & pj.size > 0 & pj.size <= 1))
            add("Figures", p0 + ".size", "error", "A panel's size is [width height], each a share of its cell over 0 and at most 1.");
        end
        if ~ismember(pj.align, EphysAnalysisConfig.PanelAligns)
            add("Figures", p0 + ".align", "error", "A panel's align is left, center or right.");
        end
        if ~ismember(pj.valign, EphysAnalysisConfig.PanelVAligns)
            add("Figures", p0 + ".valign", "error", "A panel's valign is top, middle or bottom.");
        end
    end
    if gridOk && placed && ~isempty(fg.panels)
        [cells, over] = EphysAnalysisConfig.figureCells(fg);
        for j = 1:size(over, 1)
            add("Figures", f0 + "." + pids(over(j, 2)) + ".row", "error", "Panels """ + pids(over(j, 1)) + """ and """ + ...
                pids(over(j, 2)) + """ overlap: a cell holds one panel.");
        end
        [ec, er] = find(cells.' == 0);   % row by row
        if ~isempty(er)
            add("Figures", f0 + ".grid", "warning", "No panel covers cell(s) " + strjoin(compose("(%d,%d)", er(:).', ec(:).'), ", ") + ...
                ": they stay blank.");
        end
    end

    % each panel: type, alignment, layers, options
    ovNames = strings(1, 0);   % the overlays' names over every panel of the figure (one aesthetics rule reaches each name)
    for j = 1:numel(fg.panels)
        pj = fg.panels(j);
        p0 = f0 + "." + pj.id;
        % the panel's text note and overlays (an overlay is drawn on the panel's own axes)
        checkNote(pj.note, "Figures", p0 + ".note", "panel");
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

        for af = ["ref" "window" "selection"]
            if ~isstruct(pj.(af)); continue; end
            if ~tr.Aligned
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
        if ~any(on)
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
                checkLatency(op.firstSpike, o0 + ".firstSpike", pw, false);
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
                if ~(isscalar(op.stackSpacing) && isfinite(op.stackSpacing) && op.stackSpacing > 0)
                    add("Figures", o0 + ".stackSpacing", "error", "stackSpacing must be positive (1 = the tallest PSTH reaches the next row).");
                end
                if ~ismember(op.display, ["trace" "heatmap"])
                    add("Figures", o0 + ".display", "error", "A PSTH's display is trace (bars or a line per group) or heatmap (a row per group).");
                end
                if op.colormap ~= "" && ~ismember(exist(char(op.colormap)), [2 5]) %#ok<EXIST>
                    add("Figures", o0 + ".colormap", "warning", "No colormap function """ + op.colormap + """; the heat map takes the design's.");
                end
                checkFigLim(op.cLim, o0 + ".cLim", "color");
                checkFigLim(op.yLim, o0 + ".yLim", "y");
                checkLatency(op.latencyBox, o0 + ".latencyBox", pw, true);
                checkFigWaveform(op.waveform, o0 + ".waveform", false);
            case "continuous"
                checkFigBaseline(op.baseline, EphysAnalysisConfig.baselineModes("continuous"), o0, A);
                checkSignalBaseline(op.baseline, pw, o0);
                if ~ismember(op.display, ["lines" "stacked"])
                    add("Figures", o0 + ".display", "error", "A continuous signal panel's display is lines or stacked.");
                end
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
                if ~(isnan(op.stackSpacing) || (isfinite(op.stackSpacing) && op.stackSpacing > 0))
                    add("Figures", o0 + ".stackSpacing", "error", "stackSpacing is positive (NaN = automatic).");
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
        end
    end

    % the style (its error drawn as a bootstrap CI by a PSTH's bands, a rate panel's bars, a tuning curve's error bars)
    drawsCi95 = ~isempty(fg.panels) && any(ismember([fg.panels.type], ["psth" "rate" "tuning"]));
    checkStyle(fg.style, "Figures", f0, drawsCi95 && fg.style.ErrorType == "ci95");
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
        %checkFigWaveform  A raster / PSTH panel's waveform inset, or (HOWN) a waveforms panel's settings.
        if ~ismember(hW.ampScale, ["unit" "common"])
            add("Figures", hW0 + ".ampScale", "error", "The waveform amplitude scale is unit or common.");
        end
        if ~ismember(hW.mode, ["off" "mean" "subsample" "both"])
            add("Figures", hW0 + ".mode", "error", "The waveform mode is off, mean, subsample or both.");
        elseif hOwn && hW.mode == "off"
            add("Figures", hW0 + ".mode", "error", "A unit waveforms panel shows the mean, a subsample or both: its waveform mode cannot be off.");
        elseif hW.mode ~= "off"
            if ~ismember(hW.location, EphysAnalysisConfig.WaveformLocations)
                add("Figures", hW0 + ".location", "error", "The waveform location is one of " + ...
                    strjoin(EphysAnalysisConfig.WaveformLocations, ", ") + ".");
            end
            if ~(hW.scale > 0 && hW.scale <= 3)
                add("Figures", hW0 + ".scale", "error", "The waveform scale is above 0 and at most 3 (1 = a third of the tile).");
            end
            if ~(hW.maxSpikes >= 1 && hW.maxSpikes == round(hW.maxSpikes))
                add("Figures", hW0 + ".maxSpikes", "error", "maxSpikes is a whole number of spikes, at least 1.");
            end
        end
    end

    function checkLatency(hL, hL0, hW, hBox)
        %checkLatency  A raster's first-spike marks (firstSpike) or, HBOX, a PSTH's latency box plot (latencyBox), against the panel's window HW.
        %   Checked only while enabled: the window (minSec <= maxSec, both
        %   numbers; a window that misses the panel's [pre post] warns, as
        %   no spike can be found there), the color ("groups" or a color:
        %   else a warning, and the groups' colors are used), the marker and
        %   its size, and the box's line, lane height, opacity and outliers.
        if ~hL.enabled; return; end
        markers = PlotAesthetics.catalog().Marker.Choices;
        if isnan(hL.minSec) || isnan(hL.maxSec) || ~(hL.minSec <= hL.maxSec) || hL.minSec == Inf || hL.maxSec == -Inf
            add("Figures", hL0 + ".minSec", "error", sprintf(['The first-spike latency window [%g %g] s needs minSec <= ' ...
                'maxSec (maxSec Inf = the window''s end).'], hL.minSec, hL.maxSec));
        elseif isstruct(hW) && isfinite(hW.pre) && isfinite(hW.post) && (hL.minSec >= hW.post || hL.maxSec < hW.pre)
            add("Figures", hL0 + ".minSec", "warning", sprintf(['The first-spike latency window [%g %g] s misses the ' ...
                'panel''s window [%g %g] s: no first spike can be found.'], hL.minSec, hL.maxSec, hW.pre, hW.post));
        end
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

    function checkStyle(st, sec, id, drawsCi95)
        %checkStyle  A figure's Style; DRAWSCI95: it draws the style's error (figureErrorType) as a bootstrap CI.
        if ~(st.MaxTiles >= 1); add(sec, id + ".style.MaxTiles", "error", "MaxTiles must be >= 1."); end
        if ~ismember(st.TileSpacing, ["loose" "compact" "tight" "none"])
            add(sec, id + ".style.TileSpacing", "error", "TileSpacing is loose, compact, tight or none.");
        end
        if ~ismember(st.LegendLocation, ["auto" "inside" "north" "south" "east" "west"])
            add(sec, id + ".style.LegendLocation", "error", "LegendLocation is auto, inside, north, south, east or west.");
        end
        if ~ismember(st.LegendOrientation, ["auto" "vertical" "horizontal"])
            add(sec, id + ".style.LegendOrientation", "error", "LegendOrientation is auto, vertical or horizontal.");
        end
        if ~ismember(st.ErrorType, EphysAnalysisConfig.ErrorTypes)
            add(sec, id + ".style.ErrorType", "error", "ErrorType is sem (mean +/- SEM), std (mean +/- SD) or ci95 (bootstrap 95% CI).");
        elseif st.ShowSEM && st.ErrorType == "ci95" && drawsCi95 ...
                && ~(license('test', 'Statistics_Toolbox') && exist('bootci', 'file'))
            add(sec, id + ".style.ErrorType", "error", "The bootstrap 95% CI needs the Statistics and Machine Learning Toolbox (bootci).");
        end
        if ~(isfinite(st.ErrorResamples) && st.ErrorResamples >= 1 && st.ErrorResamples == round(st.ErrorResamples))
            add(sec, id + ".style.ErrorResamples", "error", "ErrorResamples is a whole number of bootstrap resamples, at least 1.");
        end
        if ~(isnan(st.ErrorFaceAlpha) || (st.ErrorFaceAlpha >= 0 && st.ErrorFaceAlpha <= 1))
            add(sec, id + ".style.ErrorFaceAlpha", "error", "ErrorFaceAlpha is an opacity from 0 to 1 (NaN = opaque, the trace's color paled).");
        end
        if st.ErrorFaceColor ~= "" && ~isColor(st.ErrorFaceColor)
            add(sec, id + ".style.ErrorFaceColor", "warning", "No color """ + st.ErrorFaceColor + """; the bands take their trace's color.");
        end
        if ~ismember(lower(strtrim(st.ErrorEdgeColor)), ["none" "auto"]) && ~isColor(st.ErrorEdgeColor)
            add(sec, id + ".style.ErrorEdgeColor", "warning", "No color """ + st.ErrorEdgeColor + """; the bands have no edge.");
        end
        if ~ismember(st.ErrorEdgeStyle, EphysAnalysisConfig.OverlayLineStyles)
            add(sec, id + ".style.ErrorEdgeStyle", "error", "ErrorEdgeStyle is one of " + strjoin(EphysAnalysisConfig.OverlayLineStyles, "  ") + ".");
        end
        if ~(isfinite(st.ErrorEdgeWidth) && st.ErrorEdgeWidth > 0)
            add(sec, id + ".style.ErrorEdgeWidth", "error", "ErrorEdgeWidth must be positive (points).");
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
        if ~ismember(a.cutoff, ["ci" "fixed" "test" "none"])
            add(sec, field + ".cutoff", "error", "The auROC cutoff is ci, fixed, test or none.");
        elseif ~isPlot && a.cutoff == "none"
            add(sec, field + ".cutoff", "error", "The auROC response test needs a cutoff (ci, fixed or test) to call units modulated.");
        end
        if a.cutoff == "fixed" && ~(a.threshold >= 0 && a.threshold < 0.5)
            add(sec, field + ".threshold", "error", "The threshold is |auROC - 0.5|, from 0 up to (not including) 0.5.");
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
            if a.modulatedOnly && a.cutoff == "none"
                add(sec, field + ".modulatedOnly", "error", "Modulated units only needs a cutoff (ci, fixed or test) to call units modulated.");
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
    validatecolor(name);
    tf = true;
catch
    tf = false;
end
end
