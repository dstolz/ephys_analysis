function buildPlotsTab(obj)
%buildPlotsTab  Plot list, plot editor (collapsible sections) and the preview.
%   The editor is a column of sections (formSection): the plot's kind, id,
%   title, source and layout, always open; then Units & channels, Event
%   reference, Epoch window, Trial selection (the Alignment tab's values
%   while "Use default" is ticked; editing one gives the plot its own),
%   Bins & baseline, the kind's own options and Appearance, each collapsing
%   under its header (onPlotSectionToggled). syncPlotEditor shows the rows
%   the selected plot uses; layoutPlotEditor packs them.
g = uigridlayout(obj.TabPlots, [1 3]);
g.ColumnWidth = {190, 470, '1x'};
g.Padding = [8 8 8 8];
changed = @(~,~) obj.onConfigChanged("plot");

% --- the list --------------------------------------------------------------------
lg = uigridlayout(g, [6 2]);
lg.RowHeight = {22, '1x', 30, 30, 30, 24};
lg.ColumnWidth = {'1x', '1x'};
lg.Padding = [0 0 0 0];
l = uilabel(lg, "Text", "Plots", "FontWeight", "bold");
l.Layout.Row = 1; l.Layout.Column = [1 2];
obj.PlotsListBox = uilistbox(lg, "Items", {}, "ValueChangedFcn", @(lb, ~) obj.onPlotSelected(lb.Value));
obj.PlotsListBox.Layout.Row = 2; obj.PlotsListBox.Layout.Column = [1 2];
K = EphysAnalysisConfig.plotKinds();
obj.AddKindDropDown = uidropdown(lg, "Items", K.Label, "ItemsData", K.Kind);
obj.AddKindDropDown.Layout.Row = 3; obj.AddKindDropDown.Layout.Column = 1;
obj.AddPlotButton = uibutton(lg, "Text", "Add", "ButtonPushedFcn", @(~,~) obj.onAddPlot(obj.AddKindDropDown.Value));
obj.AddPlotButton.Layout.Row = 3; obj.AddPlotButton.Layout.Column = 2;
obj.RemovePlotButton = uibutton(lg, "Text", "Remove", "ButtonPushedFcn", @(~,~) obj.onRemovePlot());
obj.RemovePlotButton.Layout.Row = 4; obj.RemovePlotButton.Layout.Column = 1;
obj.DuplicatePlotButton = uibutton(lg, "Text", "Duplicate", "ButtonPushedFcn", @(~,~) obj.onDuplicatePlot());
obj.DuplicatePlotButton.Layout.Row = 4; obj.DuplicatePlotButton.Layout.Column = 2;
obj.UpPlotButton = uibutton(lg, "Text", "Up", "ButtonPushedFcn", @(~,~) obj.onMovePlot(-1));
obj.UpPlotButton.Layout.Row = 5; obj.UpPlotButton.Layout.Column = 1;
obj.DownPlotButton = uibutton(lg, "Text", "Down", "ButtonPushedFcn", @(~,~) obj.onMovePlot(1));
obj.DownPlotButton.Layout.Row = 5; obj.DownPlotButton.Layout.Column = 2;

% --- the editor ----------------------------------------------------------------------
ep = uipanel(g, "Title", "Plot");
eg = uigridlayout(ep, [9 1]);
eg.RowHeight = [repmat({0}, 1, 8) {'1x'}];
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
[S, r] = formRow(S, "baselineMode", "Baseline:");
E.baselineMode = uidropdown(S.Body, "Items", "none", "ValueChangedFcn", changed);
place(E.baselineMode, r, 2);
[S, r] = formRow(S, ["baseFrom" "baseTo"], "Baseline (s):");
bg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.baseFrom = uieditfield(bg, "numeric", "Value", -0.2, "ValueChangedFcn", changed, "Tooltip", "Baseline window start (s from the event).");
uilabel(bg, "Text", "to");
E.baseTo = uieditfield(bg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "Baseline window end (s).");
sec(end+1) = S;

