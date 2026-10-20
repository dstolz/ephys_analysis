function buildArtifactsTab(obj)
%buildArtifactsTab  Artifacts step: automatic detection settings + preview,
%   an artifact viewer, and the manual periods of the active dataset (the
%   Dataset box). Edits the config's Artifacts section (gatherArtifactsSection /
%   applyArtifactsSection) and its Reference section (below). Manual
%   periods are per dataset (marked here, saved in the manifest) and always
%   apply; the automatic detector applies when the step is enabled. Where
%   the intervals are used (sorting, spike detection) is chosen here too.
%   After a preview the viewer steps through
%   the detected artifacts one at a time, each with the signal around it,
%   the kept and removed samples drawn apart; Go to (s) shows any stretch
%   of the recording instead.
%
%   One plot holds both kinds of period: the detected (automatic) artifacts
%   shaded orange and the manual periods purple (artifactColors). With Mark
%   artifacts on (under the periods table) a drag over the plot adds a
%   manual period and a click on one removes it (onArtViewInput).
%
%   The common reference (CAR / CMR) comes first, in a panel of its own: it
%   is the config's Reference section (gatherReferenceSection /
%   applyReferenceSection), not part of Artifacts, since every step that
%   reads the recording subtracts it (artifact detection, the sorting .bin,
%   spike detection, the signals ticked on the Signals tab, Visualize "As
%   the pipeline"). It sits here because detection is the first of those
%   reads and the viewer shows its effect. The panel also holds the active
%   dataset's channels left out of the reference, suggested by the
%   noise-floor rule of Ludwig et al. 2009 (onSuggestReferenceExclude) or
%   typed in (onReferenceExcludeEdited).
%
%   Three columns: the reference and the detection settings with the manual
%   periods below them, the viewer (the plot takes the full height), and the preview's
%   summary with its per-channel table. With a probe assigned to the
%   dataset the viewer and the table can follow the probe layout, show one
%   shank and color the channels by shank (syncArtProbeControls). The
%   wheel and keys scale the plot's voltage and time, S or Shade artifacts
%   turns the shading off and on, and Ctrl+drag moves the chosen artifact's
%   onset or offset, kept for the dataset (Restore bounds puts them back;
%   onArtViewInput).
%
%   Measure (beside Shade artifacts) turns a drag over the plot into a
%   selection instead: the stretch dragged over is scored by every
%   detection method at once (running RMS, MAD, absolute, common mode;
%   measureArtifactSelection) and shown on the right column's Selection
%   tab, per method and per channel, to see what each would make of it and
%   how far it is from its threshold. A click clears the selection.
%
%   See also EphysDataset.detectArtifacts, EphysDataset.analyzeArtifacts,
%   EphysDataset.artifactIntervals, EphysDataset.channelLayout,
%   onDetectArtifacts, showArtifactView, drawArtifactView, onArtViewInput.

g = uigridlayout(obj.TabArtifacts, [1 3]);
g.ColumnWidth = {400, '1x', 350};
g.Padding     = [10 10 10 10];
changed = @(~,~) obj.onArtifactControlsChanged();

% =========== left: the reference, the controls, then the manual periods ===========
left = uigridlayout(g, [3 1]);
left.Layout.Column = 1;
left.Padding = [0 0 0 0];
left.RowHeight = {'fit', '1x', 210};

buildReferencePanel(obj, left, changed);

ctrl = uipanel(left, "Title", "Automatic artifact detection (config: Artifacts)");
ctrl.Layout.Row = 2;

nRows = 18;
cg = uigridlayout(ctrl, [nRows 2]);
cg.RowHeight   = [repmat({'fit'}, 1, nRows - 1), {'1x'}];
cg.ColumnWidth = {'fit', '1x'};
cg.RowSpacing  = 6;
cg.Scrollable  = "on";

row = 1;
obj.ArtEnableCheckBox = uicheckbox(cg, "Text", "Enable automatic detection", "FontWeight", "bold", "Value", false, ...
    "Tooltip", "Manual periods (Mark artifacts, below) always apply, whether or not this is on.", ...
    "ValueChangedFcn", changed);
obj.ArtEnableCheckBox.Layout.Row = row; obj.ArtEnableCheckBox.Layout.Column = [1 2];

row = row + 1;
lab(cg, "Dataset:", row);
obj.ArtDatasetDropDown = obj.datasetPicker(cg);
obj.ArtDatasetDropDown.Layout.Row = row; obj.ArtDatasetDropDown.Layout.Column = 2;

row = row + 1;
lab(cg, "Method:", row);
obj.ArtMethodDropDown = uidropdown(cg);
obj.ArtMethodDropDown.Items = {'Running RMS (per-channel SD)', 'MAD (per-channel SD)', ...
              'Absolute microvolts', 'Common-mode (mean)'};
obj.ArtMethodDropDown.ItemsData = {'rms', 'mad', 'microvolts', 'commonmode'};
obj.ArtMethodDropDown.Value = 'rms';
obj.ArtMethodDropDown.ValueChangedFcn = changed;
obj.ArtMethodDropDown.Layout.Row = row; obj.ArtMethodDropDown.Layout.Column = 2;

row = row + 1;
lab(cg, "Threshold:", row);
obj.ArtThresholdField = uieditfield(cg, "numeric", "Value", 9, "Limits", [0 Inf], ...
    "Tooltip", "Robust SDs above the per-channel baseline (microvolts for the absolute method).", ...
    "ValueChangedFcn", changed);
obj.ArtThresholdField.Layout.Row = row; obj.ArtThresholdField.Layout.Column = 2;

row = row + 1;
lab(cg, "RMS window (ms):", row);
obj.ArtRmsWindowField = uieditfield(cg, "numeric", "Value", 1, "Limits", [0 Inf], ...
    "Tooltip", "Running-RMS window length (ms). 0 = auto (~1 ms). RMS method only.", ...
    "ValueChangedFcn", changed);
obj.ArtRmsWindowField.Layout.Row = row; obj.ArtRmsWindowField.Layout.Column = 2;

row = row + 1;
lab(cg, "Stitch gap (ms):", row);
obj.ArtMergeGapField = uieditfield(cg, "numeric", "Value", 0, "Limits", [0 Inf], ...
    "Tooltip", "Merge artifacts separated by at most this much clean signal.", ...
    "ValueChangedFcn", changed);
obj.ArtMergeGapField.Layout.Row = row; obj.ArtMergeGapField.Layout.Column = 2;

row = row + 1;
lab(cg, "Pad (ms):", row);
obj.ArtPadField = uieditfield(cg, "numeric", "Value", 0, "Limits", [0 Inf], ...
    "Tooltip", "Expand each flagged region by this much on both sides.", ...
    "ValueChangedFcn", changed);
obj.ArtPadField.Layout.Row = row; obj.ArtPadField.Layout.Column = 2;

row = row + 1;
lab(cg, "Min channels:", row);
obj.ArtMinChannelsField = uieditfield(cg, "numeric", "Value", 2, "Limits", [1 Inf], ...
    "RoundFractionalValues", "on", "Tooltip", ...
    "Channels that must exceed the threshold at the same sample (ignored for common-mode).", ...
    "ValueChangedFcn", changed);
obj.ArtMinChannelsField.Layout.Row = row; obj.ArtMinChannelsField.Layout.Column = 2;

row = row + 1;
obj.ArtFilterCheckBox = uicheckbox(cg, "Text", "High-pass before detecting", "Value", false, ...
    "Tooltip", "Detect on the high-pass-filtered signal instead of broadband (applies to runs and previews alike).", ...
    "ValueChangedFcn", changed);
obj.ArtFilterCheckBox.Layout.Row = row; obj.ArtFilterCheckBox.Layout.Column = [1 2];

row = row + 1;
lab(cg, "High-pass (Hz):", row);
obj.ArtHighpassField = uieditfield(cg, "numeric", "Value", 300, "Limits", [0 Inf], "Enable", "off", ...
    "ValueChangedFcn", changed);
obj.ArtHighpassField.Layout.Row = row; obj.ArtHighpassField.Layout.Column = 2;

row = row + 1;
lab(cg, "Erase with:", row);
obj.ArtFillDropDown = uidropdown(cg);
obj.ArtFillDropDown.Items = {'Gaussian noise (recording level)', 'Zeros'};
obj.ArtFillDropDown.ItemsData = {'noise', 'zero'};
obj.ArtFillDropDown.Value = 'noise';
obj.ArtFillDropDown.Tooltip = "What replaces the artifact samples, manual periods included. " + ...
    "A sorter such as Kilosort4 reads a block of zeros across every channel as a signal discontinuity, " + ...
    "so the periods are filled with per-channel Gaussian noise at the recording's own " + ...
    "level (measured over the whole recording, above 300 Hz; the band and the random " + ...
    "seed are the config's NoiseBandHz and NoiseSeed).";
obj.ArtFillDropDown.ValueChangedFcn = changed;
obj.ArtFillDropDown.Layout.Row = row; obj.ArtFillDropDown.Layout.Column = 2;

row = row + 1;
obj.ArtApplySortingCheckBox = uicheckbox(cg, "Text", "Erase in sorting (in the .bin the sorter sorts)", ...
    "Value", true, "ValueChangedFcn", changed);
obj.ArtApplySortingCheckBox.Layout.Row = row; obj.ArtApplySortingCheckBox.Layout.Column = [1 2];
row = row + 1;
obj.ArtApplySpikesCheckBox = uicheckbox(cg, "Text", "Apply in spike detection (reject or erase: Spikes tab)", ...
    "Value", true, "Tooltip", "Spike detection takes these periods as the Spikes tab's ""Artifact periods"" " + ...
    "says: rejecting the events inside them, or erasing them before detection so it runs on the cleaned " + ...
    "recording. Manual periods always apply unless that setting ignores the periods.", ...
    "ValueChangedFcn", changed);
obj.ArtApplySpikesCheckBox.Layout.Row = row; obj.ArtApplySpikesCheckBox.Layout.Column = [1 2];
row = row + 1;
obj.ArtApplySignalsCheckBox = uicheckbox(cg, "Text", "Erase in the signals (LFP / MUA / SPIKE, before filtering)", ...
    "Value", true, "Tooltip", "The Signals step erases the periods in the recording before it derives " + ...
    "any signal, so no filter spreads an artifact into its neighbors, and records them in every " + ...
    "signal file; the analysis and Export's epochs (Artifact periods: drop) drop the epochs that touch one. Manual periods always " + ...
    "apply while the Signals tab's erase switch is on.", "ValueChangedFcn", changed);
obj.ArtApplySignalsCheckBox.Layout.Row = row; obj.ArtApplySignalsCheckBox.Layout.Column = [1 2];
row = row + 1;
obj.ArtCacheCheckBox = uicheckbox(cg, "Text", "Cache intervals (<Name>_artifacts.json)", ...
    "Value", true, "Tooltip", "Reuse detected intervals across steps and runs while the settings and manual periods are unchanged.", ...
    "ValueChangedFcn", changed);
obj.ArtCacheCheckBox.Layout.Row = row; obj.ArtCacheCheckBox.Layout.Column = [1 2];

% Display only (the detectors treat every channel alike), so it is not part
% of the config; syncArtProbeControls sets it per dataset.
row = row + 1;
obj.ArtProbeOrderCheckBox = uicheckbox(cg, "Text", "Order channels by probe layout", ...
    "Value", false, "Enable", "off", "Tooltip", ...
    "Show the channels in the plot and the per-channel table as they sit on the probe: " + ...
    "by shank, then from the top of each shank down. Needs a probe assigned to the dataset " + ...
    "(Probe tab), and is on by default when it has one. Detection is the same either way.", ...
    "ValueChangedFcn", @(~,~) probeOrderChanged(obj));
obj.ArtProbeOrderCheckBox.Layout.Row = row; obj.ArtProbeOrderCheckBox.Layout.Column = [1 2];

row = row + 1;
obj.ArtDetectButton = uibutton(cg, "Text", "Detect / Preview", ...
    "ButtonPushedFcn", @(~,~) obj.onDetectArtifacts());
obj.ArtDetectButton.Layout.Row = row; obj.ArtDetectButton.Layout.Column = [1 2];
cg.RowHeight{row} = 30;

row = row + 1;
obj.ArtStatusLabel = uilabel(cg, "Text", "", "FontColor", [0.4 0.4 0.4], "WordWrap", "on");
obj.ArtStatusLabel.Layout.Row = row; obj.ArtStatusLabel.Layout.Column = [1 2];

manual = uipanel(left);
manual.Layout.Row = 3;
mg = uigridlayout(manual, [3 2]);
mg.RowHeight = {'fit', '1x', 30};
mg.ColumnWidth = {'1x', 'fit'};
mg.Padding = [8 8 8 8];
mg.RowSpacing = 6;
obj.ArtManualLabel = uilabel(mg, "Text", "Manual periods (scan a project first)", ...
    "FontWeight", "bold", "WordWrap", "on");
obj.ArtManualLabel.Layout.Row = 1; obj.ArtManualLabel.Layout.Column = [1 2];
obj.ArtManualTable = uitable(mg, "ColumnName", {'Start (s)', 'End (s)', 'Duration (s)'}, ...
    "ColumnWidth", {'1x', '1x', '1x'}, "RowName", {});
obj.ArtManualTable.Layout.Row = 2; obj.ArtManualTable.Layout.Column = [1 2];
makeSortable(obj, obj.ArtManualTable);
obj.ArtMarkButton = uibutton(mg, "state", "Text", "Mark artifacts: off", "Enable", "off", ...
    "Tooltip", ["Toggle manual marking on the plot. When on: drag over the plot to mark a period " ...
        "(purple); click a purple period to remove it (Esc turns it off). The plot shows a detected " ...
        "artifact, or any stretch of the recording with Go to (s). Periods are saved to the " ...
        "dataset's manifest and erased from the .bin and the signals by a run."], ...
    "ValueChangedFcn", @(src, ~) obj.onArtViewInput("mark", src.Value));
obj.ArtMarkButton.Layout.Row = 3; obj.ArtMarkButton.Layout.Column = 1;
obj.ArtManualClearButton = uibutton(mg, "Text", "Clear", "ButtonPushedFcn", @(~,~) obj.onClearManualArtifacts());
obj.ArtManualClearButton.Layout.Row = 3; obj.ArtManualClearButton.Layout.Column = 2;

% =========== middle: the artifact viewer, full height ===========
% One detected artifact at a time with the signal around it, or a stretch of
% the recording (showArtifactView reads, drawArtifactView draws); the
% detected and the manual periods are shaded on it, and marked on it.
mid = uigridlayout(g, [6 1]);
mid.Layout.Column = 2;
mid.Padding = [0 0 0 0];
mid.RowSpacing = 4;
mid.RowHeight = {'fit', 'fit', 'fit', 'fit', '1x', 'fit'};

nav = uigridlayout(mid, [1 11]);
nav.Padding = [0 0 0 0]; nav.ColumnSpacing = 6;
nav.ColumnWidth = {'fit', 34, 64, 'fit', 34, 'fit', '1x', 'fit', 70, 'fit', 60};
uilabel(nav, "Text", "Detected artifacts", "FontWeight", "bold");
obj.ArtViewPrevButton = uibutton(nav, "Text", char(9664), "Tooltip", "Previous artifact", ...
    "ButtonPushedFcn", @(~,~) stepArtifact(obj, -1));
obj.ArtViewSpinner = uispinner(nav, "Limits", [1 Inf], "Step", 1, "RoundFractionalValues", "on", ...
    "Value", 1, "Tooltip", "Artifact number, in recording order", ...
    "ValueChangedFcn", @(~,~) obj.showArtifactView("artifact"));
obj.ArtViewCountLabel = uilabel(nav, "Text", "of 0");
obj.ArtViewNextButton = uibutton(nav, "Text", char(9654), "Tooltip", "Next artifact", ...
    "ButtonPushedFcn", @(~,~) stepArtifact(obj, 1));
obj.ArtViewRestoreButton = uibutton(nav, "Text", "Restore bounds", "Enable", "off", "Tooltip", ...
    "Put this artifact's onset and offset back where the detector found them " + ...
    "(Ctrl+drag over the plot moves them).", ...
    "ButtonPushedFcn", @(~,~) obj.onArtViewInput("restore", []));
uilabel(nav, "Text", "");
uilabel(nav, "Text", "Go to (s):", "HorizontalAlignment", "right");
obj.ArtViewGotoField = uieditfield(nav, "numeric", "Value", 0, "Limits", [0 Inf], ...
    "ValueDisplayFormat", "%.4g", "Enable", "off", "Tooltip", ...
    "Show the recording from this time, to mark manual periods anywhere: 2 s, or the width " + ...
    "of the stretch shown (PgDn / PgUp then page through it). The artifact number goes back " + ...
    "to the detected artifacts.", ...
    "ValueChangedFcn", @(src, ~) gotoTime(obj, src.Value));
uilabel(nav, "Text", "Context (ms):", "HorizontalAlignment", "right");
obj.ArtViewContextField = uieditfield(nav, "numeric", "Value", 0, "Limits", [0 60000], ...
    "Tooltip", "Signal shown before and after the artifact. 0 = auto (twice its length, 25 ms to 5 s). " + ...
    "Not used for a stretch shown with Go to (s).", ...
    "ValueChangedFcn", @(~,~) obj.showArtifactView());

chans = uigridlayout(mid, [1 6]);
chans.Padding = [0 0 0 0]; chans.ColumnSpacing = 6;
chans.ColumnWidth = {'fit', 50, 'fit', 110, 'fit', '1x'};
uilabel(chans, "Text", "Channels:");
obj.ArtViewChannelsField = uieditfield(chans, "numeric", "Value", 8, "Limits", [1 Inf], ...
    "RoundFractionalValues", "on", "Tooltip", ...
    "How many channels to draw: the ones the artifact is largest on (on the chosen shank).", ...
    "ValueChangedFcn", @(~,~) obj.drawArtifactView());
uilabel(chans, "Text", "Shank:", "HorizontalAlignment", "right");
obj.ArtViewShankDropDown = uidropdown(chans, "Items", {'All shanks'}, "ItemsData", {'all'}, ...
    "Value", 'all', "Enable", "off", "Tooltip", ...
    "Draw the channels of one shank only (needs a probe assigned to the dataset).", ...
    "ValueChangedFcn", @(~,~) obj.drawArtifactView());
obj.ArtViewShankColorCheckBox = uicheckbox(chans, "Text", "Color by shank", "Value", true, ...
    "Enable", "off", "Tooltip", ...
    "Draw each shank's kept signal in its own color (needs a probe assigned to the dataset).", ...
    "ValueChangedFcn", @(~,~) obj.drawArtifactView());

sc = uigridlayout(mid, [1 8]);
sc.Padding = [0 0 0 0]; sc.ColumnSpacing = 6;
sc.ColumnWidth = {'fit', 150, 'fit', 70, '1x', 'fit', 'fit', 'fit'};
uilabel(sc, "Text", "Scale:");
obj.ArtViewScaleDropDown = uidropdown(sc, "Items", {'Fit the artifact', 'Fit the kept signal', 'Manual'}, ...
    "ItemsData", {'artifact', 'kept', 'manual'}, "Value", 'artifact', ...
    "Tooltip", "Fit the kept signal to check that nothing of the artifact is left either side, " + ...
    "or set the lane spacing by hand (Lanes). Larger values are clipped.", ...
    "ValueChangedFcn", @(~,~) scaleChanged(obj));
uilabel(sc, "Text", "Lanes (uV):", "HorizontalAlignment", "right");
obj.ArtViewLanesField = uieditfield(sc, "numeric", "Value", 0, "Limits", [0 Inf], ...
    "ValueDisplayFormat", "%.4g", "Tooltip", ...
    "Microvolts between lanes: shows the spacing drawn; type one to set it by hand (Scale: Manual).", ...
    "ValueChangedFcn", @(~,~) lanesChanged(obj));
uilabel(sc, "Text", "");
obj.ArtMeasureButton = uibutton(sc, "state", "Text", "Measure: off", "Value", false, "Enable", "off", ...
    "Tooltip", "Drag over the plot to select a stretch and score it with every detection method " + ...
    "(running RMS, MAD, absolute, common mode) against the window shown; the results are on the " + ...
    "Selection tab (right). A click clears the selection; Esc (or M) turns it off.", ...
    "ValueChangedFcn", @(src, ~) obj.onArtViewInput("measure", src.Value));
obj.ArtViewShadeButton = uibutton(sc, "state", "Text", "Shade artifacts", "Value", true, ...
    "Tooltip", "Shade the detected artifacts (orange) and the manual periods (purple) over the " + ...
    "signal; off to see the signal under them (S over the plot). The chosen artifact's bounds " + ...
    "stay drawn as dashed lines.", ...
    "ValueChangedFcn", @(~,~) obj.onArtViewInput("shade", []));
obj.ArtViewResetButton = uibutton(sc, "Text", "Reset view", ...
    "Tooltip", "Show the whole window at the Scale fit (R over the plot)", ...
    "ButtonPushedFcn", @(~,~) obj.onArtViewInput("reset", []));

obj.ArtViewNoteLabel = uilabel(mid, "Text", "", "WordWrap", "on");

% The wheel zoom is onArtViewInput's (time only), so the axes keep just the
% drag pan (along time) and data tips of their built-in interactions.
obj.ArtViewAxes = uiaxes(mid);
obj.ArtViewAxes.Toolbar.Visible = "on";
obj.ArtViewAxes.Interactions = [panInteraction(Dimensions="x"), dataTipInteraction];
obj.drawArtifactView();   % the empty state

uilabel(mid, "WordWrap", "on", "FontColor", [0.45 0.45 0.45], "Text", ...
    "Pointer over the plot: wheel zooms time, drag or " + char(8592) + "/" + char(8594) + ...
    " pans, Shift+" + char(8592) + "/" + char(8594) + " zooms time, Ctrl+wheel, " + ...
    char(8593) + "/" + char(8595) + " or +/" + char(8722) + " scale the voltage, S shades, R resets. " + ...
    "PgDn / N and PgUp / P step to the next and previous artifact (Shift: ten), End and Home to the last and first; " + ...
    "on a stretch shown with Go to (s) they page through the recording. " + ...
    "Hold Ctrl and drag to move the artifact's nearer bound (dashed); it is saved for the dataset. " + ...
    "Orange: detected (automatic) artifacts; purple: manual periods. With Mark artifacts on, drag to mark a " + ...
    "manual period and click a purple one to remove it; Esc stops marking. With Measure on (M), drag to " + ...
    "select a stretch (blue) and score it with every method (Selection tab, right); a click clears it.");

% =========== right: the preview's summary and per-channel table, and the selection's ===========
obj.ArtResultTabs = uitabgroup(g);
obj.ArtResultTabs.Layout.Column = 3;
previewTab = uitab(obj.ArtResultTabs, "Title", "Preview");
right = uigridlayout(previewTab, [3 1]);
right.Padding = [4 6 4 4];
right.RowSpacing = 6;
right.RowHeight = {'fit', 215, '1x'};

uilabel(right, "Text", "Preview summary", "FontWeight", "bold");
summaryPanel = uipanel(right);
sg = uigridlayout(summaryPanel, [1 1]);
sg.Padding = [8 6 8 6];
obj.ArtSummaryLabel = uilabel(sg, "Text", "Pick a dataset and press Detect / Preview.", ...
    "VerticalAlignment", "top", "WordWrap", "on", "FontName", "monospaced", "FontColor", [0.2 0.2 0.2]);
obj.ArtChannelTable = uitable(right, "RowName", {});
makeSortable(obj, obj.ArtChannelTable);
obj.refreshArtChannelTable();   % its columns

% The stretch selected with Measure, scored by every method.
obj.ArtSelectionTab = uitab(obj.ArtResultTabs, "Title", "Selection");
sel = uigridlayout(obj.ArtSelectionTab, [3 1]);
sel.Padding = [4 6 4 4];
sel.RowSpacing = 6;
sel.RowHeight = {'fit', 125, '1x'};
selPanel = uipanel(sel);
pg = uigridlayout(selPanel, [1 1]);
pg.Padding = [8 6 8 6];
obj.ArtSelectionLabel = uilabel(pg, "VerticalAlignment", "top", "WordWrap", "on", ...
    "FontColor", [0.2 0.2 0.2]);
obj.ArtSelectionMethodTable = uitable(sel, "RowName", {}, "Tooltip", ...
    "Each detection method on the selection: its largest statistic over the channels, its " + ...
    "threshold (the method chosen on the left at the threshold set there, the others at their " + ...
    "defaults), the channels that cross it, and the share of the selection it would flag " + ...
    "(Min channels applied; no stitching or padding). Rows that would flag are shaded.");
makeSortable(obj, obj.ArtSelectionMethodTable);
obj.ArtSelectionTable = uitable(sel, "RowName", {}, "ColumnSortable", true, ...
    "DisplayDataChangedFcn", @(~, evt) obj.onTableSorted("ArtSelection", evt), ...
    "ContextMenu", uicontextmenu(obj.Fig, "ContextMenuOpeningFcn", @(m, ~) obj.onTableSortMenu(m, "ArtSelection")));
obj.measureArtifactSelection();   % the empty state

obj.routeFigureInput();         % the wheel, keys and buttons on the plot
end


function stepArtifact(obj, step)
% Previous / next artifact; the spinner's limits keep it in range. From a
% stretch of the recording (Go to), the first artifact after its start or
% the last before it.
sp = obj.ArtViewSpinner;
free = obj.ArtView.free;
if ~isempty(free)
    iv = obj.ArtView.intervals;
    if step > 0
        v = find(iv(:, 1) >= free(1), 1);
    else
        v = find(iv(:, 1) < free(1), 1, 'last');
    end
    if isempty(v); return; end
else
    v = min(max(sp.Value + step, sp.Limits(1)), sp.Limits(2));
    if v == sp.Value; return; end
end
sp.Value = v;
obj.showArtifactView("artifact");
end


function gotoTime(obj, t)
% Go to (s): the recording from time T, as wide as the stretch shown or 2 s.
wid = 2;
if ~isempty(obj.ArtView.free)
    wid = diff(obj.ArtView.free);
end
obj.showArtifactView([t, t + wid]);
end


function probeOrderChanged(obj)
% The table and the plot follow the probe order (or the recording order).
obj.refreshArtChannelTable();
obj.drawArtifactView();
end


function scaleChanged(obj)
% A new Scale fit starts from its own voltage scale.
obj.ArtView.gain = 1;
obj.drawArtifactView();
end


function lanesChanged(obj)
% A lane spacing typed in sets the scale by hand; 0 goes back to fitting.
if obj.ArtViewLanesField.Value > 0
    obj.ArtViewScaleDropDown.Value = 'manual';
elseif obj.ArtViewScaleDropDown.Value == "manual"
    obj.ArtViewScaleDropDown.Value = 'artifact';
end
obj.ArtView.gain = 1;
obj.drawArtifactView();
end


function buildReferencePanel(obj, parent, changed)
% The common reference: its mode and noise bounds (the config's Reference
% section), the weighted CAR's options, and the active dataset's channels
% left out of it (manifest). refreshReferencePanel fills the dataset part.
p = uipanel(parent, "Title", "Common reference, for every step (config: Reference)");
p.Layout.Row = 1;
rg = uigridlayout(p, [6 2]);
rg.RowHeight   = {'fit', 'fit', 'fit', 'fit', 30, 'fit'};
rg.ColumnWidth = {'fit', '1x'};
rg.RowSpacing  = 6;

note = uilabel(rg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "Subtracted once from every read of the recording: artifact detection, the sorting .bin, " + ...
    "spike detection, the signals ticked on the Signals tab and Visualize's ""As the pipeline"".");
note.Layout.Row = 1; note.Layout.Column = [1 2];

lab(rg, "Reference:", 2);
obj.ArtRefDropDown = uidropdown(rg, ...
    "Items", {'None (as recorded)', 'CAR: common average', 'CMR: common median', 'WCAR: adaptive weighted CAR'}, ...
    "ItemsData", {'none', 'car', 'cmr', 'wcar'}, "Value", 'none', ...
    "Tooltip", "Reference.Mode: subtract, sample by sample, the mean (CAR) or median (CMR) of the good " + ...
    "channels from every channel, once, as each step reads the recording: artifact detection, the sorting " + ...
    ".bin (the sorter's own common reference, such as Kilosort4's do_CAR, is then kept out), spike detection, the derived signals " + ...
    "ticked on the Signals tab (MUA and SPIKE by default, not the LFP), and the Visualize tab's " + ...
    """As the pipeline"" view. CMR is not dragged along by a large spike or artifact on a few channels. " + ...
    "WCAR (Khorasani, Shalchyan & Daliri 2019, Front. Neurosci. 13:350): each channel minus its own share " + ...
    "of the plain CAR, a weight a Kalman filter tracks sample by sample, so an artifact that reaches the " + ...
    "channels at different strengths is removed from each. Its state is worked out once per recording, " + ...
    "in a pass over every channel (about 8 s per channel-hour at 30 kHz; another pass first for an " + ...
    "automatic Q), and kept in <Name>_wcar.mat; each read is then padded for its high-pass.", ...
    "ValueChangedFcn", changed);
obj.ArtRefDropDown.Layout.Row = 2; obj.ArtRefDropDown.Layout.Column = 2;

buildWCARControls(obj, rg, 3, changed);

lab(rg, "Good noise (x median):", 4);
bg = uigridlayout(rg, [1 3]);
bg.Layout.Row = 4; bg.Layout.Column = 2;
bg.Padding = [0 0 0 0]; bg.ColumnSpacing = 6;
bg.ColumnWidth = {'1x', 'fit', '1x'};
tip = "Reference.BadLow / BadHigh: a channel whose noise floor lies outside this band, relative to the " + ...
    "median across channels, is suggested to stay out of the reference (Ludwig et al. 2009: 0.3 to 2; " + ...
    "broken sites run 3-6x).";
obj.ArtRefLowField = uieditfield(bg, "numeric", "Value", 0.3, "Limits", [0 Inf], ...
    "ValueDisplayFormat", "%.3g", "Tooltip", tip, "ValueChangedFcn", changed);
uilabel(bg, "Text", "to");
obj.ArtRefHighField = uieditfield(bg, "numeric", "Value", 2, "Limits", [0 Inf], ...
    "ValueDisplayFormat", "%.3g", "Tooltip", tip, "ValueChangedFcn", changed);

lab(rg, "Left out:", 5);
xg = uigridlayout(rg, [1 2]);
xg.Layout.Row = 5; xg.Layout.Column = 2;
xg.Padding = [0 0 0 0]; xg.ColumnSpacing = 6;
xg.ColumnWidth = {'1x', 'fit'};
obj.ArtRefExcludeField = uieditfield(xg, "text", "Value", "", "Placeholder", "none", ...
    "Tooltip", "The active dataset's channels left out of the reference (1-based, e.g. ""3,7,12-14""); " + ...
    "they are still referenced. Channels excluded on the Probe tab are left out as well. Saved in its manifest.", ...
    "ValueChangedFcn", @(~,~) obj.onReferenceExcludeEdited());
obj.ArtRefSuggestButton = uibutton(xg, "Text", "Suggest", ...
    "Tooltip", "Measure each channel's noise floor on a sample of the recording and leave out the channels " + ...
    "outside the band above.", ...
    "ButtonPushedFcn", @(~,~) obj.onSuggestReferenceExclude());

obj.ArtRefStatusLabel = uilabel(rg, "Text", "", "FontColor", [0.4 0.4 0.4], "WordWrap", "on");
obj.ArtRefStatusLabel.Layout.Row = 6; obj.ArtRefStatusLabel.Layout.Column = [1 2];
end


function buildWCARControls(obj, rg, row, changed)
% The weighted CAR's options (Reference.WCAR_*), live while Reference.Mode
% is "wcar" (refreshReferencePanel): two label / field pairs a row.
wg = uigridlayout(rg, [4 4]);
wg.Layout.Row = row; wg.Layout.Column = [1 2];
wg.Padding = [0 0 0 0]; wg.RowSpacing = 4; wg.ColumnSpacing = 6;
wg.RowHeight = {22, 22, 22, 22};
wg.ColumnWidth = {'fit', '1x', 'fit', '1x'};
place(uilabel(wg, "Text", "WCAR order:"), 1, 1);
obj.ArtRefWCAROrderField = uieditfield(wg, "numeric", "Value", 1, "Limits", [1 16], ...
    "RoundFractionalValues", "on", "ValueDisplayFormat", "%d", ...
    "Tooltip", "Reference.WCAR_Order (1-16, default 1): weights per channel, the CAR and its previous " + ...
        "order-1 samples. The paper does not state it for its recordings; 1 is plain CAR's shape.", ...
    "ValueChangedFcn", changed);
place(obj.ArtRefWCAROrderField, 1, 2);
place(uilabel(wg, "Text", "Alpha at 1 kHz:"), 1, 3);
obj.ArtRefWCARAlphaField = uieditfield(wg, "numeric", "Value", 1, "Limits", [0 1], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%.10g", ...
    "Tooltip", "Reference.WCAR_Alpha1k ((0, 1], default 1): the weights' state transition at 1 kHz, " + ...
        "rescaled to the recording rate. Below 1 pulls the weights toward 0 (no reference). The paper's " + ...
        "0.99 was fitted to simulated ground truth; 1 (a random walk) was the more robust in our simulations.", ...
    "ValueChangedFcn", changed);
place(obj.ArtRefWCARAlphaField, 1, 4);

place(uilabel(wg, "Text", "Drift (/s):"), 2, 1);
obj.ArtRefWCARDriftField = uieditfield(wg, "numeric", "Value", 1, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%.10g", ...
    "Tooltip", "Reference.WCAR_DriftPerSec (default 1, our choice; the paper gives no value): the " + ...
        "weights' process variance per second. Larger adapts faster, and absorbs more of the shared signal.", ...
    "ValueChangedFcn", changed);
place(obj.ArtRefWCARDriftField, 2, 2);
place(uilabel(wg, "Text", "High-pass (Hz):"), 2, 3);
obj.ArtRefWCARHighpassField = uieditfield(wg, "numeric", "Value", 0.5, "Limits", [0 Inf], ...
    "ValueDisplayFormat", "%.10g", ...
    "Tooltip", "Reference.WCAR_HighpassHz (default 0.5, the paper's lower band edge; 0 = none): " + ...
        "zero-phase high-pass of the inputs the weights are estimated from. Nothing below it is " + ...
        "subtracted. Each streamed read is padded by the filter's memory (23 s on either side at 0.5 Hz); " + ...
        "0 needs no padding.", ...
    "ValueChangedFcn", changed);
place(obj.ArtRefWCARHighpassField, 2, 4);

place(uilabel(wg, "Text", "Q (uV^2):"), 3, 1);
obj.ArtRefWCARQField = uieditfield(wg, "numeric", "Value", 100, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%.10g", ...
    "Tooltip", "Reference.WCAR_Q: the observation variance, each channel's own signal power " + ...
        "(the paper's q = E[s^2]). Used when Automatic Q is off.", ...
    "ValueChangedFcn", changed);
place(obj.ArtRefWCARQField, 3, 2);
obj.ArtRefWCARQAutoCheckBox = uicheckbox(wg, "Text", "Automatic Q", "Value", true, ...
    "Tooltip", "Reference.WCAR_Q = NaN (default): the median over the reference channels of the robust " + ...
        "variance (1.4826 x MAD)^2 of the high-passed plain-CAR residual, per dataset.", ...
    "ValueChangedFcn", changed);
place(obj.ArtRefWCARQAutoCheckBox, 3, [3 4]);

place(uilabel(wg, "Text", "Estimate:"), 4, 1);
obj.ArtRefWCAREstimateDropDown = uidropdown(wg, ...
    "Items", {'prior (default)', 'posterior (paper)'}, "ItemsData", {'prior', 'posterior'}, "Value", 'prior', ...
    "Tooltip", "Reference.WCAR_Estimate: the weights subtracted at each sample. Prior (default, our " + ...
        "choice): the prediction made before the sample is seen. Posterior: the paper's Fig. 1 / eq. 8, " + ...
        "updated with the sample; it scales a sample with a large common signal down whole, neural " + ...
        "signal included.", ...
    "ValueChangedFcn", changed);
place(obj.ArtRefWCAREstimateDropDown, 4, [2 4]);
end


function place(c, row, col)
% Put control C at ROW, COL of its grid.
c.Layout.Row = row;
c.Layout.Column = col;
end


function lab(parent, txt, row)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = 1;
end
