function buildPlotsTab(obj)
%buildPlotsTab  Plot list, plot editor (rows follow the kind) and the preview.
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
ep = uipanel(g, "Title", "Plot", "Scrollable", "on");
eg = uigridlayout(ep, [2 1]);
eg.RowHeight = {'fit', 'fit'};
eg.Padding = [4 4 4 4];
fg = uigridlayout(eg, [22 4]);
fg.RowHeight = repmat({22}, 1, 22);
fg.ColumnWidth = {95, '1x', 95, '1x'};
fg.RowSpacing = 4;
fg.Padding = [0 0 0 0];
E = struct();
r = 1;
E.enabled = uicheckbox(fg, "Text", "Enabled", "ValueChangedFcn", changed);
place(E.enabled, r, 1);
lab(fg, "Kind:", r, 3); E.kind = uilabel(fg, "Text", "", "FontWeight", "bold"); place(E.kind, r, 4);
r = r + 1;
lab(fg, "Id:", r, 1);
E.id = uieditfield(fg, "text", "ValueChangedFcn", changed, "Tooltip", "Unique; names the exported files ({Plot}).");
place(E.id, r, 2);
lab(fg, "Title:", r, 3);
E.title = uieditfield(fg, "text", "Placeholder", "automatic", "ValueChangedFcn", changed);
place(E.title, r, 4);
r = r + 1;
lab(fg, "Source:", r, 1);
E.source = uidropdown(fg, "Items", "units", "ValueChangedFcn", changed);
place(E.source, r, 2);
lab(fg, "Layout:", r, 3);
E.layout = uidropdown(fg, "Items", "grid", "ValueChangedFcn", changed);
place(E.layout, r, 4);
r = r + 1;
lab(fg, "Unit classes:", r, 1);
cg = uigridlayout(fg, [1 4]); cg.Padding = [0 0 0 0]; cg.ColumnSpacing = 2;
cg.Layout.Row = r; cg.Layout.Column = [2 4];
E.classes = struct();
for c = ["su" "mua" "uns" "noise"]
    E.classes.(c) = uicheckbox(cg, "Text", c, "Value", ismember(c, ["su" "mua"]), "ValueChangedFcn", changed, ...
        "Tooltip", "Sorted-unit classes drawn (none ticked = every class).");
end
r = r + 1;
lab(fg, "Unit ids:", r, 1);
E.ids = uieditfield(fg, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "Unit ids (sorted units) or channels (detections), e.g. 3 5 8:12.");
place(E.ids, r, 2);
lab(fg, "Max units:", r, 3);
E.maxUnits = uieditfield(fg, "text", "Value", "Inf", "ValueChangedFcn", changed);
place(E.maxUnits, r, 4);
r = r + 1;
lab(fg, "Channels:", r, 1);
E.channels = uieditfield(fg, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "Units / detections: recording channels kept. Signals: the extract's columns drawn.");
place(E.channels, r, 2);
lab(fg, "Shanks:", r, 3);
E.shanks = uieditfield(fg, "text", "Placeholder", "all", "ValueChangedFcn", changed);
place(E.shanks, r, 4);
r = r + 1;
lab(fg, "Bin (ms):", r, 1);
E.binMs = uieditfield(fg, "numeric", "Value", 10, "Limits", [0.001 Inf], "ValueChangedFcn", changed);
place(E.binMs, r, 2);
lab(fg, "Smooth (ms):", r, 3);
E.smoothMs = uieditfield(fg, "numeric", "Value", 10, "Limits", [0 Inf], "ValueChangedFcn", changed, ...
    "Tooltip", "Gaussian SD; 0 = none.");
