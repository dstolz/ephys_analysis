function reason = sessionPlotSkipReason(cfg, sp, reasons, opts)
%sessionPlotSkipReason  Why a session plot cannot be drawn ("" = it can).
%   REASON = sessionPlotSkipReason(CFG, SP, REASONS, Labels=L) checks the
%   session plot SP (an entry of CFG.SessionPlots, or a struct of its
%   fields) against the config CFG and REASONS, each session's
%   plotSkipReason for SP's effective spec ("" = that session can draw it;
%   "cannot read ..." for a dataset that cannot be read), and gives the
%   first that applies:
%     "disabled"
%     "no base plot X"
%     "a <kind> plot is not drawn across sessions" (not in
%                  EphysAnalysisConfig.SessionKinds)
%     "an auROC baseline is not merged across sessions"
%     "no mapping file" / "mapping file not found: F" (match "mapping")
%     "fewer than N session(s) can draw it (<label>: <reason>; ...)"
%                  N = max(1, SP.minSessions), the sessions' own reasons
%                  listed with their labels L (default "session <k>")
%   A session plot that passes may still draw nothing when it runs (no unit
%   or site reaches minSessions, combineSessions:TooFew).
%
%   See also plotSkipReason, EphysAnalysisRunner.plan, combineSessions.

arguments
    cfg (1,1) EphysAnalysisConfig
    sp (1,1) struct
    reasons (1,:) string = string.empty(1, 0)
    opts.Labels (1,:) string = string.empty(1, 0)
end

sp = EphysAnalysisConfig.normalizeSection("SessionPlot", sp);
reason = "";
if ~sp.enabled; reason = "disabled"; return; end
b = cfg.plotIndex(sp.plot);
if b == 0; reason = "no base plot " + sp.plot; return; end
p = cfg.Plots(b);
if ~ismember(p.kind, EphysAnalysisConfig.SessionKinds)
    reason = "a " + p.kind + " plot is not drawn across sessions";
    return
end
if p.baseline.Mode == "auroc"; reason = "an auROC baseline is not merged across sessions"; return; end
if sp.match == "mapping" && ~ismember(p.source, EphysAnalysisConfig.SignalSources) && ~ismember(p.kind, ["heatmap" "waveforms" "behavior"])
    if strtrim(sp.mappingFile) == ""; reason = "no mapping file"; return; end
    if ~isfile(sp.mappingFile); reason = "mapping file not found: " + sp.mappingFile; return; end
end
need = max(1, sp.minSessions);
if nnz(reasons == "") < need
    labels = opts.Labels;
    if numel(labels) ~= numel(reasons); labels = "session " + (1:numel(reasons)); end
    why = labels(reasons ~= "") + ": " + reasons(reasons ~= "");
    reason = sprintf("fewer than %d session(s) can draw it", need);
    if ~isempty(why); reason = reason + " (" + strjoin(why, "; ") + ")"; end
end
end
