function rows = runDataset(obj, k, opts)
%runDataset  Run the plots and figures on one dataset: compute, render, export, report.
%   ROWS = r.runDataset(K, Plots=IDS, Figures=FIDS, Export=TF, Report=TF)
%   runs each plot, then each figure, on dataset K, appends a Results row
%   per plot and per figure as it goes and returns them. Plots and Figures:
%   [] (the default) = the enabled ones (Config.enabledPlots(),
%   Config.enabledFigures()); string.empty(1, 0) = none; else the ids.
%   After cancel() the plots and figures left are "canceled" rows and
%   EphysAnalysisRunner:Canceled is rethrown (also when a compute throws it
%   at a checkpoint, while PollFcn is set). For every plot that the dataset
%   supports (plotSkipReason) it is always this sequence of public calls:
%     R = r.computePlot(src, spec)
%     for each page p of plotPageCount(R, spec), one figure at a time:  (Export)
%       fig = newExportFigure(Export, R, spec, Page=p); h = renderPlot(R, spec, fig, Page=p)
%       files = [files exportFigure(fig, <folder>/<name>, Format=, Dpi=)]
%       images{p} = reportImage(fig, report, Title=h.title, Files=)   (an HTML report)
%       pages(p) = reportPdfPage(fig, report, Files=)                 (a PDF report)
%       close(fig)
%     report = addReportFigure(report, spec, R, Files=files, Images=images, Pages=pages)  (Report)
%   The folder is Export.Folder with {OutputFolder} (this dataset's output
%   folder), {OutputRoot}, {Root}, {Name} and {Date} filled; the name is
%   plotFileName(Export.FilenamePattern, ...) (the page's tokens, and
%   "_p<page>" for a paged plot whose pattern does not tell its pages
%   apart). With Export.Overwrite off, a page whose files all exist is not
%   written again, nor drawn unless the report needs its image or page.
%   Without Export the report draws its own (addReportFigure). A
%   plot that fails is an "error" row (its open page is closed); the
%   others still run.
%
%   A figure (Config.Figures; spec = Config.figureFor(id)) is drawn once
%   per observation, one page each:
%     reason = figureSkipReason(src, spec)   ("" = it can be drawn; else a
%         "skipped" row and report entry)
%     T = figureObservations(src, spec)      (none: skipped, "no observation"; a
%         figure with observe.perGroup: a row per observation and trial group)
%     for each observation i of n, one figure at a time:
%       F = r.computeFigure(src, spec, Observation=T(i,:))
%       fig = newExportFigure(Export, F, spec); h = renderFigure(F, spec, fig)
%       files = [files exportFigure(fig, <folder>/<figureOutputName(...)>, Format=, Dpi=)]   (Export)
%       images{i} = reportImage(...); pages(i) = reportPdfPage(...)                (Report)
%       close(fig)
%     report = addReportFigure(report, spec (kind "figure"), F, Files=, Images=, Pages=,
%         Caption=figureCaption(spec, T, Dataset=name))                            (Report)
%   one Results row per figure (Kind "figure", Files every observation's
%   files, Message "<n> observation(s)") and one report entry holding every
%   observation's page. The file name is figureOutputName's ({Plot} the
%   figure's id, {Unit} the observation's short label, "_<Unit>" appended
%   when the pattern tells the observations apart by neither {Unit} nor
%   {Index}; {Group} a per-group observation's group, "_<Group>" appended
%   likewise). With Export.Overwrite off an observation whose files all
%   exist is neither computed nor drawn again unless the report needs its
%   page. Without Export and Report each observation is computed only. A
%   layer or panel that cannot be computed for one observation is drawn as
%   its note, not a failure; a figure that fails is an "error" row.
%   Progress before each observation: "<name>: <id> (<i>/<n>)".
%
%   Afterwards the dataset's cached data is cleared. A result whose
%   cacheKey is in r.CacheWanted (run puts the enabled session plots' keys
%   there) is kept in r.ResultCache (cachePut), so the session plots after
%   the datasets reuse it. The report (Report) is r.Report, started by
%   run(). Span=[a b] is the share of a longer run this dataset covers (run
%   passes it): its m plots and figures share it evenly, plot j reporting
%   progress a + (b - a) * (j-1)/m and a figure's observations dividing its
%   share (default [0 1]).
%
%   See also EphysAnalysisRunner.run, EphysAnalysisRunner.computePlot,
%   EphysAnalysisRunner.computeFigure, renderFigure, figureOutputName.

