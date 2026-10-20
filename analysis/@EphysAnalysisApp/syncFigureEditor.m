function syncFigureEditor(obj)
%syncFigureEditor  Show, enable and list the figure editor's rows for the selected figure, panel and layer.
%   What shows (rows a section does not use are hidden, and so is a
%   section left with none: layoutFigureEditor):
%     Observations   under Observe, the unit filter for sorted units or
%                    detected spikes (classes and quality for sorted units;
%                    the response test's rows, its auROC rows with the
%                    auROC test), the channels for a signal, nothing more
%                    for the dataset
%     Arrangement    the selected panel's rows once there is one (Align in
%                    cell's drop-downs enabled each way the panel is
%                    smaller than its cell)
%     Panel, Panel alignment, Layers, Options   with a panel selected;
%                    Group shown for the one-group types (heat map, unit
%                    correlation); the Y axis row's side grayed out on a
%                    stacked PSTH (a y axis on each side); Panel alignment's rows grayed out (they
%                    show the figure's) while "Same as the figure" is
%                    ticked, and, with a note, for a type not aligned to
%                    events; its trial selection rows grayed out while
%                    "Trial selection as the figure" is ticked; its Apply
%                    to all panels only while the panel has its own,
%                    Re-link all panels while any panel has its own
%                    event, window or selection; Options' Apply to all
%                    panels while another panel has one of its shared
%                    rows (sharedFieldsOf) or is of its type
%     Event reference, Epoch window, Trial selection   unless every panel
%                    of the figure is one not aligned to events
%     Layers         the picked layer's rows by its source and binding:
%                    what a following layer draws; a fixed spike layer's
%                    unit rows, a fixed signal layer's channels, the
%                    aggregate on a raster, PSTH or continuous panel; an
%                    events layer's line, edge, sequence and how it is
%                    drawn (a mark's look for marks, the color and span
%                    line for a span; Draw as grayed out on an event-trace
%                    panel, which offers a train only on a raster, PSTH or
%                    heat map); the color and line style but for marks
%                    and spans
%     Options        the panel type's own (titled "<Type> options"); a heat
%                    map of a signal has no bins or measure; a PSTH's or a
%                    spike heat map's auROC rows with the auroc baseline
%                    (the test row with a per-unit test); a PSTH's display,
%                    its trace rows (PSTH as, fill, stack, y limits) or,
%                    drawn as a heat map, its colormap and color limits;
%                    a continuous panel's trials (and at most, enabled
%                    unless off); a heat map's rows, its raster sort
%                    rows for trials (and neither row order nor Group
%                    shown then);
%                    a rate panel's display; a tuning panel's parameter
%                    and series; a waveforms panel's layout; a spectral
%                    panel's Chronux rows (tapers, TW / K or W / p enabled
%                    by the taper mode, pad, frequency range, detrend; a
%                    spectrum's and a coherence panel's time base, its range
%                    and segment on "segments", the error and its p-value,
%                    the spike rate with a spike layer; the scale of a
%                    spectrum or spectrogram; a spectrogram's moving window,
%                    baseline, color limits and group; a coherence panel's
%                    over-time box, its phase box or, over time, the moving
%                    window, color limits and group); an event-trace
%                    panel's rows (the bar outline with bars, the level
%                    line with a line, the group bands with a sub-row per
%                    epoch, the baseline's look with a baseline)
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
%   What is enabled: the binding only where a layer may follow the
%   observation (figureEditorChoices: Bindable; otherwise it shows Fixed),
%   the train only on a raster, PSTH or heat map, the response test's rows
%   with Responsive only, the baseline window with a baseline, the fill
%   opacity when filled, the sort event with "event", the
%   waveform's rows when it is not Off, the bins of a unit
%   correlation for its peak rate, the mask with a stop event, the stack
%   spacing when stacked, the error and legend rows with their boxes, each
%   Move button when the panel has a same-shaped neighbor that way, and
%   the list buttons; Up and Down when the figure has a neighbor that way in
%   its group of the tree. The schematic is redrawn (drawFigureSchematic),
%   and the preview outlines the selected panel (markFigurePanel).
E = obj.FigureEditor;
S = obj.FigureSections;
k = obj.SelectedFigure;
nf = numel(obj.Config.Figures);
has = k >= 1 && k <= nf;
onoff = @(tf) matlab.lang.OnOffSwitchState(tf);
en = @(c, tf) set(c, 'Enable', onoff(tf));
set([obj.RemoveFigureButton obj.DuplicateFigureButton], 'Enable', onoff(has));
obj.CopyFigureButton.Enable = onoff(has && nf > 1);
if ~isempty(obj.FigureGenerateButton)
    obj.FigureGenerateButton.Enable = onoff(has && ~obj.Running);   % off while a run (or a generate) goes
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
    obj.layoutFigureEditor();
    obj.drawFigureSchematic();
    return
