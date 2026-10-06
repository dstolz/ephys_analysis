function buildAnalysisTab(obj)
%buildAnalysisTab  Analysis step: an EphysAnalysisApp config's figures and report.
%   Edits the config's Analysis section (gatherAnalysisSection /
%   applyAnalysisSection): the analysis config file, and whether the step
%   writes the figure files and the report. What the analysis config holds
%   (its plots, alignment, export and report settings) is shown read-only
%   (refreshAnalysisSummary) and edited in the analysis app (Open in the
%   analysis app). The right side plans the step for the selected datasets,
%   runs it, and opens the report or the figures it wrote
%   (onOpenAnalysisOutput).

g = uigridlayout(obj.TabAnalysis, [1 2]);
g.ColumnWidth = {520, '1x'};
g.Padding     = [10 10 10 10];

opt = uipanel(g, "Title", "Analysis options (config: Analysis; EphysAnalysisRunner)");
opt.Layout.Column = 1;
cg = uigridlayout(opt, [9 4]);
cg.RowHeight   = {26, 26, 26, 30, 118, '1x', 26, 26, 66};
cg.ColumnWidth = {130, '1x', '1x', 30};

r = 1;
obj.AnaEnableCheckBox = uicheckbox(cg, "Text", "Enable the Analysis step", "FontWeight", "bold", ...
    "Value", false, "ValueChangedFcn", @(~,~) obj.onAnalysisControlsChanged("enable"));
obj.AnaEnableCheckBox.Layout.Row = r; obj.AnaEnableCheckBox.Layout.Column = [1 4];

r = r + 1; sep(cg, "Analysis config (made in the analysis app)", r);
r = r + 1;
lab(cg, "Config file:", r);
obj.AnaConfigField = uieditfield(cg, "text", "Placeholder", "an analysis config (.json)", ...
    "Tooltip", ["An EphysAnalysisApp config: its plots, the event they align to, and how its figure files and " ...
                "report are written. It is read when the step runs, so what is saved in the analysis app applies " ...
                "to the next run."], ...
    "ValueChangedFcn", @(~,~) obj.onAnalysisControlsChanged("file"));
obj.AnaConfigField.Layout.Row = r; obj.AnaConfigField.Layout.Column = [2 3];
obj.AnaBrowseButton = uibutton(cg, "Text", "...", "Tooltip", "Choose an analysis config", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseAnalysisConfig());
obj.AnaBrowseButton.Layout.Row = r; obj.AnaBrowseButton.Layout.Column = 4;

r = r + 1;
bg = uigridlayout(cg, [1 3], "Padding", [0 0 0 0], "ColumnSpacing", 6);
bg.Layout.Row = r; bg.Layout.Column = [1 4];
bg.ColumnWidth = {'fit', 'fit', '1x'}; bg.RowHeight = {30};
obj.AnaOpenAppButton = uibutton(bg, "Text", "Open in the analysis app", ...
    "Tooltip", ["Edit this config's plots in EphysAnalysisApp (without a config chosen: start one on this " ...
                "project). Save it there; Reload here."], ...
    "ButtonPushedFcn", @(~,~) obj.onOpenAnalysisConfig());
obj.AnaReloadButton = uibutton(bg, "Text", "Reload", "Tooltip", "Read the analysis config again", ...
    "ButtonPushedFcn", @(~,~) obj.onAnalysisControlsChanged("file"));

r = r + 1;
obj.AnaSummaryLabel = uilabel(cg, "Text", "", "WordWrap", "on", "VerticalAlignment", "top");
obj.AnaSummaryLabel.Layout.Row = r; obj.AnaSummaryLabel.Layout.Column = [1 4];

r = r + 1;
obj.AnaPlotsTable = uitable(cg, "ColumnName", {'Plot', 'Kind', 'Source', 'On'}, ...
    "ColumnWidth", {'1x', 80, 80, 40}, "RowName", {}, ...
    "Tooltip", "The analysis config's plots; the step draws the enabled ones (edit them in the analysis app).");
