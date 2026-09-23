function buildReviewTab(obj)
%buildReviewTab  Summary stats + plots for a Kilosort4 results folder.
%   The active dataset's sorted output loads when the tab opens or the
%   dataset changes (syncReviewDataset); Browse... / Load take any other
%   kilosort4/ output folder. The left column shows aggregate stats and a
%   per-unit table, the right column shows units-per-shank, mean waveforms,
%   spike amplitudes over time, and per-unit firing rates, and beside them,
%   full height, the selected unit's spikes on the shank it was detected on.
%   Selecting a table row focuses the waveform and amplitude plots on that
%   single unit and draws its spikes; "Show all units" clears the focus.
%   All parsing happens once in loadReviewResults; selection re-renders from
%   the cached ReviewData and reads only the selected unit's spikes. See
%   loadReviewResults / renderReviewPlots / renderReviewUnitShank.

g = uigridlayout(obj.TabReview, [1 2]);
g.ColumnWidth = {470, '1x'};
g.Padding     = [10 10 10 10];

% =================== left column: source + stats + table ===================
left = uigridlayout(g, [8 1]);
left.Layout.Column = 1;
left.RowHeight = {'fit', 'fit', 30, 30, 'fit', 220, '1x', 30};
left.Padding   = [0 0 0 0];
left.RowSpacing = 6;

uilabel(left, "Text", "Kilosort4 results folder:", "FontWeight", "bold");

fr = uigridlayout(left, [1 2]);
fr.ColumnWidth = {'1x', 'fit'};
fr.Padding = [0 0 0 0];
obj.ReviewFolderField = uieditfield(fr, "text", ...
    "Placeholder", "...\<dataset>\kilosort4");
obj.BrowseReviewButton = uibutton(fr, "Text", "Browse...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseReviewFolder());

dr = uigridlayout(left, [1 3]);
dr.ColumnWidth = {'fit', '1x', 'fit'};
dr.Padding = [0 0 0 0];
uilabel(dr, "Text", "Dataset:");
obj.ReviewDatasetDropDown = obj.datasetPicker(dr);
obj.LoadReviewButton = uibutton(dr, "Text", "Load", ...
    "Tooltip", "Load the results folder above.", ...
    "ButtonPushedFcn", @(~,~) obj.loadReviewResults());

br = uigridlayout(left, [1 2]);
br.ColumnWidth = {'1x', '1x'};
br.Padding = [0 0 0 0];
obj.OpenReviewFolderButton = uibutton(br, "Text", "Open folder in explorer", ...
    "ButtonPushedFcn", @(~,~) obj.onOpenReviewFolder());
obj.ReviewPhyButton = uibutton(br, "Text", "Open in phy", ...
    "ButtonPushedFcn", @(~,~) obj.onReviewOpenPhy(), ...
    "Tooltip", "Run 'phy template-gui params.py' in the results folder above");

uilabel(left, "Text", "Summary", "FontWeight", "bold");

summaryPanel = uipanel(left);
sg = uigridlayout(summaryPanel, [1 1]);
sg.Padding = [8 6 8 6];
obj.ReviewSummaryLabel = uilabel(sg, ...
    "Text", "Pick a Kilosort4 results folder and press Load.", ...
    "VerticalAlignment", "top", "WordWrap", "on", ...
    "FontName", "monospaced", "FontColor", [0.2 0.2 0.2]);

% Ch = peak channel name; X / Y = template centre on the probe (um); Notes is
% editable and saved to cluster_notes.tsv next to the sort (onReviewNoteEdited).
obj.ReviewUnitsTable = uitable(left, ...
    "ColumnName", {'Unit', 'Group', 'Shank', 'Ch', 'X(um)', 'Y(um)', '#Spk', 'FR(Hz)', 'Amp', 'Cont%', 'Notes'}, ...
    "ColumnWidth", {44, 50, 46, 54, 52, 52, 52, 56, 48, 50, 200}, ...
    "ColumnEditable", [false(1, 10) true], ...
    "RowName", {}, ...
    "ColumnSortable", true, ...
    "SelectionType", "row", ...
    "CellSelectionCallback", @(~, evt) obj.onReviewUnitSelected(evt), ...
    "CellEditCallback", @(~, evt) obj.onReviewNoteEdited(evt));
obj.ReviewUnitsTable.Layout.Row = 7;

obj.ReviewAllUnitsButton = uibutton(left, "Text", "Show all units", ...
    "ButtonPushedFcn", @(~,~) obj.onReviewAllUnits());

% =================== right column: 2x2 axes + the unit on its shank ===================
right = uigridlayout(g, [2 3]);
right.Layout.Column = 2;
right.ColumnWidth = {'1x', '1x', '1x'};
right.RowSpacing = 14;
right.ColumnSpacing = 14;

obj.ReviewShankAxes = uiaxes(right);
obj.ReviewShankAxes.Layout.Row = 1; obj.ReviewShankAxes.Layout.Column = 1;
title(obj.ReviewShankAxes, "Units per shank");

obj.ReviewWaveAxes = uiaxes(right);
obj.ReviewWaveAxes.Layout.Row = 1; obj.ReviewWaveAxes.Layout.Column = 2;
title(obj.ReviewWaveAxes, "Mean waveforms");

obj.ReviewAmpAxes = uiaxes(right);
obj.ReviewAmpAxes.Layout.Row = 2; obj.ReviewAmpAxes.Layout.Column = 1;
title(obj.ReviewAmpAxes, "Amplitudes over time");

obj.ReviewRateAxes = uiaxes(right);
obj.ReviewRateAxes.Layout.Row = 2; obj.ReviewRateAxes.Layout.Column = 2;
title(obj.ReviewRateAxes, "Firing rate per unit");

% The selected unit's spikes at the sites of the shank it was detected on,
% full height: what to draw above it (renderReviewUnitShank).
sp = uigridlayout(right, [2 1]);
sp.Layout.Row = [1 2]; sp.Layout.Column = 3;
sp.RowHeight = {30, '1x'};
sp.Padding = [0 0 0 0];
sp.RowSpacing = 4;
sc = uigridlayout(sp, [1 4]);
sc.ColumnWidth = {'fit', 70, 'fit', 70};
sc.Padding = [0 0 0 0];
sc.ColumnSpacing = 6;
redraw = @(~,~) obj.renderReviewUnitShank();
obj.ReviewShankSpikesCheckBox = uicheckbox(sc, "Text", "Spikes", "Value", true, ...
    "Tooltip", "Draw the unit's spikes, cut from the sorted .bin", ...
    "ValueChangedFcn", redraw);
obj.ReviewShankCountSpinner = uispinner(sc, "Limits", [10 2000], "Step", 50, "Value", 100, ...
    "RoundFractionalValues", "on", ...
    "Tooltip", "How many of the unit's spikes to read (picked at random, the same ones each time); the mean is over these", ...
    "ValueChangedFcn", redraw);
obj.ReviewShankMeanCheckBox = uicheckbox(sc, "Text", "Mean " + char(177), "Value", true, ...
    "Tooltip", "Draw the spikes' mean with an error band", ...
    "ValueChangedFcn", redraw);
obj.ReviewShankBandDropDown = uidropdown(sc, "Items", {'SD', 'SEM', 'none'}, "Value", 'SD', ...
    "Tooltip", "Error band around the mean: standard deviation, standard error of the mean, or none", ...
    "ValueChangedFcn", redraw);
obj.ReviewUnitShankAxes = uiaxes(sp);
obj.ReviewUnitShankAxes.Layout.Row = 2;
title(obj.ReviewUnitShankAxes, "Unit on its shank");
end
