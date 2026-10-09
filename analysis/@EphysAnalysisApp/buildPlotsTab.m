function buildPlotsTab(obj)
%buildPlotsTab  Plot tree, plot editor (collapsible sections) and the preview.
%   The tree groups the plots by plot type, source, layout or status (Group
%   by; refreshPlotList), with the kind to add on its own row; Ctrl- or
%   Shift-click selects several plots, edited together (showPlotSelection
%   puts an amber banner in the editor and a bar of the same colours over
%   the preview). The editor is a column of sections (formSection): the plot's kind, id,
%   title, source and layout, always open; then Units & channels, Event
%   reference, Epoch window (with "Epoch Diagram" under it, the epoch
%   diagram, onShowEpochs), Trial selection (the Alignment tab's values
%   while "Use default" is ticked; editing one gives the plot its own),
%   Bins & baseline, the kind's own options, Appearance and Unit waveform
%   (each unit's mean and / or spikes in its tile) and Text note (a block of
%   descriptive text beside or over the plot), each collapsing under
%   its header (onPlotSectionToggled). syncPlotEditor shows the rows
%   the selected plot uses; layoutPlotEditor packs them.
g = uigridlayout(obj.TabPlots, [1 3]);
g.ColumnWidth = {285, 470, '1x'};
g.Padding = [8 8 8 8];
changed = @(~,~) obj.onConfigChanged("plot");

% --- the plots: a tree under groups ------------------------------------------------------
lg = uigridlayout(g, [7 2]);
lg.RowHeight = {22, 28, '1x', 30, 30, 30, 30};
lg.ColumnWidth = {'1x', '1x'};
lg.Padding = [0 0 0 0];
l = uilabel(lg, "Text", "Plots", "FontWeight", "bold");
l.Layout.Row = 1; l.Layout.Column = [1 2];
l = uilabel(lg, "Text", "Group by:");
l.Layout.Row = 2; l.Layout.Column = 1;
obj.PlotGroupDropDown = uidropdown(lg, "Items", ["Plot type" "Source" "Layout" "Enabled / off" "None"], ...
    "ItemsData", ["kind" "source" "layout" "status" "none"], "Value", "kind", ...
    "ValueChangedFcn", @(~,~) obj.onPlotGroupChanged(), ...
    "Tooltip", "How the tree sorts the plots: by plot type (PSTH, raster, ...), the source they read (units, detected, " + ...
    "LFP, ...), the layout they draw, enabled or off, or a flat list. Within a group the plots keep the run order; " + ...
    "Up / Down move a plot within its group.");
obj.PlotGroupDropDown.Layout.Row = 2; obj.PlotGroupDropDown.Layout.Column = 2;
obj.PlotsTree = uitree(lg, "Multiselect", "on", "SelectionChangedFcn", @(~, evt) obj.onPlotTreeSelected(evt.SelectedNodes), ...
    "NodeExpandedFcn", @(~, evt) obj.onPlotGroupToggled(evt.Node, false), ...
    "NodeCollapsedFcn", @(~, evt) obj.onPlotGroupToggled(evt.Node, true), ...
    "Tooltip", "Click a plot to edit it. Ctrl- or Shift-click to select several: the editor then changes them " + ...
    "all at once (the options they all have), and the preview draws the first one picked.");
obj.PlotsTree.Layout.Row = 3; obj.PlotsTree.Layout.Column = [1 2];
K = EphysAnalysisConfig.plotKinds();
obj.AddKindDropDown = uidropdown(lg, "Items", K.Label, "ItemsData", K.Kind);
obj.AddKindDropDown.Layout.Row = 4; obj.AddKindDropDown.Layout.Column = [1 2];
obj.AddPlotButton = uibutton(lg, "Text", "Add", "ButtonPushedFcn", @(~,~) obj.onAddPlot(obj.AddKindDropDown.Value));
obj.AddPlotButton.Layout.Row = 5; obj.AddPlotButton.Layout.Column = [1 2];
obj.RemovePlotButton = uibutton(lg, "Text", "Remove", "ButtonPushedFcn", @(~,~) obj.onRemovePlot(), ...
    "Tooltip", "Remove the selected plots from the config.");
obj.RemovePlotButton.Layout.Row = 6; obj.RemovePlotButton.Layout.Column = 1;
obj.DuplicatePlotButton = uibutton(lg, "Text", "Duplicate", "ButtonPushedFcn", @(~,~) obj.onDuplicatePlot(), ...
    "Tooltip", "Copy each selected plot under a new id, right after it; the copies are selected.");
obj.DuplicatePlotButton.Layout.Row = 6; obj.DuplicatePlotButton.Layout.Column = 2;
obj.UpPlotButton = uibutton(lg, "Text", "Up", "ButtonPushedFcn", @(~,~) obj.onMovePlot(-1));
obj.UpPlotButton.Layout.Row = 7; obj.UpPlotButton.Layout.Column = 1;
obj.DownPlotButton = uibutton(lg, "Text", "Down", "ButtonPushedFcn", @(~,~) obj.onMovePlot(1));
obj.DownPlotButton.Layout.Row = 7; obj.DownPlotButton.Layout.Column = 2;

% --- the editor ----------------------------------------------------------------------
ep = uipanel(g, "Title", "Plot");
obj.PlotEditorPanel = ep;
eg = uigridlayout(ep, [11 1]);
eg.RowHeight = [repmat({0}, 1, 10) {'1x'}];
eg.RowSpacing = 6;
eg.Padding = [4 4 4 4];
eg.Scrollable = "on";
obj.PlotEditorGrid = eg;
E = struct();

% the plot: always open
S = formSection(eg, 1, "general", "");
[S, r] = formRow(S, ["kind" "enabled"], "Kind:");
kg = subgrid(S.Body, r, {'1x', 'fit'});
E.kind = uilabel(kg, "Text", "", "FontWeight", "bold");
E.enabled = uicheckbox(kg, "Text", "Enabled", "ValueChangedFcn", changed, ...
    "Tooltip", "Unticked, the plot stays in the config but is not run.");
[S, r] = formRow(S, "note", "", 30);
E.note = uilabel(S.Body, "Text", "", "FontColor", [0.35 0.35 0.35], "WordWrap", "on", "VerticalAlignment", "top");
place(E.note, r, [1 2]);
[S, r] = formRow(S, "id", "Id:");
E.id = uieditfield(S.Body, "text", "ValueChangedFcn", changed, "Tooltip", "Unique; names the exported files ({Plot}).");
place(E.id, r, 2);
[S, r] = formRow(S, "title", "Title:");
E.title = uieditfield(S.Body, "text", "Placeholder", "automatic", "ValueChangedFcn", changed);
place(E.title, r, 2);
[S, r] = formRow(S, "source", "Source:");
E.source = uidropdown(S.Body, "Items", "units", "ValueChangedFcn", changed, ...
    "Tooltip", "Sorted units, threshold detections (spike times), or a signal extract.");