place(E.smoothMs, r, 4);
r = r + 1;
lab(fg, "Baseline:", r, 1);
E.baselineMode = uidropdown(fg, "Items", "none", "ValueChangedFcn", changed);
place(E.baselineMode, r, 2);
bg = uigridlayout(fg, [1 2]); bg.Padding = [0 0 0 0]; bg.ColumnSpacing = 2;
bg.Layout.Row = r; bg.Layout.Column = [3 4];
E.baseFrom = uieditfield(bg, "numeric", "Value", -0.2, "ValueChangedFcn", changed, "Tooltip", "Baseline window start (s from the event).");
E.baseTo = uieditfield(bg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "Baseline window end (s).");
r = r + 1;
E.withRaster = uicheckbox(fg, "Text", "Raster above each PSTH", "Value", true, "ValueChangedFcn", changed);
E.withRaster.Layout.Row = r; E.withRaster.Layout.Column = [1 2];
E.maskAfterStop = uicheckbox(fg, "Text", "Mask after the stop event", "ValueChangedFcn", changed);
E.maskAfterStop.Layout.Row = r; E.maskAfterStop.Layout.Column = [3 4];
r = r + 1;
lab(fg, "PSTH as:", r, 1);
E.histStyle = uidropdown(fg, "Items", ["bar" "line"], "Value", "bar", "ValueChangedFcn", changed, ...
    "Tooltip", "PSTH: one bar per bin, or a line through the bin centres.");
place(E.histStyle, r, 2);
lab(fg, "Normalize:", r, 3);
E.normalize = uidropdown(fg, "Items", ["none" "unit peak" "group peak"], "ItemsData", ["none" "unitPeak" "groupPeak"], ...
    "ValueChangedFcn", changed, "Tooltip", "PSTH: divide each unit's PSTHs by their largest peak (unit peak: the groups keep " + ...
    "their sizes), or each PSTH by its own (group peak). The overlay layout normalizes each unit before the mean.");
place(E.normalize, r, 4);
r = r + 1;
E.fill = uicheckbox(fg, "Text", "Filled", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "PSTH: fill the bars, or the area under the line; untick for the bars' outline, or the line alone.");
E.fill.Layout.Row = r; E.fill.Layout.Column = [1 2];
lab(fg, "Opacity:", r, 3);
E.fillAlpha = uieditfield(fg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "auto", "Limits", [0 1], ...
    "ValueChangedFcn", changed, "Tooltip", "PSTH fill opacity, 0 to 1 (blank: 0.5 where groups overlap, else 1).");
place(E.fillAlpha, r, 4);
r = r + 1;
E.stack = uicheckbox(fg, "Text", "Stack groups", "ValueChangedFcn", changed, ...
    "Tooltip", "PSTH: one row per group, the first at the bottom; each row's value on the left axis, its peak on the right.");
E.stack.Layout.Row = r; E.stack.Layout.Column = [1 2];
lab(fg, "Spacing:", r, 3);
E.stackSpacing = uieditfield(fg, "numeric", "Value", 1.1, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "Stacked PSTHs: the row step, times the tallest PSTH (1: it just reaches the " + ...
    "next row; below 1 the rows overlap).");
