function rows = runDataset(obj, k, opts)
%runDataset  Run the plots on one dataset: compute, render, export, report.
%   ROWS = r.runDataset(K, Plots=IDS, Export=TF, Report=TF) runs each plot on
%   dataset K, appends a Results row per plot as it goes and returns them.
%   After cancel() the plots left are "cancelled" rows and
%   EphysAnalysisRunner:Cancelled is rethrown. For every plot that the dataset
%   supports (plotSkipReason) it is always this sequence of public calls:
%     R = r.computePlot(src, spec)
%     figs = r.renderPlotFigures(R, spec)          % one figure per page
%     exportFigure(figs(p), <folder>/<name>, Format=, Dpi=)   (Export)
%     report = addReportFigure(report, spec, R, Files=files)  (Report)
%   The folder is Export.Folder with {OutputFolder} (this dataset's output
%   folder), {OutputRoot}, {Root}, {Name} and {Date} filled; the name is
%   plotFileName(Export.FilenamePattern, ...) (the page's tokens, and
%   "_p<page>" for a paged plot whose pattern names no page token). With Export.Overwrite off, pages whose files all
%   exist are not written again. A plot that fails is an "error" row; the
%   others still run. Afterwards the dataset's cached data is cleared.
%   The report (Report) is r.Report, started by run().
%
%   See also EphysAnalysisRunner.run, EphysAnalysisRunner.computePlot.

arguments
    obj (1,1) EphysAnalysisRunner
    k (1,1) double
    opts.Plots (1,:) string = string.empty(1, 0)
    opts.Export (1,1) logical = true
    opts.Report (1,1) logical = false
end

cfg = obj.Config;
ids = opts.Plots;
if isempty(ids); ids = cfg.enabledPlots(); end
first = height(obj.Results) + 1;
name = obj.Names(k);
src = obj.source(k);
if opts.Report
    obj.Report = addReportDataset(obj.Report, src);
end
X = cfg.Export;
folder = figureFileName(X.Folder, struct('OutputFolder', obj.datasetFolder(k), 'OutputRoot', obj.outputRoot(), ...
    'Root', cfg.Source.Root, 'Name', name), Kind="folder");
for j = 1:numel(ids)
    spec = cfg.plotFor(ids(j));
    try
        obj.progress((j - 1) / numel(ids), sprintf("%s: %s", name, spec.id));
    catch ME
        if ME.identifier ~= "EphysAnalysisRunner:Cancelled"; rethrow(ME); end
        for jj = j:numel(ids)
            s = cfg.plotFor(ids(jj));
            obj.Results(end+1, :) = {name, s.id, s.kind, "cancelled", "cancelled", "", 0};
        end
        src.outputs.clearCache();
        rethrow(ME);
    end
    t0 = tic;
    reason = plotSkipReason(src, spec);
    if reason ~= ""
        obj.Results(end+1, :) = {name, spec.id, spec.kind, "skipped", reason, "", 0};
        obj.log("%s: %s skipped (%s)", name, spec.id, reason);
        if opts.Report
            obj.Report = addReportFigure(obj.Report, spec, [], Status="skipped", Message=reason);
        end
        continue
    end
    try
        R = obj.computePlot(src, spec);
        files = string.empty(1, 0);
        if opts.Export
            figs = obj.renderPlotFigures(R, spec);
            closer = onCleanup(@() close(figs(isgraphics(figs))));
            n = numel(figs);
            for p = 1:n
                base = fullfile(folder, plotFileName(X.FilenamePattern, name, spec, R, p, n));
                want = base + "." + X.Formats;
                if ~X.Overwrite && all(isfile(want))
                    files = [files want]; %#ok<AGROW>
                    continue
                end
                files = [files exportFigure(figs(p), base, Format=X.Formats, Dpi=X.Dpi)]; %#ok<AGROW>
            end
            clear closer
        end
        if opts.Report
            obj.Report = addReportFigure(obj.Report, spec, R, Files=files);
        end
        obj.Results(end+1, :) = {name, spec.id, spec.kind, "done", "", strjoin(files, "; "), toc(t0)};
        obj.log("%s: %s done (%d file(s), %.1f s)", name, spec.id, numel(files), toc(t0));
    catch ME
        obj.Results(end+1, :) = {name, spec.id, spec.kind, "error", string(ME.message), "", toc(t0)};
        obj.log("%s: %s FAILED: %s", name, spec.id, ME.message);
        if opts.Report
            obj.Report = addReportFigure(obj.Report, spec, [], Status="error", Message=string(ME.message));
        end
    end
end
src.outputs.clearCache();
rows = obj.Results(first:end, :);
end