obj.AnaPlotsTable.Layout.Row = r; obj.AnaPlotsTable.Layout.Column = [1 4];

r = r + 1; sep(cg, "In this pipeline", r);
r = r + 1;
changed = @(~,~) obj.onAnalysisControlsChanged("output");
obj.AnaFiguresCheckBox = uicheckbox(cg, "Text", "Write the figure files", "Value", true, ...
    "Tooltip", ["Each plot's pages as files, in the formats, folder and names of the analysis config's " ...
                "Export settings. Off: the plots are drawn for the report only."], ...
    "ValueChangedFcn", changed);
obj.AnaFiguresCheckBox.Layout.Row = r; obj.AnaFiguresCheckBox.Layout.Column = [1 2];
obj.AnaReportCheckBox = uicheckbox(cg, "Text", "Write the report", "Value", true, ...
    "Tooltip", ["The HTML and / or PDF report of the analysis config's Report settings: one over every " ...
                "selected dataset, or one per dataset."], ...
    "ValueChangedFcn", changed);
obj.AnaReportCheckBox.Layout.Row = r; obj.AnaReportCheckBox.Layout.Column = [3 4];

r = r + 1;
note = uilabel(cg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "The step runs the analysis config over the datasets selected on the Project tab (not over the source " + ...
    "saved in the config). It reads each dataset's extract, spikes file, sorted units and behavior file, " + ...
    "so it runs after Signals, Spikes and Export. Plots a dataset cannot have (no sorted units, no paired " + ...
    "trials, ...) are skipped for that dataset.");
note.Layout.Row = r; note.Layout.Column = [1 4];

% =================== right: plan + run ===================
runPanel = uipanel(g, "Title", "This step for the selected datasets");
runPanel.Layout.Column = 2;
rg = uigridlayout(runPanel, [2 5]);
rg.RowHeight   = {'1x', 30};
rg.ColumnWidth = {'fit', 'fit', 'fit', '1x', 'fit'};
obj.AnaTargetsTable = uitable(rg, "ColumnName", {'Step', 'Dataset', 'Output', 'Status', 'Note'}, ...
    "ColumnWidth", {120, 'fit', '2x', 110, '1x'}, "RowName", {});
obj.AnaTargetsTable.Layout.Row = 1; obj.AnaTargetsTable.Layout.Column = [1 5];
obj.RunStepAnalysisButton = uibutton(rg, "Text", "Run this step", ...
    "ButtonPushedFcn", @(~,~) obj.onRunStep("analysis"));
obj.RunStepAnalysisButton.Layout.Row = 2; obj.RunStepAnalysisButton.Layout.Column = 1;
obj.AnaOpenReportButton = uibutton(rg, "Text", "Open report", ...
    "Tooltip", "Open the report of the active dataset's analysis (or the one over every dataset) in the browser.", ...
    "ButtonPushedFcn", @(~,~) obj.onOpenAnalysisOutput("report"));
obj.AnaOpenReportButton.Layout.Row = 2; obj.AnaOpenReportButton.Layout.Column = 2;
obj.AnaOpenFiguresButton = uibutton(rg, "Text", "Open figures folder", ...
    "Tooltip", "Show the active dataset's figure folder (else the first selected dataset's).", ...
    "ButtonPushedFcn", @(~,~) obj.onOpenAnalysisOutput("figures"));
obj.AnaOpenFiguresButton.Layout.Row = 2; obj.AnaOpenFiguresButton.Layout.Column = 3;
obj.AnaRefreshButton = uibutton(rg, "Text", "Refresh plan", ...
    "ButtonPushedFcn", @(~,~) obj.refreshStepPlan("analysis"));
obj.AnaRefreshButton.Layout.Row = 2; obj.AnaRefreshButton.Layout.Column = 5;

obj.refreshAnalysisSummary();
end


function l = lab(parent, txt, row)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = 1;
end


function sep(parent, txt, row)
l = uilabel(parent, "Text", txt, "FontWeight", "bold");
l.Layout.Row = row;
l.Layout.Column = [1 4];
end
