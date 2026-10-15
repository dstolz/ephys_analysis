function ls = figSeriesStyle(R, g, ls, L)
%figSeriesStyle  A figure trace's line style when its result is merged across sessions with trial groups combined.
%   LS = figSeriesStyle(R, G, LS, L): R.groups.lineStyle(G) (combineSessions
%   TrialGroups "combine": the sessions told apart by color, the trial
%   groups by line style; groupLineStyles) when R's groups have one and the
%   layer L sets no line style of its own; else LS (figLayerLook's).
%
%   See also figLayerLook, groupLineStyles, figureSessionCompute.
if ~isstruct(R) || ~isfield(R, 'groups') || ~istable(R.groups) || ~ismember("lineStyle", string(R.groups.Properties.VariableNames))
    return
end
if isfield(L, 'lineStyle') && ismember(string(L.lineStyle), ["-" "--" ":" "-."]); return; end
s = groupLineStyles(R);
if g >= 1 && g <= numel(s); ls = s(g); end
end
