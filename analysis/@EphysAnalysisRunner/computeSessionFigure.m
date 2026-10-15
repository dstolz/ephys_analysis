function [res, sessions, spec, Fs] = computeSessionFigure(obj, fig, idx, opts)
%computeSessionFigure  Compute a session figure for one matched observation across the datasets.
%   [RES, SESSIONS, SPEC, FS] = r.computeSessionFigure(FIG, IDX,
%   Observation=OBS) for the figure FIG (an id of Config.Figures or a
%   figureFor spec) over the datasets IDX (indices, keys or names; [] =
%   all) -- or, with sessions.datasets "list", over sessions.datasetKeys
%   (keys not found are left out) -- is
%     SPEC = Config.figureFor(FIG)
%     [T, SESSIONS, SOURCES] = r.sessionFigureObservations(SPEC, IDX)
%     [RES, SESSIONS, FS] = figureSessionCompute(SOURCES, SESSIONS, SPEC,
%         Observation=OBS (default T(1, :)), Check=CHK)
%   (figureSessionCompute says what RES and FS hold). While PollFcn is set
%   (the app's preview) CHK is the runner's checkpoint: after cancel() the
%   compute stops with EphysAnalysisRunner:Canceled.
%
%   See also figureSessionCompute, EphysAnalysisRunner.sessionFigureObservations,
%   EphysAnalysisRunner.runSessionFigure, EphysAnalysisRunner.computeFigure.

arguments
    obj (1,1) EphysAnalysisRunner
    fig
    idx = []
    opts.Observation = []
end

spec = specOf(obj, fig);
chk = [];
if ~isempty(obj.PollFcn); chk = @() obj.checkpoint(); end
[T, sessions, sources] = obj.sessionFigureObservations(spec, idx);
obs = opts.Observation;
if isempty(obs)
    if height(T) == 0
        error('EphysAnalysisRunner:NoObservation', 'Figure "%s": no %s is matched across the %d session(s).', ...
            spec.id, spec.observe.kind, height(sessions));
    end
    obs = T(1, :);
end
[res, sessions, Fs] = figureSessionCompute(sources, sessions, spec, Observation=obs, Check=chk);
end


function spec = specOf(obj, fig)
if isstruct(fig)
    spec = fig;
else
    spec = obj.Config.figureFor(fig);
end
end
