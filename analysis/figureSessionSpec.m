function s = figureSessionSpec(spec)
%figureSessionSpec  A session figure's spec as it is computed and drawn: the sessions' rules on trial groups.
%   S = figureSessionSpec(SPEC) for a figure spec (EphysAnalysisConfig.
%   figureFor) with a sessions block is SPEC with
%     observe.perGroup off (the trial groups follow sessions.trialGroups)
%     trialGroups "pool"     the figure's and every panel's
%                            selection.groupBy cleared, a tuning panel's
%                            seriesParam "" (the sessions are the series)
%     trialGroups "combine"  a PSTH panel's histStyle "line" (sessions x
%                            trial groups are told apart by line style)
%   figureSessionCompute computes each session's figure with it and
%   renderFigure draws a merged figure (F.nSessions) with it, so the
%   runner, the app and the standalone script pass the figure's own spec.
%   It changes nothing a second time (idempotent).
%
%   See also figureSessionCompute, EphysAnalysisConfig.sessionPlotFor.
s = spec;
if ~isfield(spec, 'sessions'); return; end
s.observe.perGroup = false;
tg = spec.sessions.trialGroups;
for k = 1:numel(s.panels)
    p = s.panels(k);
    if tg == "pool"
        if isstruct(p.selection) && isfield(p.selection, 'groupBy'); p.selection.groupBy = string.empty(1, 0); end
        if p.type == "tuning" && isfield(p.options, 'seriesParam'); p.options.seriesParam = ""; end
    end
    if tg == "combine" && p.type == "psth" && isfield(p.options, 'histStyle'); p.options.histStyle = "line"; end
    s.panels(k) = p;
end
if tg == "pool" && isstruct(s.selection) && isfield(s.selection, 'groupBy')
    s.selection.groupBy = string.empty(1, 0);
end
end
