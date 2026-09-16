function buildUI(obj)
%buildUI  Create the figure, menus, tabs (workflow order) and the status bar.

pos = [120 90 1240 800];   % default; overridden by the saved preference
obj.Fig = uifigure("Name", "Ephys preprocessing", "Position", pos);
obj.Fig.CloseRequestFcn = @(~,~) obj.onClose();

obj.buildMenus();

outer = uigridlayout(obj.Fig, [2 1]);
outer.RowHeight   = {'1x', 24};
outer.ColumnWidth = {'1x'};
outer.RowSpacing  = 0;
outer.Padding     = [0 0 0 0];

obj.Tabs = uitabgroup(outer);
obj.Tabs.Layout.Row = 1; obj.Tabs.Layout.Column = 1;
obj.Tabs.SelectionChangedFcn = @(~,~) obj.onTabChanged();

buildStatusBar(obj, outer);

% Tabs in workflow order; the two utility tabs come last.
obj.TabProject   = uitab(obj.Tabs, "Title", "Project");
obj.TabTrials    = uitab(obj.Tabs, "Title", "Trials");
obj.TabProbe     = uitab(obj.Tabs, "Title", "Probe");
obj.TabArtifacts = uitab(obj.Tabs, "Title", "Artifacts");
obj.TabSorting   = uitab(obj.Tabs, "Title", "Sorting");
obj.TabSignals   = uitab(obj.Tabs, "Title", "Signals");
obj.TabSpikes    = uitab(obj.Tabs, "Title", "Spikes");
obj.TabExport    = uitab(obj.Tabs, "Title", "Export");
obj.TabRun       = uitab(obj.Tabs, "Title", "Run");
obj.TabVisualize = uitab(obj.Tabs, "Title", "Visualize");
obj.TabReview    = uitab(obj.Tabs, "Title", "Review");

obj.buildProjectTab();
obj.buildTrialsTab();
obj.buildVisualizeTab();     % before Artifacts: the artifact tab links to it
obj.buildArtifactsTab();
obj.buildProbeTab();
obj.buildSortingTab();
obj.buildSignalsTab();
obj.buildSpikesTab();
obj.buildExportTab();
obj.buildRunTab();
obj.buildReviewTab();

obj.onTabChanged();
end


function buildStatusBar(obj, parent)
%buildStatusBar  Status strip along the bottom of the figure.
panel = uipanel(parent, "BorderType", "line", "BackgroundColor", [0.96 0.96 0.98]);
panel.Layout.Row = 2; panel.Layout.Column = 1;
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
