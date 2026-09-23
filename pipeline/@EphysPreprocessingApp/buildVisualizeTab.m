function buildVisualizeTab(obj)
%buildVisualizeTab  Controls, toolbar, plot and overview strip of the Visualize tab.
%   The tab shows any signal of the active dataset - the recording, the
%   Sorting .bin, the Signals step's LFP / MUA / SPIKE / AUX - with its
%   sorted units and detected spikes over it, through an EphysTraceViewer
%   (obj.Viewer) that reads only the window shown. Opening the tab (or
%   choosing another dataset while it is open) loads the active dataset:
%   onPlotVisualization finds its processed files, and Reload finds them
%   again after a run. Every other control applies at once and never
%   changes a file, except the manual artifact periods (Mark Artifacts),
%   which are written to the dataset's manifest.
%
%   See also onPlotVisualization, onVizControlsChanged, onVizInput,
%   EphysTraceViewer, EphysTraceSource.

g = uigridlayout(obj.TabVisualize, [1 2]);
g.ColumnWidth = {384, '1x'};
g.Padding     = [10 10 10 10];

% --- left: controls ---------------------------------------------------------
ctrl = uipanel(g, "Title", "Display options (never change the data)");
ctrl.Layout.Column = 1;

nRows = 26;
cg = uigridlayout(ctrl, [nRows 4]);
cg.RowHeight   = [repmat({'fit'}, 1, nRows - 1), {'1x'}];
cg.ColumnWidth = {84, 80, 66, 80};   % fixed: wrapped labels never widen the panel
cg.ColumnSpacing = 8;
cg.Padding = [8 8 8 8];
cg.RowSpacing  = 5;
cg.Scrollable  = "on";
changed = @(what) @(~, ~) obj.onVizControlsChanged(what);

row = 1;
heading(cg, "Data", row);

row = row + 1;
lab(cg, "Dataset:", row);
obj.VizDatasetDropDown = obj.datasetPicker(cg);
obj.VizDatasetDropDown.Layout.Row = row; obj.VizDatasetDropDown.Layout.Column = [2 4];

row = row + 1;
lab(cg, "Show:", row);
obj.VizSourceDropDown = uidropdown(cg, "Items", {'(press Reload)'}, "ItemsData", {'none'}, ...
    "Tooltip", ["The continuous signal drawn: the recording (as every step reads it), the " ...
        ".bin Kilosort4 sorted, or a signal the Signals step wrote. Only the files that " ...
        "exist for this dataset are offered."], ...
    "ValueChangedFcn", changed("source"));
obj.VizSourceDropDown.Layout.Row = row; obj.VizSourceDropDown.Layout.Column = [2 4];

row = row + 1;
obj.VizSourceNoteLabel = uilabel(cg, "Text", "", "WordWrap", "on", "FontColor", [0.4 0.4 0.4]);
obj.VizSourceNoteLabel.Layout.Row = row; obj.VizSourceNoteLabel.Layout.Column = [1 4];

row = row + 1;
lab(cg, "Channels:", row);
obj.VizChannelsField = uieditfield(cg, "text", "Value", "all", "Placeholder", "all, or e.g. 1:16", ...
    "Tooltip", "Recording channels to draw (1-based): all, or a list such as 1:16 or 1 3 5.", ...
    "ValueChangedFcn", changed("channels"));
obj.VizChannelsField.Layout.Row = row; obj.VizChannelsField.Layout.Column = 2;
lab(cg, "Lanes:", row, 3);
obj.VizLanesField = uieditfield(cg, "numeric", "Value", 16, "Limits", [1 512], ...
    "RoundFractionalValues", "on", "Tooltip", "Lanes shown at once; scroll for the others (Shift+wheel, or drag up / down).", ...
    "ValueChangedFcn", changed("lanes"));
obj.VizLanesField.Layout.Row = row; obj.VizLanesField.Layout.Column = 4;