end
fig = obj.Config.Figures(k);
PT = EphysAnalysisConfig.panelTypes();
np = numel(fig.panels);
j = obj.SelectedPanel;
hasPanel = j >= 1 && j <= np;
kind = EphysAnalysisConfig.observeKind(fig);
spikes = EphysAnalysisConfig.SpikeSources;
signals = EphysAnalysisConfig.SignalSources;
plural = @(n, w) sprintf("%d %s%s", n, w, repmat('s', 1, n ~= 1));
E.summary.Text = plural(fig.grid.rows, "row") + " x " + plural(fig.grid.cols, "column") + ", " + plural(np, "panel") + "; per " + kind;
aligned = false(1, np);
for q = 1:np
    row = PT.Type == fig.panels(q).type;
    aligned(q) = any(row) && PT.Aligned(row);
end

v = struct();
for f = ["id" "title" "enabled" "summary" "observe" "sesEnabled" "obsPerGroup" "obsCount" "schematic" "newPanel" "spacing" ...
        "fontSize" "lineWidth" "colormap" "sortDepth" "labelDepth" "showSEM" "legendLoc" "errType" "errFace" "errEdge" "looksText"]
    v.(f) = true;   % the rows every figure shows
end
% observations
unit = kind == "unit";
sorted = fig.observe.data == "units";
respAuroc = unit && string(E.obsRespTest.Value) == "auroc";
v.obsClasses = sorted; v.obsQuality = sorted;
v.obsResponse = unit; v.obsRespBaseFrom = unit; v.obsRespParam = unit;
v.obsRaMethod = respAuroc; v.obsRaWinMs = respAuroc; v.obsRaCutoff = respAuroc;
v.obsRaTest = respAuroc && string(E.obsRaCutoff.Value) == "test";
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
v.obsPerGroup = ~ses;   % a session figure's trial groups follow its Trial groups
E.sesNote.Text = sessionNote(fig, kind);
% arrangement and panel
v.selPanel = hasPanel; v.noPanel = ~hasPanel;
v.rowSpan = hasPanel; v.colSpan = hasPanel; v.rowHeight = hasPanel; v.colWidth = hasPanel; v.panelButtons = hasPanel;
v.panelWidth = hasPanel; v.panelAlign = hasPanel;
en(E.panelAlign, E.panelWidth.Value < 100);   % where it sits only matters when it is smaller than its cell
en(E.panelVAlign, E.panelHeight.Value < 100);
v.panelType = hasPanel; v.panelTitle = hasPanel; v.panelBox = hasPanel; v.panelXLabel = hasPanel; v.panelYLabel = hasPanel;
v.group = false;
% layers and options: off unless the panel uses them
layerKeys = ["layerList" "layerAdd" "layerNote" "layerName" "layerSource" "layerBinding" "layerFollows" "layerClasses" ...
    "layerIds" "layerQuality" "layerMaxUnits" "layerShanks" "layerUnitChannels" "layerChannels" "layerAggregate" "evLine" ...
    "evEdge" "evSeqText" "evDrawAs" "evMarker" "evColor" "evSpanStyle" "layerColor" "layerLineStyle"];
