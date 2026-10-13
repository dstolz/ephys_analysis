function [cfg, sp, idx] = sessionPlotContext(obj, sp)
%sessionPlotContext  The config, the session plot and the datasets a Sessions tab command works on.
%   [CFG, SP, IDX] = sessionPlotContext(OBJ, SP) gathers the app's config
%   (the editors' current state, gatherConfig) and resolves SP, an id of
%   CFG.SessionPlots or a session plot struct, to a normalized session
%   plot. IDX are the runner's dataset indices it covers: the ticked
%   datasets for SP.datasets "ticked", the datasets of SP.datasetKeys for
%   "list". SP is [] and the status bar says why when there is nothing to
%   work on (no scanned runner, no such session plot, no dataset).
cfg = [];
idx = [];
if isempty(obj.Runner)
    obj.setStatus("Sessions: scan the datasets first (Data tab).");
    sp = [];
    return
end
cfg = obj.gatherConfig();
if isstring(sp) || ischar(sp)
    k = cfg.sessionPlotIndex(string(sp));
    if k == 0
        obj.setStatus("Sessions: there is no session plot " + string(sp) + ".");
        sp = [];
        return
    end
    sp = cfg.SessionPlots(k);
else
    sp = EphysAnalysisConfig.normalizeSection("SessionPlot", sp);
end
if sp.datasets == "list"
    idx = arrayfun(@(key) obj.Runner.index(key), reshape(sp.datasetKeys, 1, []));
    idx = idx(idx > 0);
else
    idx = obj.tickedDatasetIndices();
end
if isempty(idx)
    obj.setStatus("Sessions: no dataset is ticked to include (Data tab).");
    sp = [];
end
end
