function rows = runDataset(obj, k, opts)
%runDataset  Run the figures on one dataset: compute, render, export, report.
%   ROWS = r.runDataset(K, Figures=FIDS, Export=TF, Report=TF) runs each
%   figure on dataset K, appends a Results row per figure as it goes and
%   returns them. Figures: [] (the default) = the enabled ones
%   (Config.enabledFigures()); string.empty(1, 0) = none; else the ids.
%   After cancel() the figures left are "canceled" rows and
%   EphysAnalysisRunner:Canceled is rethrown (also when a compute throws it
%   at a checkpoint, while PollFcn is set). The export folder is
%   Export.Folder with {OutputFolder} (this dataset's output folder),
%   {OutputRoot}, {Root}, {Name} and {Date} filled.
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
%         Caption=figureCaption(spec, T, Dataset=name, Auroc=<each observation's
%         figureAurocCalls(F)>))                                                   (Report)
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
%   Afterwards the dataset's cached data is cleared. The report (Report)
%   is r.Report, started by run(). Span=[a b] is the share of a longer run
%   this dataset covers (run passes it): its m figures share it evenly,
%   figure j reporting progress a + (b - a) * (j-1)/m and its observations
%   dividing its share (default [0 1]).
%
%   See also EphysAnalysisRunner.run, EphysAnalysisRunner.computeFigure,
%   renderFigure, figureOutputName.

arguments
    obj (1,1) EphysAnalysisRunner
    k (1,1) double
    opts.Figures = []
    opts.Export (1,1) logical = true
    opts.Report (1,1) logical = false
    opts.Span (1,2) double = [0 1]
end

cfg = obj.Config;
fids = EphysAnalysisRunner.idList(opts.Figures, @() cfg.enabledFigures());
nAll = max(1, numel(fids));   % the figures share the dataset's span
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

for jf = 1:numel(fids)
    at = jf - 1;   % this figure's place among the dataset's figures
    try
        spec = cfg.figureFor(fids(jf));
        obj.progress(opts.Span(1) + diff(opts.Span) * at / nAll, sprintf("%s: %s", name, spec.id));
    catch ME
        if ME.identifier ~= "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        cancelFrom(obj, src, name, fids, jf);
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
        calls = {};   % each observation's auROC calls, for the caption (figureAurocCalls)
        for i = 1:nObs
            obj.progress(opts.Span(1) + diff(opts.Span) * (at + (i - 1) / nObs) / nAll, ...
                sprintf("%s: %s (%d/%d)", name, spec.id, i, nObs));   % cancel() stops between observations
            base = fullfile(folder, figureOutputName(X.FilenamePattern, name, spec, T(i, :), i, nObs));
            want = base + "." + X.Formats;
            kept = opts.Export && ~X.Overwrite && all(isfile(want));   % its files exist: not written again
            if kept; files = [files want]; end %#ok<AGROW>
            if kept && ~withImages && ~withPages; continue; end   % ... nor computed, unless the report needs the page
            F = obj.computeFigure(src, spec, Observation=T(i, :));
            ac = figureAurocCalls(F);
            if ~isempty(ac); calls{end+1} = ac; end %#ok<AGROW>
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
                Caption=figureCaption(spec, T, Dataset=name, Auroc=calls));
        end
        obj.Results(end+1, :) = {name, spec.id, "figure", "done", sprintf("%d observation(s)", nObs), strjoin(files, "; "), toc(t0)};
        obj.log("%s: %s done (%d observation(s), %d file(s), %.1f s)", name, spec.id, nObs, numel(files), toc(t0));
    catch ME
        clear closer   % the page a failure left open
        if ME.identifier == "EphysAnalysisRunner:Canceled"
            cancelFrom(obj, src, name, fids, jf);
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


function cancelFrom(obj, src, name, fids, jFig)
%cancelFrom  "canceled" rows for the figures from jFig on, then free the dataset.
for jj = jFig:numel(fids)
    obj.Results(end+1, :) = {name, fids(jj), "figure", "canceled", "canceled", "", 0};
end
src.outputs.clearCache();
end
