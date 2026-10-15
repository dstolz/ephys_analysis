function idx = sessionFigureIndices(obj, spec, idx)
%sessionFigureIndices  The datasets a session figure is drawn across: IDX, or its listed keys.
%   IDX = r.sessionFigureIndices(SPEC, IDX) for a figure SPEC (figureFor:
%   its sessions block) is, with sessions.datasets "list", the runner's
%   indices of sessions.datasetKeys (keys not found are logged and left
%   out); else IDX as indices (keys or names resolved; [] = every dataset).
%
%   See also EphysAnalysisRunner.sessionFigureObservations, EphysAnalysisRunner.run.

arguments
    obj (1,1) EphysAnalysisRunner
    spec (1,1) struct
    idx = []
end

ss = spec.sessions;
if ss.datasets == "list"
    idx = arrayfun(@(key) obj.index(key), reshape(ss.datasetKeys, 1, []));
    missing = ss.datasetKeys(idx == 0);
    if ~isempty(missing)
        obj.log("%s: dataset key(s) not found: %s", spec.id, strjoin(missing, ", "));
    end
    idx = idx(idx > 0);
elseif isempty(idx)
    idx = 1:numel(obj.Outputs);
elseif ~isnumeric(idx)
    idx = arrayfun(@(k) obj.index(k), reshape(string(idx), 1, []));
    idx = idx(idx > 0);
end
idx = reshape(idx, 1, []);
end
