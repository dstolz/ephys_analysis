function buildReviewTab(obj)
%buildReviewTab  Summary stats + plots for a Kilosort4 results folder.
%   The active dataset's sorted output loads when the tab opens or the
%   dataset changes (syncReviewDataset); Browse... / Load take any other
%   kilosort4/ output folder. The left column shows aggregate stats and a
%   per-unit table. On the right, the selected unit's inter-spike interval
%   histogram and autocorrelogram sit above spike amplitudes over time, and
%   beside them, largest, the selected unit's spikes on the shank it was
%   detected on, with units per shank and per-unit firing rates below it.
%   A row above the three timing plots overlays the unit's mean waveform
%   and / or a subsample of its spikes on each, at a compass point, scaled.
%   Selecting a table row focuses the timing and amplitude plots on that
%   single unit and draws its spikes; "Show all units" clears the focus.
%   All parsing happens once in loadReviewResults; selection re-renders from
%   the cached ReviewData and reads only the selected unit's spikes. See
%   loadReviewResults / renderReviewPlots / renderReviewUnitShank.

g = uigridlayout(obj.TabReview, [1 2]);
g.ColumnWidth = {470, '1x'};
g.Padding     = [10 10 10 10];

% =================== left column: source + stats + table ===================
left = uigridlayout(g, [9 1]);
left.Layout.Column = 1;
left.RowHeight = {'fit', 'fit', 30, 30, 'fit', 220, 'fit', '1x', 30};
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