row = row + 1;
lab(cg, "Reference:", row);
obj.VizRefDropDown = uidropdown(cg);
obj.VizRefDropDown.Items = {'As the pipeline (Artifacts tab)', 'None (as recorded)', ...
    'Common average (mean)', 'Common median'};
obj.VizRefDropDown.ItemsData = {'pipeline', 'none', 'car', 'cmr'};
obj.VizRefDropDown.Value = 'pipeline';
obj.VizRefDropDown.Tooltip = "The recording only (the other signals carry their own), one reference at most: " + ...
    "the pipeline's common reference (Artifacts tab, over its good channels), none, or this view's own " + ...
    "mean / median across the channels shown, taken from the recording as stored.";
obj.VizRefDropDown.ValueChangedFcn = changed("processing");
obj.VizRefDropDown.Layout.Row = row; obj.VizRefDropDown.Layout.Column = [2 4];

row = row + 1;
lab(cg, "High-pass:", row);
obj.VizHighpassField = uieditfield(cg, "text", "Value", "", "Placeholder", "off", ...
    "Tooltip", "Display high-pass cut-off (Hz); blank = off. Both set = band-pass.", ...
    "ValueChangedFcn", changed("processing"));
obj.VizHighpassField.Layout.Row = row; obj.VizHighpassField.Layout.Column = 2;
lab(cg, "Low-pass:", row, 3);
obj.VizLowpassField = uieditfield(cg, "text", "Value", "", "Placeholder", "off", ...
    "Tooltip", "Display low-pass cut-off (Hz); blank = off. Both set = band-pass.", ...
    "ValueChangedFcn", changed("processing"));
obj.VizLowpassField.Layout.Row = row; obj.VizLowpassField.Layout.Column = 4;

row = row + 1;
lab(cg, "Filter order:", row);
obj.VizOrderField = uieditfield(cg, "numeric", "Value", 4, "Limits", [1 8], ...
    "RoundFractionalValues", "on", "ValueChangedFcn", changed("processing"));
obj.VizOrderField.Layout.Row = row; obj.VizOrderField.Layout.Column = 2;
obj.VizOffsetCheckBox = uicheckbox(cg, "Text", "Remove offset", "Value", true, ...
    "Tooltip", "Centre each lane on its median in view.", "ValueChangedFcn", changed("processing"));
obj.VizOffsetCheckBox.Layout.Row = row; obj.VizOffsetCheckBox.Layout.Column = [3 4];

row = row + 1;
obj.VizPlotButton = uibutton(cg, "Text", "Reload data", ...
    "Tooltip", "Find the active dataset's processed files again (after a run) and draw it.", ...
    "ButtonPushedFcn", @(~, ~) obj.onPlotVisualization());
obj.VizPlotButton.Layout.Row = row; obj.VizPlotButton.Layout.Column = [1 4];
cg.RowHeight{row} = 30;

row = row + 1;
heading(cg, "Spikes", row);

row = row + 1;
obj.VizUnitsCheckBox = uicheckbox(cg, "Text", "Sorted units", "Value", true, ...
    "Tooltip", "The Kilosort4 / phy units associated with the dataset (Review tab), one colour per unit.", ...
    "ValueChangedFcn", changed("spikes"));
obj.VizUnitsCheckBox.Layout.Row = row; obj.VizUnitsCheckBox.Layout.Column = [1 2];
obj.VizUnitStyleDropDown = styleDropDown(cg, changed("spikes"));
obj.VizUnitStyleDropDown.Layout.Row = row; obj.VizUnitStyleDropDown.Layout.Column = [3 4];

row = row + 1;
lab(cg, "Units:", row);
obj.VizUnitGroupsDropDown = uidropdown(cg, "Items", {'All but noise', 'Good + MUA', 'Good only'}, ...
    "ItemsData", {'all', 'goodmua', 'good'}, "Value", 'all', "ValueChangedFcn", changed("spikes"), ...
    "Tooltip", "Which units by their label (phy's curation, else Kilosort4's own).");
