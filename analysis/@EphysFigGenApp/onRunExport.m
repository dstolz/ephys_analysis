function R = onRunExport(obj, opts)
%onRunExport  Run the enabled figures on the ticked datasets, then the session figures: figure files and report.
%   Validates first (errors stop it), then EphysAnalysisRunner.run with its
%   progress in the status bar (a bar, the runner's message and the time
%   left, and a Cancel button; the Export tab's and the toolbar's Cancel
%   stop it too: onCancelRun). Nothing is modal: the window stays usable
%   (a scan is refused meanwhile). What stops a run before it starts is an
%   alert that names the first problem and takes the tab that fixes it (the
%   Export tab's issues table for a config error, the Data tab for no
%   dataset ticked or no project, stopAction). A run that throws still
%   fills the results table with the rows it finished and says which
%   dataset it was on (AppDialog.failure). Figures= and Datasets= narrow the run (the
%   tests use them); by default every enabled figure on every ticked
%   dataset, then every enabled session figure across them.
%   SessionFigures=, Export= and Report= are run's
%   ([] = the config's); Config= runs that config instead of the controls'
%   (gatherConfig) and Title= names the run in the status bar: the Figures tab's
%   Generate selected figure (onGenerateFigure) runs one figure that way, and Test report
%   (onTestReport) one observation (Observation=, run's). The strip's
%   message is the runner's (what it is on, the report's pages) and the
%   time left (ProgressClock). One run goes at a time (Running): Run,
%   Plan, Validate, Generate, Test report and Export preview are off
%   meanwhile, and the previews compute nothing. The pages are drawn on
%   as many process workers as the Export tab's Workers says
%   (EphysAnalysisRunner.Workers).
arguments
    obj (1,1) EphysFigGenApp
    opts.Figures = []    % [] = the enabled figures; string.empty(1, 0) = none; else ids
    opts.SessionFigures = [] % likewise for the session figures (figures drawn across the datasets)
    opts.Datasets = []
    opts.Export = []     % [] = Export.Enabled
    opts.Report = []     % [] = Report.Enabled
    opts.Config = []     % an EphysAnalysisConfig to run ([] = gatherConfig)
    opts.Title (1,1) string = "Running the analysis"
    opts.Observation = [] % run's: one observation only (the Export tab's Test report, onTestReport)
end
R = table();
if obj.Running; return; end
if isempty(obj.Runner)
    obj.onScan();   % says why when there is nothing to scan (an alert on the Data tab)
    if isempty(obj.Runner); return; end
end
cfg = opts.Config;
if ~isa(cfg, 'EphysAnalysisConfig'); cfg = obj.gatherConfig(); end
issues = cfg.validate();
if any(issues.Severity == "error")
    obj.IssuesTable.Data = issues;
    bad = issues(issues.Severity == "error", :);
    stopAction(obj, "Run", sprintf("The config has %d error(s), so nothing was run.\nFirst: %s (%s)\n" + ...
        "Double-click a row of the table on the Export tab to go to it.", height(bad), bad.Message(1), bad.Section(1) + " > " + bad.Field(1)), ...
        Tab=obj.TabExport, Icon="error", Status=sprintf("The config has %d error(s): see the table; nothing was run.", height(bad)));
    return
end
idx = opts.Datasets;
if isempty(idx); idx = obj.tickedDatasetIndices(); end
if isempty(idx)
    stopAction(obj, "Run", "No dataset is ticked to run. On the Data tab, tick Run for at least one dataset.", Tab=obj.TabData);
    return
end
r = obj.Runner;
r.Config = cfg;
r.Workers = obj.WorkersSpinner.Value;
clock = ProgressClock();   % the time left, in the status bar
showRunBar(obj, true);
r.ProgressFcn = @(f, m) progress(obj, r, opts.Title, clock, f, m);
obj.Running = true;
obj.GenerateFigureMenu.Enable = 'off';
set([obj.RunButton obj.PlanButton obj.ValidateButton obj.FigureRedrawAllButton obj.TestReportButton ...
    obj.FigureExportPreviewButton obj.FigureExportPreviewColumnButton], 'Enable', 'off');
set([obj.ToolbarRunTool obj.ToolbarPlanTool obj.ToolbarValidateTool], 'Enable', 'off');
obj.CancelButton.Enable = 'on';
obj.ToolbarCancelTool.Enable = 'on';
cleanup = onCleanup(@() finish(obj));
t0 = tic;
try
    R = r.run(Datasets=idx, Figures=opts.Figures, SessionFigures=opts.SessionFigures, ...
        Export=opts.Export, Report=opts.Report, Observation=opts.Observation);
catch ME
    obj.log("Run failed: " + string(ME.message));
    R = r.Results;   % the rows it finished: the table shows them whatever stopped it
    obj.ResultsTable.Data = withSubjectDate(obj, addRemedy(R));
    obj.RunLabel.Text = "Results of the run that stopped: " + height(R) + " row(s)";
    clear cleanup   % the strip goes before the alert
    stopAction(obj, "Run", AppDialog.failure("finish the run", lastDataset(R), string(ME.message), ...
        Try="look at the rows in the Results table, fix the cause, and run again", Details="Log tab"), ...
        Tab=obj.TabExport, Icon="error", Status="The run stopped: " + string(ME.message));
    return