optionKeys = ["binMs" "smoothMs" "measure" "baselineMode" "baseFrom" "rasterSort" "sortLine" "sortSeqText" "rasterByGroup" "yTicks" "tickColor" "backColor" ...
    "maskAfterStop" "psthDisplay" "histStyle" "fill" "normalize" "contDisplay" "statistic" "errorType" "stackSpacing" "order" ...
    "value" "metric" "correlation" "fisherZ" "yLim" "cLim" "panelColormap" "waveMode" "waveLocation" "waveScale" "wavePP" ...
    "optApplyAll" "auMethod" "auWinMs" "auModFrom" "auCutoff" "auTest" "auMarks" "stack" "param" "rateDisplay" "waveLayout" ...
    "contTrials" "heatRows" "spTimeBase" "spRangeFrom" "spSegment" "spTaperMode" "spTW" "spW" "spPad" "spFmin" "spErr" ...
    "spDetrend" "spScale" "spSpikeFs" "spOverTime" "spWin" "spShowPhase" "etDisplay" "etTrials" "etColorBy" "etHeight" ...
    "etEdge" "etMinWidth" "etLineStyle" "etBaseline" "etBaseStyle" "etRowSpacing"];
noteKeys = ["annText" "annPlace" "annX" "annAlign" "annRotation" "annFont" "annBold" "annColor" "annInterp"];
overlayKeys = ["ovList" "ovName" "ovKind" "ovValue" "ovFrom" "ovLayer" "ovColor" "ovFill" "ovEdge" "ovStyle"];
for f = [layerKeys optionKeys noteKeys overlayKeys]; v.(f) = false; end
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
        v.group = PT.OneGroup(row);
    end
    on = [p.layers.enabled];
    first = "";
    if any(on); first = p.layers(find(on, 1)).source; end
    pointHeat = t == "heatmap" && ~ismember(first, signals);
    rowsNow = string(E.heatRows.Value);   % a heat map's rows: its units / channels, or one unit's epochs
    trialHeat = t == "heatmap" && rowsNow == "trials";
    ch = figureEditorChoices(t, first);

    % layers
    nl = numel(p.layers);
    labels = strings(1, nl);
    for i = 1:nl; labels(i) = layerLabel(p.layers(i)); end
    if ~isequal(string(E.layerList.Items), labels)
        if nl == 0
            set(E.layerList, "Items", {}, "ItemsData", []);
        else
            set(E.layerList, "Items", cellstr(labels), "ItemsData", 1:nl, "Value", min(max(obj.SelectedLayer, 1), nl));
        end
    end
    v.layerList = true; v.layerAdd = true;
    multi = known && PT.MultiLayer(row);
    v.layerNote = ~multi && nl > 1;
    if v.layerNote
        E.layerNote.Text = "A " + lower(typeLabel) + " panel draws one layer: only the first enabled one is drawn.";
    end
    i = obj.SelectedLayer;
    if i >= 1 && i <= nl
        L = p.layers(i);
        lc = figureEditorChoices(t, L.source, rowsNow);
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
        v.layerAggregate = fixed && (isSpike || isSignal) && ismember(t, ["raster" "psth" "continuous" "rate" "tuning"]);
        v.evLine = L.source == "events"; v.evEdge = v.evLine; v.evSeqText = v.evLine; v.evDrawAs = v.evLine;
        v.evMarker = marks; v.evColor = marks || span; v.evSpanStyle = span;
        v.layerColor = ~(marks || span); v.layerLineStyle = v.layerColor;
        if ~lc.Bindable; E.layerBinding.Value = "fixed"; end
        en(E.layerBinding, lc.Bindable);
        en(E.layerQuality, L.source == "units");
        drawAsChoices(E.evDrawAs, t);
        en(E.evDrawAs, ~onTrace);
        what = "unit";
        if isSignal; what = "channel"; end
        set(E.layerAggregate, "Items", ["each " + what "their mean"], "ItemsData", ["each" "mean"]);
        E.layerFollows.Text = followsText(L, kind, fig.observe);
    end
    en([E.removeLayer], i >= 1 && i <= nl);
    en(E.layerUp, i > 1 && i <= nl);
    en(E.layerDown, i >= 1 && i < nl);
    en(E.addLayer, ~isempty(ch.Sources));

    % options
    v.binMs = t == "psth" || pointHeat || t == "corrmap"; v.smoothMs = v.binMs;
    v.measure = t == "psth" || pointHeat || ismember(t, ["rate" "tuning"]);
    v.baselineMode = ismember(t, ["psth" "continuous" "heatmap" "corrmap" "rate" "tuning"]); v.baseFrom = v.baselineMode;
    psthHeat = t == "psth" && string(E.psthDisplay.Value) == "heatmap";   % a PSTH drawn as a heat map: no trace rows
    v.psthDisplay = t == "psth";
    v.stack = t == "psth" && ~psthHeat;
    v.param = t == "tuning";
    v.rateDisplay = t == "rate";
    v.waveLayout = t == "waveforms";
    v.rasterSort = t == "raster" || trialHeat || t == "eventTrace"; v.sortLine = v.rasterSort; v.sortSeqText = v.rasterSort; v.rasterByGroup = v.rasterSort;
    v.yTicks = t == "raster"; v.tickColor = v.yTicks; v.backColor = v.yTicks;
    v.heatRows = t == "heatmap";
    v.contTrials = t == "continuous";
    en(E.maxTrials, string(E.contTrials.Value) ~= "off");
    v.maskAfterStop = ismember(t, ["raster" "psth"]) || pointHeat;
    v.histStyle = t == "psth" && ~psthHeat; v.fill = v.histStyle; v.normalize = t == "psth";
    v.contDisplay = t == "continuous"; v.statistic = v.contDisplay; v.errorType = v.contDisplay; v.stackSpacing = v.contDisplay;
    v.order = t == "heatmap" && ~trialHeat;
    et = t == "eventTrace";   % an event-trace panel's rows; those its display or trials do not use stay grayed out
    v.etDisplay = et; v.etTrials = et; v.etColorBy = et; v.etHeight = et; v.etEdge = et; v.etMinWidth = et; v.etLineStyle = et;
    v.etBaseline = et; v.etBaseStyle = et; v.etRowSpacing = et;
    bars = string(E.etDisplay.Value) == "bars";
    en([E.etEdge E.etEdgeWidth E.etMinWidth], bars);
    en([E.etLineStyle E.etLineWidth], ~bars);
    en(E.etGroupBands, string(E.etTrials.Value) == "rows");
    en([E.etBaseColor E.etBaseStyle E.etBaseWidth], E.etBaseline.Value);
    if trialHeat; v.group = false; end   % a heat map of trials draws every group
    v.value = t == "probemap";
    v.metric = t == "corrmap"; v.correlation = v.metric; v.fisherZ = v.metric;
    v.yLim = ismember(t, ["psth" "continuous" "waveforms" "rate" "tuning" "spectrum"]) && ~psthHeat;
    v.cLim = ismember(t, ["heatmap" "probemap" "corrmap" "spectrogram"]) || psthHeat;
    v.panelColormap = psthHeat;
    % the spectral panels: the Chronux tab's rows
    spectral = ismember(t, ["spectrum" "spectrogram" "coherence"]);
    overTime = t == "coherence" && logical(E.spOverTime.Value);   % a coherogram: an image of one group over time
    v.spTimeBase = ismember(t, ["spectrum" "coherence"]);
    ranged = v.spTimeBase && string(E.spTimeBase.Value) == "range";
    v.spRangeFrom = ranged; v.spSegment = ranged && ~overTime;
    v.spTaperMode = spectral; v.spTW = spectral; v.spW = spectral; v.spPad = spectral; v.spFmin = spectral; v.spDetrend = spectral;
    en([E.spTW E.spK], string(E.spTaperMode.Value) == "TWK");
    en([E.spW E.spP], string(E.spTaperMode.Value) == "Wp");
    v.spErr = ismember(t, ["spectrum" "coherence"]) && ~overTime;
    en(E.spErrP, string(E.spErr.Value) ~= "none");
    v.spScale = ismember(t, ["spectrum" "spectrogram"]);
    v.spSpikeFs = ismember(t, ["spectrum" "coherence"]) && any(ismember([p.layers.source], spikes));
    v.spOverTime = t == "coherence";
    v.spWin = t == "spectrogram" || overTime;
    v.spShowPhase = t == "coherence" && ~overTime;
    if t == "coherence"
        v.yLim = ~overTime;
        v.cLim = overTime;
        v.group = overTime;
    end
    if t == "spectrogram"; v.baselineMode = true; v.baseFrom = true; end
    v.waveMode = ismember(t, ["raster" "psth" "waveforms" "tuning"]); v.wavePP = v.waveMode;
    v.waveLocation = ismember(t, ["raster" "psth" "tuning"]); v.waveScale = v.waveLocation;
    if v.baselineMode; offerItems(E.baselineMode, ch.BaselineModes); end
    en([E.baseFrom E.baseTo], string(E.baselineMode.Value) ~= "none");
    auOn = (t == "psth" || pointHeat) && string(E.baselineMode.Value) == "auroc";   % the panel's auROC settings
    v.auMethod = auOn; v.auWinMs = auOn; v.auModFrom = auOn; v.auCutoff = auOn; v.auMarks = auOn;
    v.auTest = auOn && string(E.auCutoff.Value) == "test";
    en(E.auStepMs, string(E.auWindows.Value) == "sliding");
    en(E.auThreshold, string(E.auCutoff.Value) == "fixed");
    en(E.auResamples, string(E.auTest.Value) ~= "ranksum");
    en([E.auMarks E.auModOnly], string(E.auCutoff.Value) ~= "none");
    en(E.psthSpacing, E.stack.Value);
    en(E.panelYSide, ~(t == "psth" && ~psthHeat && E.stack.Value));   % a stacked PSTH has a y axis on each side
    en(E.fillAlpha, E.fill.Value);
    sortOn = ~(t == "eventTrace" && string(E.etTrials.Value) ~= "rows");   % an event trace sorts its sub-rows only
    en([E.rasterSort E.rasterSortOrder E.rasterByGroup], sortOn);
    en([E.sortLine E.sortEdge E.sortSeqText E.sortSeqEdit], sortOn && strtrim(string(E.rasterSort.Value)) == "event");
    en([E.waveSpikes E.waveLocation E.waveBox E.waveScale E.wavePP E.waveCount], string(E.waveMode.Value) ~= "off");
    en([E.binMs E.smoothMs], t ~= "corrmap" || string(E.metric.Value) == "peak");
    stop = obj.FigureAlignControls.StopOn.Value;
    if isstruct(p.window); stop = obj.PanelAlignControls.StopOn.Value; end
    en(E.maskAfterStop, stop);
    en(E.stackSpacing, string(E.contDisplay.Value) == "stacked");
    % Apply to all panels: another panel of the type, or one with a row this panel shares (sharedFieldsOf)
    cf = EphysAnalysisConfig.sharedFieldsOf(t);
    to = false;
    for q = [1:j-1, j+1:np]
        tq = fig.panels(q).type;
        to = to || tq == t || any(ismember(cf, EphysAnalysisConfig.sharedFieldsOf(tq)));
    end
    v.optApplyAll = known;
    en(E.optApplyAll, to);

    % the panel's own alignment
    modes = "fixed";
    if ismember(t, ["corrmap" "rate" "tuning"]); modes = ["fixed" "between"]; end
    setWindowModes(obj.PanelAlignControls.Mode, modes);
    C2 = obj.PanelAlignControls;
    unlinked = paligned && ~E.panelSame.Value;   % linked ("Same as the figure"): the rows show the figure's, locked
    ctl = findobj([C2.RefGrid C2.WindowGrid], '-property', 'Enable');
    set(ctl, 'Enable', onoff(unlinked));
    if unlinked; syncAlignEnable(C2); end
    ownSel = paligned && ~E.panelSameSel.Value;   % linked ("Trial selection as the figure"): the figure's, locked
    set(findobj(C2.SelectionGrid, '-property', 'Enable'), 'Enable', onoff(ownSel));
    en(E.panelSame, paligned);
    en(E.panelSameSel, paligned);
    en(E.alignApplyAll, unlinked || ownSel);
    E.palignNote.Text = "";
    if ~paligned
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

    % moving and removing
    for d = ["up" "down" "left" "right"]
        [~, moved] = EphysAnalysisConfig.movePanel(fig, p.id, d);
        en(E.("move" + upper(extractBefore(d, 2)) + extractAfter(d, 1)), moved);
    end
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
pg.RowHeight = {note, 30, hs(1), hs(2), 22, hs(3)};
S(names == "palign").BodyHeight = note + 30 + hs(1) + hs(2) + 22 + hs(3) + 5 * pg.RowSpacing;

