function T = run(obj, opts)
%run  Run every enabled plot on every dataset; export and report.
%   T = r.run(Datasets=, Plots=, Export=, Report=) runs runDataset on each
%   dataset in turn and returns (and keeps in r.Results) one row per dataset
%   and plot: Dataset, Plot, Kind, Status (done | skipped | error |
%   cancelled), Message, Files, Seconds. With Report it builds the report
%   (newAnalysisReport) and writes it (Report.Format: html, pdf or both)
%   to Report.Folder / Report.FileName -- one report over all datasets, or
%   one per dataset with Report.PerDataset. The written files are in
%   r.ReportFiles. cancel() stops before the next plot; the rest are
%   "cancelled".
%
%   Options
%     Datasets  indices, keys or names (default all)
%     Plots     plot ids (default Config.enabledPlots())
%     Export    write figure files (default Config.Export.Enabled)
%     Report    write the report (default Config.Report.Enabled)
%
%   See also EphysAnalysisRunner.runDataset, EphysAnalysisRunner.plan,
%   writeHtmlReport, writePdfReport.

arguments
    obj (1,1) EphysAnalysisRunner
    opts.Datasets = []
    opts.Plots (1,:) string = string.empty(1, 0)
    opts.Export = []
    opts.Report = []
end

cfg = obj.Config;
obj.CancelRequested = false;
doExport = cfg.Export.Enabled;
if ~isempty(opts.Export); doExport = logical(opts.Export); end
doReport = cfg.Report.Enabled;
if ~isempty(opts.Report); doReport = logical(opts.Report); end
ids = opts.Plots;
if isempty(ids); ids = cfg.enabledPlots(); end
if isempty(opts.Datasets)
    idx = 1:numel(obj.Outputs);
elseif isnumeric(opts.Datasets)
    idx = reshape(opts.Datasets, 1, []);
else
    idx = arrayfun(@(k) obj.index(k), reshape(string(opts.Datasets), 1, []));
    idx = idx(idx > 0);
end
obj.Results = EphysAnalysisRunner.emptyResults();
obj.ReportFiles = string.empty(1, 0);
P = cfg.Report;
perDataset = doReport && P.PerDataset;
if doReport && ~perDataset
    obj.Report = newReport(cfg);
end
obj.log("Analysis ""%s"": %d dataset(s) x %d plot(s)", cfg.Name, numel(idx), numel(ids));
cancelled = false;
for j = 1:numel(idx)
    k = idx(j);
    if perDataset; obj.Report = newReport(cfg); end
    try
        obj.progress((j - 1) / max(1, numel(idx)), "Dataset " + obj.Names(k));
        obj.runDataset(k, Plots=ids, Export=doExport, Report=doReport);   % appends to obj.Results
    catch ME
        if ME.identifier ~= "EphysAnalysisRunner:Cancelled"; rethrow(ME); end
        cancelled = true;
        if ~any(obj.Results.Dataset == obj.Names(k))   % cancelled before the dataset started
            for id = ids
                obj.Results(end+1, :) = {obj.Names(k), id, kindOf(cfg, id), "cancelled", "cancelled", "", 0};
            end
        end
    end
    if cancelled
        for kk = idx(j+1:end)
            for id = ids
                obj.Results(end+1, :) = {obj.Names(kk), id, kindOf(cfg, id), "cancelled", "cancelled", "", 0};
            end
        end
        obj.log("Cancelled.");
        break
    end
    if perDataset
        obj.ReportFiles = [obj.ReportFiles writeReports(obj, k)];
    end
end
if doReport && ~perDataset && ~cancelled && ~isempty(idx)
    obj.ReportFiles = writeReports(obj, idx(1));
end
try
    obj.progress(1, "Done");
catch
end
T = obj.Results;
end


function report = newReport(cfg)
title = replace(cfg.Report.Title, "{Name}", cfg.Name);
title = replace(title, "{Date}", string(datetime('now', 'Format', 'yyyy-MM-dd')));
report = newAnalysisReport(Title=title, Config=cfg.toStruct(), Export=cfg.Export, Options=cfg.Report);
end


function files = writeReports(obj, k)
%writeReports  Write obj.Report as HTML and / or PDF; {OutputFolder} = dataset K's.
cfg = obj.Config;
P = cfg.Report;
folder = figureFileName(P.Folder, struct('OutputFolder', obj.datasetFolder(k), 'OutputRoot', obj.outputRoot(), ...
    'Root', cfg.Source.Root, 'Name', obj.Names(k)), Kind="folder");
base = fullfile(folder, P.FileName);
if P.PerDataset; base = base + "_" + regexprep(obj.Names(k), '[^\w\-\.]', '_'); end
files = string.empty(1, 0);
if ismember(P.Format, ["html" "both"])
    files(end+1) = writeHtmlReport(obj.Report, base + ".html");
end
if ismember(P.Format, ["pdf" "both"])
    files(end+1) = writePdfReport(obj.Report, base + ".pdf");
end
obj.log("Report: %s", strjoin(files, ", "));
end


function k = kindOf(cfg, id)
k = cfg.Plots(cfg.plotIndex(id)).kind;
end