end
obj.ResultsTable.Data = withSubjectDate(obj, addRemedy(R));
obj.LastReportFiles = r.ReportFiles;
obj.LastExportFolder = "";
doExport = cfg.Export.Enabled;
if ~isempty(opts.Export); doExport = logical(opts.Export); end
if doExport
    obj.LastExportFolder = figureFileName(cfg.Export.Folder, struct('OutputFolder', r.datasetFolder(idx(1)), ...
        'OutputRoot', r.outputRoot(), 'Root', cfg.Source.Root, 'Name', r.Names(idx(1))), Kind="folder");
end
sids = EphysAnalysisRunner.idList(opts.SessionFigures, @() cfg.enabledSessionFigures());
obj.OpenFolderButton.Tooltip = openFolderTip(obj, cfg, idx, sids);
obj.OpenReportButton.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.LastReportFiles));
obj.OpenFolderButton.Enable = matlab.lang.OnOffSwitchState(obj.LastExportFolder ~= "" && isfolder(obj.LastExportFolder));
obj.ToolbarReportTool.Enable = obj.OpenReportButton.Enable;
obj.ToolbarFolderTool.Enable = obj.OpenFolderButton.Enable;
counts = arrayfun(@(s) nnz(R.Status == s), ["done" "skipped" "error" "canceled"]);
obj.RunLabel.Text = sprintf("Results: %d done, %d skipped, %d failed, %d canceled (%.0f s)", counts, toc(t0));
obj.RunLabel.FontColor = ternary(counts(3) > 0, [0.75 0.1 0.1], [0 0 0]);   % a failed row shows red; its message is in the table
clear cleanup   % the strip goes, then the status bar says how it ended
obj.setStatus(obj.RunLabel.Text);
end


function progress(obj, r, title, clock, fraction, message)
%progress  The runner's report: the strip's bar and the status bar (setStatus draws, which also lets a Cancel click through).
if ~isvalid(obj) || ~isvalid(r); return; end
f = min(max(fraction, 0), 1);
w = round(1000 * f);
if w <= 0
    obj.RunStrip.Bar.ColumnWidth = {0, '1x'};
elseif w >= 1000
    obj.RunStrip.Bar.ColumnWidth = {'1x', 0};
else
    obj.RunStrip.Bar.ColumnWidth = {sprintf('%dx', w), sprintf('%dx', 1000 - w)};
end
text = clock.message(message, fraction);
obj.RunLabel.Text = char(title + ": " + text);
obj.setStatus(title + ": " + text);
end


function showRunBar(obj, on)
%showRunBar  The progress bar and Cancel in the status bar: shown while a run goes (ON), hidden after.
if on
    obj.RunStrip.Bar.ColumnWidth = {0, '1x'};
    obj.RunStrip.Host.ColumnWidth = {'1x', 280, 90};
else
    obj.RunStrip.Host.ColumnWidth = {'1x', 0, 0};
end
end


function T = addRemedy(T)
%addRemedy  A "WhatToDo" column after Message for the rows that were skipped with a reason figureSkipRemedy words.
if ~istable(T) || height(T) == 0 || ~all(ismember(["Status" "Message"], string(T.Properties.VariableNames)))
    return
end
what = strings(height(T), 1);
for k = reshape(find(T.Status == "skipped"), 1, [])
    what(k) = figureSkipRemedy(string(T.Message(k)));
end
if any(what ~= "")
    T = addvars(T, what, 'After', "Message", 'NewVariableNames', "WhatToDo");
end
end


function d = lastDataset(R)
%lastDataset  The dataset of the last row a stopped run recorded ("" when none).
d = "";
if istable(R) && height(R) > 0 && ismember("Dataset", string(R.Properties.VariableNames)); d = string(R.Dataset(end)); end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end


function finish(obj)
if ~isvalid(obj); return; end
showRunBar(obj, false);
obj.Running = false;
if ~isempty(obj.Runner); obj.Runner.ProgressFcn = []; end
set([obj.RunButton obj.PlanButton obj.ValidateButton], 'Enable', 'on');
set([obj.ToolbarRunTool obj.ToolbarPlanTool obj.ToolbarValidateTool], 'Enable', 'on');
has = matlab.lang.OnOffSwitchState(obj.SelectedFigure >= 1 && obj.SelectedFigure <= numel(obj.Config.Figures));
set([obj.FigureRedrawAllButton obj.FigureExportPreviewButton obj.FigureExportPreviewColumnButton], 'Enable', has);
obj.GenerateFigureMenu.Enable = has;
obj.TestReportButton.Enable = testReportEnable(obj);
obj.CancelButton.Enable = 'off';
obj.ToolbarCancelTool.Enable = 'off';
end


function tip = openFolderTip(obj, cfg, idx, sids)
%openFolderTip  The Open figure folder button's tooltip: the first dataset's folder, and where the session figures' files went.
tip = "The first dataset's figure folder of the last run.";
if isempty(sids); return; end
try
    r = obj.Runner;
    first = r.sessionTable(idx).index(1);
    folder = figureFileName(cfg.Export.SessionsFolder, struct('OutputFolder', r.datasetFolder(first), ...
        'OutputRoot', r.outputRoot(), 'Root', cfg.Source.Root, 'Name', r.Names(first)), Kind="folder");
    tip = tip + " The session figures' files are in " + folder + ".";
catch
    tip = tip + " The session figures' files are in the sessions folder (Export.SessionsFolder).";
end
end