place(E.stackSpacing, r, 4);
r = r + 1;
lab(fg, "Parameter:", r, 1);
E.param = uidropdown(fg, "Editable", "on", "Items", "", "ValueChangedFcn", changed, "Tooltip", "Tuning: the trial parameter on the x axis.");
place(E.param, r, 2);
lab(fg, "Series:", r, 3);
E.seriesParam = uidropdown(fg, "Editable", "on", "Items", "", "ValueChangedFcn", changed, "Tooltip", "Tuning: one curve per value ("""" = one curve).");
place(E.seriesParam, r, 4);
r = r + 1;
lab(fg, "Value:", r, 1);
E.value = uidropdown(fg, "Items", ["rate" "nSpikes" "nUnits"], "ValueChangedFcn", changed, "Tooltip", "Probe map: what colours each site.");
place(E.value, r, 2);
lab(fg, "Row order:", r, 3);
E.order = uidropdown(fg, "Items", ["depth" "channel" "peak"], "ValueChangedFcn", changed, ...
    "Tooltip", "Heatmap rows; unit correlation rows and columns.");
place(E.order, r, 4);
r = r + 1;
lab(fg, "Epoch rate:", r, 1);
E.metric = uidropdown(fg, "Items", ["mean" "peak"], "ValueChangedFcn", changed, ...
    "Tooltip", "Unit correlation: each epoch's mean rate over its window, or its peak binned rate.");
place(E.metric, r, 2);
lab(fg, "Correlation:", r, 3);
E.correlation = uidropdown(fg, "Items", ["Pearson" "Spearman"], "ItemsData", ["pearson" "spearman"], ...
    "ValueChangedFcn", changed, "Tooltip", "Unit correlation: Pearson's r, or Spearman's rank correlation.");
place(E.correlation, r, 4);
r = r + 1;
lab(fg, "Tiles / page:", r, 1);
E.maxTiles = uispinner(fg, "Limits", [1 64], "Value", 16, "RoundFractionalValues", "on", "ValueChangedFcn", changed);
place(E.maxTiles, r, 2);
lab(fg, "Font size:", r, 3);
E.fontSize = uispinner(fg, "Limits", [5 24], "Value", 9, "ValueChangedFcn", changed);
place(E.fontSize, r, 4);
r = r + 1;
sg = uigridlayout(fg, [1 4]); sg.Padding = [0 0 0 0]; sg.ColumnSpacing = 2;
sg.Layout.Row = r; sg.Layout.Column = [1 4];
E.showSEM = uicheckbox(sg, "Text", "SEM", "Value", true, "ValueChangedFcn", changed);
E.showStop = uicheckbox(sg, "Text", "Stop marks", "Value", true, "ValueChangedFcn", changed);
E.legend = uicheckbox(sg, "Text", "Legend", "Value", true, "ValueChangedFcn", changed);
E.grid = uicheckbox(sg, "Text", "Grid", "Value", true, "ValueChangedFcn", changed);
r = r + 1;
lab(fg, "Y limits:", r, 1);
E.ylim = uieditfield(fg, "text", "Placeholder", "auto, or e.g. 0 40", "ValueChangedFcn", changed, ...
    "Tooltip", "Not for stacked PSTHs: their spacing sets the rows.");
place(E.ylim, r, 2);
lab(fg, "Line width:", r, 3);
E.lineWidth = uispinner(fg, "Limits", [0.25 6], "Step", 0.25, "Value", 1.2, "ValueChangedFcn", changed, ...
    "Tooltip", "PSTH lines and outlines, evoked traces, tuning curves.");
place(E.lineWidth, r, 4);
r = r + 1;
lab(fg, "Group colours:", r, 1);
E.colormap = uidropdown(fg, "Editable", "on", "Items", ["lines" "parula" "turbo" "jet" "hot" "cool" "gray" "black"], ...
    "Value", "lines", "ValueChangedFcn", changed, ...
    "Tooltip", "lines: the trial selection's colours (parula for a numeric parameter with more than two values); " + ...
    "a colormap function; or one colour for every group (a name or #RRGGBB).");
place(E.colormap, r, 2);
lab(fg, "Heat colours:", r, 3);
E.heatColormap = uidropdown(fg, "Items", ["auto" "parula" "turbo" "hot" "gray" "jet" "cool" "blueWhiteRed"], ...
    "ValueChangedFcn", changed, ...
    "Tooltip", "Heatmap, probe-map and unit-correlation colours (auto: parula; blueWhiteRed for unit correlation).");
place(E.heatColormap, r, 4);
r = r + 1;
ug = uigridlayout(fg, [1 3]); ug.Padding = [0 0 0 0]; ug.ColumnSpacing = 2;
ug.Layout.Row = r; ug.Layout.Column = [1 4];
E.defaultRef = uicheckbox(ug, "Text", "Default event", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Use the Alignment tab's event reference; untick to set this plot's own below.");
E.defaultWindow = uicheckbox(ug, "Text", "Default window", "Value", true, "ValueChangedFcn", changed);
E.defaultSelection = uicheckbox(ug, "Text", "Default selection", "Value", true, "ValueChangedFcn", changed);
r = r + 1;
E.note = uilabel(fg, "Text", "", "FontColor", [0.35 0.35 0.35]);
E.note.Layout.Row = r; E.note.Layout.Column = [1 4];
obj.PlotEditor = E;
host = uipanel(eg, "BorderType", "none");
obj.PlotAlignControls = obj.buildAlignControls(host, @() obj.onConfigChanged("plot"));

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


function l = lab(parent, txt, row, col)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = col;
end


function place(c, row, col)
c.Layout.Row = row;
c.Layout.Column = col;
end
