function syncFigureEditor(obj)
%syncFigureEditor  Show, enable and list the figure editor's rows for the selected figure, panel and layer.
%   What shows (rows a section does not use are hidden, and so is a
%   section left with none: layoutFigureEditor):
%     Observations   under Observe, Starred only (always), the unit filter for sorted units or
%                    detected spikes (classes and quality for sorted units;
%                    the response test's rows, its auROC rows with the
%                    auROC test), the channels for a signal, nothing more
%                    for the dataset
%     Panels         New panel..., Units, Boxes mean, Padding, Snap and the
%                    Arrange hint always; the selected panel's line, its
%                    Position and Size and its buttons (Bring forward
%                    while a panel is drawn after it, Send back while one
%                    is drawn before it; Set corners while the preview
%                    shows the figure: syncArrangeOverlay)
%                    once there is one, else "No panel yet"; the values
%                    in the units picked (showPanelPlace)
%     Panel, Panel alignment, Layers, Options   with a panel selected;
%                    Group shown for the one-group types (heat map, unit
%                    correlation; hidden on a stack); the Y axis row's side grayed out on a
%                    stacked line panel (a y axis on each side); a legend
%                    panel's without Box and the axes' rows (it has no
%                    axes); Panel alignment's rows grayed out (they
%                    show the figure's) while "Same as the figure" is
%                    ticked, and, with a note, for a type not aligned to
%                    events; a trial panel's (no event or window) only
%                    its trial selection, with a note; its trial selection rows grayed out while
%                    "Trial selection as the figure" is ticked; its Apply
%                    to all panels only while the panel has its own,
%                    Re-link all panels while any panel has its own
%                    event, window or selection; Options' Apply to all
%                    panels while the figure has another panel (every
%                    one takes the axis sides)
%     Event reference, Epoch window, Trial selection   unless every panel
%                    of the figure is one not aligned to events (Trial
%                    selection also with a trial panel, which takes it)
%     First-spike latency   while the figure has a raster, PSTH or heat
%                    map panel: a note naming the panels that read it,
%                    Method, Detect, Baseline (its window's fields enabled
%                    with "Window"), the onset's rows; Baseline rate with a
%                    Poisson method, Burst with "surprise", Alpha with
%                    "poisson"
%     Layers         the picked layer's rows by its source and binding:
%                    what a following layer draws; a fixed spike layer's
%                    unit rows, a fixed signal layer's channels, the
%                    aggregate where the type offers a choice
%                    (figureEditorChoices: each or their mean on a raster,
%                    PSTH, continuous, rate or tuning panel; each or their
%                    vector magnitude for a signal on a spectral panel); an
%                    events layer's line, edge, sequence and how it is
%                    drawn (a mark's look for marks, the color and span
%                    line for a span; Draw as grayed out on an event-trace
%                    panel, which offers a train only on a raster, PSTH or
%                    heat map); a trials layer's Measure (and a trial
%                    scatter's X measure), each with Edit... (the Trial
%                    measure window); the color and line style but for marks
%                    and spans
%     Options        the panel type's own (titled "<Type> options"); a heat
%                    map of a signal has no bins or measure; a PSTH's or a
%                    spike heat map's auROC rows with the auroc baseline
%                    (the test row with a per-unit test); a PSTH's display,
%                    its trace rows (PSTH as, fill, y limits: the mode
%                    drop-down, its lo-hi field enabled only for Fixed) or,
%                    drawn as a heat map, its colormap and color limits;
%                    the Stack row on every type that stacks
%                    (stackModes; not a PSTH drawn as a heat map nor a
%                    heat map of trials), its spacing grayed out while
%                    Off;
%                    the Error row of a PSTH (not drawn as a heat map),
%                    continuous, rate or tuning panel (its items by type:
%                    errorTypeItems; grayed out on a rate panel but with
%                    bars, its resamples but with the bootstrap CI), and
%                    Band fill and Band edge on a PSTH, continuous,
%                    spectrum, coherence (not over time), waveforms or
%                    probe map panel (grayed out while its Error is Off;
%                    the edge's style and width while the edge is none);
%                    a continuous panel's trials (and at most, enabled
%                    unless off); a heat map's rows, its raster sort
%                    rows for trials (and neither row order nor Group
%                    shown then);
%                    a rate panel's display; a tuning panel's parameter
%                    and series; a waveforms panel's layout; a spectral
%                    panel's Chronux rows (tapers, TW / K or W / p enabled
%                    by the taper mode, pad, frequency range, detrend; a
%                    spectrum's and a coherence panel's time base, its range
%                    and segment on "segments", the error and its p-value;
%                    the spike rate with a spike layer; the scale of a
%                    spectrum or spectrogram; a spectrogram's moving window,
%                    baseline, color limits and group; a coherence panel's
%                    over-time box, its phase box or, over time, the moving
%                    window, color limits and group); an event-trace
%                    panel's rows (the bar outline with bars, the level
%                    line with a line, the group bands with a sub-row per
%                    epoch, the baseline's look with a baseline); a
%                    trial panel's rows (trialEnable: a distribution's
%                    categories, display, points and summary marks; a
%                    histogram's display, bins, opacity and summary line;
%                    a scatter's points, opacity, fit, correlation and
%                    marginals; on all three the series, summary (with
%                    the Error row), test, adjustment, how the tests show
%                    and the scales, a histogram's and scatter's x limits,
%                    a distribution's and scatter's y limits); a
%                    legend panel's entries (orientation, columns) and
%                    place in the panel
%     Waveform       with a panel whose type draws spikes (its sources
%                    hold units or detected: figureEditorChoices), titled
%                    with the panel's id: a note (waveformNote: what it
%                    sets, or why the type draws no waveform), then, where
%                    the type draws one, Show (and its band), Spikes drawn,
%                    Time (x), Amplitude (y) and Label; Size and Inset
%                    location on a raster, PSTH, rate or tuning panel (an
%                    inset), Size and On the probe on a waveforms panel in
%                    the probe layout, Size on a probe map (no Label: its
%                    Unit labels row, in Options, names the units)
%     Text note, Overlays   with a panel selected: the panel's note rows
%                    (its look enabled with text; x and y with "At x, y")
%                    and its overlay list with the rows of the overlay
%                    picked (a line's position and color, a patch's edges,
%                    fill and outline; the line style and width with a line
%                    or an outline); titled with the panel's id
%     Appearance     all rows; the site size with a probe map, the heat
%                    colors with a heat map, probe map, correlation map or
%                    a PSTH drawn as a heat map
%     Sessions       Across sessions; with it ticked every row (the keys
%                    with "These datasets", Units matched by for a unit
%                    observation and the mapping file with "mapping", the
%                    error band and faint sessions enabled unless a color
%                    per session) and a note on what it draws; Per trial
%                    group is hidden then and the preview's Dataset
%                    drop-down is off
%     Probe layout   On the probe; with it ticked every row (Overlap, Tile
%                    scale and Leaders enabled with Physical, Lanes with
%                    Lanes beside the shank) and a note counting the
%                    tiles on the active dataset (probeNote); Per trial
%                    group is hidden then. On the probe and Across
%                    sessions exclude each other: one ticked grays the
%                    other out
%   Several panels selected (Shift+click: selectedPanelIds; the shown one
%   is the first, its values in the rows): a banner over the Panel
%   section's rows names them, and only the rows each of them shows by
%   its own type and values are shown (panelRowsShown, judged for the
%   others by their stored options): their title, box, axis labels, Group
%   shown, Options and Waveform rows, and Panel alignment when each one is
%   aligned to events; not the type, the place (Position, Size), Bring
%   forward and Send back, Options' and Panel alignment's Apply to all
%   panels, nor Layers, Text note and Overlays (each panel's own). Remove
%   panel says how many it removes, and the section titles count them.
%   An edit then goes to all of them (onConfigChanged: spreadPanelEdit).
%   The selection lets go of the others when the figure's panels change
%   (one added, removed or renamed: FigurePanelIds).
%   What is enabled: the binding only where a layer may follow the
%   observation (figureEditorChoices: Bindable; otherwise it shows Fixed),
%   the train only on a raster, PSTH or heat map, the response test's rows
%   with Responsive only, the baseline window with a baseline, the fill
%   opacity when filled, the sort event with "event", the
%   waveform's rows when it is not Off (its range's fields with the fixed
%   amplitude; Spikes drawn but with Template, the band with a mean), the
%   bins of a unit
%   correlation for its peak rate, the mask with a stop event, the stack
%   spacing when stacked, the legend rows with their box, and
%   the list buttons (Add layer off on a legend panel, which has no
%   layers: the Layers note says so); Up and Down when the figure has a
%   neighbor that way in its group of the tree. The Panels section's
%   values are shown again in the units picked (showPanelPlace: an edit
%   kept on the page, a page resized), and the preview outlines the
%   selected panel (markFigurePanel).
E = obj.FigureEditor;
S = obj.FigureSections;
k = obj.SelectedFigure;
nf = numel(obj.Config.Figures);
has = k >= 1 && k <= nf;
onoff = @(tf) matlab.lang.OnOffSwitchState(tf);
en = @(c, tf) set(c, 'Enable', onoff(tf));
set([obj.RemoveFigureButton obj.DuplicateFigureButton], 'Enable', onoff(has));
obj.CopyFigureButton.Enable = onoff(has);   % (with one figure: into a design)
if ~isempty(obj.FigureRedrawAllButton)
    obj.FigureRedrawAllButton.Enable = onoff(has && ~obj.Running && ~obj.FigureRedrawing);   % off while a run (or a generate, or itself) goes
    if ~isempty(obj.GenerateFigureMenu); obj.GenerateFigureMenu.Enable = onoff(has && ~obj.Running); end
    set([obj.FigureExportPreviewButton obj.FigureExportPreviewColumnButton], 'Enable', onoff(has && ~obj.Running));
    obj.FigureOpenButton.Enable = onoff(has);
    obj.FigureCodeButton.Enable = onoff(has);
