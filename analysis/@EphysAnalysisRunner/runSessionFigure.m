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
%         page (newExportFigure + renderFigure) and exported into
%         Export.SessionsFolder (its folder tokens those of the first
%         session's dataset) named figureOutputName(Export.FilenamePattern,
%         <facet>, SPEC, OBS, i, nObs) -- {Name} the facet ("all" or the
%         subject), {Plot} ID, {Unit} "site_ch7", the mapping's cell, "ch7"
%         or "dataset", and "_<group>" for a trial group's figure; a name
%         this run already wrote (two cells that sanitize alike) gets
%         "_2", "_3", ...; with
%         Export.Overwrite off a page whose files all exist is not written
%         again
%   One Results row per figure label (facet / group): Dataset "sessions:
%   <label>", Plot ID, Kind "figure", Status done (a page per observation)
%   | skipped (no observation drew: the reasons) | error, Message "<n>
%   observation(s)", Files. With Report each label is one entry of r.Report
%   (in the section run started, "Across sessions"), its pages the
%   observations', captioned by figureCaption(SPEC, <its observations>,
%   Sessions=<its facet's sessions, as merged>). With
%   Export.Data.Enabled the computed figures are saved (writeAnalysisData:
%   one .mat in Export.Data.Folder named by Data.FilenamePattern with
%   {Name} "all", {Kind} "figure") holding schema, figure, spec, sessions,
%   observations (T), results (a struct per observation and figure: index,
%   observation, facet, group, label, status, message, F) and perSession
%   ({nObs x nSessions}: each dataset's own figure), config and created;
%   the file is added to the first row's Files. A failure is an "error"
%   row; EphysAnalysisRunner:Canceled is rethrown.
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
end

cfg = obj.Config;
X = cfg.Export;
first = height(obj.Results) + 1;
t0 = tic;
try
    spec = cfg.figureFor(id);
    spec.enabled = true;   % asked for: drawn whatever its enabled flag (as figureCompute)
    [T, sessions, sources] = obj.sessionFigureObservations(spec, idx);
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
        obj.Report = addReportFigure(obj.Report, reportSpec(cfg, id, "all", 1), [], Status="error", Message=string(ME.message));
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
tokens = struct('OutputFolder', obj.datasetFolder(k1), 'OutputRoot', obj.outputRoot(), 'Root', cfg.Source.Root, ...
    'Name', obj.Names(k1));
folder = figureFileName(X.SessionsFolder, tokens, Kind="folder");
withImages = opts.Report && obj.Report.options.Format ~= "pdf";
withPages = opts.Report && obj.Report.options.Format ~= "html";
withData = X.Data.Enabled;
nObs = height(T);
E = struct('label', {}, 'files', {}, 'images', {}, 'pages', {}, 'done', {}, 'why', {}, 'nError', {}, 'F', {}, 'seconds', {}, 'rows', {});
usedNames = strings(1, 0);   % the file names written in this run: a sanitized name met again gets "_2", "_3", ...
results = struct('index', {}, 'observation', {}, 'facet', {}, 'group', {}, 'label', {}, 'status', {}, 'message', {}, 'F', {});
perSession = cell(nObs * withData, height(sessions));
lastSessions = sessions;
for i = 1:nObs
    obj.progress(opts.Span(1) + diff(opts.Span) * (i - 1) / nObs, sprintf("sessions: %s (%d/%d)", id, i, nObs));   % cancel() stops here
    t1 = tic;
    try
        [res, lastSessions, Fs] = figureSessionCompute(sources, sessions, spec, Observation=T(i, :));
    catch ME
        if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        res = struct('facet', "all", 'group', "", 'label', "all", 'F', [], 'status', "error", 'message', string(ME.message));
        Fs = cell(1, height(sessions));
    end
    if withData; perSession(i, :) = Fs; end
    for e = reshape(res, 1, [])
        q = find(string({E.label}) == e.label, 1);
        if isempty(q)
            E(end+1) = struct('label', e.label, 'files', string.empty(1, 0), 'images', {cell(1, 0)}, 'pages', strings(1, 0), ...
                'done', 0, 'why', strings(1, 0), 'nError', 0, 'F', [], 'seconds', 0, 'rows', zeros(1, 0)); %#ok<AGROW>
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
            nameObs = struct('kind', T.kind(i), 'label', T.label(i), 'unitId', NaN, 'channel', T.channel(i), 'column', T.column(i), ...
                'meta', table(fileLabel(T(i, :), spec), "", 'VariableNames', {'label', 'class'}), 'groupLabel', e.group);
            fname = figureOutputName(X.FilenamePattern, e.facet, spec, nameObs, i, nObs);
            [fname, usedNames] = uniqueName(fname, usedNames);   % e.g. cells "A/1" and "A_1" both sanitize to A_1
            base = fullfile(folder, fname);
            want = base + "." + X.Formats;
            kept = opts.Export && ~X.Overwrite && all(isfile(want));   % its files exist: not written again
            if kept; E(q).files = [E(q).files want]; end
            if (opts.Export && ~kept) || withImages || withPages
                fig = newExportFigure(X, e.F, spec);
                closer = onCleanup(@() close(fig));   % closes the page on a failure too
                h = renderFigure(e.F, spec, fig);
                written = string.empty(1, 0);
                if opts.Export && ~kept
                    written = exportFigure(fig, base, Format=X.Formats, Dpi=X.Dpi);
                    E(q).files = [E(q).files written];
                end
                if withImages; E(q).images{end+1} = reportImage(fig, obj.Report, Title=h.title, Files=written); end
                if withPages; E(q).pages(end+1) = reportPdfPage(fig, obj.Report, Files=written); end
                clear closer
            end
            E(q).done = E(q).done + 1;
            E(q).rows(end+1) = i;
            E(q).F = e.F;
        catch ME
            clear closer
            if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
            E(q).why(end+1) = string(T.label(i)) + ": " + string(ME.message);
            E(q).nError = E(q).nError + 1;
        end
    end
    for q = 1:numel(E); E(q).seconds = E(q).seconds + toc(t1) / max(1, numel(res)); end
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
            obj.Report = addReportFigure(obj.Report, rspec, [], Status=status, Message=msg);
        end
        continue
    end
    msg = sprintf("%d observation(s)", E(q).done);
    if ~isempty(E(q).why); msg = msg + "; not drawn: " + strjoin(E(q).why, "; "); end
    if opts.Report
        obj.Report = addReportFigure(obj.Report, rspec, E(q).F, Files=E(q).files, Images=E(q).images, Pages=E(q).pages, ...
            Caption=figureCaption(spec, T(E(q).rows, :), Sessions=E(q).F.sessions));   % this figure's observations and its facet's sessions
    end
    obj.Results(end+1, :) = {label, id, "figure", "done", msg, strjoin(E(q).files, "; "), E(q).seconds};
    obj.log("%s: %s done (%d observation(s), %d file(s), %.1f s)", label, id, E(q).done, numel(E(q).files), E(q).seconds);
end

% --- the session figure's data file (writeAnalysisData) -------------------------------------
if withData && any([E.done] > 0)
    try
        S = struct('schema', "ephys-analysis-session-figure/1", 'figure', id, 'spec', spec, 'sessions', lastSessions, ...
            'observations', T, 'results', results, 'perSession', {perSession}, 'config', cfg.toStruct(), ...
            'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
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


function s = fileLabel(row, spec)
%fileLabel  The {Unit} of a session figure's observation: "site_ch7", the mapping's cell, "ch7", "dataset".
switch string(row.kind)
    case "unit"
        if spec.sessions.match == "mapping"
            s = string(row.label);
        else
            s = "site_ch" + row.channel;
        end
    case "channel"
        s = "ch" + row.channel;
        if ~isfinite(row.channel); s = string(row.label); end
    otherwise
        s = "dataset";
end
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
