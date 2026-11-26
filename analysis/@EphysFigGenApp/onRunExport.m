function R = onRunExport(obj, opts)
%onRunExport  Run the enabled figures on the ticked datasets, then the session figures: figure files and report.
%   Validates first (errors stop it), then EphysAnalysisRunner.run with its
%   progress in the status bar (a bar, the runner's message and the time
%   left, and a Cancel button; the Export tab's and the toolbar's Cancel
%   stop it too: onCancelRun). Nothing is modal: the window stays usable
%   (a scan is refused meanwhile), and an edit made while the run goes is
%   the next run's: the runner draws, writes and records with the config
%   as it was when the run started (EphysAnalysisRunner.run reads it once),
%   and what is shown after it (the figure folder, its tooltip) is that
%   config's too. What stops a run before it starts is an
%   alert that names the first problem and takes the tab that fixes it:
%   datasets listed that are not the scan of the source the Data tab shows
%   (its root, output root, name pattern, recordings or folders changed
%   since the scan: press Scan first; scanIsCurrent), a config error (the
%   Export tab's issues table), no dataset ticked or no project (the Data
%   tab; stopAction). The config's warnings (files that overwrite each
%   other, say) do not stop it: the issues table lists them, the Log has
%   each, and an alert that leaves the window usable (Cancel stays
%   reachable) names them, those about where files go first, when the run
%   starts; Export or Report warnings only when the run writes figure
%   files or a report. A run that throws still
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
%   (EphysAnalysisRunner.Workers). Run is refused while a preview computes
%   or draws (the status bar says so, as Test report and Generate do): the
%   run would start inside the preview's polls, on the runner it computes
%   with.
%   Close (onClose) during a run cancels it and hides the window; the run
%   ends as any canceled one (its finished figures, its report and its
%   records are written), its progress and its end write nothing to the
%   window (windowOpen), and the window closes when it has ended
%   (CloseWhenRunEnds). A window deleted some other way during the run
%   leaves the run going and writing its files in the same way.
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
if ismember(obj.FigurePreviewState, ["computing" "drawing"])   % a run would start inside the preview's polls, on the runner it computes with
    obj.setStatus("A preview is computing: run when it is done (or cancel it).");
    return
end
if isempty(obj.Runner)
    obj.onScan();   % says why when there is nothing to scan (an alert on the Data tab)
    if isempty(obj.Runner); return; end
end
cfg = opts.Config;
if ~isa(cfg, 'EphysAnalysisConfig'); cfg = obj.gatherConfig(); end
if ~scanIsCurrent(obj, cfg.Source, Action="Run", Again="run"); return; end   % the datasets listed must be the source's
issues = cfg.validate(DatasetVariables=obj.datasetVariableSets());   % the datasets' variables are label variables
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
doExport = cfg.Export.Enabled;
if ~isempty(opts.Export); doExport = logical(opts.Export); end
doReport = cfg.Report.Enabled;
if ~isempty(opts.Report); doReport = logical(opts.Report); end
W = runWarnings(issues, doExport, doReport);
if height(W) > 0   % they do not stop the run: said where they are seen at once
    obj.IssuesTable.Data = issues;   % the Export tab's table, as Validate fills it (double-click a row: its setting)
    for w = 1:height(W)
        obj.log("Run: warning: " + W.Message(w) + " (" + W.Section(w) + " > " + W.Field(w) + ")");
    end
    AppDialog.alert(obj.Fig, warningsText(W), "Run", "Icon", "warning", "Modal", false);   % the window stays usable: Cancel stops the run
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
closer = onCleanup(@() closeIfAsked(obj)); %#ok<NASGU> Close during the run: the window, hidden, closes when this returns
t0 = tic;
try
    R = r.run(Datasets=idx, Figures=opts.Figures, SessionFigures=opts.SessionFigures, ...
        Export=opts.Export, Report=opts.Report, Observation=opts.Observation);
catch ME
    obj.log("Run failed: " + string(ME.message));
    R = r.Results;   % the rows it finished: the table shows them whatever stopped it
    if ~windowOpen(obj) || obj.CloseWhenRunEnds; return; end   % Close was asked meanwhile: nothing is shown, the window closes
    obj.ResultsTable.Data = withSubjectDate(obj, addRemedy(R));
    obj.RunLabel.Text = "Results of the run that stopped: " + height(R) + " row(s)";
    clear cleanup   % the strip goes before the alert
    stopAction(obj, "Run", AppDialog.failure("finish the run", lastDataset(R), string(ME.message), ...
        Try="look at the rows in the Results table, fix the cause, and run again", Details="Log tab"), ...
        Tab=obj.TabExport, Icon="error", Status="The run stopped: " + string(ME.message));
    return