arguments
    obj (1,1) EphysAnalysisRunner
    k (1,1) double
    opts.Plots = []
    opts.Figures = []
    opts.Export (1,1) logical = true
    opts.Report (1,1) logical = false
    opts.Span (1,2) double = [0 1]
end

cfg = obj.Config;
ids = EphysAnalysisRunner.idList(opts.Plots, @() cfg.enabledPlots());
fids = EphysAnalysisRunner.idList(opts.Figures, @() cfg.enabledFigures());
nAll = max(1, numel(ids) + numel(fids));   % the plots and figures share the dataset's span
first = height(obj.Results) + 1;
name = obj.Names(k);
src = obj.source(k);
if opts.Report
    obj.Report = addReportDataset(obj.Report, src);
end
X = cfg.Export;
folder = figureFileName(X.Folder, struct('OutputFolder', obj.datasetFolder(k), 'OutputRoot', obj.outputRoot(), ...
    'Root', cfg.Source.Root, 'Name', name), Kind="folder");
withImages = opts.Report && obj.Report.options.Format ~= "pdf";   % the HTML report embeds each page
withPages = opts.Report && obj.Report.options.Format ~= "html";   % the PDF report holds each page

for j = 1:numel(ids)
    spec = cfg.plotFor(ids(j));
    try
        obj.progress(opts.Span(1) + diff(opts.Span) * (j - 1) / nAll, sprintf("%s: %s", name, spec.id));
    catch ME
        if ME.identifier ~= "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        cancelFrom(obj, src, name, ids, fids, j, 1);
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
        if ~isempty(obj.CacheWanted)   % only a run with session plots wants results kept
            key = EphysAnalysisRunner.cacheKey(obj.Keys(k), spec);
            if ismember(key, obj.CacheWanted); obj.cachePut(key, R); end   % a session plot of this run reuses it
        end
        files = string.empty(1, 0);
        images = cell(1, 0);
        pages = strings(1, 0);
        if opts.Export
            n = plotPageCount(R, spec);
            if withImages; images = cell(1, n); end
            if withPages; pages = strings(1, n); end
            for p = 1:n
                base = fullfile(folder, plotFileName(X.FilenamePattern, name, spec, R, p, n));
                want = base + "." + X.Formats;
                kept = ~X.Overwrite && all(isfile(want));   % its files exist: not written again
                if kept; files = [files want]; end %#ok<AGROW>
                if kept && ~withImages && ~withPages; continue; end   % ... nor drawn, unless the report needs the page
                fig = newExportFigure(X, R, spec, Page=p);
                closer = onCleanup(@() close(fig));   % closes the page on a failure too
                h = renderPlot(R, spec, fig, Page=p);
                written = string.empty(1, 0);
                if ~kept
                    written = exportFigure(fig, base, Format=X.Formats, Dpi=X.Dpi);
                    files = [files written]; %#ok<AGROW>
                end
                if withImages
                    images{p} = reportImage(fig, obj.Report, Title=h.title, Files=written);
                end
                if withPages
                    pages(p) = reportPdfPage(fig, obj.Report, Files=written);
                end
                clear closer
            end
        end
        if opts.Report
            obj.Report = addReportFigure(obj.Report, spec, R, Files=files, Images=images, Pages=pages);
        end
        obj.Results(end+1, :) = {name, spec.id, spec.kind, "done", "", strjoin(files, "; "), toc(t0)};
        obj.log("%s: %s done (%d file(s), %.1f s)", name, spec.id, numel(files), toc(t0));
    catch ME
        clear closer   % the page a failure left open
        if ME.identifier == "EphysAnalysisRunner:Canceled"   % a checkpoint inside the compute (PollFcn)
            cancelFrom(obj, src, name, ids, fids, j, 1);
            rethrow(ME);
        end
        obj.Results(end+1, :) = {name, spec.id, spec.kind, "error", string(ME.message), "", toc(t0)};
        obj.log("%s: %s FAILED: %s", name, spec.id, ME.message);
        if opts.Report
            obj.Report = addReportFigure(obj.Report, spec, [], Status="error", Message=string(ME.message));
        end
    end
end