% appearance
types = strings(1, 0);
if np > 0; types = [fig.panels.type]; end
v.siteSize = any(types == "probemap");
psthHeats = arrayfun(@(q) q.type == "psth" && isfield(q.options, 'display') && q.options.display == "heatmap", fig.panels);
v.heatColormap = any(ismember(types, ["heatmap" "probemap" "corrmap"])) || any(psthHeats);
errOn = logical(E.showSEM.Value);
en(E.errType, errOn);
en(E.errResamples, errOn && string(E.errType.Value) == "ci95");
en([E.errFace E.errAlpha E.errEdge], errOn);
en([E.errEdgeStyle E.errEdgeWidth], errOn && lower(strtrim(string(E.errEdge.Value))) ~= "none");
en([E.legendLoc E.legendOrient E.legendBox], E.legend.Value);

% observations' enables
respOn = logical(E.obsResponse.Value);
en([E.obsRespTest E.obsRespDirection E.obsRespBaseFrom E.obsRespBaseTo E.obsRespFrom E.obsRespTo E.obsRespParam ...
    E.obsRespCorrection E.obsRespAlpha E.obsRaMethod E.obsRaWindows E.obsRaWinMs E.obsRaBinMs E.obsRaCutoff E.obsRaTest], respOn);
en(E.obsRaStepMs, respOn && string(E.obsRaWindows.Value) == "sliding");
en(E.obsRaThreshold, respOn && string(E.obsRaCutoff.Value) == "fixed");
en(E.obsRaResamples, respOn && string(E.obsRaTest.Value) ~= "ranksum");
n = numel(fig.aesthetics);
E.looksText.Text = sprintf("%d remembered look(s); right-click the preview to edit.", n);
en(E.looksForget, n > 0);