end
[up, down] = groupNeighbors(obj, k);   % Up / Down move a figure within its group of the tree
obj.UpFigureButton.Enable = onoff(has && up);
obj.DownFigureButton.Enable = onoff(has && down);
names = [S.Name];
if ~has
    for i = 1:numel(S)
        S(i).Shown(:) = false;
        S(i).Visible = names(i) == "general";
    end
    S = formShow(S, "summary", true);
    E.summary.Text = "Add a figure: press Add under the list, then pick its first panel.";
    if ~isempty(obj.FiguresDatasetDropDown) && isvalid(obj.FiguresDatasetDropDown); obj.FiguresDatasetDropDown.Enable = "on"; end
    obj.FigureSections = S;
    showPanelPlace(obj);
    obj.layoutFigureEditor();
    return
end
fig = obj.Config.Figures(k);
PT = EphysAnalysisConfig.panelTypes();
np = numel(fig.panels);
j = obj.SelectedPanel;
hasPanel = j >= 1 && j <= np;
pids = strings(1, 0);
if np > 0; pids = [fig.panels.id]; end
if ~isequal(obj.FigurePanelIds, pids); obj.FigurePanelExtra = strings(1, 0); end   % a panel added, removed or renamed: the primary alone
obj.FigurePanelIds = pids;
sel = selectedPanelIds(obj);   % the shown panel first, then the others selected with Shift+click
others = find(ismember(pids, sel(2:end)));
several = hasPanel && ~isempty(others);   % the rows they all have; an edit goes to every one (spreadPanelEdit)
kind = EphysAnalysisConfig.observeKind(fig);
spikes = EphysAnalysisConfig.SpikeSources;
signals = EphysAnalysisConfig.SignalSources;
plural = @(n, w) sprintf("%d %s%s", n, w, repmat('s', 1, n ~= 1));
E.summary.Text = plural(np, "panel") + "; per " + kind;
aligned = false(1, np);
for q = 1:np
    row = PT.Type == fig.panels(q).type;
    aligned(q) = any(row) && PT.Aligned(row);
end

v = struct();
for f = ["id" "title" "size" "sizeWidth" "enabled" "summary" "observe" "obsStarred" "sesEnabled" "prbEnabled" "obsPerGroup" "obsCount" "newPanel" "rectUnits" "boxesMean" "padding" "snap" "arrangeHint" ...
        "fontSize" "lineWidth" "colormap" "sortDepth" "labelDepth" "showStop" "legendLoc" "looksText"]
    v.(f) = true;   % the rows every figure shows
end
% observations
unit = kind == "unit";
sorted = fig.observe.data == "units";
respAuroc = unit && string(E.obsRespTest.Value) == "auroc";
v.obsClasses = sorted; v.obsQuality = sorted;
v.obsResponse = unit; v.obsRespBaseFrom = unit; v.obsRespParam = unit;
v.obsRaMethod = respAuroc; v.obsRaWinMs = respAuroc; v.obsRaCutoff = respAuroc;
v.obsRaTest = respAuroc && ismember(string(E.obsRaCutoff.Value), ["test" "shuffle"]);   % shuffle: its n
v.obsIds = unit; v.obsMaxUnits = unit; v.obsShanks = unit; v.obsUnitChannels = unit;
v.obsChannels = kind == "channel";
% across sessions: every row once Across sessions is ticked; the keys with "These datasets", the mapping file with
% match "mapping", the band and the faint sessions when the sessions are averaged (a color per subject, or none)
ses = logical(E.sesEnabled.Value);
v.sesDatasets = ses; v.sesKeys = ses && string(E.sesDatasets.Value) == "list";
v.sesFacet = ses; v.sesSeries = ses; v.sesColorOrder = ses; v.sesTrialGroups = ses; v.sesMinSessions = ses;
v.sesShowMembers = ses; v.sesError = ses;
v.sesMatch = ses && kind == "unit";
v.sesMappingFile = ses && kind == "unit" && string(E.sesMatch.Value) == "mapping";
v.sesNote = ses;
en([E.sesShowMembers E.sesError], string(E.sesSeries.Value) ~= "session");
E.sesNote.Text = sessionNote(fig, kind);
% on the probe: every row once On the probe is ticked; Overlap, Lanes, Tile scale and Leaders enabled with Physical,
% Lanes with Lanes beside the shank; On the probe and Across sessions exclude each other (both ticked: both enabled,
% to untick one)
prb = logical(E.prbEnabled.Value);
for f = ["prbLayout" "prbOverlap" "prbLanes" "prbShanks" "prbChannels" "prbDepth" "prbMaxTiles" "prbPerSite" ...
        "prbTileWidth" "prbTileHeight" "prbScale" "prbLabels" "prbSharedY" "prbScaleTile" "prbShowSites" "prbLeaders" "prbNote"]
    v.(f) = prb;
