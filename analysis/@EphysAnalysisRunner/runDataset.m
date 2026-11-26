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
%     T = figureObservations(src, spec)      (none: skipped, "no observation", or
%         "no starred observation" with observe.starred; a figure with
%         observe.perGroup: a row per observation and trial group)
%     for each observation i of n, one figure at a time:
%       F = r.computeFigure(src, spec, Observation=T(i,:))
%       out = drawExportPage(F, spec, Base=<folder>/<figureOutputName(...)>, ...)
%         (newExportFigure, renderFigure, exportFigure (Export), reportImage
%         and reportPdfPage (Report), close)
%     report = addReportFigure(report, spec (kind "figure"), F, Files=, Images=, Pages=,
%         Observations=T, Caption=figureCaption(spec, T, Dataset=name, Auroc=<each
%         observation's figureAurocCalls(F)>))                                     (Report)
%   one Results row per figure (Kind "figure", Files every observation's
%   files, Message "<n> observation(s)") and one report entry holding every
%   observation's page. The file name is figureOutputName's ({Plot} the
%   figure's id, {Unit} the observation's short label, "_<Unit>" appended
%   when the pattern tells the observations apart by neither {Unit} nor
%   {Index}; {Group} a per-group observation's group, "_<Group>" appended
%   likewise). With Export.Overwrite off an observation whose files all
%   exist is kept: its files are not written again, nor is it computed or
%   drawn unless the report needs its page, and then the report holds the
%   page as this run draws it (drawExportPage never reads a kept file into
%   the report: an earlier run drew it, maybe with other settings). Its
%   files stay in the row's Files, the Message says how many were kept
%   (EphysAnalysisRunner.keptText: "; <k> kept: files on disk from an
%   earlier run, not overwritten (Export.Overwrite off)"), the report
%   entry lists them as kept (addReportFigure Kept=) and so does
%   r.KeptFiles (the lab database's record of the run leaves them out of
%   its outputs: LabCapture.analysisRun). A file this run wrote is never
%   kept, nor written over, whatever Export.Overwrite says (WrittenFiles:
%   another dataset's or figure's page at the same path, the file names
%   not telling them apart): the page is drawn only for the report, its
%   file stays the first page's, in that page's row, and this row's
%   Message says so (EphysAnalysisRunner.overlapText: "; <k> not written:
%   this run already wrote a file at that path ..."). Without Export and
%   Report each observation is computed only. A
%   layer or panel that cannot be computed for one observation is drawn as
%   its note, not a failure; a figure that fails is an "error" row, and
%   one canceled part way a "canceled" row, each listing in Files the
%   files its finished pages wrote (stopPages; never a page stopped on a
%   worker while it drew: the Log says when one may have left a file
%   partly written), so the run record and the lab database's record name
%   them. Its report entry ("error") is added when it can be: one that
%   cannot is said in the Log and the row's Message, never thrown (the
%   row and the error that stopped the figure stay).
%   Progress before each observation: "<name>: <id> (<i>/<n>)".
%
%   With Workers the pages are drawn on process workers (usePagePool):
%   each observation is computed here and its page sent to a worker
%   (submitPage) while the next is computed; the pages are then taken in
%   order (pageOutput: "<name>: <id> drawing page <j>/<n>"), the computing
%   reporting the first half of the figure's progress and the drawing the
%   second. A failure or cancel() cancels the pages still on the workers.
%
%   Afterwards the dataset's cached data is cleared. The report (Report)
%   is r.Report, started by run(). Span=[a b] is the share of a longer run
%   this dataset covers (run passes it): its m figures share it evenly,
%   figure j reporting progress a + (b - a) * (j-1)/m and its observations
%   dividing its share (default [0 1]).
%   A figure with a panel whose options.yLimMode is "batch" draws it at
%   the run's shared range: BatchYLim= (run's batchYLimits rows: figure,
%   id, lim, n), else (runDataset alone) this dataset's own, measured
%   first (batchYLimits); a figure computed while measuring is drawn
%   without computing it again (takeBatchFigure). Its caption says "y
%   shared across <n> observations" (figureCaption YShared=).
%   Observation= (a struct: kind, data, unitId, channel, label; default
%   [] = every observation) draws each figure only for the rows that
%   match it (figureObservations' Observation=): the unit picked, or what
%   is on its channel; a figure of the dataset draws the dataset, and a
%   probe figure the probe, whatever is picked. A
%   figure with no match is "skipped", the reason (e.g. "no LFP channel on
%   channel 12 (...)") its message.
%
%   A probe figure (spec.probe.enabled) is one page per dataset, every
%   observation a tile on it:
%     T = figureProbeTiles(src, spec)        (none: skipped, "no
%         observation with a probe position")
%     PF = r.computeProbeFigure(src, spec)   (progress before each tile:
%         "<name>: <id> tile <i>/<n>"; cancel() stops between them)
%     out = drawExportPage(PF, spec, Base=<folder>/<figureOutputName(...,
%         OBS, 1, 1)>, ...)   (OBS of kind "probe": {Unit} "probe"; drawn
%         here, never on the workers: one page)
%     report = addReportFigure(report, spec, PF, ..., Observations=T,
%         Caption=figureCaption(spec, T, Dataset=name))
%   one Results row, Message "<n> tile(s)", and Export.Overwrite as for an
%   observation's page. It has no "batch" range (its panels share y
%   across its tiles: probe.sharedY) and ignores observe.perGroup.
%
%   Config= (an EphysAnalysisConfig; default [] = Config) is the config
%   the figures are drawn, exported and reported with: run passes the one
%   it started with, so an edit of Config while the run goes (the app's
%   window stays usable) does not reach its later datasets. Every read of
%   the config here is of that one (the figures, Export, the folder tokens:
%   outputRoot; the source's name pattern: source). Likewise every page is
%   drawn in the plot design and remembered plot rules the run took when it
%   started (holdPageLooks; called alone, those of when runDataset starts).
%
%   See also EphysAnalysisRunner.run, EphysAnalysisRunner.computeFigure,
%   EphysAnalysisRunner.computeProbeFigure, renderFigure, figureOutputName.

arguments
    obj (1,1) EphysAnalysisRunner
    k (1,1) double
    opts.Figures = []
    opts.Export (1,1) logical = true
    opts.Report (1,1) logical = false
    opts.Span (1,2) double = [0 1]
    opts.Observation = []
    opts.BatchYLim = []
    opts.Config = []
end

cfg = opts.Config;
if ~isa(cfg, 'EphysAnalysisConfig'); cfg = obj.Config; end   % alone: the config now; from run: the one it started with
looksBack = obj.holdPageLooks();   % alone: the plot design and rules now, for every page; from run: the run's
if ~isempty(looksBack); obj.WrittenFiles = string.empty(1, 0); end   % alone: the files this call writes (from run: the run's)
fids = EphysAnalysisRunner.idList(opts.Figures, @() cfg.enabledFigures());
nAll = max(1, numel(fids));   % the figures share the dataset's span
first = height(obj.Results) + 1;
name = obj.Names(k);
src = obj.source(k, cfg);
if opts.Report
    obj.Report = addReportDataset(obj.Report, src);
end
X = cfg.Export;
folder = figureFileName(X.Folder, struct('OutputFolder', obj.datasetFolder(k), 'OutputRoot', obj.outputRoot(cfg), ...
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
    jobs = cell(1, 0);   % the figure's pages, drawn or on the workers (submitPage), in order
    try
        reason = figureSkipReason(src, spec);
        T = [];
        onProbe = spec.probe.enabled;   % a probe figure: one page, every tile on it (whatever Observation= picks)
        if reason == "" && onProbe
            T = figureProbeTiles(src, spec);
            if height(T) == 0; reason = "no observation with a probe position"; end
        elseif reason == ""
            [T, why] = figureObservations(src, spec, Observation=opts.Observation);
            if height(T) == 0 && why ~= ""; reason = why; end   % Observation= matched nothing: why
            if height(T) == 0 && reason == "" && spec.observe.starred && ~isstruct(opts.Observation)
                reason = "no starred observation";
            end
            if height(T) == 0 && reason == ""; reason = "no observation"; end
        end
        if reason ~= ""
            obj.Results(end+1, :) = {name, spec.id, "figure", "skipped", reason, "", 0};
            obj.log("%s: %s skipped (%s)", name, spec.id, reason);
            if opts.Report
                obj.Report = addReportFigure(obj.Report, rspec, [], Status="skipped", Message=reason);
            end
            continue
        end
        if onProbe   % its page drawn here (or kept), then its report entry and row; JOBS holds it, should the entry fail
            jobs = {probeJob(obj, src, spec, T, name, folder, opts, withImages, withPages, ...
                opts.Span(1) + diff(opts.Span) * at / nAll, diff(opts.Span) / nAll, X)};
            probeDone(obj, spec, rspec, T, name, opts, jobs{1}, t0);
            continue
        end
        nObs = height(T);
        BY = [];   % the "batch" panels' shared y range
        if ~isempty(figureBatchPanels(spec)) && (opts.Export || withImages || withPages)
            B = opts.BatchYLim;
            if isstruct(B) && ~isempty(B) && any([B.figure] == spec.id)
                BY = B([B.figure] == spec.id);
            else   % runDataset alone: this dataset's observations
                BY = obj.batchYLimits(k, spec, Observation=opts.Observation, Fraction=opts.Span(1) + diff(opts.Span) * at / nAll, ...
                    Config=cfg);
            end
        end
        nShared = NaN;
        if ~isempty(BY); nShared = max([BY.n]); end
        files = string.empty(1, 0);
        keptFiles = string.empty(1, 0);   % the files of the observations kept (Export.Overwrite off): on disk, not this run's
        nKept = 0;
        nMine = 0;   % the observations whose file this run wrote already (another page at that path): not written over
        images = cell(1, 0);
        pages = strings(1, 0);
        F = [];
        calls = {};   % each observation's auROC calls, for the caption (figureAurocCalls)
        trialFs = {};   % each observation's figure when it has trial panels: their statistics for the caption (trialStatsText)
        withTrials = opts.Report && any(ismember([spec.panels.type], EphysAnalysisConfig.TrialPanelTypes));
        draws = opts.Export || withImages || withPages;
        onPool = draws && obj.usePagePool(nObs);
        share = 1 - 0.5 * onPool;   % on the workers the computing is the first half, the drawing the second
        for i = 1:nObs
            obj.progress(opts.Span(1) + diff(opts.Span) * (at + share * (i - 1) / nObs) / nAll, ...
                sprintf("%s: %s (%d/%d)", name, spec.id, i, nObs));   % cancel() stops between observations
            base = fullfile(folder, figureOutputName(X.FilenamePattern, name, spec, T(i, :), i, nObs));
            want = base + "." + X.Formats;
            mine = opts.Export && obj.writtenByThisRun(want);   % this run wrote a file at that path: never written over, never "kept"
            kept = opts.Export && ~mine && ~X.Overwrite && all(isfile(want));   % its files exist from an earlier run: not written again
            keptNow = string.empty(1, 0);
            if kept
                keptNow = want;
                keptFiles = [keptFiles want]; %#ok<AGROW>
                nKept = nKept + 1;
            end
            nMine = nMine + mine;
            if (kept || mine) && ~withImages && ~withPages   % ... nor computed, unless the report needs the page
                jobs{end+1} = struct('future', [], 'out', noPage(), 'kept', keptNow); %#ok<AGROW>
                continue
            end
            F = obj.takeBatchFigure(k, spec.id, i);   % computed while measuring the batch range, else now
            if isempty(F); F = obj.computeFigure(src, spec, Observation=T(i, :)); end
            ac = figureAurocCalls(F);
            if ~isempty(ac); calls{end+1} = ac; end %#ok<AGROW>
            if withTrials; trialFs{end+1} = trialPart(F); end %#ok<AGROW>
            if ~draws; continue; end   % computed only
            page = struct('Export', X, 'Base', "", 'Formats', X.Formats, 'Dpi', X.Dpi, ...
                'BatchYLim', BY, 'Images', withImages, 'Pages', withPages);   % a kept page: drawn for the report, its files left as they are
            if opts.Export && ~kept && ~mine; page.Base = base; end
            job = obj.submitPage(F, spec, onPool, page);
            job.kept = keptNow;
            jobs{end+1} = job; %#ok<AGROW>
        end
        for j = 1:numel(jobs)
            out = obj.pageOutput(jobs{j}, opts.Span(1) + diff(opts.Span) * (at + 0.5 + 0.5 * (j - 1) / numel(jobs)) / nAll, ...
                sprintf("%s: %s drawing page %d/%d", name, spec.id, j, numel(jobs)));
            jobs{j}.out = out;   % taken: should the figure stop after it, stopPages lists its files
            jobs{j}.future = [];
            obj.noteWritten(out.files);
            files = [files jobs{j}.kept out.files]; %#ok<AGROW>
            if ~isempty(out.image); images{end+1} = out.image; end %#ok<AGROW>
            if out.page ~= ""; pages(end+1) = out.page; end %#ok<AGROW>
        end
        if opts.Report
            if isempty(F); F = struct('kind', "figure"); end
            obj.Report = addReportFigure(obj.Report, rspec, F, Files=files, Kept=keptFiles, Images=images, Pages=pages, Observations=T, ...
                Caption=figureCaption(spec, T, Dataset=name, Auroc=calls, YShared=nShared, Results=trialFs));
        end
        obj.clearBatchCache(k, spec.id);
        msg = sprintf("%d observation(s)", nObs) + EphysAnalysisRunner.keptText(nKept) + EphysAnalysisRunner.overlapText(nMine);
        obj.Results(end+1, :) = {name, spec.id, "figure", "done", msg, strjoin(files, "; "), toc(t0)};
        obj.KeptFiles = [obj.KeptFiles keptFiles];   % in Files, not this run's: the lab database's record leaves them out
        obj.log("%s: %s done (%s, %d file(s), %.1f s)", name, spec.id, msg, numel(files), toc(t0));
    catch ME
        [written, stopped] = obj.stopPages(jobs);   % the pages still on the workers canceled; the files the finished ones wrote
        if stopped > 0
            obj.log("%s: %s: %d page(s) stopped on the workers while drawn: each may have left a file partly written in %s", ...
                name, spec.id, stopped, folder);
        end
        if ME.identifier == "EphysAnalysisRunner:Canceled"
            cancelFrom(obj, src, name, fids, jf, written);   % this figure's row lists what it wrote
            rethrow(ME);
        end
        obj.Results(end+1, :) = {name, spec.id, "figure", "error", string(ME.message), strjoin(written, "; "), toc(t0)};
        obj.log("%s: %s FAILED: %s", name, spec.id, ME.message);
        if opts.Report
            obj.addFailureEntry(rspec, "error", string(ME.message), name, spec.id);   % never throws: the row and the error stay
        end
    end
end
src.outputs.clearCache();
rows = obj.Results(first:end, :);
end


function cancelFrom(obj, src, name, fids, jFig, written)
%cancelFrom  "canceled" rows for the figures from jFig on, then free the dataset.
%   WRITTEN: the files figure jFig's finished pages wrote before the cancel
%   (stopPages), in its row's Files; none by default.
if nargin < 6; written = string.empty(1, 0); end
for jj = jFig:numel(fids)
    files = "";
    if jj == jFig; files = strjoin(written, "; "); end
    obj.Results(end+1, :) = {name, fids(jj), "figure", "canceled", "canceled", files, 0};
end
src.outputs.clearCache();
end


function job = probeJob(obj, src, spec, T, name, folder, opts, withImages, withPages, from, span, X)
%probeJob  A probe figure's page on one dataset: its tiles computed (computeProbeFigure), the page drawn and exported here.
%   FROM and SPAN: the figure's share of the run's progress, the tiles
%   dividing it. The page is drawn here (drawExportPage through
%   submitPage), never on the workers: it is one page. X: the Export
%   section of the run's config (runDataset's Config=). With
%   Export.Overwrite off and its files on disk it is kept: neither
%   computed nor drawn again unless the report needs it (the report then
%   holds the page as drawn here); a file this run wrote at that path
%   (WrittenFiles) is neither kept nor written over. JOB is submitPage's
%   (OUT the page drawn, noPage() when none), with kept (the files kept),
%   mine (true for a page whose file this run wrote already) and PF (the
%   figure computed, [] when not); probeDone reports it, and runDataset
%   keeps it, so a failure after the page was written lists its files
%   (stopPages).
nT = height(T);
obsP = struct('kind', "probe", 'label', "probe", 'unitId', NaN, 'channel', NaN, 'column', NaN, 'meta', [], 'groupLabel', "");
base = fullfile(folder, figureOutputName(X.FilenamePattern, name, spec, obsP, 1, 1));
want = base + "." + X.Formats;
mine = opts.Export && obj.writtenByThisRun(want);   % this run wrote a file at that path: never written over, never "kept"
kept = opts.Export && ~mine && ~X.Overwrite && all(isfile(want));   % its files exist from an earlier run: not written again
draws = opts.Export || withImages || withPages;
job = struct('future', [], 'out', noPage(), 'kept', string.empty(1, 0), 'mine', mine, 'PF', []);
if kept; job.kept = want; end
if (kept || mine) && ~withImages && ~withPages   % ... nor computed, unless the report needs the page
    return
end
obj.progress(from, sprintf("%s: %s (%d tile(s))", name, spec.id, nT));
job.PF = obj.computeProbeFigure(src, spec, ProgressFcn=@(i, n, ~) obj.progress(from + span * (i - 1) / max(n, 1), ...
    sprintf("%s: %s tile %d/%d", name, spec.id, i, n)));   % cancel() stops between the tiles
if ~draws; return; end
page = struct('Export', X, 'Base', "", 'Formats', X.Formats, 'Dpi', X.Dpi, ...
    'BatchYLim', [], 'Images', withImages, 'Pages', withPages);
if opts.Export && ~kept && ~mine; page.Base = base; end
drawn = obj.submitPage(job.PF, spec, false, page);
job.out = obj.pageOutput(drawn, from + span, sprintf("%s: %s drawing the page", name, spec.id));
obj.noteWritten(job.out.files);
end


function probeDone(obj, spec, rspec, T, name, opts, job, t0)
%probeDone  A probe figure's report entry and Results row, from probeJob's JOB: "done", "<n> tile(s)" (and keptText's or
%   overlapText's note).
files = [job.kept job.out.files];
images = cell(1, 0);
if ~isempty(job.out.image); images{end+1} = job.out.image; end
pages = strings(1, 0);
if job.out.page ~= ""; pages(end+1) = job.out.page; end
if opts.Report
    PF = job.PF;
    if isempty(PF); PF = struct('kind', "probeFigure"); end
    obj.Report = addReportFigure(obj.Report, rspec, PF, Files=files, Kept=job.kept, Images=images, Pages=pages, Observations=T, ...
        Caption=figureCaption(spec, T, Dataset=name));
end
msg = sprintf("%d tile(s)", height(T)) + EphysAnalysisRunner.keptText(double(~isempty(job.kept))) ...
    + EphysAnalysisRunner.overlapText(double(job.mine));
obj.Results(end+1, :) = {name, spec.id, "figure", "done", msg, strjoin(files, "; "), toc(t0)};
obj.KeptFiles = [obj.KeptFiles job.kept];
obj.log("%s: %s done (%s, %d file(s), %.1f s)", name, spec.id, msg, numel(files), toc(t0));
end


function K = trialPart(F)
%trialPart  What the caption reads of a figure's trial panels (trialStatsText): the panels' id, type and layers, without
%   the other panels and the per-trial values, so a run holds no observation's whole result for it.
K = struct('panels', F.panels(ismember([F.panels.type], EphysAnalysisConfig.TrialPanelTypes)));
for k = 1:numel(K.panels)
    for j = 1:numel(K.panels(k).layers)
        R = K.panels(k).layers(j).R;
        if isstruct(R) && isfield(R, 'values'); K.panels(k).layers(j).R = rmfield(R, 'values'); end
    end
end
end


function out = noPage()
%noPage  drawExportPage's OUT for a page not drawn (its files kept).
out = struct('files', string.empty(1, 0), 'image', [], 'page', "", 'title', "");
end
