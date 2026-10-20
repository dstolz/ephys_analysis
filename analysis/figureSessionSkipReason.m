function reason = figureSessionSkipReason(spec, reasons, opts)
%figureSessionSkipReason  Why a session figure cannot be drawn across the sessions ("" = it can).
%   REASON = figureSessionSkipReason(SPEC, REASONS, Labels=L) checks the
%   figure SPEC (EphysAnalysisConfig.figureFor) against REASONS, each
%   session's figureSkipReason for it ("" = that session can draw it;
%   "cannot read ..." for a dataset that cannot be read), and gives the
%   first that applies:
%     "disabled"
%     "not a session figure" (sessions.enabled is false: it is drawn per
%                  dataset)
%     "<type> panels are not merged across sessions" (a panel type in
%                  EphysAnalysisConfig.FigureSessionUnmerged, named as
%                  panelTypeWords names it: "probe map panels ...")
%     "an auROC baseline is not merged across sessions"
%     "no mapping file" / "mapping file not found: F" (a unit observation
%                  with match "mapping")
%     "fewer than N session(s) can draw it (<label>: <reason>; ...)"
%                  N = max(1, sessions.minSessions), the sessions' own
%                  reasons listed with their labels L (default "session <k>")
%   A session figure that passes may still draw nothing when it runs (no
%   unit, site or cell matched across enough sessions).
%
%   See also figureSkipReason, EphysAnalysisRunner.plan,
%   figureSessionCompute.

arguments
    spec (1,1) struct
    reasons (1,:) string = string.empty(1, 0)
    opts.Labels (1,:) string = string.empty(1, 0)
end

reason = "";
ss = spec.sessions;
if ~spec.enabled; reason = "disabled"; return; end
if ~ss.enabled; reason = "not a session figure"; return; end
for k = 1:numel(spec.panels)
    p = spec.panels(k);
    if ismember(p.type, EphysAnalysisConfig.FigureSessionUnmerged)
        reason = panelTypeWords(p.type) + " panels are not merged across sessions";
        return
    end
    o = p.options;
    if isfield(o, 'baseline') && isstruct(o.baseline) && isfield(o.baseline, 'Mode') && o.baseline.Mode == "auroc"
        reason = "an auROC baseline is not merged across sessions";
        return
    end
end
if ss.match == "mapping" && spec.observe.kind == "unit"
    if strtrim(ss.mappingFile) == ""; reason = "no mapping file"; return; end
    if ~isfile(ss.mappingFile); reason = "mapping file not found: " + ss.mappingFile; return; end
end
need = max(1, ss.minSessions);
if nnz(reasons == "") < need
    labels = opts.Labels;
    if numel(labels) ~= numel(reasons); labels = "session " + (1:numel(reasons)); end
    why = labels(reasons ~= "") + ": " + reasons(reasons ~= "");
    reason = sprintf("fewer than %d session(s) can draw it", need);
    if ~isempty(why); reason = reason + " (" + strjoin(why, "; ") + ")"; end
end
end