end
if ~windowOpen(obj) || obj.CloseWhenRunEnds; return; end   % Close was asked meanwhile: the run ended (its files and records are written), nothing is shown
obj.ResultsTable.Data = withSubjectDate(obj, addRemedy(R));
obj.LastReportFiles = r.ReportFiles;
obj.LastExportFolder = "";
if doExport   % the run's config (CFG), not r.Config: an edit made while it went is the next run's
    obj.LastExportFolder = figureFileName(cfg.Export.Folder, struct('OutputFolder', r.datasetFolder(idx(1)), ...
        'OutputRoot', r.outputRoot(cfg), 'Root', cfg.Source.Root, 'Name', r.Names(idx(1))), Kind="folder");
end
sids = EphysAnalysisRunner.idList(opts.SessionFigures, @() cfg.enabledSessionFigures());
obj.OpenFolderButton.Tooltip = openFolderTip(obj, cfg, idx, sids);   % the run's config, as the folder above
obj.OpenReportButton.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.LastReportFiles));
obj.OpenFolderButton.Enable = matlab.lang.OnOffSwitchState(obj.LastExportFolder ~= "" && isfolder(obj.LastExportFolder));
obj.ToolbarReportTool.Enable = obj.OpenReportButton.Enable;
obj.ToolbarFolderTool.Enable = obj.OpenFolderButton.Enable;
counts = arrayfun(@(s) nnz(R.Status == s), ["done" "skipped" "error" "canceled"]);
obj.RunLabel.Text = sprintf("Results: %d done, %d skipped, %d failed, %d canceled (%.0f s)", counts, toc(t0));
obj.RunLabel.FontColor = ternary(counts(3) > 0, [0.75 0.1 0.1], [0 0 0]);   % a failed row shows red; its message is in the table
clear cleanup   % the strip goes, then the status bar says how it ended
if height(W) > 0
    obj.setStatus(string(obj.RunLabel.Text) + sprintf(". The config has %d warning(s): see the table on the Export tab.", height(W)));
else
    obj.setStatus(obj.RunLabel.Text);
end
end


function W = runWarnings(issues, doExport, doReport)
%runWarnings  The config's warnings that bear on this run: an Export one only when it writes figure files, a Report one
%   only when it writes a report; those about where the files go (Export, Report) first, then the others, in order.
W = issues(issues.Severity == "warning", :);
W = W(~(W.Section == "Export" & ~doExport) & ~(W.Section == "Report" & ~doReport), :);
[~, o] = sort(double(~ismember(W.Section, ["Export" "Report"])));   % a stable sort: each part keeps validate's order
W = W(o, :);
end


function txt = warningsText(W)
%warningsText  The run's warnings alert: how many, the first three ("<message> (<Section> > <Field>)"), where the rest are.
n = height(W);
lines = W.Message(1:min(3, n)) + " (" + W.Section(1:min(3, n)) + " > " + W.Field(1:min(3, n)) + ")";
txt = sprintf("The config has %d warning(s); the run goes on (Cancel stops it):", n) + newline + strjoin(reshape("- " + lines, 1, []), newline);
if n > 3; txt = txt + newline + sprintf("... and %d more.", n - 3); end
txt = txt + newline + "The table on the Export tab lists them: double-click a row to go to its setting.";
end


function progress(obj, r, title, clock, fraction, message)
%progress  The runner's report: the strip's bar and the status bar (setStatus draws, which also lets a Cancel click through).
if ~windowOpen(obj) || ~isvalid(r); return; end   % the window may be gone (isvalid(obj) stays true): the run goes on, writing its files and records
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
    obj.RunStrip.Host.ColumnWidth = {'1x', 280, 104};
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


function closeIfAsked(obj)
%closeIfAsked  Close was asked while the run went (onClose: CloseWhenRunEnds): the run is over, so the window closes now.
if ~isvalid(obj) || ~obj.CloseWhenRunEnds; return; end
finish(obj);
if windowOpen(obj); closeWindow(obj); end
end


function finish(obj)
if ~isvalid(obj); return; end
obj.Running = false;
if ~isempty(obj.Runner) && isvalid(obj.Runner); obj.Runner.ProgressFcn = []; end
if ~windowOpen(obj); return; end   % the window was deleted during the run: nothing to set
showRunBar(obj, false);
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
    first = r.sessionTable(idx, cfg).index(1);
    folder = figureFileName(cfg.Export.SessionsFolder, struct('OutputFolder', r.datasetFolder(first), ...
        'OutputRoot', r.outputRoot(cfg), 'Root', cfg.Source.Root, 'Name', r.Names(first)), Kind="folder");
    tip = tip + " The session figures' files are in " + folder + ".";
catch
    tip = tip + " The session figures' files are in the sessions folder (Export.SessionsFolder).";
end
end