obj.VizUnitGroupsDropDown.Layout.Row = row; obj.VizUnitGroupsDropDown.Layout.Column = [2 4];

row = row + 1;
obj.VizDetectedCheckBox = uicheckbox(cg, "Text", "Detected spikes", "Value", true, ...
    "Tooltip", "Threshold crossings from the Spikes step (<Name>_spikes.mat), one colour per channel.", ...
    "ValueChangedFcn", changed("spikes"));
obj.VizDetectedCheckBox.Layout.Row = row; obj.VizDetectedCheckBox.Layout.Column = [1 2];
obj.VizDetectedStyleDropDown = styleDropDown(cg, changed("spikes"));
obj.VizDetectedStyleDropDown.Layout.Row = row; obj.VizDetectedStyleDropDown.Layout.Column = [3 4];

row = row + 1;
lab(cg, "Draw on:", row);
obj.VizPlacementDropDown = uidropdown(cg, "Items", {'Their channel''s lane', 'Lanes of their own'}, ...
    "ItemsData", {'channels', 'raster'}, "Value", 'channels', "ValueChangedFcn", changed("spikes"), ...
    "Tooltip", ["On their (peak) channel's trace lane, or one lane per unit / channel after " ...
        "the traces (a raster). Without a signal they always get lanes of their own."]);
obj.VizPlacementDropDown.Layout.Row = row; obj.VizPlacementDropDown.Layout.Column = [2 4];

row = row + 1;
obj.VizSpikesLabel = uilabel(cg, "Text", "", "WordWrap", "on", "FontColor", [0.4 0.4 0.4]);
obj.VizSpikesLabel.Layout.Row = row; obj.VizSpikesLabel.Layout.Column = [1 4];

row = row + 1;
heading(cg, "View", row);

row = row + 1;
lab(cg, "Start (s):", row);
obj.VizStartField = uieditfield(cg, "numeric", "Value", 0, "Limits", [0 Inf], ...
    "ValueDisplayFormat", "%.4f", "ValueChangedFcn", changed("view"));
obj.VizStartField.Layout.Row = row; obj.VizStartField.Layout.Column = 2;
lab(cg, "Window (s):", row, 3);
obj.VizDurField = uieditfield(cg, "numeric", "Value", 2, "Limits", [1e-4 Inf], ...
    "ValueDisplayFormat", "%.4g", "ValueChangedFcn", changed("view"));
obj.VizDurField.Layout.Row = row; obj.VizDurField.Layout.Column = 4;

row = row + 1;
lab(cg, "Spacing (uV):", row);
obj.VizSpacingField = uieditfield(cg, "numeric", "Value", 100, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%.4g", ...
    "Tooltip", "Voltage between neighbouring lanes (the scale bar at the top right).", ...
    "ValueChangedFcn", changed("spacing"));
obj.VizSpacingField.Layout.Row = row; obj.VizSpacingField.Layout.Column = 2;
lab(cg, "Plot:", row, 3);
obj.VizModeDropDown = uidropdown(cg, "Items", {'Traces', 'Heatmap'}, "ItemsData", {'traces', 'heatmap'}, ...
    "Value", 'traces', "ValueChangedFcn", changed("mode"));
obj.VizModeDropDown.Layout.Row = row; obj.VizModeDropDown.Layout.Column = 4;

row = row + 1;
obj.VizSortByProbeCheckBox = uicheckbox(cg, "Text", "Order by probe", "Value", true, ...
    "Tooltip", "Lanes in probe order: by shank, top of the shank first (the dataset's probe, else the default probe).", ...
    "ValueChangedFcn", changed("channels"));
obj.VizSortByProbeCheckBox.Layout.Row = row; obj.VizSortByProbeCheckBox.Layout.Column = [1 2];
obj.VizColorByShankCheckBox = uicheckbox(cg, "Text", "Colour by shank", "Value", false, ...
    "ValueChangedFcn", changed("channels"));