place(E.source, r, 2);
[S, r] = formRow(S, "layout", "Layout:");
E.layout = uidropdown(S.Body, "Items", "grid", "ValueChangedFcn", changed);
place(E.layout, r, 2);
sec = S;

% units and channels
S = formSection(eg, 2, "units", "Units & channels");
[S, r] = formRow(S, "classes", "Unit classes:");
cg = subgrid(S.Body, r, repmat({'fit'}, 1, 4));
cg.ColumnSpacing = 12;
E.classes = struct();
for c = ["su" "mua" "uns" "noise"]
    E.classes.(c) = uicheckbox(cg, "Text", c, "Value", ismember(c, ["su" "mua"]), "ValueChangedFcn", changed, ...
        "Tooltip", "Sorted-unit classes drawn (none ticked = every class).");
end
[S, r] = formRow(S, "ids", "Unit ids:");
E.ids = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "Unit ids (sorted units) or channels (detections), e.g. 3 5 8:12.");
place(E.ids, r, 2);
[S, r] = formRow(S, "quality", "Quality:");
E.quality = uicheckbox(S.Body, "Text", "Good units only", "Value", false, "ValueChangedFcn", changed, ...
    "Tooltip", "Keep only the sorted units that meet the good-unit criteria (units.quality in the config: by default ISI violations ratio < 0.5, presence ratio > 0.9, amplitude cutoff < 0.1). The metrics are computed once per sort and cached in its folder.");
place(E.quality, r, 2);
[S, r] = formRow(S, ["response" "respTest" "respDirection"], "Response:");
rg = subgrid(S.Body, r, {'fit', '1x', '1x'});
E.response = uicheckbox(rg, "Text", "Responsive only", "Value", false, "ValueChangedFcn", changed, ...
    "Tooltip", "Keep only the units that respond to the event (responseStats; Statistics and Machine Learning " + ...
    "Toolbox): signrank of the response vs the baseline window's rate over the epochs of the plot's event " + ...
    "and trials, and/or kruskalwallis of the response across a trial parameter's levels; p adjusted over the units.");
E.respTest = uidropdown(rg, "Items", ["vs baseline" "tuned" "either" "both" "auROC"], "ItemsData", ["evoked" "tuning" "either" "both" "auroc"], ...
    "ValueChangedFcn", changed, "Tooltip", "vs baseline: the response window's rate differs from the baseline's " + ...
    "(signrank). tuned: it differs across the parameter's levels (kruskalwallis). either / both of them. " + ...
    "auROC: the auROC calls the unit modulated over the response window (its settings below; every epoch as one group).");
E.respDirection = uidropdown(rg, "Items", ["any" "excited" "suppressed"], "ValueChangedFcn", changed, ...
    "Tooltip", "vs baseline: keep the units whose rate rises (excited), falls (suppressed), or either.");
[S, r] = formRow(S, ["respBaseFrom" "respBaseTo" "respFrom" "respTo"], "Test windows (s):");
wg = subgrid(S.Body, r, {'1x', 'fit', '1x', 'fit', '1x', 'fit', '1x'});
E.respBaseFrom = uieditfield(wg, "numeric", "Value", -0.2, "ValueChangedFcn", changed, "Tooltip", "The test's baseline window start (s from the event).");
uilabel(wg, "Text", "to");
E.respBaseTo = uieditfield(wg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "The test's baseline window end (s).");
uilabel(wg, "Text", "response");
E.respFrom = uieditfield(wg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "The response window start (s from the event).");
uilabel(wg, "Text", "to");
E.respTo = uieditfield(wg, "numeric", "Value", 0.2, "ValueChangedFcn", changed, "Tooltip", "The response window end (s).");
[S, r] = formRow(S, ["respParam" "respCorrection" "respAlpha"], "Test options:");
og = subgrid(S.Body, r, {'1x', 'fit', '1x', 'fit', '1x'});
E.respParam = uidropdown(og, "Editable", "on", "Items", "", "ValueChangedFcn", changed, ...
    "Tooltip", "The trial parameter of the tuning test.");
uilabel(og, "Text", "correction:");
E.respCorrection = uidropdown(og, "Items", ["BH (FDR)" "Holm" "Bonferroni" "none"], "ItemsData", ["bh" "holm" "bonferroni" "none"], ...
    "ValueChangedFcn", changed, "Tooltip", "How the p values are adjusted for the number of units tested (pAdjust).");
uilabel(og, "Text", "alpha:");
E.respAlpha = uieditfield(og, "numeric", "Value", 0.05, "Limits", [0 1], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "A unit passes when its adjusted p is at most alpha.");
[S, E] = aurocRows(S, E, "ra", changed, false);
[S, r] = formRow(S, "maxUnits", "Max units:");
E.maxUnits = uieditfield(S.Body, "text", "Value", "Inf", "ValueChangedFcn", changed);
place(E.maxUnits, r, 2);
[S, r] = formRow(S, "shanks", "Shanks:");
E.shanks = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed);
place(E.shanks, r, 2);
[S, r] = formRow(S, "channels", "Channels:");
E.channels = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "Units / detections: recording channels kept. Signals: the extract's columns drawn.");
place(E.channels, r, 2);
sec(end+1) = S;

% event reference, window and selection: the Alignment tab's controls
Sr = formSection(eg, 3, "ref", "Event reference", "panel");
Sw = formSection(eg, 4, "window", "Epoch window", "panel");
Ss = formSection(eg, 5, "selection", "Trial selection", "panel");
E.defaultRef = defaultBox(obj, Sr, "event reference");
E.defaultWindow = defaultBox(obj, Sw, "epoch window");
E.defaultSelection = defaultBox(obj, Ss, "trial selection");
C = obj.buildAlignControls([Sr.Body Sw.Body Ss.Body], @(part) obj.onPlotAlignEdited(part));
E.epochs = C.Diagram;
E.epochs.ButtonPushedFcn = @(~,~) obj.onShowEpochs("plot");
E.epochs.Tooltip = "A window, kept above the app, that draws how this plot's event reference, epoch window and trial " + ...
    "selection cut the active dataset into epochs: the digital lines as TTL traces, each event (time 0), each " + ...
    "epoch's window, and the epochs dropped and why. It follows every edit.";