% --- figures, after the plots: one page per observation ---------------------------------------
for jf = 1:numel(fids)
    at = numel(ids) + jf - 1;   % this figure's place among the dataset's plots and figures
    try
        spec = cfg.figureFor(fids(jf));
        obj.progress(opts.Span(1) + diff(opts.Span) * at / nAll, sprintf("%s: %s", name, spec.id));
    catch ME
        if ME.identifier ~= "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        cancelFrom(obj, src, name, ids, fids, numel(ids) + 1, jf);
        rethrow(ME);
    end
    rspec = spec;
    rspec.kind = "figure";   % the report entry's kind
    t0 = tic;
    try
        reason = figureSkipReason(src, spec);
        T = [];
        if reason == ""
            T = figureObservations(src, spec);
            if height(T) == 0; reason = "no observation"; end
        end
        if reason ~= ""
            obj.Results(end+1, :) = {name, spec.id, "figure", "skipped", reason, "", 0};
            obj.log("%s: %s skipped (%s)", name, spec.id, reason);
            if opts.Report
                obj.Report = addReportFigure(obj.Report, rspec, [], Status="skipped", Message=reason);
            end
            continue
        end
        nObs = height(T);
        files = string.empty(1, 0);
        images = cell(1, 0);
        pages = strings(1, 0);
        F = [];
        for i = 1:nObs
            obj.progress(opts.Span(1) + diff(opts.Span) * (at + (i - 1) / nObs) / nAll, ...
                sprintf("%s: %s (%d/%d)", name, spec.id, i, nObs));   % cancel() stops between observations
            base = fullfile(folder, figureOutputName(X.FilenamePattern, name, spec, T(i, :), i, nObs));
            want = base + "." + X.Formats;
            kept = opts.Export && ~X.Overwrite && all(isfile(want));   % its files exist: not written again
            if kept; files = [files want]; end %#ok<AGROW>
            if kept && ~withImages && ~withPages; continue; end   % ... nor computed, unless the report needs the page
            F = obj.computeFigure(src, spec, Observation=T(i, :));
            if ~opts.Export && ~withImages && ~withPages; continue; end   % computed only
            fig = newExportFigure(X, F, spec);
            closer = onCleanup(@() close(fig));   % closes the page on a failure too
            h = renderFigure(F, spec, fig);
            written = string.empty(1, 0);
            if opts.Export && ~kept
                written = exportFigure(fig, base, Format=X.Formats, Dpi=X.Dpi);
                files = [files written]; %#ok<AGROW>
            end
            if withImages
                images{end+1} = reportImage(fig, obj.Report, Title=h.title, Files=written); %#ok<AGROW>
            end
            if withPages
                pages(end+1) = reportPdfPage(fig, obj.Report, Files=written); %#ok<AGROW>
            end
            clear closer
        end
        if opts.Report
            if isempty(F); F = struct('kind', "figure"); end
            obj.Report = addReportFigure(obj.Report, rspec, F, Files=files, Images=images, Pages=pages, ...
                Caption=figureCaption(spec, T, Dataset=name));
        end
        obj.Results(end+1, :) = {name, spec.id, "figure", "done", sprintf("%d observation(s)", nObs), strjoin(files, "; "), toc(t0)};
        obj.log("%s: %s done (%d observation(s), %d file(s), %.1f s)", name, spec.id, nObs, numel(files), toc(t0));
    catch ME
        clear closer   % the page a failure left open
        if ME.identifier == "EphysAnalysisRunner:Canceled"
            cancelFrom(obj, src, name, ids, fids, numel(ids) + 1, jf);
            rethrow(ME);
        end
        obj.Results(end+1, :) = {name, spec.id, "figure", "error", string(ME.message), "", toc(t0)};
        obj.log("%s: %s FAILED: %s", name, spec.id, ME.message);
        if opts.Report
            obj.Report = addReportFigure(obj.Report, rspec, [], Status="error", Message=string(ME.message));
        end
    end
end
src.outputs.clearCache();
rows = obj.Results(first:end, :);
end


function cancelFrom(obj, src, name, ids, fids, jPlot, jFig)
%cancelFrom  "canceled" rows for the plots from jPlot and the figures from jFig on, then free the dataset.
cfg = obj.Config;
for jj = jPlot:numel(ids)
    s = cfg.plotFor(ids(jj));
    obj.Results(end+1, :) = {name, s.id, s.kind, "canceled", "canceled", "", 0};
end
for jj = jFig:numel(fids)
    obj.Results(end+1, :) = {name, fids(jj), "figure", "canceled", "canceled", "", 0};
end
src.outputs.clearCache();
end
