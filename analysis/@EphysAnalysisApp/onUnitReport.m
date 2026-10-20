function [R, file] = onUnitReport(obj, opts)
%onUnitReport  A spot check: every enabled figure of the active dataset, for the observation picked only, as an HTML report.
%   [R, FILE] = onUnitReport(obj) is the Figures tab's Unit report button.
%   It runs the report as the Export tab's Run does (onRunExport: the
%   config validated first, the cancelable progress dialog, one run at a
%   time) with these differences: the active dataset only; the unit or
%   channel picked over the preview only (run's Observation=: each figure
%   draws what matches it -- the unit itself on a figure of the same
%   data, else what is on the unit's recording channel; a figure of the
%   dataset, or one with no match, is listed in the report as skipped,
%   with why); no figure files and no session figures; an HTML report
%   (whatever Report.Format says) titled for the observation, in a new
%   temporary folder (tempname), so the output folder is not touched (the
%   run record goes there too). The selected figure is drawn even when it
%   is off (for this run only). When the report is written it opens in the
%   browser (onOpenReport; Open=false leaves it closed, as the tests do)
%   and the status bar says what was drawn and what was left out. R is
%   the run's results (the Export tab's results table shows them; Open
%   report opens this report until the next run) and FILE the report ("" =
%   none: nothing to report on, or canceled).
%   The button is off without a dataset or a unit or channel picked, while
%   a run goes, and for a figure across sessions (its observations are
%   matched across datasets, not one dataset's).
%
%   See also onRunExport, onGenerateFigure, onOpenReport, EphysAnalysisRunner.run,
%   figureObservations.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Open (1,1) logical = true   % open the report in the browser when it is written
end
R = table();
file = "";
if obj.Running
    obj.setStatus("A run is going: make the unit report when it is done.");
    return
end
if ismember(obj.FigurePreviewState, ["computing" "drawing"])
    obj.setStatus("A preview is computing: make the unit report when it is done (or cancel it).");
    return
end
k = obj.SelectedFigure;
T = obj.FigureObservations;
i = obj.FigureObservationDropDown.Value;
if isempty(obj.Runner) || obj.ActiveIdx < 1 || k < 1 || k > numel(obj.Config.Figures) || ~istable(T) ...
        || ~isnumeric(i) || ~isscalar(i) || i < 1 || i > height(T)
    obj.setStatus("No unit report: scan, pick a dataset and a unit or channel over the preview.");
    return
end
spec = obj.Config.figureFor(k);
if spec.sessions.enabled || ~ismember(T.kind(i), ["unit" "channel"])
    obj.setStatus("No unit report: pick a figure drawn per dataset, and a unit or channel over the preview.");
    return
end
label = T.label(i);
if T.groupLabel(i) ~= "" && endsWith(label, " · " + T.groupLabel(i))
    label = extractBefore(label, strlength(label) - strlength(T.groupLabel(i)) - 2);   % every trial group is drawn
end
obs = struct('kind', T.kind(i), 'data', spec.observe.data, 'unitId', T.unitId(i), 'channel', T.channel(i), 'label', label);
name = obj.Runner.Names(obj.ActiveIdx);
cfg = obj.gatherConfig();
id = cfg.Figures(k).id;
wasOff = ~cfg.Figures(k).enabled;
cfg.Figures(k).enabled = true;   % for this run only: obj.Config keeps it as it is
cfg.Export.Enabled = false;
cfg.Report.Enabled = true;
cfg.Report.Format = "html";
cfg.Report.PerDataset = false;
cfg.Report.Folder = string(tempname);   % a folder of its own: the output folder is not touched
cfg.Report.FileName = "unit_report";
cfg.Report.Title = "{Name}: " + label + " on " + name;
obj.setStatus("Making the unit report for " + label + " ...");
R = obj.onRunExport(SessionFigures=string.empty(1, 0), Datasets=obj.ActiveIdx, Export=false, Report=true, ...
    Config=cfg, Title="Unit report: " + label, Observation=obs);
if ~isempty(obj.Runner) && isvalid(obj.Runner)
    obj.Runner.Config = obj.gatherConfig();   % the runner holds the config as the controls show it again
end
if ~istable(R) || height(R) == 0
    return   % not run: onRunExport said why
end
html = obj.LastReportFiles(endsWith(obj.LastReportFiles, ".html"));
if any(R.Status == "canceled") || isempty(html)
    obj.setStatus("The unit report for " + label + " was canceled.");
    return
end
file = html(1);
if opts.Open; obj.onOpenReport(); end
txt = sprintf("Unit report for %s: %d figure(s) drawn", label, nnz(R.Status == "done"));
out = R(R.Status ~= "done", :);
if height(out) > 0
    txt = txt + "; left out: " + strjoin(out.Plot + " (" + out.Message + ")", ", ");
end
if wasOff
    txt = txt + "; " + id + " is off, so it was drawn for this report only";
end
obj.setStatus(txt + ". " + file);
end
