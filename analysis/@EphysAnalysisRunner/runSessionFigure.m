function rows = runSessionFigure(obj, id, idx, opts)
%runSessionFigure  Run one session figure across the datasets: compute, render, export, report, per observation.
%   ROWS = r.runSessionFigure(ID, IDX, Export=TF, Report=TF, Span=[a b])
%   draws the figure ID (Config.Figures, sessions.enabled; its enabled flag
%   is not checked) across the datasets IDX (or sessions.datasetKeys with
%   sessions.datasets "list"):
%     [T, SESSIONS] = r.sessionFigureObservations(SPEC, IDX)  the matched
%         observations (sites, cells, channels or the dataset)
%     figureSessionSkipReason(SPEC, each session's figureSkipReason) or no
%         observation: one "skipped" row ("sessions: all")
%     per observation i of T (cancel() stops between them, through
%         progress): figureSessionCompute -> one figure per facet and trial
%         group (RES); each drawn exactly as runDataset draws a figure's
%         page (drawExportPage; on the process workers with Workers, the
%         pages taken in order after the observations are computed) and
%         exported into
%         Export.SessionsFolder (its folder tokens those of the first
%         session's dataset) named figureOutputName(Export.FilenamePattern,
%         <facet>, SPEC, OBS, i, nObs) -- {Name} the facet ("all" or the
%         subject), {Plot} ID, {Unit} "site_ch7", the mapping's cell, "ch7"
%         or "dataset", and "_<group>" for a trial group's figure; a name
%         this run already wrote (two cells that sanitize alike) gets
%         "_2", "_3", ...; with
%         Export.Overwrite off a page whose files all exist is kept: not
%         written again (the report holds the page as this run draws it)
%   One Results row per figure label (facet / group): Dataset "sessions:
%   <label>", Plot ID, Kind "figure", Status done (a page per observation)
%   | skipped (no observation drew: the reasons) | error, Message "<n>
%   observation(s)" (and EphysAnalysisRunner.keptText's note on the pages
%   kept), Files (the kept pages' files too; the report entry lists them as
%   kept, addReportFigure Kept=, and so does r.KeptFiles; a page whose
%   file this run wrote already, for another page at that path, is
%   neither kept nor written over: overlapText's note). With Report each label is one entry of r.Report
%   (in the section run started, "Across sessions"), its pages the
%   observations', captioned by figureCaption(SPEC, <its observations>,
%   Sessions=<its facet's sessions, as merged>, Results=<its last page's
%   trial panels (keptPart)>: their statistics, trialStatsText). With
%   Export.Data.Enabled the computed figures are saved (writeAnalysisData:
%   one .mat in Export.Data.Folder named by Data.FilenamePattern with
%   {Name} "all", {Kind} "figure") holding schema, figure, spec, sessions,
%   observations (T), results (a struct per observation and figure: index,
%   observation, facet, group, label, status, message, F) and perSession
%   ({nObs x nSessions}: each dataset's own figure), config and created;
%   the file is added to the first row's Files. A failure is an "error"
%   row; EphysAnalysisRunner:Canceled is rethrown, after a "canceled" row
%   "sessions: all" listing the files the finished pages wrote (stopPages;
%   run adds none for it then). A report entry that cannot be added is
%   said in the Log and the row's Message, never thrown: a label whose
%   entry fails is an "error" row listing the files its pages wrote.
%   A panel with options.yLimMode "batch" shares one y range over the
%   figure's every matched observation: they are all computed first (held
%   for their pages, as Export.Data holds them), measured (figureYExtents,
%   figureBatchYLim; appended to r.BatchYLim) and then drawn at the union
%   (renderFigure BatchYLim=), each caption saying "y shared across <n>
%   observations".
%   Config= (an EphysAnalysisConfig; default [] = Config) is the config
%   the figure is drawn, exported and reported with: run passes the one it
%   started with, so an edit of Config while the run goes does not reach
%   it (the figure, Export, the folder tokens, the sessions' name pattern).
%   Its pages are drawn in the plot design and remembered plot rules the
%   run took when it started (holdPageLooks; alone, those of when it starts).
%
%   See also figureSessionCompute, EphysAnalysisRunner.computeSessionFigure,
%   EphysAnalysisRunner.run.

arguments
    obj (1,1) EphysAnalysisRunner
    id (1,1) string
    idx = []
    opts.Export (1,1) logical = true
    opts.Report (1,1) logical = false
    opts.Span (1,2) double = [0 1]
    opts.Config = []
end

cfg = opts.Config;
if ~isa(cfg, 'EphysAnalysisConfig'); cfg = obj.Config; end   % alone: the config now; from run: the one it started with
looksBack = obj.holdPageLooks();   % alone: the plot design and rules now, for every page; from run: the run's
if ~isempty(looksBack); obj.WrittenFiles = string.empty(1, 0); end   % alone: the files this call writes (from run: the run's)
X = cfg.Export;
first = height(obj.Results) + 1;
t0 = tic;
try
    spec = cfg.figureFor(id);
    spec.enabled = true;   % asked for: drawn whatever its enabled flag (as figureCompute)
    [T, sessions, sources] = obj.sessionFigureObservations(spec, idx, Config=cfg);
    reasons = strings(1, height(sessions));
    for j = 1:height(sessions)
        if isempty(sources{j})
            reasons(j) = sessions.message(j);
        else
            reasons(j) = figureSkipReason(sources{j}, spec);
        end
    end
    reason = figureSessionSkipReason(spec, reasons, Labels=reshape(sessions.label, 1, []));
    if reason == "" && height(T) == 0; reason = "no " + spec.observe.kind + " is matched across the sessions"; end
catch ME
    if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
    obj.Results(end+1, :) = {"sessions: all", id, "figure", "error", string(ME.message), "", toc(t0)};
    obj.log("sessions: %s FAILED: %s", id, ME.message);
    if opts.Report
        obj.addFailureEntry(reportSpec(cfg, id, "all", 1), "error", string(ME.message), "sessions: all", id);   % never throws
    end
    rows = obj.Results(first:end, :);
    return
end
if reason ~= ""
    obj.Results(end+1, :) = {"sessions: all", id, "figure", "skipped", reason, "", toc(t0)};
    obj.log("sessions: %s skipped (%s)", id, reason);
    if opts.Report
        obj.Report = addReportFigure(obj.Report, reportSpec(cfg, id, "all", 1, spec), [], Status="skipped", Message=reason);
    end
    rows = obj.Results(first:end, :);
    return
end

k1 = sessions.index(1);
tokens = struct('OutputFolder', obj.datasetFolder(k1), 'OutputRoot', obj.outputRoot(cfg), 'Root', cfg.Source.Root, ...
    'Name', obj.Names(k1));
folder = figureFileName(X.SessionsFolder, tokens, Kind="folder");
withImages = opts.Report && obj.Report.options.Format ~= "pdf";
withPages = opts.Report && obj.Report.options.Format ~= "html";
withData = X.Data.Enabled;
nObs = height(T);
E = struct('label', {}, 'files', {}, 'images', {}, 'pages', {}, 'done', {}, 'why', {}, 'nError', {}, 'F', {}, 'seconds', {}, 'rows', {}, ...
    'kept', {}, 'nKept', {}, 'nMine', {});   % kept, nKept: the files of the pages kept (Export.Overwrite off) and how many pages; nMine: the pages whose file this run wrote already
usedNames = strings(1, 0);   % the file names written in this run: a sanitized name met again gets "_2", "_3", ...
results = struct('index', {}, 'observation', {}, 'facet', {}, 'group', {}, 'label', {}, 'status', {}, 'message', {}, 'F', {});
perSession = cell(nObs * withData, height(sessions));
lastSessions = sessions;
% "batch" panels: every observation computed and measured first, then drawn at the union of their y extents
BY = [];
pre = {};
if ~isempty(figureBatchPanels(spec)) && ((opts.Export) || withImages || withPages)
    pre = cell(nObs, 4);
    ext = cell(1, 0);
    for i = 1:nObs
        obj.progress(opts.Span(1), sprintf("sessions: %s y range (%d/%d)", id, i, nObs));   % cancel() stops here
        t1 = tic;
        [res, lastSessions, Fs] = computeOne(sources, sessions, spec, T(i, :));
        pre(i, :) = {res, lastSessions, Fs, toc(t1)};
        for e = reshape(res, 1, [])
            if e.status == "done"; ext{end+1} = figureYExtents(e.F, spec); end %#ok<AGROW>
        end
    end
    Bf = figureBatchYLim(ext);
    BY = struct('figure', cell(1, 0), 'id', cell(1, 0), 'lim', cell(1, 0), 'n', cell(1, 0));
    for b = Bf; BY(end+1) = struct('figure', id, 'id', b.id, 'lim', b.lim, 'n', b.n); end %#ok<AGROW>
    obj.BatchYLim = [obj.BatchYLim BY];
end
nShared = NaN;
if ~isempty(BY); nShared = max([BY.n]); end
draws = opts.Export || withImages || withPages;
onPool = draws && obj.usePagePool(nObs);
share = 1 - 0.5 * onPool;   % on the workers the computing is the first half, the drawing the second
jobs = cell(1, 0);   % the pages, drawn or on the workers (submitPage), in order: each with its entry q, row i and F
for i = 1:nObs
    try
        obj.progress(opts.Span(1) + diff(opts.Span) * share * (i - 1) / nObs, sprintf("sessions: %s (%d/%d)", id, i, nObs));   % cancel() stops here
    catch ME
        stoppedRow(obj, id, jobs, folder, t0);   % the pages on the workers canceled; a row with the files the finished ones wrote
        rethrow(ME);
    end
    t1 = tic;
    if ~isempty(pre)   % computed while measuring
        [res, lastSessions, Fs] = pre{i, 1:3};
        pre(i, 1:3) = {[], [], []};
    else
        [res, lastSessions, Fs] = computeOne(sources, sessions, spec, T(i, :));
    end
    if withData; perSession(i, :) = Fs; end
    for e = reshape(res, 1, [])
        q = find(string({E.label}) == e.label, 1);
        if isempty(q)
            E(end+1) = struct('label', e.label, 'files', string.empty(1, 0), 'images', {cell(1, 0)}, 'pages', strings(1, 0), ...
                'done', 0, 'why', strings(1, 0), 'nError', 0, 'F', [], 'seconds', 0, 'rows', zeros(1, 0), ...
                'kept', string.empty(1, 0), 'nKept', 0, 'nMine', 0); %#ok<AGROW>
            q = numel(E);
        end
        if withData
            results(end+1) = struct('index', i, 'observation', string(T.label(i)), 'facet', e.facet, 'group', e.group, ...
                'label', e.label, 'status', e.status, 'message', e.message, 'F', e.F); %#ok<AGROW>
        end
        if e.status ~= "done"
            E(q).why(end+1) = string(T.label(i)) + ": " + e.message;
            E(q).nError = E(q).nError + (e.status == "error");
            continue
        end
        try
            fname = EphysAnalysisRunner.sessionOutputName(X.FilenamePattern, spec, T(i, :), e.facet, e.group, i, nObs);
            [fname, usedNames] = uniqueName(fname, usedNames);   % e.g. cells "A/1" and "A_1" both sanitize to A_1
            base = fullfile(folder, fname);
            want = base + "." + X.Formats;
            mine = opts.Export && obj.writtenByThisRun(want);   % this run wrote a file at that path: never written over, never "kept"
            kept = opts.Export && ~mine && ~X.Overwrite && all(isfile(want));   % its files exist from an earlier run: not written again
            job = struct('future', [], 'out', noPage());
            if (opts.Export && ~kept && ~mine) || withImages || withPages
                page = struct('Export', X, 'Base', "", 'Formats', X.Formats, 'Dpi', X.Dpi, ...
                    'BatchYLim', BY, 'Images', withImages, 'Pages', withPages);   % a kept page: drawn for the report, its files left as they are
                if opts.Export && ~kept && ~mine; page.Base = base; end
                job = obj.submitPage(e.F, spec, onPool, page);
            end
            job.kept = string.empty(1, 0);
            if kept; job.kept = want; end
            job.mine = mine;
            job.q = q;
            job.i = i;
            job.F = keptPart(e.F);   % what the report reads of it (its sessions), not every page's whole result
            jobs{end+1} = job; %#ok<AGROW>
        catch ME
            if ME.identifier == "EphysAnalysisRunner:Canceled"; stoppedRow(obj, id, jobs, folder, t0); rethrow(ME); end
            E(q).why(end+1) = string(T.label(i)) + ": " + string(ME.message);
            E(q).nError = E(q).nError + 1;
        end
    end
    for q = 1:numel(E); E(q).seconds = E(q).seconds + toc(t1) / max(1, numel(res)); end
end
for j = 1:numel(jobs)   % the pages, in order
    job = jobs{j};
    q = job.q;
    t1 = tic;
    try
        out = obj.pageOutput(job, opts.Span(1) + diff(opts.Span) * (0.5 + 0.5 * (j - 1) / numel(jobs)), ...
            sprintf("sessions: %s drawing page %d/%d", id, j, numel(jobs)));
        jobs{j}.out = out;   % taken: should the figure stop after it, stopPages lists its files
        jobs{j}.future = [];
        obj.noteWritten(out.files);
        E(q).files = [E(q).files job.kept out.files];
        if ~isempty(job.kept)
            E(q).kept = [E(q).kept job.kept];
            E(q).nKept = E(q).nKept + 1;
        end
        E(q).nMine = E(q).nMine + job.mine;
        if ~isempty(out.image); E(q).images{end+1} = out.image; end
        if out.page ~= ""; E(q).pages(end+1) = out.page; end
        E(q).done = E(q).done + 1;
        E(q).rows(end+1) = job.i;
        E(q).F = job.F;
    catch ME
        if ME.identifier == "EphysAnalysisRunner:Canceled"; stoppedRow(obj, id, jobs, folder, t0); rethrow(ME); end
        E(q).why(end+1) = string(T.label(job.i)) + ": " + string(ME.message);
        E(q).nError = E(q).nError + 1;
    end
    E(q).seconds = E(q).seconds + toc(t1) * onPool;   % here the drawing was counted with its observation
end

for q = 1:numel(E)
    label = "sessions: " + E(q).label;
    rspec = reportSpec(cfg, id, E(q).label, numel(E), spec);
    if E(q).done == 0
        msg = strjoin(E(q).why, "; ");
        if msg == ""; msg = "no observation was drawn"; end
        status = "skipped";
        if E(q).nError > 0 && E(q).nError == numel(E(q).why); status = "error"; end   % only failures: an error
        obj.Results(end+1, :) = {label, id, "figure", status, msg, "", E(q).seconds};
        obj.log("%s: %s %s (%s)", label, id, status, msg);
        if opts.Report
            obj.addFailureEntry(rspec, status, msg, label, id);   % never throws
        end
        continue
    end
    msg = sprintf("%d observation(s)", E(q).done) + EphysAnalysisRunner.keptText(E(q).nKept) + EphysAnalysisRunner.overlapText(E(q).nMine);
    if ~isempty(E(q).why); msg = msg + "; not drawn: " + strjoin(E(q).why, "; "); end
    if opts.Report
        try
            obj.Report = addReportFigure(obj.Report, rspec, E(q).F, Files=E(q).files, Kept=E(q).kept, Images=E(q).images, Pages=E(q).pages, ...
                Caption=figureCaption(spec, T(E(q).rows, :), Sessions=E(q).F.sessions, YShared=nShared, Results={E(q).F.trial}));   % this figure's observations and its facet's sessions
        catch ME
            % its pages are written: an "error" row that lists them (not the kept ones), and the next label goes on
            written = E(q).files(~ismember(E(q).files, E(q).kept));
            obj.Results(end+1, :) = {label, id, "figure", "error", string(ME.message), strjoin(written, "; "), E(q).seconds};
            obj.log("%s: %s FAILED: %s", label, id, ME.message);
            obj.addFailureEntry(rspec, "error", string(ME.message), label, id);
            continue
        end
    end
    obj.Results(end+1, :) = {label, id, "figure", "done", msg, strjoin(E(q).files, "; "), E(q).seconds};
    obj.KeptFiles = [obj.KeptFiles E(q).kept];   % in Files, not this run's: the lab database's record leaves them out
    obj.log("%s: %s done (%d observation(s), %d file(s), %.1f s)", label, id, E(q).done, numel(E(q).files), E(q).seconds);
end

% --- the session figure's data file (writeAnalysisData) -------------------------------------
if withData && any([E.done] > 0)
    try
        S = struct('schema', "ephys-analysis-session-figure/1", 'figure', id, 'spec', spec, 'sessions', lastSessions, ...
            'observations', T, 'results', results, 'perSession', {perSession}, 'config', cfg.toStruct(), ...
            'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
        S.values = TrialDataExport.resultsTable(results);   % the trial panels' per-trial values of every merged figure, observation first
        dname = figureFileName(X.Data.FilenamePattern, struct('Name', "all", 'Plot', id, 'Kind', "figure", ...
            'Group', "all", 'Unit', "all", 'Index', 1));
        dfile = fullfile(figureFileName(X.Data.Folder, tokens, Kind="folder"), dname + ".mat");
        writeAnalysisData(dfile, S, MatVersion=X.Data.MatVersion, Overwrite=X.Overwrite);
        both = [obj.Results.Files(first) string(dfile)];
        obj.Results.Files(first) = strjoin(both(both ~= ""), "; ");
    catch ME
        if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        obj.Results.Message(first) = strtrim(obj.Results.Message(first) + " data file: " + string(ME.message));
        obj.log("sessions: %s data file FAILED: %s", id, ME.message);
    end
end
rows = obj.Results(first:end, :);
end


function [res, lastSessions, Fs] = computeOne(sources, sessions, spec, row)
%computeOne  One observation across the sessions (figureSessionCompute); a failure is one "error" result.
lastSessions = sessions;
try
    [res, lastSessions, Fs] = figureSessionCompute(sources, sessions, spec, Observation=row);
catch ME
    if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
    res = struct('facet', "all", 'group', "", 'label', "all", 'F', [], 'status', "error", 'message', string(ME.message));
    Fs = cell(1, height(sessions));
end
end


function [name, used] = uniqueName(name, used)
%uniqueName  NAME, or NAME_2, NAME_3, ... when this run already wrote NAME (case-blind, as Windows names files).
base = name;
k = 1;
while any(lower(used) == lower(name))
    k = k + 1;
    name = base + "_" + k;
end
used(end+1) = name;
end


function s = reportSpec(cfg, id, label, nFigures, spec)
%reportSpec  The spec a session figure is listed under in the report: its id (and figure label), kind "figure".
if nargin < 5 || isempty(spec)
    k = cfg.figureIndex(id);
    if k > 0
        s = cfg.Figures(k);
    else
        s = EphysAnalysisConfig.defaults("Figure");
        s.id = id;
    end
else
    s = spec;
end
s.kind = "figure";
s.id = id;
if nFigures > 1; s.id = id + " (" + label + ")"; end
end


function stoppedRow(obj, id, jobs, folder, t0)
%stoppedRow  A session figure canceled part way (EphysAnalysisRunner:Canceled): its pages still on the workers
%   canceled, and a "canceled" row "sessions: all" listing the files its finished pages wrote (stopPages), so the run
%   record and the lab database's record name them; run adds no row of its own for the figure then.
[written, stopped] = obj.stopPages(jobs);
if stopped > 0
    obj.log("sessions: %s: %d page(s) stopped on the workers while drawn: each may have left a file partly written in %s", ...
        id, stopped, folder);
end
obj.Results(end+1, :) = {"sessions: all", id, "figure", "canceled", "canceled", strjoin(written, "; "), toc(t0)};
end


function out = noPage()
%noPage  drawExportPage's OUT for a page not drawn (its files kept).
out = struct('files', string.empty(1, 0), 'image', [], 'page', "", 'title', "");
end


function K = keptPart(F)
%keptPart  What the report reads of a page's figure (addReportFigure, figureCaption Sessions=, Results=): its kind,
%   sessions and, in trial.panels, its trial panels (their statistics for the caption, trialStatsText; a trial
%   panel's values are small). Not in K.panels: addReportFigure's label variables read panels by the spec's order.
K = struct('kind', "figure", 'sessions', [], 'trial', struct('panels', []));
if isfield(F, 'kind'); K.kind = F.kind; end
if isfield(F, 'sessions'); K.sessions = F.sessions; end
if isfield(F, 'panels'); K.trial.panels = F.panels(ismember([F.panels.type], EphysAnalysisConfig.TrialPanelTypes)); end
end
