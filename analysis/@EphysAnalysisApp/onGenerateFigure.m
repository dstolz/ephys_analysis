function R = onGenerateFigure(obj, opts)
%onGenerateFigure  Draw the selected figure for every observation it selects, on every ticked dataset, into the Export folder.
%   R = onGenerateFigure(obj) is the Figures tab's Generate button: the
%   figure in the editor (SelectedFigure) alone, run as the Export tab's
%   Run runs (onRunExport: EphysAnalysisRunner.run with Figures=<id>, no
%   session figures, Export on, no report), so the config is
%   validated first, the progress dialog, the Export tab's Cancel and the
%   toolbar's Cancel (onCancelRun) stop it between observations, only one
%   run goes at a time and the previews compute nothing meanwhile. Its
%   files go where a run's go: the Export tab's folder and file names, one
%   file set per observation (figureOutputName). A figure that is off is
%   switched on for this run only (the config keeps it off) and the status
%   bar says so. R is the run's results, which the Export tab's results
%   table shows (Kind "figure"); its Open figure folder comes on as after
%   a run. The status bar then says "Generated <id>: <n> observation(s) on
%   <m> dataset(s), <k> file(s) in <folder>" (and what was skipped, failed
%   or canceled). Datasets= narrows it (indices; the tests use it); by
%   default the ticked datasets.
%   A session figure (sessions.enabled) runs as run(SessionFigures=<id>)
%   instead, no per-dataset figures: one page per matched observation
%   across the datasets, into Export.SessionsFolder (runSessionFigure);
%   the status bar says how many observations each of its figures (facet,
%   trial group) drew, the files, and what was not drawn. With
%   sessions.datasets "list" it runs on the listed datasets, ticked or not.
%
%   See also onRunExport, EphysAnalysisRunner.run, EphysAnalysisRunner.runDataset.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Datasets = []
end
R = table();
if obj.Running
    obj.setStatus("A run is going: generate the figure when it is done.");
    return
end
busy = ["computing" "drawing"];
if ismember(obj.FigurePreviewState, busy)
    obj.setStatus("A preview is computing: generate the figure when it is done (or cancel it).");
    return
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("No figure to generate: pick one in the list, or add one.");
    return
