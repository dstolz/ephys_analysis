function buildUI(obj)
%buildUI  Create the figure, menus, tabs (workflow order) and the status bar.
%   The tab group's own headers cannot be coloured, so they are clipped out
%   of view (TabHost) and a strip of buttons takes their place: one per
%   tab, coloured by the tab's status (see syncTabStrip) with an underline
%   on the selected one. obj.Tabs.SelectedTab stays the source of truth.
%   Every button is then styled (styleButtons), the main actions in colour.

pos = [120 90 1240 800];   % default; overridden by the saved preference
obj.Fig = uifigure("Name", "Ephys preprocessing", "Position", pos);
obj.Fig.CloseRequestFcn = @(~,~) obj.onClose();

obj.buildMenus();

outer = uigridlayout(obj.Fig, [3 1]);
outer.RowHeight   = {34, '1x', 24};
outer.ColumnWidth = {'1x'};
outer.RowSpacing  = 0;
outer.Padding     = [0 0 0 0];

obj.TabHost = uipanel(outer, "BorderType", "none", "AutoResizeChildren", "off");
obj.TabHost.Layout.Row = 2; obj.TabHost.Layout.Column = 1;
obj.Tabs = uitabgroup(obj.TabHost);
obj.Tabs.SelectionChangedFcn = @(~,~) obj.onTabChanged();
obj.TabHost.SizeChangedFcn = @(~,~) fitTabGroup(obj);

buildStatusBar(obj, outer);

% Tabs in workflow order (Copy first: pulling sessions from the source comes
% before everything); the Diagram chart and the utility tabs come last, Clean
% up (freeing local disk space once a dataset is done) at the very end.
obj.TabCopy       = uitab(obj.Tabs, "Title", "Copy");
obj.TabProject   = uitab(obj.Tabs, "Title", "Project");
obj.TabTrials    = uitab(obj.Tabs, "Title", "Trials");
obj.TabProbe     = uitab(obj.Tabs, "Title", "Probe");
obj.TabArtifacts = uitab(obj.Tabs, "Title", "Artifacts");
obj.TabSorting   = uitab(obj.Tabs, "Title", "Sorting");
obj.TabSignals   = uitab(obj.Tabs, "Title", "Signals");
obj.TabSpikes    = uitab(obj.Tabs, "Title", "Spikes");
obj.TabExport    = uitab(obj.Tabs, "Title", "Export");
obj.TabFlow      = uitab(obj.Tabs, "Title", "Diagram");
obj.TabRun       = uitab(obj.Tabs, "Title", "Run");
obj.TabVisualize = uitab(obj.Tabs, "Title", "Visualize");
obj.TabReview    = uitab(obj.Tabs, "Title", "Review");
obj.TabCleanup   = uitab(obj.Tabs, "Title", "Clean up");
obj.TabList = [obj.TabCopy, obj.TabProject, obj.TabTrials, obj.TabProbe, obj.TabArtifacts, ...
    obj.TabSorting, obj.TabSignals, obj.TabSpikes, obj.TabExport, obj.TabFlow, ...
    obj.TabRun, obj.TabVisualize, obj.TabReview, obj.TabCleanup];

buildTabStrip(obj, outer);
fitTabGroup(obj);

obj.buildCopyTab();
obj.buildProjectTab();
obj.buildTrialsTab();
obj.buildVisualizeTab();     % before Artifacts: the artifact tab links to it
obj.buildArtifactsTab();
obj.buildProbeTab();
obj.buildSortingTab();
obj.buildSignalsTab();
obj.buildSpikesTab();
obj.buildExportTab();
obj.buildFlowTab();
obj.buildRunTab();
obj.buildReviewTab();
obj.buildCleanupTab();
styleButtons(obj);   % before syncTabStrip, which colours the tab strip by status

obj.Tabs.SelectedTab = obj.TabProject;   % the app still opens on Project
obj.syncTabStrip();
obj.onTabChanged();
end


function styleButtons(obj)
%styleButtons  Every button a size up; the main actions in colour (styleButton).
%   A button that changes role while the app runs restyles itself
%   (setCopyRunning, onVizArtToggle).
styleButton(findall(obj.Fig, "Type", "uibutton", "-or", "Type", "uistatebutton"));
styleButton([obj.CopyFindButton, obj.CopyRunButton, obj.ScanButton, obj.TrialsLoadButton, ...
    obj.AssignSelectedButton, obj.ArtDetectButton, obj.RunStepSortingButton, obj.RunStepSignalsButton, obj.RunStepSpikesButton, ...
    obj.RunStepExportButton, obj.RunButton, obj.VizPlotButton, obj.LoadReviewButton, ...
    obj.CleanupPreviewButton], "primary");
styleButton([obj.TrialsApproveButton, obj.CopyScheduleSaveButton], "confirm");
styleButton([obj.CleanupRunButton, obj.RunCancelButton, obj.RunKSStopRunsButton, obj.RunKSStopQueueButton, ...
    obj.CopyScheduleRemoveButton, obj.ArtManualClearButton, obj.VizArtClearButton], "danger");
end


function buildTabStrip(obj, parent)
%buildTabStrip  One button per tab plus a thin underline row for the selection.
n = numel(obj.TabList);
sg = uigridlayout(parent, [2 n + 1]);
sg.Layout.Row = 1; sg.Layout.Column = 1;
sg.RowHeight     = {'1x', 3};
sg.ColumnWidth   = [repmat({82}, 1, n), {'1x'}];   % 14 tabs fit the default 1240 px width
sg.RowSpacing    = 1;
sg.ColumnSpacing = 3;
sg.Padding       = [6 3 6 0];
for k = n:-1:1
    tab = obj.TabList(k);
    b = uibutton(sg, "Text", tab.Title, "ButtonPushedFcn", @(~,~) obj.selectTab(tab));
    b.Layout.Row = 1; b.Layout.Column = k;
    m = uipanel(sg, "BorderType", "none", "BackgroundColor", [0.15 0.45 0.80], "Visible", "off");
    m.Layout.Row = 2; m.Layout.Column = k;
    buttons(k) = b; marks(k) = m;
end
obj.TabButtons = buttons;
obj.TabMarks   = marks;
end


function fitTabGroup(obj)
%fitTabGroup  Size the tab group so its header row sits above the host's clip edge.
if isempty(obj.Tabs) || ~isvalid(obj.Tabs); return; end
hdr = 26;   % tab header height in R2025a, plus its bottom border
p = obj.TabHost.InnerPosition;
obj.Tabs.Position = [-1 0 p(3) + 2, p(4) + hdr];
end


function buildStatusBar(obj, parent)
%buildStatusBar  Status strip along the bottom of the figure.
panel = uipanel(parent, "BorderType", "line", "BackgroundColor", [0.96 0.96 0.98]);
panel.Layout.Row = 3; panel.Layout.Column = 1;
sg = uigridlayout(panel, [1 2]);
sg.ColumnWidth  = {'1x', 'fit'};
sg.RowHeight    = {'1x'};
sg.Padding      = [8 0 8 0];
sg.ColumnSpacing = 16;
obj.StatusBar = uilabel(sg, "Text", "Ready.", "FontColor", [0.15 0.15 0.15], "VerticalAlignment", "center");
obj.StatusBar.Layout.Row = 1; obj.StatusBar.Layout.Column = 1;
obj.StatusHint = uilabel(sg, "Text", "", "FontAngle", "italic", "FontColor", [0.15 0.45 0.75], ...
    "HorizontalAlignment", "right", "VerticalAlignment", "center");
obj.StatusHint.Layout.Row = 1; obj.StatusHint.Layout.Column = 2;
end