% the kind's own options
S = formSection(eg, 7, "kind", "Options");
[S, r] = formRow(S, "withRaster", "");
E.withRaster = uicheckbox(S.Body, "Text", "Raster above each PSTH", "Value", true, "ValueChangedFcn", changed);
place(E.withRaster, r, [1 2]);
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
[S, r] = formRow(S, "param", "Parameter:");
E.param = uidropdown(S.Body, "Editable", "on", "Items", "", "ValueChangedFcn", changed, "Tooltip", "The trial parameter on the x axis.");
place(E.param, r, 2);
[S, r] = formRow(S, "seriesParam", "Series:");
E.seriesParam = uidropdown(S.Body, "Editable", "on", "Items", "", "ValueChangedFcn", changed, "Tooltip", "One curve per value ("""" = one curve).");
place(E.seriesParam, r, 2);
[S, r] = formRow(S, "value", "Value:");
E.value = uidropdown(S.Body, "Items", ["rate" "nSpikes" "nUnits"], "ValueChangedFcn", changed, "Tooltip", "What colours each site.");
place(E.value, r, 2);
[S, r] = formRow(S, "order", "Row order:");
E.order = uidropdown(S.Body, "Items", ["depth" "channel" "peak"], "ValueChangedFcn", changed, ...
    "Tooltip", "The heatmap's rows; the unit correlation's rows and columns.");
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
[S, r] = formRow(S, "fontSize", "Font size:");
E.fontSize = uispinner(S.Body, "Limits", [5 24], "Value", 9, "ValueChangedFcn", changed);
place(E.fontSize, r, 2);
[S, r] = formRow(S, "lineWidth", "Line width:");
E.lineWidth = uispinner(S.Body, "Limits", [0.25 6], "Step", 0.25, "Value", 1.2, "ValueChangedFcn", changed, ...
    "Tooltip", "PSTH lines and outlines, evoked traces, tuning curves.");
place(E.lineWidth, r, 2);
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
[S, r] = formRow(S, ["showSEM" "showStop" "legend" "grid"], "Show:");
shg = subgrid(S.Body, r, repmat({'fit'}, 1, 4));
shg.ColumnSpacing = 12;
E.showSEM = uicheckbox(shg, "Text", "SEM", "Value", true, "ValueChangedFcn", changed);
E.showStop = uicheckbox(shg, "Text", "Stop marks", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Mark each epoch's stop event (the Epoch window's).");
E.legend = uicheckbox(shg, "Text", "Legend", "Value", true, "ValueChangedFcn", changed);
E.grid = uicheckbox(shg, "Text", "Grid", "Value", true, "ValueChangedFcn", changed);
sec(end+1) = S;

for i = 2:numel(sec)
    name = sec(i).Name;
    sec(i).Toggle.ButtonPushedFcn = @(~,~) obj.onPlotSectionToggled(name);
end
obj.PlotEditor = E;
obj.PlotSections = sec;
obj.layoutPlotEditor();

% --- the preview ---------------------------------------------------------------------------
pg = uigridlayout(g, [3 6]);
pg.RowHeight = {30, '1x', 22};
pg.ColumnWidth = {'fit', '1x', 'fit', 'fit', 'fit', 'fit'};
pg.Padding = [0 0 0 0];
l = uilabel(pg, "Text", "Active dataset:");
l.Layout.Row = 1; l.Layout.Column = 1;
obj.PlotsDatasetDropDown = uidropdown(pg, "Items", "(scan first)", "ItemsData", 0, ...
    "ValueChangedFcn", @(dd, ~) obj.selectDataset(dd.Value));
obj.PlotsDatasetDropDown.Layout.Row = 1; obj.PlotsDatasetDropDown.Layout.Column = 2;
obj.PreviewButton = uibutton(pg, "Text", "Preview", "ButtonPushedFcn", @(~,~) obj.refreshPreview(Force=true));
obj.PreviewButton.Layout.Row = 1; obj.PreviewButton.Layout.Column = 3;
obj.AutoPreviewCheckBox = uicheckbox(pg, "Text", "Auto", "Value", true, ...
    "Tooltip", "Redraw on every change while a preview takes under 2 s.", "ValueChangedFcn", @(~,~) obj.onAutoPreviewToggled());
obj.AutoPreviewCheckBox.Layout.Row = 1; obj.AutoPreviewCheckBox.Layout.Column = 4;
obj.PrevPageButton = uibutton(pg, "Text", "<", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onPreviewPage(-1));
obj.PrevPageButton.Layout.Row = 1; obj.PrevPageButton.Layout.Column = 5;
obj.NextPageButton = uibutton(pg, "Text", ">", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onPreviewPage(1));
obj.NextPageButton.Layout.Row = 1; obj.NextPageButton.Layout.Column = 6;
obj.PreviewPanel = uipanel(pg, "BackgroundColor", "w", "BorderType", "line");
obj.PreviewPanel.Layout.Row = 2; obj.PreviewPanel.Layout.Column = [1 6];
obj.PreviewLabel = uilabel(pg, "Text", "Add a plot, scan and pick a dataset to preview.", "FontColor", [0.35 0.35 0.35]);
obj.PreviewLabel.Layout.Row = 3; obj.PreviewLabel.Layout.Column = [1 4];
obj.PageLabel = uilabel(pg, "Text", "", "HorizontalAlignment", "right");
obj.PageLabel.Layout.Row = 3; obj.PageLabel.Layout.Column = [5 6];
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
