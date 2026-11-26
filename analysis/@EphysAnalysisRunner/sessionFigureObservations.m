function [T, sessions, sources] = sessionFigureObservations(obj, fig, idx, opts)
%sessionFigureObservations  A session figure's matched observations over the datasets, with their sessions and sources.
%   [T, SESSIONS, SOURCES] = r.sessionFigureObservations(FIG, IDX) for the
%   figure FIG (an id of Config.Figures or a figureFor spec) over the
%   datasets IDX (indices, keys or names; [] = all) -- or, with
%   sessions.datasets "list", over sessions.datasetKeys (keys not found are
%   logged and left out):
%     SESSIONS = r.sessionTable(IDX)               by date, then name
%     SOURCES  = {r.source(k) for each session}    [] where one cannot be read
%     T = figureSessionObservations(SOURCES, SPEC) the preview's picker and
%                                                  what runSessionFigure repeats
%   SESSIONS gains status ("done" | "error") and message for a dataset that
%   cannot be read. Config= (an EphysAnalysisConfig; default [] = Config)
%   is the config the figure id, the sessions' name pattern and the sources
%   are read with (runSessionFigure passes the one its run started with).
%
%   See also figureSessionObservations, EphysAnalysisRunner.computeSessionFigure.

arguments
    obj (1,1) EphysAnalysisRunner
    fig
    idx = []
    opts.Config = []
end

cfg = opts.Config;
if ~isa(cfg, 'EphysAnalysisConfig'); cfg = obj.Config; end
if isstruct(fig)
    spec = fig;
else
    spec = cfg.figureFor(fig);
end
idx = obj.sessionFigureIndices(spec, idx);
sessions = obj.sessionTable(idx, cfg);
n = height(sessions);
sessions.status = repmat("done", n, 1);
sessions.message = strings(n, 1);
sources = cell(1, n);
for j = 1:n
    try
        sources{j} = obj.source(sessions.index(j), cfg);
    catch ME
        sessions.status(j) = "error";
        sessions.message(j) = "cannot read the dataset: " + string(ME.message);
        obj.log("%s: %s cannot be read: %s", spec.id, obj.Names(sessions.index(j)), ME.message);
    end
end
T = figureSessionObservations(sources, spec);
end