set([C.RefGrid C.WindowGrid C.SelectionGrid], 'Padding', [4 2 4 2]);
Sr.BodyHeight = gridHeight(C.RefGrid);
Sw.BodyHeight = gridHeight(C.WindowGrid);
Ss.BodyHeight = gridHeight(C.SelectionGrid);
obj.PlotAlignControls = C;
sec = [sec Sr Sw Ss];

% bins and baseline
S = formSection(eg, 6, "bins", "Bins & baseline");
[S, r] = formRow(S, "binMs", "Bin (ms):");
E.binMs = uieditfield(S.Body, "numeric", "Value", 10, "Limits", [0.001 Inf], "ValueChangedFcn", changed);
place(E.binMs, r, 2);
[S, r] = formRow(S, "smoothMs", "Smooth (ms):");
E.smoothMs = uieditfield(S.Body, "numeric", "Value", 10, "Limits", [0 Inf], "ValueChangedFcn", changed, ...
    "Tooltip", "Gaussian SD; 0 = none.");
place(E.smoothMs, r, 2);
[S, r] = formRow(S, "maskAfterStop", "");
E.maskAfterStop = uicheckbox(S.Body, "Text", "Mask after the stop event", "ValueChangedFcn", changed, ...
    "Tooltip", "Drop each epoch's bins from its stop event on (the Epoch window's): the mean then covers the epochs still going.");
place(E.maskAfterStop, r, [1 2]);
[S, r] = formRow(S, "measure", "Measure:");
E.measure = uidropdown(S.Body, "Items", ["rate" "count" "probability"], "ValueChangedFcn", changed, ...
    "Tooltip", "rate: spikes/s; count: spikes per bin (or epoch window); probability: the share of epochs with a spike in the bin (or window).");
place(E.measure, r, 2);
[S, r] = formRow(S, "baselineMode", "Baseline:");
E.baselineMode = uidropdown(S.Body, "Items", "none", "ValueChangedFcn", changed, ...
    "Tooltip", "subtract / zscore / percent / ratio: against the baseline window's rate. auroc (PSTH, heatmap of " + ...
    "spikes): each window's auROC against the baseline, 0.5 = no change, above = more firing (Cohen et al. 2012; " + ...
    "Macedo-Lima et al. 2024); its settings below.");
place(E.baselineMode, r, 2);
[S, r] = formRow(S, ["baseFrom" "baseTo"], "Baseline (s):");
bg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.baseFrom = uieditfield(bg, "numeric", "Value", -0.2, "ValueChangedFcn", changed, "Tooltip", "Baseline window start (s from the event).");
uilabel(bg, "Text", "to");
E.baseTo = uieditfield(bg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "Baseline window end (s).");
[S, E] = aurocRows(S, E, "a", changed, true);
sec(end+1) = S;

% the kind's own options
S = formSection(eg, 7, "kind", "Options");
[S, r] = formRow(S, "withRaster", "");
E.withRaster = uicheckbox(S.Body, "Text", "Raster above each PSTH", "Value", true, "ValueChangedFcn", changed);
place(E.withRaster, r, [1 2]);
[S, r] = formRow(S, ["rasterSort" "rasterSortOrder"], "Sort raster by:");
rsg = subgrid(S.Body, r, {'1x', 110});
E.rasterSort = uidropdown(rsg, "Editable", "on", "Items", ["" "stop"], "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "The order of the raster's epochs: blank = trial (time) order; stop = the stop " + ...
    "event's latency; or a trial parameter. Missing values go last; ties keep the trial order.");
E.rasterSortOrder = uidropdown(rsg, "Items", ["ascending" "descending"], "Value", "ascending", "ValueChangedFcn", changed, ...
    "Tooltip", "The sort's direction (descending with a blank sort: the last trial on top). Missing values stay last.");
[S, r] = formRow(S, "rasterByGroup", "");
E.rasterByGroup = uicheckbox(S.Body, "Text", "Raster rows by group first (one band per group)", "Value", true, ...
    "ValueChangedFcn", changed, "Tooltip", "Ticked: each group's epochs together on a band of its colour, sorted " + ...
    "within it. Unticked: every epoch sorted as one block, each row on its group's colour.");
place(E.rasterByGroup, r, [1 2]);
[S, r] = formRow(S, ["markLines" "markEdge" "markScope"], "Mark events:");
mg = subgrid(S.Body, r, {'1x', 80, 80});
E.markLines = uieditfield(mg, "text", "Placeholder", "lines, e.g. Trough", "ValueChangedFcn", changed, ...
    "Tooltip", "Digital lines whose events are marked on each raster row, e.g. Trough (beam breaks) or a lick " + ...
    "line; several separated by spaces or commas. Every event in the epoch is marked, so a trial with several " + ...
    "crossings gets several marks. Right-click a mark to change its look per line.");
E.markEdge = uidropdown(mg, "Items", ["onset" "offset" "both"], "Value", "onset", "ValueChangedFcn", changed, ...
    "Tooltip", "Mark each event's onset, offset, or both (each its own mark).");
E.markScope = uidropdown(mg, "Items", ["window" "trial"], "Value", "window", "ValueChangedFcn", changed, ...
    "Tooltip", "window: every event inside the epoch's window; trial: only those inside the epoch's own trial " + ...
    "(a sequence's: those whose sequence started in the epoch's trial).");
[S, r] = formRow(S, ["markSeqText" "markSeqEdit"], "Mark sequences:");
msg = subgrid(S.Body, r, {'1x', 70});
E.markSeqText = uilabel(msg, "Text", "none");
setSequenceHolder(E.markSeqText, repmat(EphysAnalysisConfig.defaults("EventRef"), 1, 0));
E.markSeqEdit = uibutton(msg, "Text", "Edit...", "Tooltip", "Mark events defined by a sequence on each raster row, " + ...
    "e.g. Trial offset then Trough onset: the first Trough onset after each trial's end.");
E.markSeqEdit.ButtonPushedFcn = @(~,~) obj.editSequence(E.markSeqText, "marks", obj.PlotAlignControls.Line, [], ...
    @() obj.onConfigChanged("plot"));
[S, r] = formRow(S, ["markMarker" "markSize" "markColor"], "Mark look:");
mlg = subgrid(S.Body, r, {'1x', 'fit', 60, '1x'});
markers = PlotAesthetics.catalogue().Marker;
E.markMarker = uidropdown(mlg, "Items", markers.ChoiceLabels(2:end), "ItemsData", markers.Choices(2:end), ...
    "Value", "diamond", "ValueChangedFcn", changed, "Tooltip", "The marker drawn at each event.");
uilabel(mlg, "Text", "size:");
E.markSize = uispinner(mlg, "Limits", [0.5 40], "Step", 1, "Value", 4, "ValueChangedFcn", changed, ...
    "Tooltip", "Marker size, points.");