obj.VizColorByShankCheckBox.Layout.Row = row; obj.VizColorByShankCheckBox.Layout.Column = [3 4];

row = row + 1;
obj.VizShadingCheckBox = uicheckbox(cg, "Text", "Shade artifact periods", "Value", true, ...
    "ValueChangedFcn", changed("shading"));
obj.VizShadingCheckBox.Layout.Row = row; obj.VizShadingCheckBox.Layout.Column = [1 2];
lab(cg, "Colours:", row, 3);
obj.VizColormapDropDown = uidropdown(cg, "Items", {'turbo', 'parula', 'hot', 'gray', 'jet'}, ...
    "Value", 'turbo', "Tooltip", "Heatmap colours", "ValueChangedFcn", changed("mode"));
obj.VizColormapDropDown.Layout.Row = row; obj.VizColormapDropDown.Layout.Column = 4;

row = row + 1;
heading(cg, "Manual artifact periods", row);

row = row + 1;
obj.VizArtButton = uibutton(cg, "state", "Text", "Mark Artifacts: off", ...
    "Tooltip", ["Toggle artifact marking. When on: drag on the plot to mark a period; click a " ...
        "marked region to remove it (drag with the right button to pan). Periods are saved " ...
        "to the dataset's manifest and erased from the .bin and the signals by a run."], ...
    "ValueChangedFcn", @(src, ~) obj.onVizArtToggle(src.Value));
obj.VizArtButton.Layout.Row = row; obj.VizArtButton.Layout.Column = [1 2];
obj.VizArtClearButton = uibutton(cg, "Text", "Clear Artifacts", ...
    "ButtonPushedFcn", @(~, ~) obj.onVizArtClear());
obj.VizArtClearButton.Layout.Row = row; obj.VizArtClearButton.Layout.Column = [3 4];
cg.RowHeight{row} = 30;

row = row + 1;
obj.VizArtStatusLabel = uilabel(cg, "Text", "No artifacts defined.", "WordWrap", "on", ...
    "FontColor", [0.6 0.2 0.2]);
obj.VizArtStatusLabel.Layout.Row = row; obj.VizArtStatusLabel.Layout.Column = [1 4];

row = row + 1;
obj.VizHelpLabel = uilabel(cg, "WordWrap", "on", "FontColor", [0.3 0.3 0.3], ...
    "VerticalAlignment", "top", "Text", helpText());
obj.VizHelpLabel.Layout.Row = row; obj.VizHelpLabel.Layout.Column = [1 4];

% --- right: toolbar, plot, overview -----------------------------------------
rg = uigridlayout(g, [3 1]);
rg.Layout.Column = 2;
rg.RowHeight = {30, '1x', 64};
rg.Padding = [0 0 0 0];
rg.RowSpacing = 4;

tb = uigridlayout(rg, [1 9]);
tb.Layout.Row = 1;
tb.Padding = [0 0 0 0];
tb.ColumnSpacing = 4;
tb.ColumnWidth = {70, 70, 70, 70, 70, 70, 80, 80, '1x'};
act = @(f) @(~, ~) vizAction(obj, f);
specs = { ...
    "< Page",   "Back one window (Page Up)",               @(v) v.panTime(-1); ...
    "Page >",   "Forward one window (Page Down)",          @(v) v.panTime(1); ...
    "Zoom in",  "Narrower window (wheel up; Shift+Right)", @(v) v.zoomTime(1 / 1.5); ...
    "Zoom out", "Wider window (wheel down; Shift+Left)",   @(v) v.zoomTime(1.5); ...
    "Taller",   "Larger traces (Ctrl+wheel up; Up arrow)", @(v) v.scaleVoltage(1.5); ...
    "Shorter",  "Smaller traces (Ctrl+wheel down; Down arrow)", @(v) v.scaleVoltage(1 / 1.5); ...
    "Auto scale", "Fit the traces to the signal in view (A)", @(v) v.autoScale(); ...
    "Reset view", "The default window, top lane, automatic scale (R)", @(v) v.resetView()};