for f = string(fieldnames(v)).'
    S = formShow(S, f, v.(f));
end
for i = 1:numel(S)
    switch names(i)
        case {"panel" "palign" "layers" "options" "note" "overlays"}
            S(i).Visible = hasPanel;
        case {"ref" "window" "selection"}
            S(i).Visible = np == 0 || any(aligned);
        otherwise
            S(i).Visible = true;
    end
end
S(names == "options").Title = optionsTitle;
S(names == "note").Title = "Text note";
S(names == "overlays").Title = "Overlays";
if hasPanel
    S(names == "note").Title = "Text note on " + fig.panels(j).id;
    S(names == "overlays").Title = "Overlays on " + fig.panels(j).id;
    if nOv > 0; S(names == "overlays").Title = "Overlays (" + nOv + ") on " + fig.panels(j).id; end
end
S(names == "layers").Title = "Layers";
if hasPanel && ~isempty(fig.panels(j).layers)
    S(names == "layers").Title = "Layers (" + numel(fig.panels(j).layers) + ") of " + fig.panels(j).id;
end
obj.FigureSections = S;
syncAlignEnable(obj.FigureAlignControls);
if ~isempty(obj.FiguresDatasetDropDown) && isvalid(obj.FiguresDatasetDropDown)
    obj.FiguresDatasetDropDown.Enable = onoff(~ses);   % a session figure is drawn across the datasets, not on the active one
end
obj.layoutFigureEditor();
obj.drawFigureSchematic();
obj.markFigurePanel();   % the preview outlines the selected panel
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
txt = "Generate and Run draw it once across the datasets, for " + what + ", not per dataset. Auto preview is off for it.";
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