E.markColor = uidropdown(mlg, "Editable", "on", "Items", ["auto" "black" "red" "blue" "green" "magenta" "cyan"], ...
    "Value", "auto", "ValueChangedFcn", changed, "Tooltip", "auto: a colour per line and edge; or one colour for " + ...
    "every mark (a name or #RRGGBB). The aesthetics editor (right-click) styles each line's marks on its own.");
[S, r] = formRow(S, "histStyle", "PSTH as:");
E.histStyle = uidropdown(S.Body, "Items", ["bar" "line"], "Value", "bar", "ValueChangedFcn", changed, ...
    "Tooltip", "One bar per bin, or a line through the bin centres.");
place(E.histStyle, r, 2);
[S, r] = formRow(S, "normalize", "Normalize:");
E.normalize = uidropdown(S.Body, "Items", ["none" "unit peak" "group peak"], "ItemsData", ["none" "unitPeak" "groupPeak"], ...
    "ValueChangedFcn", changed, "Tooltip", "Divide each unit's PSTHs by their largest peak (unit peak: the groups keep " + ...
    "their sizes), or each PSTH by its own (group peak). The overlay layout normalizes each unit before the mean.");
place(E.normalize, r, 2);
[S, r] = formRow(S, ["fill" "fillAlpha"], "Fill:");
fg = subgrid(S.Body, r, {'fit', 'fit', '1x'});
E.fill = uicheckbox(fg, "Text", "Filled", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Fill the bars, or the area under the line; untick for the bars' outline, or the line alone.");
uilabel(fg, "Text", "opacity:");
E.fillAlpha = uieditfield(fg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "auto", "Limits", [0 1], ...
    "ValueChangedFcn", changed, "Tooltip", "Fill opacity, 0 to 1 (blank: 0.5 where groups overlap, else 1).");
[S, r] = formRow(S, ["stack" "stackSpacing"], "Stack:");
sg = subgrid(S.Body, r, {'fit', 'fit', '1x'});
E.stack = uicheckbox(sg, "Text", "Stack groups", "ValueChangedFcn", changed, ...
    "Tooltip", "One row per group, the first at the bottom; each row's value on the left axis, its peak on the right.");
uilabel(sg, "Text", "spacing:");
E.stackSpacing = uieditfield(sg, "numeric", "Value", 1.1, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "The row step, times the tallest PSTH (1: it just reaches the " + ...
    "next row; below 1 the rows overlap).");
[S, r] = formRow(S, "yParam", "Y value:");
E.yParam = uidropdown(S.Body, "Editable", "on", "Items", ["" "stop"], "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "What each epoch shows: a numeric trial parameter, e.g. RespLatency (as recorded, ms in Epsych2), " + ...
    "or stop: the stop event's latency from the epoch's event, ms (Epoch window, e.g. Trough onset after Stim onset).");
place(E.yParam, r, 2);
[S, r] = formRow(S, "param", "Parameter:");
E.param = uidropdown(S.Body, "Editable", "on", "Items", "", "ValueChangedFcn", changed, "Tooltip", "The trial parameter on the x axis.");
place(E.param, r, 2);
[S, r] = formRow(S, "seriesParam", "Series:");
E.seriesParam = uidropdown(S.Body, "Editable", "on", "Items", "", "ValueChangedFcn", changed, "Tooltip", "One curve per value ("""" = one curve).");
place(E.seriesParam, r, 2);
[S, r] = formRow(S, ["xScale" "jitter"], "X axis:");
xg = subgrid(S.Body, r, {'1x', 'fit'});
E.xScale = uidropdown(xg, "Items", ["evenly spaced" "at their values"], "ItemsData", ["category" "linear"], ...
    "Value", "category", "ValueChangedFcn", changed, "Tooltip", "The x values evenly spaced and labelled, or at " + ...
    "their values on a linear axis (numeric parameters).");
E.jitter = uicheckbox(xg, "Text", "Jitter points", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Points layout: spread the dots sideways (a fixed pattern) so they do not hide each other.");
[S, r] = formRow(S, "value", "Value:");
E.value = uidropdown(S.Body, "Items", ["rate" "nSpikes" "nUnits"], "ValueChangedFcn", changed, "Tooltip", "What colours each site.");
place(E.value, r, 2);
[S, r] = formRow(S, "order", "Row order:");
E.order = uidropdown(S.Body, "Items", ["probe" "peak"], "ValueChangedFcn", changed, ...
    "Tooltip", "probe: the rows follow the Sort options (Appearance); peak: by the time of each row's maximum.");
place(E.order, r, 2);
[S, r] = formRow(S, "metric", "Epoch rate:");
E.metric = uidropdown(S.Body, "Items", ["mean" "peak"], "ValueChangedFcn", changed, ...
    "Tooltip", "Each epoch's mean rate over its window, or its peak binned rate.");
place(E.metric, r, 2);
[S, r] = formRow(S, "correlation", "Correlation:");
E.correlation = uidropdown(S.Body, "Items", ["Pearson" "Spearman"], "ItemsData", ["pearson" "spearman"], ...
    "ValueChangedFcn", changed, "Tooltip", "Pearson's r, or Spearman's rank correlation.");
place(E.correlation, r, 2);
sec(end+1) = S;

% appearance
S = formSection(eg, 8, "style", "Appearance");
[S, r] = formRow(S, "maxTiles", "Tiles per page:");
E.maxTiles = uispinner(S.Body, "Limits", [1 64], "Value", 16, "RoundFractionalValues", "on", "ValueChangedFcn", changed);
place(E.maxTiles, r, 2);
[S, r] = formRow(S, "tileSpacing", "Grid spacing:");
E.tileSpacing = uidropdown(S.Body, "Items", ["loose" "compact" "tight" "none"], "Value", "compact", "ValueChangedFcn", changed, ...
    "Tooltip", "Space between the tiles of a grid (and round it).");
place(E.tileSpacing, r, 2);
[S, r] = formRow(S, "fontSize", "Font size:");
E.fontSize = uispinner(S.Body, "Limits", [5 24], "Value", 9, "ValueChangedFcn", changed);
place(E.fontSize, r, 2);
[S, r] = formRow(S, "lineWidth", "Line width:");
E.lineWidth = uispinner(S.Body, "Limits", [0.25 6], "Step", 0.25, "Value", 1.2, "ValueChangedFcn", changed, ...
    "Tooltip", "PSTH lines and outlines, evoked traces, tuning curves.");
place(E.lineWidth, r, 2);
[S, r] = formRow(S, "siteSize", "Site size:");
E.siteSize = uispinner(S.Body, "Limits", [1 40], "Step", 1, "Value", 8, "ValueChangedFcn", changed, ...
    "Tooltip", "Probe map: size of the plotted sites (points).");
place(E.siteSize, r, 2);
[S, r] = formRow(S, "ylim", "Y limits:");
E.ylim = uieditfield(S.Body, "text", "Placeholder", "auto, or e.g. 0 40", "ValueChangedFcn", changed, ...
    "Tooltip", "The rate or amplitude axis (a PSTH's, not its raster's).");
place(E.ylim, r, 2);
[S, r] = formRow(S, "colormap", "Group colours:");
E.colormap = uidropdown(S.Body, "Editable", "on", "Items", ["lines" "parula" "turbo" "jet" "hot" "cool" "gray" "black"], ...
    "Value", "lines", "ValueChangedFcn", changed, ...
    "Tooltip", "lines: the trial selection's colours (parula for a numeric parameter with more than two values); " + ...
    "a colormap function; or one colour for every group (a name or #RRGGBB).");
place(E.colormap, r, 2);
[S, r] = formRow(S, "heatColormap", "Heat colours:");
E.heatColormap = uidropdown(S.Body, "Items", ["auto" "parula" "turbo" "hot" "gray" "jet" "cool" "blueWhiteRed"], ...
    "ValueChangedFcn", changed, "Tooltip", "auto: parula; blueWhiteRed for unit correlation.");
place(E.heatColormap, r, 2);
[S, r] = formRow(S, ["sortDepth" "sortShank"], "Sort by:");
sog = subgrid(S.Body, r, {'fit', 'fit', '1x'});
sog.ColumnSpacing = 12;
E.sortDepth = uicheckbox(sog, "Text", "Depth", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Units / channels with the top of the probe first (probe y). Neither Depth nor Shank ticked: as listed.");
E.sortShank = uicheckbox(sog, "Text", "Shank", "ValueChangedFcn", changed, ...
    "Tooltip", "Units / channels grouped by shank first; with Depth, top of the probe first within each shank.");
[S, r] = formRow(S, ["labelDepth" "labelShank"], "Label with:");
lag = subgrid(S.Body, r, {'fit', 'fit', '1x'});
lag.ColumnSpacing = 12;
E.labelDepth = uicheckbox(lag, "Text", "Depth", "ValueChangedFcn", changed, ...
    "Tooltip", "Append each unit's / channel's probe depth (y, µm) to its label.");
E.labelShank = uicheckbox(lag, "Text", "Shank", "ValueChangedFcn", changed, ...
    "Tooltip", "Append each unit's / channel's shank to its label.");
[S, r] = formRow(S, ["showSEM" "showStop" "legend" "grid"], "Show:");
shg = subgrid(S.Body, r, repmat({'fit'}, 1, 4));
shg.ColumnSpacing = 12;
E.showSEM = uicheckbox(shg, "Text", "SEM", "Value", true, "ValueChangedFcn", changed);
E.showStop = uicheckbox(shg, "Text", "Stop marks", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Mark each epoch's stop event (the Epoch window's).");
E.legend = uicheckbox(shg, "Text", "Legend", "Value", true, "ValueChangedFcn", changed);
E.grid = uicheckbox(shg, "Text", "Grid", "Value", true, "ValueChangedFcn", changed);
[S, r] = formRow(S, ["legendLoc" "legendOrient" "legendBox"], "Legend:");
lgg = subgrid(S.Body, r, {'1x', '1x', 'fit'});
E.legendLoc = uidropdown(lgg, "Items", ["Auto" "Inside" "North (above)" "South (below)" "East (right)" "West (left)"], ...
    "ItemsData", ["auto" "inside" "north" "south" "east" "west"], "Value", "auto", "ValueChangedFcn", changed, ...
    "Tooltip", "Where the legend goes. Auto: east of a grid, else the plot's own place. Inside: in the first tile. North, south, " + ...
    "east, west: outside the whole grid of plots, on that side.");
E.legendOrient = uidropdown(lgg, "Items", ["Auto" "Vertical" "Horizontal"], ...
    "ItemsData", ["auto" "vertical" "horizontal"], "Value", "auto", "ValueChangedFcn", changed, ...
    "Tooltip", "How the legend's entries line up. Auto: horizontal above or below the grid, vertical elsewhere.");
E.legendBox = uicheckbox(lgg, "Text", "Box", "ValueChangedFcn", changed, ...
    "Tooltip", "Draw the legend's outline and background.");
sec(end+1) = S;

% each unit's waveform in its tile
S = formSection(eg, 9, "waveform", "Unit waveform");
[S, r] = formRow(S, ["waveMode" "waveSpikes"], "Show:");
wg = subgrid(S.Body, r, {'1x', 'fit', 70});
E.waveMode = uidropdown(wg, "Items", ["Off" "Mean" "Subsample" "Mean + subsample"], ...
    "ItemsData", ["off" "mean" "subsample" "both"], "Value", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "Overlay each unit's waveform on its peak channel in its tile: the mean of its spikes, a " + ...
    "subsample of them, or both. Sorted units: cut from the sorted .bin as Kilosort4 saw them (their " + ...
    "template when the .bin is not there). Detections: the waveforms the spikes file keeps (the Spikes " + ...
    "step's Waveforms option).");
uilabel(wg, "Text", "spikes:");
E.waveSpikes = uispinner(wg, "Limits", [1 2000], "Step", 50, "Value", 100, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "How many of each unit's spikes the subsample draws, picked at " + ...
    "random (the same ones each time); a sorted unit's mean is over these too.");
[S, r] = formRow(S, ["waveLocation" "waveBox"], "Location:");
wl = subgrid(S.Body, r, {'1x', 'fit'});
E.waveLocation = uidropdown(wl, "Items", ["North-east" "North" "North-west" "West" "South-west" "South" "South-east" "East"], ...
    "ItemsData", EphysAnalysisConfig.WaveformLocations, "Value", "northeast", "ValueChangedFcn", changed, ...
    "Tooltip", "Where in each unit's tile the waveform sits: north is the top edge, east the right.");
E.waveBox = uicheckbox(wl, "Text", "Axis box", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Draw the waveform's box, an outline on a pale ground; untick for the waveform alone.");
[S, r] = formRow(S, "waveScale", "Size:");
E.waveScale = uispinner(S.Body, "Limits", [0.25 3], "Step", 0.25, "Value", 1, "ValueDisplayFormat", "%.2gx", ...
    "ValueChangedFcn", changed, "Tooltip", "A tile's box: its size, a factor of its default (a third of the tile's width and " + ...
    "height). A waveforms plot on the probe: the size of each unit's waveform, a factor of its default (about a " + ...
    "twelfth of the probe's length).");
place(E.waveScale, r, 2);
[S, r] = formRow(S, "waveLabel", "Label:");
wt = subgrid(S.Body, r, {'fit', 'fit', '1x'});
E.wavePP = uicheckbox(wt, "Text", "p-p", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Say the mean waveform's peak-to-peak amplitude (in the box, or in a waveforms plot's tile; on the " + ...
    "probe, beside the unit's name).");
E.waveCount = uicheckbox(wt, "Text", "# spikes", "Value", false, "ValueChangedFcn", changed, ...
    "Tooltip", "Say how many spikes the unit has (not for a template).");
[S, r] = formRow(S, "waveAmp", "Amplitude:");
E.waveAmp = uidropdown(S.Body, "Items", ["Each unit's own scale" "One scale for all units"], "ItemsData", ["unit" "common"], ...
    "Value", "unit", "ValueChangedFcn", changed, "Tooltip", "Each unit's waveform fills its tile (or its place on the probe), " + ...
    "or all units are drawn on one amplitude scale, so their sizes compare (a bar on the probe says how big). Units " + ...
    "whose values are of a different kind (a template, say) keep scales of their own.");
place(E.waveAmp, r, 2);
[S, r] = formRow(S, ["waveSites" "waveNames"], "On the probe:");
wp = subgrid(S.Body, r, {'fit', 'fit', '1x'});
wp.ColumnSpacing = 12;
E.waveSites = uicheckbox(wp, "Text", "Sites", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Draw the probe's sites in grey behind the waveforms.");
E.waveNames = uicheckbox(wp, "Text", "Unit names", "Value", false, "ValueChangedFcn", changed, ...
    "Tooltip", "Write each unit's name (and the label ticked above) beside its waveform.");
sec(end+1) = S;

% descriptive text on the plot
S = formSection(eg, 10, "note", "Text note");
[S, r] = formRow(S, "annText", "Text:", 78);
E.annText = uitextarea(S.Body, "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "Words to put on the plot -- a caption, a condition, a remark. Each new line is a line of text; blank " + ...
    "draws nothing. Where it goes, and how it looks, are set below.");
place(E.annText, r, 2);
[S, r] = formRow(S, "annPlace", "Place:");
E.annPlace = uidropdown(S.Body, "Items", ["Below the plot" "Above the plot" "Right of the plot" "Left of the plot" ...
    "Over the plot: top left" "Over the plot: top" "Over the plot: top right" "Over the plot: left" "Over the plot: center" ...
    "Over the plot: right" "Over the plot: bottom left" "Over the plot: bottom" "Over the plot: bottom right" "At x, y"], ...
    "ItemsData", EphysAnalysisConfig.NotePlacements, "Value", "below", "ValueChangedFcn", changed, ...
    "Tooltip", "Outside the plot, the plot gives up a band for the text. Over the plot, the text sits at that place " + ...
    "in the plot's whole area, on top of what is drawn there (the title too, at the top). At x, y puts its anchor at the point below.");
place(E.annPlace, r, 2);
[S, r] = formRow(S, ["annX" "annY"], "At x, y:");
xyg = subgrid(S.Body, r, {'fit', '1x', 'fit', '1x'});
uilabel(xyg, "Text", "x");
E.annX = uieditfield(xyg, "numeric", "Value", 0.5, "Limits", [-2 3], "ValueChangedFcn", changed, ...
    "Tooltip", "Across the plot: 0 is its left edge, 1 its right. The text's anchor (its left, center or right edge, by Align) goes here.");
uilabel(xyg, "Text", "y");
E.annY = uieditfield(xyg, "numeric", "Value", 0.5, "Limits", [-2 3], "ValueChangedFcn", changed, ...
    "Tooltip", "Up the plot: 0 is its bottom edge, 1 its top. The text's anchor (its top, middle or bottom, by Align) goes here.");
[S, r] = formRow(S, ["annAlign" "annVAlign"], "Align:");
ag = subgrid(S.Body, r, {'1x', '1x'});
E.annAlign = uidropdown(ag, "Items", ["Left" "Center" "Right"], "ItemsData", ["left" "center" "right"], "Value", "left", ...
    "ValueChangedFcn", changed, "Tooltip", "How the lines line up, left to right. Below and above the plot it is also where " + ...
    "the text sits across the plot; at x, y it is the anchor.");
E.annVAlign = uidropdown(ag, "Items", ["Top" "Middle" "Bottom"], "ItemsData", ["top" "middle" "bottom"], "Value", "middle", ...
    "ValueChangedFcn", changed, "Tooltip", "Where the text sits up the plot beside it (right and left), or its anchor at x, y.");
[S, r] = formRow(S, "annRotation", "Rotation:");
E.annRotation = uispinner(S.Body, "Limits", [-180 180], "Step", 15, "Value", 0, "ValueDisplayFormat", "%g°", ...
    "ValueChangedFcn", changed, "Tooltip", "Degrees, counter-clockwise: 90 reads upwards (for the band beside the plot).");
place(E.annRotation, r, 2);
[S, r] = formRow(S, ["annFont" "annSize"], "Font:");
fg = subgrid(S.Body, r, {'1x', 70});
E.annFont = uidropdown(fg, "Editable", "on", "Items", ["auto" "Arial" "Helvetica" "Times New Roman" "Courier New" "Calibri" ...
    "Segoe UI" "Verdana" "Georgia" "Palatino Linotype"], "Value", "auto", "ValueChangedFcn", changed, ...
    "Tooltip", "auto: the design's font. Or any installed font's name.");
E.annSize = uieditfield(fg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "auto", "Limits", [1 200], ...
    "ValueChangedFcn", changed, "Tooltip", "Points; blank is the plot's font size (Appearance).");
[S, r] = formRow(S, ["annBold" "annItalic" "annBox"], "Style:");
stg = subgrid(S.Body, r, {'fit', 'fit', 'fit', '1x'});
stg.ColumnSpacing = 12;
E.annBold = uicheckbox(stg, "Text", "Bold", "ValueChangedFcn", changed);
E.annItalic = uicheckbox(stg, "Text", "Italic", "ValueChangedFcn", changed);
E.annBox = uicheckbox(stg, "Text", "Outline", "ValueChangedFcn", changed, ...
    "Tooltip", "Draw a box round the text, in its colour.");
[S, r] = formRow(S, ["annColor" "annBackground"], "Colours:");
cg = subgrid(S.Body, r, {'fit', '1x', 'fit', '1x'});
uilabel(cg, "Text", "text");
E.annColor = uidropdown(cg, "Editable", "on", "Items", ["auto" "black" "white" "red" "blue" "green" "magenta" "cyan"], ...
    "Value", "auto", "ValueChangedFcn", changed, "Tooltip", "auto: the design's text colour; or a name or #RRGGBB.");
uilabel(cg, "Text", "ground");
E.annBackground = uidropdown(cg, "Editable", "on", "Items", ["none" "white" "black" "yellow" "cyan" "#F0F0F0"], ...
    "Value", "none", "ValueChangedFcn", changed, "Tooltip", "none: the plot shows through; or a name or #RRGGBB behind the text.");
[S, r] = formRow(S, "annInterp", "Interpreter:");
E.annInterp = uidropdown(S.Body, "Items", ["As typed" "TeX"], "ItemsData", ["none" "tex"], "Value", "none", ...
    "ValueChangedFcn", changed, "Tooltip", "As typed: every character is printed as it is. TeX: \mu, \pm, x^2, x_i, \bf{...} " + ...
    "set symbols, powers, subscripts and bold or italic runs.");
place(E.annInterp, r, 2);
sec(end+1) = S;

for i = 2:numel(sec)
    name = sec(i).Name;
    sec(i).Toggle.ButtonPushedFcn = @(~,~) obj.onPlotSectionToggled(name);
end
obj.PlotEditor = E;
obj.PlotSections = sec;
obj.layoutPlotEditor();

% --- the preview ---------------------------------------------------------------------------
pg = uigridlayout(g, [4 6]);
pg.RowHeight = {30, 30, '1x', 26};
pg.ColumnWidth = {'fit', '1x', 'fit', 'fit', 'fit', 'fit'};
pg.Padding = [0 0 0 0];
l = uilabel(pg, "Text", "Active dataset:");
l.Layout.Row = 1; l.Layout.Column = 1;
obj.PlotsDatasetDropDown = uidropdown(pg, "Items", "(scan first)", "ItemsData", 0, ...
    "ValueChangedFcn", @(dd, ~) obj.selectDataset(dd.Value));
obj.PlotsDatasetDropDown.Layout.Row = 1; obj.PlotsDatasetDropDown.Layout.Column = 2;
obj.PreviewButton = uibutton(pg, "Text", "Preview", ...
    "Tooltip", "Compute and draw the selected plot on the active dataset: only the page shown, for a grid of " + ...
    "units or channels. Ctrl+click to compute every page, so < and > flip pages without computing.", ...
    "ButtonPushedFcn", @(~,~) obj.refreshPreview(Force=true, AllPages=string(obj.Fig.SelectionType) == "alt"));
obj.PreviewButton.Layout.Row = 1; obj.PreviewButton.Layout.Column = 3;
obj.AutoPreviewCheckBox = uicheckbox(pg, "Text", "Auto", "Value", true, ...
    "Tooltip", "Redraw on every change while a preview takes under 2 s.", "ValueChangedFcn", @(~,~) obj.onAutoPreviewToggled());
obj.AutoPreviewCheckBox.Layout.Row = 1; obj.AutoPreviewCheckBox.Layout.Column = 4;
obj.PrevPageButton = uibutton(pg, "Text", "<", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onPreviewPage(-1));
obj.PrevPageButton.Layout.Row = 1; obj.PrevPageButton.Layout.Column = 5;
obj.NextPageButton = uibutton(pg, "Text", ">", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onPreviewPage(1));
obj.NextPageButton.Layout.Row = 1; obj.NextPageButton.Layout.Column = 6;
l = uilabel(pg, "Text", "Design:");
l.Layout.Row = 2; l.Layout.Column = 1;
dg = uigridlayout(pg, [1 3]);
dg.Layout.Row = 2; dg.Layout.Column = [2 6];
dg.ColumnWidth = {200, 'fit', '1x'};
dg.Padding = [0 0 0 0];
obj.DesignDropDown = uidropdown(dg, "Items", PlotDesign.DefaultName, "ItemsData", PlotDesign.DefaultName, ...
    "ValueChangedFcn", @(dd, ~) obj.onDesignChosen(dd.Value), ...
    "Tooltip", "The look of every plot: its ground, colours, fonts, axes, ticks, lines and marks. " + ...
    "Choosing one redraws every plot on screen; runs draw their figures in it too.");
obj.SaveDesignButton = uibutton(dg, "Text", "Save look as design...", "ButtonPushedFcn", @(~,~) obj.onSaveDesign(), ...
    "Tooltip", "Keep the preview's look -- every property of every component, its ground and its group " + ...
    "colours -- as a design of your own, to choose for any plot.");
vg = uigridlayout(pg, [2 1], "RowHeight", {0, '1x'}, "Padding", [0 0 0 0], "RowSpacing", 0);
vg.Layout.Row = 3; vg.Layout.Column = [1 6];
obj.PreviewGrid = vg;
A.Grid = uigridlayout(vg, [1 1], "Padding", [8 2 8 2], "Visible", "off");   % shown while several plots are selected
A.Text = uilabel(A.Grid, "Text", "", "FontWeight", "bold");
obj.SelectionBar = A;
obj.PreviewPanel = uipanel(vg, "BackgroundColor", "w", "BorderType", "line");
obj.PreviewPanel.Layout.Row = 2;
sg = uigridlayout(pg, [1 3], "ColumnWidth", {'fit', '1x', 'fit'}, "Padding", [0 0 0 0], "ColumnSpacing", 8);
sg.Layout.Row = 4; sg.Layout.Column = [1 6];
B.Grid = uigridlayout(sg, [1 2], "ColumnWidth", {18, 'fit'}, "Padding", [6 2 10 2], "ColumnSpacing", 5);
B.Icon = uiimage(B.Grid, "ScaleMethod", "fit");
B.Text = uilabel(B.Grid, "FontWeight", "bold");
obj.PreviewBadge = B;
obj.PreviewLabel = uilabel(sg, "Text", "Add a plot, scan and pick a dataset to preview.", "FontColor", [0.35 0.35 0.35]);
obj.PageLabel = uilabel(sg, "Text", "", "HorizontalAlignment", "right");
obj.setPreviewState("idle");
end


function b = defaultBox(obj, S, what)
%defaultBox  The "Use default" box in the header of an alignment section.
b = uicheckbox(S.HeaderGrid, "Text", "Use default", "Value", true, ...
    "ValueChangedFcn", @(~,~) obj.onPlotDefaultToggled(), ...
    "Tooltip", "Ticked: the Alignment tab's " + what + " (the config's Defaults). Editing a value below " + ...
    "gives this plot its own; tick again to go back to the default.");
b.Layout.Column = 2;
end


function h = gridHeight(g)
%gridHeight  The height a grid of fixed-height rows takes.
rh = [g.RowHeight{:}];
h = sum(rh) + (numel(rh) - 1) * g.RowSpacing + g.Padding(2) + g.Padding(4);
end


function sg = subgrid(parent, row, widths)
%subgrid  A borderless one-row grid in column 2 of form row ROW.
sg = uigridlayout(parent, [1 numel(widths)]);
sg.ColumnWidth = widths;
sg.Padding = [0 0 0 0];
sg.ColumnSpacing = 6;
place(sg, row, 2);
end


function place(c, row, col)
c.Layout.Row = row;
c.Layout.Column = col;
end


function [S, E] = aurocRows(S, E, p, changed, isPlot)
%aurocRows  The auROC settings' rows in form section S; P prefixes their editor fields.
%   ISPLOT: a plot's own (baseline Mode "auroc"), with the call window, the
%   test's correction and alpha, and the marks. Otherwise the response
%   test's ("auroc"): its own bins; its windows, correction and alpha are
%   the test's. Each row shows by its first field's key (syncPlotEditor).
[S, r] = formRow(S, p + "Method", "auROC from:");
g = subgrid(S.Body, r, {'1x', '1x'});
E.(p + "Method") = uidropdown(g, "Items", ["PSTH bins" "each epoch"], "ItemsData", ["psth" "epochs"], ...
    "ValueChangedFcn", changed, "Tooltip", "PSTH bins: the trial-averaged PSTH's bins in each window against " + ...
    "those in the baseline (the paper's). each epoch: each epoch's spike count in the window against the " + ...
    "epochs' counts in window-long pieces of the baseline.");
E.(p + "Windows") = uidropdown(g, "Items", ["tiled" "sliding"], "ValueChangedFcn", changed, ...
    "Tooltip", "tiled: windows back to back, edged at the event (the paper's). sliding: a window starts every step; neighbours share bins.");
widths = {'fit', '1x', 'fit', '1x'};
if ~isPlot; widths = [widths {'fit', '1x'}]; end
[S, r] = formRow(S, p + "WinMs", "auROC (ms):");
g = subgrid(S.Body, r, widths);
uilabel(g, "Text", "window");
E.(p + "WinMs") = uieditfield(g, "numeric", "Value", 100, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "The auROC window, ms: a whole number of bins.");
uilabel(g, "Text", "step");
E.(p + "StepMs") = uieditfield(g, "numeric", "Value", 10, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "Sliding windows: one starts every step, ms (a whole number of bins).");
if ~isPlot
    uilabel(g, "Text", "bin");
    E.(p + "BinMs") = uieditfield(g, "numeric", "Value", 10, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
        "ValueChangedFcn", changed, "Tooltip", "The bins the test counts spikes in, ms.");
end
if isPlot
    [S, r] = formRow(S, p + "ModFrom", "Call window (s):");
    g = subgrid(S.Body, r, {'1x', 'fit', '1x'});
    E.(p + "ModFrom") = uieditfield(g, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", ...
        "The call window's start, s from the event: the auROC windows wholly inside it decide each unit's call " + ...
        "(the paper: -0.5 to 0 before a spout withdrawal).");
    uilabel(g, "Text", "to");
    E.(p + "ModTo") = uieditfield(g, "numeric", "Value", 0.5, "ValueChangedFcn", changed, "Tooltip", "The call window's end, s.");
end
items = ["95% CI (paper)" "fixed threshold" "per-unit test" "none"];
data = ["ci" "fixed" "test" "none"];
if ~isPlot; items = items(1:3); data = data(1:3); end
[S, r] = formRow(S, p + "Cutoff", "Modulated if:");
g = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.(p + "Cutoff") = uidropdown(g, "Items", items, "ItemsData", data, "ValueChangedFcn", changed, "Tooltip", ...
    "95% CI: the unit's mean auROC in the call window lies beyond 0.5 +/- the upper bound of the 95% confidence " + ...
    "interval of the units' mean phasic modulation |auROC - 0.5| (the paper's; it needs many units). fixed: " + ...
    "beyond 0.5 +/- the threshold. per-unit test: the test below, its p adjusted over the units. none: no call.");
uilabel(g, "Text", "+/-");
E.(p + "Threshold") = uieditfield(g, "numeric", "Value", 0.1, "Limits", [0 0.5], "UpperLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "fixed threshold: modulated when |mean auROC - 0.5| is above this.");
widths = {'1x', 'fit', '1x'};
if isPlot; widths = {'2x', 'fit', '1x', '2x', 'fit', '1x'}; end
[S, r] = formRow(S, p + "Test", "Unit test:");
g = subgrid(S.Body, r, widths);
E.(p + "Test") = uidropdown(g, "Items", ["bootstrap" "ranksum" "shuffle"], "ValueChangedFcn", changed, "Tooltip", ...
    "bootstrap: resample the epochs; p from how often the mean auROC lands across 0.5. ranksum: the call " + ...
    "window's values against the baseline's (from the same epochs, so p runs small). shuffle: shift each " + ...
    "epoch's spikes circularly at random; p from how often the phasic modulation reaches the observed one.");
uilabel(g, "Text", "n");
E.(p + "Resamples") = uieditfield(g, "numeric", "Value", 1000, "Limits", [1 Inf], "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "Bootstrap resamples, or shuffles.");
if isPlot
    E.(p + "Correction") = uidropdown(g, "Items", ["BH (FDR)" "Holm" "Bonferroni" "none"], ...
        "ItemsData", ["bh" "holm" "bonferroni" "none"], "ValueChangedFcn", changed, ...
        "Tooltip", "How the p values are adjusted over the units and groups (pAdjust).");
    uilabel(g, "Text", "alpha:");
    E.(p + "Alpha") = uieditfield(g, "numeric", "Value", 0.05, "Limits", [0 1], "LowerLimitInclusive", "off", ...
        "ValueChangedFcn", changed, "Tooltip", "Modulated when the adjusted p is at most alpha.");
    [S, r] = formRow(S, p + "Marks", "Calls:");
    g = subgrid(S.Body, r, {'fit', 'fit', '1x'});
    g.ColumnSpacing = 12;
    E.(p + "Marks") = uicheckbox(g, "Text", "Mark them", "Value", true, "ValueChangedFcn", changed, "Tooltip", ...
        "PSTH: each unit's call (up, down, n.s., per group) by its title, and the call window shaded. Heatmap: a " + ...
        "triangle by each modulated row and a bar over the call window. The caption counts them either way.");
    E.(p + "ModOnly") = uicheckbox(g, "Text", "Modulated units only", "ValueChangedFcn", changed, ...
        "Tooltip", "Draw only the units called modulated in at least one group.");
end
end