end
physical = string(E.prbLayout.Value) == "physical";
en([E.prbOverlap E.prbScale E.prbLeaders], physical);
en(E.prbLanes, physical && string(E.prbOverlap.Value) == "lanes");
en(E.sesEnabled, ~prb || ses);
en(E.prbEnabled, ~ses || prb);
if prb; E.prbNote.Text = probeNote(obj, k); end
v.obsPerGroup = ~ses && ~prb;   % a session figure's trial groups follow its Trial groups; a probe figure has none
% the first-spike latency: the figure's block, while it has a panel that can read it (a raster, PSTH or heat map); the
% rate with a Poisson method, the burst's rows with "surprise", alpha with "poisson"; the baseline window's fields with
% "Window"
types0 = strings(1, 0);
if np > 0; types0 = [fig.panels.type]; end
latOn = any(ismember(types0, ["raster" "psth" "heatmap"]));
method = string(E.latMethod.Value);
v.latNote = latOn; v.latMethod = latOn; v.latFrom = latOn; v.latBaseline = latOn;
v.latRate = latOn && method ~= "first";
v.latSurprise = latOn && method == "surprise";
v.latAlpha = latOn && method == "poisson";
v.latCusum = latOn; v.latCusumSD = latOn;
en([E.latBaseFrom E.latBaseTo], string(E.latBaseline.Value) == "window");
E.latNote.Text = latencyNote(fig);
% arrangement and panel
v.selPanel = hasPanel; v.noPanel = ~hasPanel;
v.rectXY = hasPanel && ~several; v.rectWH = v.rectXY; v.panelButtons = hasPanel;   % (several: each keeps its place)
en(E.bringForward, hasPanel && j < np && ~several);   % the drawing order: forward while a panel is drawn after it
en(E.sendBack, hasPanel && j > 1 && ~several);
E.removePanel.Text = "Remove panel";
if several; E.removePanel.Text = sprintf("Remove %d panels", numel(sel)); end
v.multiNote = several;
if several; E.multiNote.Text = multiText(sel); end
v.panelType = hasPanel && ~several; v.panelTitle = hasPanel;   % (several: each keeps its type)
v.panelBox = false; v.panelXLabel = false; v.panelYLabel = false; v.group = false;   % (panelRowsShown: none on a legend panel)
v.panelXShow = false;
% layers and options: off unless the panel uses them
layerKeys = ["layerList" "layerAdd" "layerNote" "layerName" "layerSource" "layerBinding" "layerFollows" "layerClasses" ...
    "layerIds" "layerQuality" "layerMaxUnits" "layerShanks" "layerUnitChannels" "layerChannels" "layerAggregate" "evLine" ...
    "evEdge" "evSeqText" "evDrawAs" "evMarker" "evColor" "evSpanStyle" "trMeasure" "trXMeasure" "layerColor" "layerLineStyle"];
optionKeys = ["binMs" "smoothMs" "measure" "baselineMode" "baseFrom" "rasterSort" "sortLine" "sortSeqText" "rasterByGroup" "yTicks" "tickColor" "tickWidth" "backColor" ...
    "firstSpike" "latencyBox" "onsetLine" "trialCount" ...
    "maskAfterStop" "psthDisplay" "histStyle" "fill" "normalize" "statistic" "errorType" "errFace" "errEdge" "order" ...
    "value" "unitLabels" "waveColor" "metric" "correlation" "fisherZ" "detrend" "yLim" "cLim" "panelColormap" ...
    "optApplyAll" "auMethod" "auWinMs" "auModFrom" "auCutoff" "auTest" "auMarks" "stack" "param" "rateDisplay" "waveLayout" ...
    "contTrials" "heatRows" "spTimeBase" "spRangeFrom" "spSegment" "spTaperMode" "spTW" "spW" "spPad" "spFmin" "spErr" ...
    "spDetrend" "spScale" "spSpikeFs" "spOverTime" "spWin" "spShowPhase" "etDisplay" "etTrials" "etColorBy" "etHeight" ...
    "etEdge" "etMinWidth" "etLineStyle" "etBaseline" "etBaseStyle" "etRowSpacing" "legOrient" "legAlign" ...
    "trCategories" "trSeries" "trSummary" "trTest" "trAdjust" "trTestShow" "trDisplay" "trMarker" "trShowSummary" ...
    "trHistDisplay" "trBins" "trOpacity" "trFit" "trCorr" "trMarginals" "trXScale" "trXLim"];