obj.VizToolbarButtons = gobjects(1, size(specs, 1));
for k = 1:size(specs, 1)
    b = uibutton(tb, "Text", specs{k, 1}, "Tooltip", specs{k, 2}, "ButtonPushedFcn", act(specs{k, 3}));
    b.Layout.Column = k;
    obj.VizToolbarButtons(k) = b;
end
obj.VizStatusLabel = uilabel(tb, "Text", "", "FontColor", [0.4 0.4 0.4], "WordWrap", "on");
obj.VizStatusLabel.Layout.Column = 9;

obj.VizAxes = uiaxes(rg);
obj.VizAxes.Layout.Row = 2;
xlabel(obj.VizAxes, "Time (s)");
obj.VizOverviewAxes = uiaxes(rg);
obj.VizOverviewAxes.Layout.Row = 3;
obj.VizOverviewAxes.FontSize = 9;

obj.Viewer = EphysTraceViewer(obj.VizAxes, OverviewAxes=obj.VizOverviewAxes);
obj.Viewer.ViewChangedFcn = @(~) obj.onVizViewChanged();
obj.Viewer.BusyFcn = @(msg) vizBusy(obj, msg);
obj.Viewer.render();

% The figure's buttons: drag to pan, click or drag the overview, mark
% artifacts (onVizButtonDown); the wheel and keys come through
% routeFigureInput (onVizInput).
obj.Fig.WindowButtonDownFcn = @(~, ~) obj.onVizButtonDown();
obj.Fig.WindowButtonUpFcn   = @(~, ~) obj.onVizButtonUp();
end


function vizAction(obj, f)
%vizAction  A toolbar button: act on the viewer when a dataset is shown.
if isempty(obj.Viewer) || ~isvalid(obj.Viewer); return; end
f(obj.Viewer);
end


function vizBusy(obj, msg)
%vizBusy  The status line while the viewer reads a long window.
if msg ~= ""
    obj.VizStatusLabel.Text = msg;
    drawnow limitrate
end
end


function dd = styleDropDown(parent, fcn)
dd = uidropdown(parent, "Items", {'Ticks', 'Waveforms'}, "ItemsData", {'ticks', 'waveforms'}, ...
    "Value", 'ticks', "ValueChangedFcn", fcn, ...
    "Tooltip", ["Ticks: a mark per spike. Waveforms: on a trace lane the trace itself is " ...
        "recoloured over each spike (a spike-band signal, zoomed in); on lanes of their " ...
        "own, the detected snippet or the unit's template."]);
end


function heading(parent, txt, row)
%heading  A bold section title across the grid.
l = uilabel(parent, "Text", txt, "FontWeight", "bold");
l.Layout.Row = row;
l.Layout.Column = [1 4];
end


function lab(parent, txt, row, col)
%lab  A label at the given grid row (column 1 unless given).
if nargin < 4; col = 1; end
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = col;
end


function s = helpText()
%helpText  Mouse / keyboard cheatsheet shown under the controls.
s = sprintf([ ...
    'With the pointer over the plot:\n' ...
    '  wheel ............... zoom time about the pointer\n' ...
    '  Ctrl+wheel .......... scale the voltage\n' ...
    '  Shift+wheel ......... scroll the lanes\n' ...
    '  drag ................ pan time (and lanes)\n' ...
    '  <- / -> ............. pan a quarter window\n' ...
    '  Shift+<- / -> ....... zoom time out / in\n' ...
    '  Page Up / Down ...... a whole window\n' ...
    '  Up / Down, + / - .... scale the voltage\n' ...
    '  Shift+Up / Down ..... scroll the lanes\n' ...
    '  Home / End .......... start / end\n' ...
    '  A ................... auto scale    R ... reset view\n' ...
    'Overview strip: click or drag to move there.\n' ...
    'Mark Artifacts on: drag to mark a period, click a red one to remove it.']);
end