end
cfg = obj.gatherConfig();
id = cfg.Figures(k).id;
wasOff = ~cfg.Figures(k).enabled;
cfg.Figures(k).enabled = true;   % for this run only: obj.Config keeps it as it is
cfg.Export.Enabled = true;       % the figure files are written: validated as such
obj.setStatus("Generating " + id + " ...");
across = cfg.Figures(k).sessions.enabled;   % a session figure: drawn once across the datasets, into the sessions folder
if across && isempty(opts.Datasets) && cfg.Figures(k).sessions.datasets == "list" && ~isempty(obj.Runner)
    % "These datasets": the listed ones, ticked or not (runSessionFigure draws across them whatever the run's datasets)
    listed = arrayfun(@(key) obj.Runner.index(key), reshape(cfg.Figures(k).sessions.datasetKeys, 1, []));
    opts.Datasets = listed(listed > 0);
    if isempty(opts.Datasets)
        obj.setStatus("Generating " + id + ": none of its listed datasets is scanned (Sessions: Pick...).");
        return
    end
end
if across
    R = obj.onRunExport(Figures=string.empty(1, 0), SessionFigures=id, Datasets=opts.Datasets, ...
        Export=true, Report=false, Config=cfg, Title="Generating " + id);
else
    R = obj.onRunExport(Figures=id, SessionFigures=string.empty(1, 0), Datasets=opts.Datasets, ...
        Export=true, Report=false, Config=cfg, Title="Generating " + id);
end
if ~isempty(obj.Runner) && isvalid(obj.Runner)
    obj.Runner.Config = obj.gatherConfig();   % the runner holds the config as the controls show it again
end
if ~istable(R) || height(R) == 0
    return   % not run: onRunExport said why (errors, no dataset ticked, a failure)
end
if across
    obj.setStatus(generatedAcross(obj, R, id, wasOff));
else
    obj.setStatus(generatedText(obj, R, id, wasOff));
end
end


function txt = generatedAcross(~, R, id, wasOff)
%generatedAcross  A session figure's: "Generated <id> across the sessions: <figure>: <n> observation(s), ...; <k> file(s) in <folder>".
%   Each figure it made (a facet, a trial group: a "sessions: <label>"
%   row) is counted on its own.
rows = R(R.Kind == "figure" & R.Plot == id & startsWith(R.Dataset, "sessions: "), :);
done = rows(rows.Status == "done", :);
nFiles = 0;
parts = strings(1, 0);
for i = 1:height(done)
    n = sscanf(char(done.Message(i)), '%d', 1);
    if isempty(n); n = 0; end
    parts(end+1) = extractAfter(done.Dataset(i), "sessions: ") + ": " + n + " observation(s)"; %#ok<AGROW>
    if done.Files(i) ~= ""; nFiles = nFiles + numel(split(done.Files(i), "; ")); end
end
where = "";
if nFiles > 0
    first = split(done.Files(find(done.Files ~= "", 1)), "; ");
    where = " in " + string(fileparts(first(1)));
end
if any(rows.Status == "canceled")
    txt = "Generating " + id + " was canceled";
else
    txt = "Generated " + id + " across the sessions: " + strjoin(parts, ", ") + sprintf("; %d file(s)", nFiles) + where;
end
bad = rows(ismember(rows.Status, ["skipped" "error"]), :);
if height(bad) > 0
    txt = txt + "; not drawn: " + strjoin(bad.Dataset + " (" + bad.Message + ")", ", ");
end
if wasOff
    txt = txt + "; " + id + " is off, so it was switched on for this run only";
end
txt = txt + ".";
end


function txt = generatedText(obj, R, id, wasOff)
%generatedText  "Generated <id>: <n> observation(s) on <m> dataset(s), <k> file(s) in <folder>", and what did not draw.
rows = R(R.Kind == "figure" & R.Plot == id, :);
done = rows(rows.Status == "done", :);
nObs = 0;
nFiles = 0;
folders = strings(1, 0);
cfg = obj.Runner.Config;
for i = 1:height(done)
    n = sscanf(char(done.Message(i)), '%d', 1);   % "<n> observation(s)"
    if ~isempty(n); nObs = nObs + n; end
    if done.Files(i) ~= ""; nFiles = nFiles + numel(split(done.Files(i), "; ")); end
    j = obj.Runner.index(done.Dataset(i));
    if j > 0
        folders(end+1) = figureFileName(cfg.Export.Folder, struct('OutputFolder', obj.Runner.datasetFolder(j), ...
            'OutputRoot', obj.Runner.outputRoot(), 'Root', cfg.Source.Root, 'Name', obj.Runner.Names(j)), Kind="folder"); %#ok<AGROW>
    end
end
folders = unique(folders, 'stable');
where = "";
if isscalar(folders)
    where = " in " + folders;
elseif numel(folders) > 1
    where = sprintf(" in %d folders (the first: %s)", numel(folders), folders(1));
end
body = sprintf("%d observation(s) on %d dataset(s), %d file(s)", nObs, height(done), nFiles) + where;
if any(rows.Status == "canceled")
    txt = "Generating " + id + " was canceled: " + body + " before it stopped";
else
    txt = "Generated " + id + ": " + body;
end
skipped = rows(rows.Status == "skipped", :);
if height(skipped) > 0
    txt = txt + sprintf("; %d dataset(s) skipped (%s)", height(skipped), strjoin(reshape(unique(skipped.Message, 'stable'), 1, []), ", "));
end
nErr = nnz(rows.Status == "error");
if nErr > 0
    txt = txt + sprintf("; %d dataset(s) failed (the Export tab's results say why)", nErr);
end
if wasOff
    txt = txt + "; " + id + " is off, so it was switched on for this run only";
end
txt = txt + ".";
end
