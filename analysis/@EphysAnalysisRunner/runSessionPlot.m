function rows = runSessionPlot(obj, sp, idx, opts)
%runSessionPlot  Run one session plot: compute, render, export, report.
%   ROWS = r.runSessionPlot(SP, IDX, Export=TF, Report=TF, Span=[a b])
%   computes the session plot SP (an id or a session plot struct) over the
%   datasets IDX (computeSessionPlot) and, for each figure it makes
%   (sessionResults: per facet and trial group), appends a Results row:
%     Dataset  "sessions: <label>" (label "all", the subject, or
%              "<subject> / <group>"; never a dataset's name)
%     Plot     SP.id, Kind the base plot's kind
%     Status   done | skipped (too few sessions or tiles: the message lists
%              each session that could not draw it, and why) | error
%     Files    the figure files written (and the data file, see below)
%   Its pages are drawn exactly as runDataset draws a plot's: one
%   newExportFigure + renderPlot per page, exportFigure into
%   Export.SessionsFolder (its folder tokens those of IDX's first dataset),
%   named plotFileName(Export.FilenamePattern, <facet>, SPEC, R, p, n) --
%   {Name} is the facet ("all" or the subject), {Plot} SP.id -- with
%   "_<group>" appended for a trial group, so the default pattern writes
%   <SessionsFolder>/all_<id>.png; with Export.Overwrite off a page whose
%   files all exist is not written again. With Report each figure goes to
%   r.Report (addReportFigure: into the section run started, "Across
%   sessions"). With Export.Data.Enabled the session plot's data are saved
%   as well (sessionData, handed what was computed here, + writeAnalysisData,
%   one .mat per session plot, in
%   Export.Data.Folder named by Data.FilenamePattern with {Name} "all"),
%   and the file is added to the first row's Files. A failure is an
%   "error" row; EphysAnalysisRunner:Canceled is rethrown.
%
%   See also EphysAnalysisRunner.computeSessionPlot, EphysAnalysisRunner.run,
%   EphysAnalysisRunner.runDataset.
arguments
    obj (1,1) EphysAnalysisRunner
    sp
    idx = []
    opts.Export (1,1) logical = true
    opts.Report (1,1) logical = false
    opts.Span (1,2) double = [0 1]
end
cfg = obj.Config;
X = cfg.Export;
first = height(obj.Results) + 1;
t0 = tic;
if isstring(sp) || ischar(sp)
    k = cfg.sessionPlotIndex(sp);
    if k == 0; error('EphysAnalysisConfig:NoSessionPlot', 'No session plot "%s".', string(sp)); end
    sp = cfg.SessionPlots(k);
end
sp = EphysAnalysisConfig.normalizeSection("SessionPlot", sp);
kind = "";
if cfg.plotIndex(sp.plot) > 0; kind = cfg.Plots(cfg.plotIndex(sp.plot)).kind; end
try
    [res, sessions, spec, Rs] = obj.computeSessionPlot(sp, idx, Span=opts.Span);
catch ME
    if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
    obj.Results(end+1, :) = {"sessions: all", sp.id, kind, "error", string(ME.message), "", toc(t0)};
    obj.log("sessions: %s FAILED: %s", sp.id, ME.message);
    if opts.Report
        obj.Report = addReportFigure(obj.Report, reportSpec(sp, kind, "all", 1), [], Status="error", Message=string(ME.message));
    end
    rows = obj.Results(first:end, :);
    return
end
why = sessions.label(sessions.status ~= "done") + ": " + sessions.message(sessions.status ~= "done");
if isempty(res)
    msg = "no session";
    if ~isempty(why); msg = msg + " (" + strjoin(why, "; ") + ")"; end
    obj.Results(end+1, :) = {"sessions: all", sp.id, spec.kind, "skipped", msg, "", toc(t0)};
    if opts.Report
        obj.Report = addReportFigure(obj.Report, reportSpec(sp, spec.kind, "all", 1, spec), [], Status="skipped", Message=msg);
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
for i = 1:numel(res)
    t1 = tic;
    e = res(i);
    label = "sessions: " + e.label;
    rspec = reportSpec(sp, spec.kind, e.label, numel(res), spec);
    if e.status ~= "done"
        msg = e.message;
        if ~isempty(why); msg = msg + " (" + strjoin(why, "; ") + ")"; end
        obj.Results(end+1, :) = {label, sp.id, spec.kind, e.status, msg, "", toc(t1)};
        obj.log("%s: %s %s (%s)", label, sp.id, e.status, msg);
        if opts.Report
            obj.Report = addReportFigure(obj.Report, rspec, [], Status=e.status, Message=msg);
        end
        continue
    end
    R = e.R;
    try
        files = string.empty(1, 0);
        images = cell(1, 0);
        pages = strings(1, 0);
        if opts.Export
            n = plotPageCount(R, spec);
            if withImages; images = cell(1, n); end
            if withPages; pages = strings(1, n); end
            for p = 1:n
                name = plotFileName(X.FilenamePattern, e.facet, spec, R, p, n);
                if e.group ~= ""; name = name + "_" + regexprep(e.group, '[^\w\-\.]', '_'); end
                base = fullfile(folder, name);
                want = base + "." + X.Formats;
                kept = ~X.Overwrite && all(isfile(want));   % its files exist: not written again
                if kept; files = [files want]; end %#ok<AGROW>
                if kept && ~withImages && ~withPages; continue; end
                fig = newExportFigure(X, R, spec, Page=p);
                closer = onCleanup(@() close(fig));   % closes the page on a failure too
                h = renderPlot(R, spec, fig, Page=p);
                written = string.empty(1, 0);
                if ~kept
                    written = exportFigure(fig, base, Format=X.Formats, Dpi=X.Dpi);
                    files = [files written]; %#ok<AGROW>
                end
                if withImages; images{p} = reportImage(fig, obj.Report, Title=h.title, Files=written); end
                if withPages; pages(p) = reportPdfPage(fig, obj.Report, Files=written); end
                clear closer
            end
        end
        if opts.Report
            obj.Report = addReportFigure(obj.Report, rspec, R, Files=files, Images=images, Pages=pages);
        end
        obj.Results(end+1, :) = {label, sp.id, spec.kind, "done", "", strjoin(files, "; "), toc(t1)};
        obj.log("%s: %s done (%d file(s), %.1f s)", label, sp.id, numel(files), toc(t1));
    catch ME
        clear closer
        if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        obj.Results(end+1, :) = {label, sp.id, spec.kind, "error", string(ME.message), "", toc(t1)};
        obj.log("%s: %s FAILED: %s", label, sp.id, ME.message);
        if opts.Report
            obj.Report = addReportFigure(obj.Report, rspec, [], Status="error", Message=string(ME.message));
        end
    end
end

% --- the session plot's data file (sessionData + writeAnalysisData) ----------------------
% Runs only with Export.Data.Enabled; a failure goes into the first row's message
% without stopping the run.
if X.Data.Enabled && any([res.status] == "done")
    try
        S = obj.sessionData(sp, idx, Results=res, Sessions=sessions, Spec=spec, Rs=Rs);   % nothing computed again
        dname = figureFileName(X.Data.FilenamePattern, struct('Name', "all", 'Plot', sp.id, 'Kind', spec.kind, ...
            'Group', "all", 'Unit', "all", 'Index', 1));
        dfile = fullfile(figureFileName(X.Data.Folder, tokens, Kind="folder"), dname + ".mat");
        writeAnalysisData(dfile, S, MatVersion=X.Data.MatVersion, Overwrite=X.Overwrite);
        both = [obj.Results.Files(first) string(dfile)];
        obj.Results.Files(first) = strjoin(both(both ~= ""), "; ");
    catch ME
        if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        obj.Results.Message(first) = strtrim(obj.Results.Message(first) + " data file: " + string(ME.message));
        obj.log("sessions: %s data file FAILED: %s", sp.id, ME.message);
    end
end
rows = obj.Results(first:end, :);
end


function s = reportSpec(sp, kind, label, nFigures, spec)
%reportSpec  The spec a session figure is listed under in the report: the session plot's id (and figure label).
if nargin < 5 || isempty(spec)
    s = EphysAnalysisConfig.normalizePlot(struct('kind', kind));
else
    s = spec;
end
if s.kind == ""; s.kind = kind; end
s.id = sp.id;
if nFigures > 1; s.id = sp.id + " (" + label + ")"; end
end