waveKeys = ["waveNote" "waveMode" "waveSpikes" "waveFrom" "waveAmp" "waveWidth" "waveLocation" "wavePP" "waveSites"];
noteKeys = ["annText" "annPlace" "annX" "annAlign" "annRotation" "annFont" "annBold" "annColor" "annInterp"];
overlayKeys = ["ovList" "ovName" "ovKind" "ovValue" "ovFrom" "ovLayer" "ovColor" "ovFill" "ovEdge" "ovStyle"];
for f = [layerKeys optionKeys waveKeys noteKeys overlayKeys]; v.(f) = false; end
waveSpiky = false;   % the panel's layers may be spikes: the Waveform section shows
optionsTitle = "Options";
paligned = false;
nOv = 0;
if hasPanel
    p = fig.panels(j);
    t = p.type;
    row = PT.Type == t;
    known = any(row);
    typeLabel = t;
    if known
        typeLabel = PT.Label(row);
        optionsTitle = typeLabel + " options";
        paligned = PT.Aligned(row);
    end
    on = [p.layers.enabled];
    first = "";
    if any(on); first = p.layers(find(on, 1)).source; end
    rowsNow = string(E.heatRows.Value);   % a heat map's rows: its units / channels, or one unit's epochs
    ch = figureEditorChoices(t, first);

    % layers
    nl = numel(p.layers);
    labels = strings(1, nl);
    for i = 1:nl; labels(i) = layerLabel(p.layers(i), t); end
    if ~isequal(string(E.layerList.Items), labels)
        if nl == 0
            set(E.layerList, "Items", {}, "ItemsData", []);
        else
            set(E.layerList, "Items", cellstr(labels), "ItemsData", 1:nl, "Value", min(max(obj.SelectedLayer, 1), nl));
        end
    end
    v.layerList = true; v.layerAdd = true;
    multi = known && PT.MultiLayer(row);
    v.layerNote = (~multi && nl > 1) || isempty(ch.Sources);
    if isempty(ch.Sources)
        E.layerNote.Text = "A " + lower(typeLabel) + " panel has no layers: it draws the figure's legend entries.";
    elseif v.layerNote
        E.layerNote.Text = "A " + lower(typeLabel) + " panel draws one layer: only the first enabled one is drawn.";
    end
    i = obj.SelectedLayer;
    if i >= 1 && i <= nl
        L = p.layers(i);
        lc = figureEditorChoices(t, L.source, rowsNow, Observed=fig.observe.data);
        isSpike = ismember(L.source, spikes);
        isSignal = ismember(L.source, signals);
        fixed = L.binding == "fixed";
        onTrace = t == "eventTrace";   % an event-trace panel draws its events layers its own way: no Draw as, marker or span
        marks = L.source == "events" && L.eventsAs == "marks" && ~onTrace;
        span = L.source == "events" && L.eventsAs == "span" && ~onTrace;
        v.layerName = true; v.layerSource = true; v.layerBinding = true;
        v.layerFollows = ~fixed && (isSpike || isSignal);
        v.layerClasses = fixed && L.source == "units";
        v.layerIds = fixed && isSpike; v.layerQuality = v.layerIds; v.layerMaxUnits = v.layerIds;
        v.layerShanks = v.layerIds; v.layerUnitChannels = v.layerIds;
        v.layerChannels = fixed && isSignal;
        v.layerAggregate = fixed && (isSpike || isSignal) && numel(lc.Aggregates) > 1;
        v.evLine = L.source == "events"; v.evEdge = v.evLine; v.evSeqText = v.evLine; v.evDrawAs = v.evLine;
        v.evMarker = marks; v.evColor = marks || span; v.evSpanStyle = span;
        v.trMeasure = L.source == "trials"; v.trXMeasure = v.trMeasure && t == "trialScatter";   % its measures: Edit... opens the Trial measure window
        v.layerColor = ~(marks || span); v.layerLineStyle = v.layerColor;
        if ~lc.Bindable; E.layerBinding.Value = "fixed"; end
        en(E.layerBinding, lc.Bindable);
        en(E.layerQuality, L.source == "units");
        drawAsChoices(E.evDrawAs, t);
        en(E.evDrawAs, ~onTrace);
        was = string(E.layerAggregate.Value);
        if ~isequal(string(E.layerAggregate.Items), reshape(string(lc.AggregateLabels), 1, [])) ...
                || ~isequal(string(E.layerAggregate.ItemsData), reshape(string(lc.Aggregates), 1, []))   % (set only when they change)
            E.layerAggregate.ItemsData = [];   % the lists may change length: the value is put back when the type offers it
            set(E.layerAggregate, "Items", lc.AggregateLabels, "ItemsData", lc.Aggregates);
            if ismember(was, lc.Aggregates); E.layerAggregate.Value = was; end
        end
        E.layerFollows.Text = followsText(L, kind, fig.observe);
    end
    en([E.removeLayer], i >= 1 && i <= nl);
    en(E.layerUp, i > 1 && i <= nl);
    en(E.layerDown, i >= 1 && i < nl);
    en(E.addLayer, ~isempty(ch.Sources));

    % options and the unit waveform: the rows the panel's type and values use (panelRowsShown); with several panels
    % selected, only the rows every one of them shows (each by its own values)
    [pv, d] = panelRowsShown(p, editorValues(E), [optionKeys waveKeys]);
    own = pv;   % the shown panel's own: what its rows' enabling reads
    for q = others
        qv = panelRowsShown(fig.panels(q), storedValues(fig.panels(q)), [optionKeys waveKeys]);
        for f = string(fieldnames(pv)).'
            pv.(f) = pv.(f) && qv.(f);
        end
    end
    if several; pv.optApplyAll = false; end   % (Apply to all panels gives one panel's options to every other)
    waveSpiky = pv.waveSection;
    pv = rmfield(pv, 'waveSection');
    for f = string(fieldnames(pv)).'
        v.(f) = pv.(f);
    end
    stackNow = d.stack;
    overTime = d.overTime;
    en(E.maxTrials, string(E.contTrials.Value) ~= "off");
    if own.errorType; errorTypeItems(E.errorType, t); end
    errOn = t ~= "rate" || string(E.rateDisplay.Value) == "bar";   % a rate panel draws its error bars on bars
    en(E.errorType, errOn);
    en(E.errResamples, errOn && string(E.errorType.Value) == "ci95");
    bars = string(E.etDisplay.Value) == "bars";   % an event-trace panel's rows its display or trials do not use: grayed out
    en([E.etEdge E.etEdgeWidth E.etMinWidth], bars);
    en([E.etLineStyle E.etLineWidth], ~bars);
    en(E.etGroupBands, string(E.etTrials.Value) == "rows");
    en([E.etBaseColor E.etBaseStyle E.etBaseWidth], E.etBaseline.Value);
    en([E.spTW E.spK], string(E.spTaperMode.Value) == "TWK");
    en([E.spW E.spP], string(E.spTaperMode.Value) == "Wp");
    bandOn = ~(own.errorType && string(E.errorType.Value) == "off");   % its error off: no band to style
    en([E.errFace E.errAlpha E.errEdge], bandOn);
    en([E.errEdgeStyle E.errEdgeWidth], bandOn && lower(strtrim(string(E.errEdge.Value))) ~= "none");
    en(E.spErrP, string(E.spErr.Value) ~= "none");
    if own.baselineMode; offerItems(E.baselineMode, ch.BaselineModes); end
    en([E.baseFrom E.baseTo], string(E.baselineMode.Value) ~= "none");
    auCut = string(E.auCutoff.Value);
    en(E.auStepMs, string(E.auWindows.Value) == "sliding");
    en(E.auThreshold, auCut == "fixed");
    en([E.auTest E.auCorrection], auCut == "test");
    en(E.auResamples, auCut == "shuffle" || string(E.auTest.Value) ~= "ranksum");
    en([E.auMarks E.auModOnly], string(E.auCutoff.Value) ~= "none");
    en(E.stackSpacing, stackNow ~= "off");
    en(E.yLim, string(E.yLimMode.Value) == "fixed");   % the limits are typed only for Fixed
    lineStack = stackNow ~= "off" && ismember(t, ["psth" "continuous" "spectrum" "coherence" "tuning"]) && ~overTime;
    en(E.panelYSide, ~lineStack);   % a stacked line panel has a y axis on each side
    en(E.fillAlpha, E.fill.Value);
    sortOn = ~(t == "eventTrace" && string(E.etTrials.Value) ~= "rows");   % an event trace sorts its sub-rows only
    en([E.rasterSort E.rasterSortOrder E.rasterByGroup], sortOn);
    en([E.sortLine E.sortEdge E.sortSeqText E.sortSeqEdit], sortOn && strtrim(string(E.rasterSort.Value)) == "event");
    en([E.binMs E.smoothMs], t ~= "corrmap" || string(E.metric.Value) == "peak");
    stop = obj.FigureAlignControls.StopOn.Value;
    if isstruct(p.window); stop = obj.PanelAlignControls.StopOn.Value; end
    en(E.maskAfterStop, stop);
    if ismember(t, EphysAnalysisConfig.TrialPanelTypes); trialEnable(E, t); end   % a trial panel's rows its values do not use: grayed out
    en(E.optApplyAll, np > 1);   % Apply to all panels: any other panel (every one takes the axis sides; adoptPanelOptions)

    % the unit waveform's note (what it sets, or why the type draws none) and its rows' enabling
    E.waveNote.Text = d.waveText;
    mode = string(E.waveMode.Value);
    waveOn = mode ~= "off";
    en([E.waveSpikes E.waveFrom E.waveTo E.waveAmp E.waveWidth E.waveHeight E.waveLocation E.waveBox E.wavePP E.waveCount ...
        E.waveSites E.waveNames], waveOn);
    en(E.waveSpikes, ismember(mode, ["mean" "subsample" "both"]));   % a template reads no spikes
    en(E.waveBand, ismember(mode, ["mean" "both"]));
    en([E.waveAmpLo E.waveAmpHi], waveOn && string(E.waveAmp.Value) == "fixed");

    % the panel's own alignment
    modes = "fixed";
    if ismember(t, ["corrmap" "rate" "tuning"]); modes = ["fixed" "between"]; end
    AlignControls.setWindowModes(obj.PanelAlignControls.Mode, modes);
    C2 = obj.PanelAlignControls;
    trialPanel = ismember(t, EphysAnalysisConfig.TrialPanelTypes);   % no event or window, but a trial selection of its own
    unlinked = paligned && ~E.panelSame.Value;   % linked ("Same as the figure"): the rows show the figure's, locked
    ctl = findobj([C2.RefGrid C2.WindowGrid], '-property', 'Enable');
    set(ctl, 'Enable', onoff(unlinked));
    if unlinked; AlignControls.syncEnable(C2); end
    selectable = paligned || trialPanel;
    ownSel = selectable && ~E.panelSameSel.Value;   % linked ("Trial selection as the figure"): the figure's, locked
    set(findobj(C2.SelectionGrid, '-property', 'Enable'), 'Enable', onoff(ownSel));
    if ownSel; en(C2.MinArtifact, C2.ExcludeArtifacts.Value); end
    en(E.panelSame, paligned);
    en(E.panelSameSel, selectable);
    set([E.panelSame C2.RefGrid C2.WindowGrid], 'Visible', onoff(~trialPanel));   % a trial panel: the selection alone
    en(E.alignApplyAll, (unlinked || ownSel) && ~several);   % (it gives one panel's own to the figure)
    E.palignNote.Text = "";
    if trialPanel
        E.palignNote.Text = "Trial panels use no event or window: they take the figure's trial selection, or their own.";
    elseif ~paligned
        E.palignNote.Text = typeLabel + " panels are not aligned to events: they use no event or window.";
    end

    % the panel's text note and overlays (a panel's overlays have no panel row)
    for f = noteKeys; v.(f) = true; end
    noted = strtrim(strjoin(string(E.annText.Value(:)).', newline)) ~= "";
    en([E.annPlace E.annAlign E.annVAlign E.annRotation E.annFont E.annSize E.annBold E.annItalic E.annBox ...
        E.annColor E.annBackground E.annInterp], noted);
    en([E.annX E.annY], noted && string(E.annPlace.Value) == "custom");
    items = overlayGather(E);
    overlayList(E, items, E.ovList.UserData.shown);   % the labels follow the name and position edited
    at = E.ovList.UserData.shown;
    picked = at >= 1 && at <= numel(items);
    isLine = startsWith(string(E.ovKind.Value), "line");
    v.ovList = true;
    v.ovName = picked; v.ovKind = picked; v.ovLayer = picked; v.ovStyle = picked;
    v.ovValue = picked && isLine; v.ovColor = picked && isLine;
    v.ovFrom = picked && ~isLine; v.ovFill = picked && ~isLine; v.ovEdge = picked && ~isLine;
    set([E.ovDuplicate E.ovRemove], 'Enable', onoff(picked));
    outlined = isLine || ~ismember(lower(strtrim(string(E.ovEdge.Value))), ["" "none"]);
    en([E.ovStyle E.ovWidth], outlined);
    nOv = numel(items);
end
if several   % each keeps its own layers, text note and overlays
    for f = [layerKeys noteKeys overlayKeys]; v.(f) = false; end
end
en(E.removePanel, hasPanel);
own = false;   % any panel with its own event, window or selection: Re-link all panels has something to do
for q = 1:np
    own = own || isstruct(fig.panels(q).ref) || isstruct(fig.panels(q).window) || isstruct(fig.panels(q).selection);
end
en(E.alignRelinkAll, own);
pg = E.palignGrid;
hs = pg.UserData;
note = 34 * (hasPanel && ~paligned);
hs(1:2) = hs(1:2) * ~(hasPanel && ismember(fig.panels(j).type, EphysAnalysisConfig.TrialPanelTypes));   % a trial panel: no event or window rows
pg.RowHeight = {note, 30, hs(1), hs(2), 22, hs(3)};
S(names == "palign").BodyHeight = note + 30 + hs(1) + hs(2) + 22 + hs(3) + 5 * pg.RowSpacing;

% appearance
types = strings(1, 0);
if np > 0; types = [fig.panels.type]; end
v.siteSize = any(types == "probemap");
psthHeats = arrayfun(@(q) q.type == "psth" && isfield(q.options, 'display') && q.options.display == "heatmap", fig.panels);
v.heatColormap = any(ismember(types, ["heatmap" "probemap" "corrmap"])) || any(psthHeats);
en([E.legendLoc E.legendOrient E.legendBox], E.legend.Value);

% observations' enables
respOn = logical(E.obsResponse.Value);
en([E.obsRespTest E.obsRespDirection E.obsRespBaseFrom E.obsRespBaseTo E.obsRespFrom E.obsRespTo E.obsRespParam ...
    E.obsRespCorrection E.obsRespAlpha E.obsRaMethod E.obsRaWindows E.obsRaWinMs E.obsRaBinMs E.obsRaCutoff E.obsRaTest], respOn);
en(E.obsRaStepMs, respOn && string(E.obsRaWindows.Value) == "sliding");
en(E.obsRaThreshold, respOn && string(E.obsRaCutoff.Value) == "fixed");
en(E.obsRaTest, respOn && string(E.obsRaCutoff.Value) == "test");
en(E.obsRaResamples, respOn && (string(E.obsRaCutoff.Value) == "shuffle" || string(E.obsRaTest.Value) ~= "ranksum"));
n = numel(fig.aesthetics);
E.looksText.Text = sprintf("%d remembered look(s); right-click the preview to edit.", n);
en(E.looksForget, n > 0);

for f = string(fieldnames(v)).'
    S = formShow(S, f, v.(f));
end
for i = 1:numel(S)
    switch names(i)
        case {"panel" "options"}
            S(i).Visible = hasPanel;
        case "palign"
            S(i).Visible = hasPanel && (~several || all(aligned([j others])));   % several: when each one is aligned to events
        case {"layers" "note" "overlays"}
            S(i).Visible = hasPanel && ~several;   % each panel's own
        case "waveform"
            S(i).Visible = hasPanel && waveSpiky;
        case {"ref" "window"}
            S(i).Visible = np == 0 || any(aligned);
        case "selection"   % the trial panels take the figure's trial selection too
            S(i).Visible = np == 0 || any(aligned) || any(ismember(types0, EphysAnalysisConfig.TrialPanelTypes));
        case "latency"
            S(i).Visible = latOn;
        otherwise
            S(i).Visible = true;
    end
end
S(names == "options").Title = optionsTitle;
S(names == "note").Title = "Text note";
S(names == "overlays").Title = "Overlays";
S(names == "waveform").Title = "Waveform";
if hasPanel
    S(names == "waveform").Title = "Waveform on " + fig.panels(j).id;
    S(names == "note").Title = "Text note on " + fig.panels(j).id;
    S(names == "overlays").Title = "Overlays on " + fig.panels(j).id;
    if nOv > 0; S(names == "overlays").Title = "Overlays (" + nOv + ") on " + fig.panels(j).id; end
end
S(names == "panel").Title = "Selected panel";
S(names == "palign").Title = "Panel alignment";
if several   % the sections' titles count the panels an edit goes to
    nSel = numel(sel);
    S(names == "panel").Title = sprintf("%d selected panels", nSel);
    S(names == "palign").Title = sprintf("Panel alignment of %d panels", nSel);
    S(names == "waveform").Title = sprintf("Waveform on %d panels", nSel);
    if isscalar(unique([fig.panels([j others]).type]))
        S(names == "options").Title = optionsTitle + sprintf(" (%d panels)", nSel);
    else
        S(names == "options").Title = sprintf("Options the %d panels share", nSel);
    end
end
S(names == "layers").Title = "Layers";
if hasPanel && ~isempty(fig.panels(j).layers)
    S(names == "layers").Title = "Layers (" + numel(fig.panels(j).layers) + ") of " + fig.panels(j).id;
end
obj.FigureSections = S;
AlignControls.syncEnable(obj.FigureAlignControls);
if ~isempty(obj.FiguresDatasetDropDown) && isvalid(obj.FiguresDatasetDropDown)
    obj.FiguresDatasetDropDown.Enable = onoff(~ses);   % a session figure is drawn across the datasets, not on the active one
end
syncColorSwatches(E.swatch);   % each color field's swatch: its color, enabled with it
showPanelPlace(obj);   % the rect, padding and snap step in the units picked (kept on the page, the page resized)
obj.layoutFigureEditor();
obj.markFigurePanel();   % the preview outlines the selected panel
end


function [v, d] = panelRowsShown(p, val, keys)
%panelRowsShown  Which of panel P's own rows show while its rows hold the values VAL: Box, the axis labels, Group shown, its Options and Waveform rows.
%   [V, D] = panelRowsShown(P, VAL, KEYS): V has a field per key of KEYS
%   (the Options and Waveform rows', off unless P's type uses them) and
%   panelBox, panelXLabel, panelYLabel, group and waveSection (the
%   Waveform section shows: the type's layers may be spikes). VAL holds
%   the values the showing follows: editorValues (the editor's controls,
%   for the panel it shows) or storedValues (another selected panel's
%   options), so each panel selected is judged by its own values. D: what
%   the enabling of the shown panel's rows reads too (pointHeat,
%   trialHeat, psthHeat, stack: "off" where the type shows no stack row,
%   overTime, waveText).
PT = EphysAnalysisConfig.panelTypes();
t = p.type;
row = PT.Type == t;
known = any(row);
v = struct();
for f = keys; v.(f) = false; end
axesOn = t ~= "legend";   % a legend panel has no axes
v.panelBox = axesOn; v.panelXLabel = axesOn; v.panelYLabel = axesOn;
v.panelXShow = axesOn;
v.group = known && PT.OneGroup(row);
first = "";
if ~isempty(p.layers)
    on = [p.layers.enabled];
    if any(on); first = p.layers(find(on, 1)).source; end
end
ch = figureEditorChoices(t, first);
pointHeat = t == "heatmap" && ~ismember(first, EphysAnalysisConfig.SignalSources);
trialHeat = t == "heatmap" && val.heatRows == "trials";   % a heat map of one unit's epochs
psthHeat = t == "psth" && val.psthDisplay == "heatmap";   % a PSTH drawn as a heat map: no trace rows
v.binMs = t == "psth" || pointHeat || t == "corrmap"; v.smoothMs = v.binMs;
v.measure = t == "psth" || pointHeat || ismember(t, ["rate" "tuning"]);
v.baselineMode = ismember(t, ["psth" "continuous" "heatmap" "corrmap" "rate" "tuning"]); v.baseFrom = v.baselineMode;
v.psthDisplay = t == "psth";
v.stack = ~isempty(EphysAnalysisConfig.stackModes(t)) && ~psthHeat && ~trialHeat;   % one row for every type that stacks
stackNow = val.stack;
if ~v.stack; stackNow = "off"; end
v.param = t == "tuning";
v.rateDisplay = t == "rate";
v.waveLayout = t == "waveforms";
v.rasterSort = t == "raster" || trialHeat || t == "eventTrace"; v.sortLine = v.rasterSort; v.sortSeqText = v.rasterSort; v.rasterByGroup = v.rasterSort;
v.yTicks = t == "raster"; v.tickColor = v.yTicks; v.tickWidth = v.yTicks; v.backColor = v.yTicks;
v.firstSpike = t == "raster";
v.latencyBox = t == "psth" && ~psthHeat;
v.onsetLine = ismember(t, ["raster" "psth"]);
v.trialCount = t == "psth";
v.heatRows = t == "heatmap";
v.contTrials = t == "continuous";
v.maskAfterStop = ismember(t, ["raster" "psth"]) || pointHeat;
v.histStyle = t == "psth" && ~psthHeat; v.fill = v.histStyle; v.normalize = t == "psth";
v.statistic = t == "continuous";
v.errorType = ismember(t, ["psth" "continuous" "rate" "tuning" EphysAnalysisConfig.TrialPanelTypes]) && ~psthHeat;   % the panel's own error (its items by type; a trial panel's summary's)
v.order = t == "heatmap" && ~trialHeat;
et = t == "eventTrace";   % an event-trace panel's rows
v.etDisplay = et; v.etTrials = et; v.etColorBy = et; v.etHeight = et; v.etEdge = et; v.etMinWidth = et; v.etLineStyle = et;
v.etBaseline = et; v.etBaseStyle = et; v.etRowSpacing = et;
if trialHeat; v.group = false; end   % a heat map of trials draws every group
v.value = t == "probemap";
v.legOrient = t == "legend"; v.legAlign = v.legOrient;
v.unitLabels = v.value;
v.waveColor = v.value;
v.metric = t == "corrmap"; v.correlation = v.metric; v.fisherZ = v.metric; v.detrend = v.metric;
v.yLim = ismember(t, ["psth" "continuous" "waveforms" "rate" "tuning" "spectrum" "trialDist" "trialScatter"]) && ~psthHeat;
% the trial panels: a distribution's categories and display, a histogram's bins, a scatter's fit, correlation and
% marginals; the grouping, summary, test and scale rows on all three (trialEnable grays what their values do not use)
isDist = t == "trialDist"; isHist = t == "trialHist"; isScat = t == "trialScatter";
trial = isDist || isHist || isScat;
v.trCategories = isDist; v.trDisplay = isDist;
v.trSeries = trial; v.trSummary = trial; v.trTest = trial; v.trAdjust = trial; v.trTestShow = trial; v.trXScale = trial;
v.trMarker = isDist || isScat; v.trShowSummary = isDist || isHist; v.trOpacity = isHist || isScat; v.trXLim = isHist || isScat;
v.trHistDisplay = isHist; v.trBins = isHist;
v.trFit = isScat; v.trCorr = isScat; v.trMarginals = isScat;
v.cLim = ismember(t, ["heatmap" "probemap" "corrmap" "spectrogram"]) || psthHeat;
v.panelColormap = psthHeat;
% the spectral panels: the Chronux tab's rows
spectral = ismember(t, ["spectrum" "spectrogram" "coherence"]);
overTime = t == "coherence" && val.overTime;   % a coherogram: an image of one group over time
v.spTimeBase = ismember(t, ["spectrum" "coherence"]);
ranged = v.spTimeBase && val.timeBase == "range";
v.spRangeFrom = ranged; v.spSegment = ranged && ~overTime;
v.spTaperMode = spectral; v.spTW = spectral; v.spW = spectral; v.spPad = spectral; v.spFmin = spectral; v.spDetrend = spectral;
v.spErr = ismember(t, ["spectrum" "coherence"]) && ~overTime;
v.errFace = ismember(t, ["psth" "continuous" "spectrum" "coherence" "waveforms" "probemap"]) && ~psthHeat && ~overTime;   % the bands' look
v.errEdge = v.errFace;
v.spScale = ismember(t, ["spectrum" "spectrogram"]);
v.spSpikeFs = spectral && ~isempty(p.layers) && any(ismember([p.layers.source], EphysAnalysisConfig.SpikeSources));
v.spOverTime = t == "coherence";
v.spWin = t == "spectrogram" || overTime;
v.spShowPhase = t == "coherence" && ~overTime;
if t == "coherence"
    v.yLim = ~overTime;
    v.cLim = overTime;
    v.group = overTime;
end
if stackNow ~= "off"; v.group = false; end   % a stack draws every group
if t == "spectrogram"; v.baselineMode = true; v.baseFrom = true; end
auOn = (t == "psth" || pointHeat) && val.baselineMode == "auroc";   % the panel's auROC settings
v.auMethod = auOn; v.auWinMs = auOn; v.auModFrom = auOn; v.auCutoff = auOn; v.auMarks = auOn;
v.auTest = auOn && ismember(val.aurocCutoff, ["test" "shuffle"]);   % shuffle: its n and alpha
v.optApplyAll = known;
% the unit waveform: its section for every type whose layers may be spikes, its rows where the type draws one
v.waveSection = any(ismember(ch.Sources, EphysAnalysisConfig.SpikeSources));
[waveText, draws] = waveformNote(t, val.waveLayout);
inset = ismember(t, EphysAnalysisConfig.WaveformInsetTypes);
probe = t == "waveforms" && val.waveLayout == "probe";
glyphs = probe || t == "probemap";   % the units' waveforms at their places on the probe
v.waveNote = v.waveSection;
v.waveMode = draws; v.waveSpikes = draws; v.waveFrom = draws; v.waveAmp = draws; v.wavePP = draws && t ~= "probemap";
v.waveWidth = inset || glyphs; v.waveLocation = inset; v.waveSites = probe;
d = struct('pointHeat', pointHeat, 'trialHeat', trialHeat, 'psthHeat', psthHeat, 'stack', stackNow, 'overTime', overTime, ...
    'waveText', waveText);
end


function val = editorValues(E)
%editorValues  The values panelRowsShown follows, as the editor's controls show them (the panel the editor shows).
val = struct('heatRows', string(E.heatRows.Value), 'psthDisplay', string(E.psthDisplay.Value), 'stack', string(E.stack.Value), ...
    'overTime', logical(E.spOverTime.Value), 'timeBase', string(E.spTimeBase.Value), 'baselineMode', string(E.baselineMode.Value), ...
    'aurocCutoff', string(E.auCutoff.Value), 'waveLayout', string(E.waveLayout.Value));
end


function val = storedValues(p)
%storedValues  The values panelRowsShown follows, as panel P's options hold them (another of the panels selected).
op = p.options;
val = struct('heatRows', optionText(op, "rows", "items"), 'psthDisplay', optionText(op, "display", ""), ...
    'stack', optionText(op, "stack", "off"), 'overTime', false, 'timeBase', optionText(op, "timeBase", ""), ...
    'baselineMode', "", 'aurocCutoff', "", 'waveLayout', optionText(op, "layout", "grid"));
if isfield(op, 'overTime'); val.overTime = isscalar(op.overTime) && logical(op.overTime); end
if isfield(op, 'baseline') && isstruct(op.baseline) && isfield(op.baseline, 'Mode'); val.baselineMode = optionText(op.baseline, "Mode", ""); end
if isfield(op, 'auroc') && isstruct(op.auroc) && isfield(op.auroc, 'cutoff'); val.aurocCutoff = optionText(op.auroc, "cutoff", ""); end
end


function trialEnable(E, t)
%trialEnable  A trial panel's (TYPE T) Options rows enabled by its values: what they do not use grayed out.
%   A parameter's name and bins with "a trial parameter"; the pairs, the
%   adjustment, alpha and how the tests show unless the test is none (the
%   bracketed pairs on a distribution with brackets); x at values with
%   points or a line, the jitter with points, the summary mark with a
%   swarm, points or violin, n in the ticks on a distribution; the
%   normalization but with an ECDF, the bin count or width by Bins; the fit's
%   band with a line or polynomial, its window with a moving one; the
%   marginals' size with them; the x scale but on a distribution, the y
%   scale but on a histogram. The Show tests items are the type's.
en = @(c, tf) set(c, 'Enable', matlab.lang.OnOffSwitchState(tf));
isDist = t == "trialDist";
en([E.trCategoryParam E.trCategoryBins], string(E.trCategories.Value) == "param");
en([E.trSeriesParam E.trSeriesBins], string(E.trSeries.Value) == "param");
shows = ["text" "off"];
labels = ["the p in a corner" "off (the caption only)"];
if isDist
    shows = ["brackets" shows];
    labels = ["brackets, stars and the p" labels];
end
if ~isequal(string(E.trTestShow.ItemsData), shows)   % (set only when they change)
    was = string(E.trTestShow.Value);
    E.trTestShow.ItemsData = [];
    set(E.trTestShow, "Items", labels, "ItemsData", shows);
    if ismember(was, shows); E.trTestShow.Value = was; end
end
testOn = string(E.trTest.Value) ~= "none";
en([E.trPairs E.trAdjust E.trAlpha E.trTestShow], testOn);
en(E.trBracketPairs, testOn && isDist && string(E.trTestShow.Value) == "brackets");
drawn = string(E.trDisplay.Value);
en(E.trOrdinalX, ismember(drawn, ["points" "line"]));
en(E.trJitter, isDist && drawn == "points");
en(E.trShowSummary, ~isDist || ismember(drawn, ["swarm" "points" "violin"]));
en(E.trShowN, isDist);
en(E.trNormalization, string(E.trHistDisplay.Value) ~= "ecdf");
bins = string(E.trBins.Value);
en(E.trBinCount, bins == "count");
en(E.trBinWidth, bins == "width");
fitted = string(E.trFit.Value);
en(E.trFitBand, ismember(fitted, ["linear" "poly2" "poly3"]));
en(E.trFitWindow, ismember(fitted, ["movmean" "movmedian"]));
en(E.trMarginalSize, logical(E.trMarginals.Value));
en(E.trXScale, ~isDist);
en(E.trYScale, t ~= "trialHist");
end


function x = optionText(op, f, default)
%optionText  Option F of OP as one string, else DEFAULT (a type without it, or a value that is not one text).
x = string(default);
if ~isfield(op, f); return; end
y = string(op.(f));
if isscalar(y) && ~ismissing(y); x = y; end
end


function [up, down] = groupNeighbors(obj, k)
%groupNeighbors  Whether figure K has a figure before (UP) and after (DOWN) it in its group of the tree (figureGroups).
up = false;
down = false;
F = obj.Config.Figures;
if k < 1 || k > numel(F); return; end
[~, ~, members] = figureGroups(F, string(obj.FigureGroupDropDown.Value));
group = members{cellfun(@(m) any(m == k), members)};
i = find(group == k);
up = i > 1;
down = i < numel(group);
end


function t = multiText(sel)
%multiText  The banner over the Panel section's rows while the panels SEL (the shown one first) are selected.
n = numel(sel);
t = sprintf("%d panels selected: %s. Only the settings they all have are shown, with %s's values; an edit goes to " + ...
    "all %d. Shift+click a panel to add it or take it out; Esc keeps %s alone.", n, strjoin(sel, ", "), sel(1), n, sel(1));
end


function s = latencyNote(fig)
%latencyNote  The First-spike latency section's note: one block for the figure, and the panels that read it (and what for).
parts = strings(1, 0);
for q = 1:numel(fig.panels)
    p = fig.panels(q);
    o = p.options;
    what = strings(1, 0);
    sortLat = isfield(o, 'rasterSort') && o.rasterSort == "latency";
    switch p.type
        case "raster"
            if o.firstSpike.enabled; what(end+1) = "marks"; end %#ok<AGROW>
            if sortLat; what(end+1) = "sort"; end %#ok<AGROW>
        case "psth"
            if o.latencyBox.enabled && o.display ~= "heatmap"; what(end+1) = "box plot"; end %#ok<AGROW>
        case "heatmap"
            if o.rows == "trials" && sortLat; what(end+1) = "sort"; end %#ok<AGROW>
    end
    if isfield(o, 'onsetLine') && o.onsetLine ~= "off"; what(end+1) = "onset line"; end %#ok<AGROW>
    if ~isempty(what); parts(end+1) = p.id + " (" + strjoin(what, ", ") + ")"; end %#ok<AGROW>
end
s = "One block for the whole figure, found once per unit and alignment: ";
if isempty(parts)
    s = s + "no panel reads it yet (a raster's First spike marks or Sort rows by latency, a PSTH's Latency box, a " + ...
        "heat map of trials sorted by latency, an Onset line).";
else
    s = s + "read by " + strjoin(parts, ", ") + ".";
end
end


function txt = probeNote(obj, k)
%probeNote  What the active dataset gives probe figure K, under the Probe layout rows: its tiles and what is left out.
%   "23 tiles: 23 units on 2 shanks; 3 left out (1 without a position, 2
%   over 3 per site)." (private/probeTileCount, counted once per edit),
%   "Scan and pick a dataset to count the tiles." with none open, or why
%   they cannot be counted.
try
    P = probeTileCount(obj, obj.Config.figureFor(k));
    txt = P.note;
catch ME
    txt = "Cannot count the tiles: " + string(ME.message);
end
end


function txt = sessionNote(fig, kind)
%sessionNote  What a session figure draws, under the Sessions rows (and what it cannot hold).
ss = fig.sessions;
switch kind
    case "unit"
        if ss.match == "mapping"
            what = "each cell of the mapping file";
        else
            what = "each recording channel with a unit (a site)";
        end
    case "channel"
        what = "each recording channel";
    otherwise
        what = "the datasets together";
end
txt = "Generate selected figure and Run draw it once across the datasets, for " + what + ", not per dataset. Auto preview is off for it.";
bad = intersect(string([fig.panels.type]), EphysAnalysisConfig.FigureSessionUnmerged);
if isempty(fig.panels); bad = strings(1, 0); end
if ~isempty(bad)   % by their labels: "probe map, unit correlation panels"
    PT = EphysAnalysisConfig.panelTypes();
    words = PT.Label(ismember(PT.Type, bad)).';
    up = words == upper(words);
    words(~up) = lower(words(~up));
    txt = txt + " Not merged across sessions: " + strjoin(words, ", ") + " panels.";
end
end


function t = followsText(L, kind, ob)
%followsText  What a layer that follows the observation draws, in words (the mockup's notes).
spike = ismember(L.source, EphysAnalysisConfig.SpikeSources);
switch kind
    case "unit"
        if spike
            if ob.data == L.source
                t = "Draws the observed unit.";
            elseif L.source == "detected"
                t = "Draws the detections on the observed unit's channel.";
            else
                t = "Draws the sorted units on the observed channel.";
            end
        elseif L.source == "AUX"
            t = "AUX has no recording channel: bind it to fixed channels.";
        else
            t = "Draws the observed unit's own " + L.source + " channel.";
        end
    case "channel"
        if spike
            t = "Draws the observed channel's " + ternary(L.source == "detected", "detections.", "sorted units.");
        elseif L.source == ob.data
            t = "Draws the observed channel.";
        elseif L.source == "AUX" || ob.data == "AUX"
            t = "AUX has no recording channel: bind it to fixed channels.";
        else
            t = "Draws the same channel number in the " + L.source + " extract.";
        end
    otherwise
        t = "The figure observes the dataset: a following layer has nothing to follow. Bind it to fixed items.";
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