% Good-unit criteria (the config's Sorting.Quality, unitQualityPass): the QC
% column and the QC report judge the units by them.
cp = uipanel(left, "Title", "Good-unit criteria (Sorting.Quality; blank = not applied)");
cp.Layout.Row = 7;
cg = uigridlayout(cp, [2 6]);
cg.RowHeight = {24, 24};
cg.ColumnWidth = {'fit', '1x', 'fit', '1x', 'fit', '1x'};
cg.Padding = [6 4 6 4];
cg.RowSpacing = 4;
crit = ["isiViolationsRatioMax" "ISI ratio <" "isiViolationsRatio (SpikeInterface): the rate of a hypothetical contaminating unit, relative to the unit's"; ...
        "presenceRatioMin"      "Presence >" "presenceRatio: the fraction of the recording's whole 60 s bins with a spike"; ...
        "amplitudeCutoffMax"    "Cutoff <"   "amplitudeCutoff: the estimated fraction of spikes missed below the detection threshold"; ...
        "snrMin"                "SNR >"      "snr: the template's peak over the noise of the 300 Hz high-passed recording on the peak channel"; ...
        "driftPtpMax"           "Drift <"    "driftPtp (um): the range of the unit's median depth over 60 s intervals (needs spike_positions.npy)"; ...
        "firingRateMin"         "Rate >"     "firingRate (Hz) over the sorted span"];
obj.ReviewCriteriaFields = struct();
for k = 1:size(crit, 1)
    l = uilabel(cg, "Text", crit(k, 2), "Tooltip", crit(k, 3));
    l.Layout.Row = 1 + (k > 3); l.Layout.Column = 2 * mod(k - 1, 3) + 1;
    fld = uieditfield(cg, "text", "Placeholder", "off", "Tooltip", crit(k, 3), ...
        "ValueChangedFcn", @(~,~) obj.onReviewCriteriaChanged());
    fld.Layout.Row = 1 + (k > 3); fld.Layout.Column = 2 * mod(k - 1, 3) + 2;
    obj.ReviewCriteriaFields.(crit(k, 1)) = fld;
end

% Ch = peak channel name; X / Y = template centre on the probe (um); QC =
% meets the criteria above, then the metrics they judge (EphysDataset.unitQuality:
% ISI violations ratio, presence ratio, amplitude cutoff, SNR); Notes is
% editable and saved to cluster_notes.tsv next to the sort (onReviewNoteEdited).
% A header click's sort is kept for every sort loaded (showReviewUnits);
% right-click clears it.
obj.ReviewUnitsTable = uitable(left, ...
    "ColumnName", {'Unit', 'Group', 'Shank', 'Ch', 'X(um)', 'Y(um)', '#Spk', 'FR(Hz)', 'Amp', 'Cont%', ...
        'QC', 'ISIv', 'Pres', 'Cutoff', 'SNR', 'Notes'}, ...
    "ColumnWidth", {44, 50, 46, 54, 52, 52, 52, 56, 48, 50, 34, 44, 40, 48, 40, 200}, ...
    "ColumnEditable", [false(1, 15) true], ...
    "RowName", {}, ...
    "ColumnSortable", true, ...
    "SelectionType", "row", ...
    "CellSelectionCallback", @(~, evt) obj.onReviewUnitSelected(evt), ...
    "CellEditCallback", @(~, evt) obj.onReviewNoteEdited(evt), ...
    "DisplayDataChangedFcn", @(~, evt) obj.onTableSorted("Review", evt), ...
    "ContextMenu", uicontextmenu(obj.Fig, "ContextMenuOpeningFcn", @(m, ~) obj.onTableSortMenu(m, "Review")));
obj.ReviewUnitsTable.Layout.Row = 8;

ub = uigridlayout(left, [1 2]);
ub.Layout.Row = 9;
ub.ColumnWidth = {'1x', '1x'};
ub.Padding = [0 0 0 0];
obj.ReviewAllUnitsButton = uibutton(ub, "Text", "Show all units", ...
    "ButtonPushedFcn", @(~,~) obj.onReviewAllUnits());
obj.ReviewQCButton = uibutton(ub, "Text", "QC report", ...
    "Tooltip", "Write the loaded sort's unit-quality page (quality_report.html in the results folder) and open it", ...
    "ButtonPushedFcn", @(~,~) obj.onReviewQCReport());

% =================== right: ISI + ACG over amplitudes | the unit on its shank ===================
right = uigridlayout(g, [3 3]);
right.Layout.Column = 2;
right.ColumnWidth = {'1x', '1x', '1x'};
right.RowHeight = {30, '1x', '1x'};
right.RowSpacing = 14;
right.ColumnSpacing = 14;

% The waveform inset on the three timing plots: the unit's mean and / or a
% subsample of its spikes on the peak channel, at a compass point of each plot
% and scaled (renderReviewPlots).
wr = uigridlayout(right, [1 6]);
wr.Layout.Row = 1; wr.Layout.Column = [1 2];
wr.ColumnWidth = {'fit', 130, 'fit', 110, 'fit', 70};
wr.Padding = [0 0 0 0];
wr.ColumnSpacing = 6;
redrawPlots = @(~,~) obj.renderReviewPlots();
uilabel(wr, "Text", "Waveform on plots:");
obj.ReviewWaveModeDropDown = uidropdown(wr, ...
    "Items", {'Off', 'Mean', 'Subsample', 'Mean + subsample'}, ...
    "ItemsData", {'off', 'mean', 'sample', 'both'}, "Value", 'off', ...
    "Tooltip", "Overlay the selected unit's waveform on its peak channel on the interval, autocorrelogram and amplitude plots: the mean, a subsample of its spikes (the number read for the shank plot), or both", ...
    "ValueChangedFcn", redrawPlots);
uilabel(wr, "Text", "at");
obj.ReviewWaveLocDropDown = uidropdown(wr, ...
    "Items", {'North', 'North-east', 'East', 'South-east', 'South', 'South-west', 'West', 'North-west', 'Centre'}, ...
    "ItemsData", {'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'C'}, "Value", 'NE', ...
    "Tooltip", "Where on each plot the waveform sits: north is the top edge, east the right", ...
    "ValueChangedFcn", redrawPlots);
uilabel(wr, "Text", "scale");
obj.ReviewWaveScaleSpinner = uispinner(wr, "Limits", [0.25 3], "Step", 0.25, "Value", 1, ...
    "ValueDisplayFormat", "%.2gx", ...
    "Tooltip", "Size of the waveform box, a factor of its default (a third of each plot's width and height)", ...
    "ValueChangedFcn", redrawPlots);

obj.ReviewISIAxes = uiaxes(right);
obj.ReviewISIAxes.Layout.Row = 2; obj.ReviewISIAxes.Layout.Column = 1;
title(obj.ReviewISIAxes, "Inter-spike intervals");

obj.ReviewACGAxes = uiaxes(right);
obj.ReviewACGAxes.Layout.Row = 2; obj.ReviewACGAxes.Layout.Column = 2;
title(obj.ReviewACGAxes, "Autocorrelogram");

obj.ReviewAmpAxes = uiaxes(right);
obj.ReviewAmpAxes.Layout.Row = 3; obj.ReviewAmpAxes.Layout.Column = [1 2];
title(obj.ReviewAmpAxes, "Amplitudes over time");

% The selected unit's spikes at the sites of the shank it was detected on,
% most of the height, with what to draw above it (renderReviewUnitShank);
% units per shank and firing rates, smaller, below it.
sp = uigridlayout(right, [4 1]);
sp.Layout.Row = [1 3]; sp.Layout.Column = 3;
sp.RowHeight = {30, '2.5x', '1x', '1x'};
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

obj.ReviewShankAxes = uiaxes(sp);
obj.ReviewShankAxes.Layout.Row = 3;
title(obj.ReviewShankAxes, "Units per shank");

obj.ReviewRateAxes = uiaxes(sp);
obj.ReviewRateAxes.Layout.Row = 4;
title(obj.ReviewRateAxes, "Firing rate per unit");
end
