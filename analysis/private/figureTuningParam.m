function [param, series] = figureTuningParam(options, selection, src)
%figureTuningParam  The trial parameters a figure's tuning panel draws: its x parameter and its series.
%   [PARAM, SERIES] = figureTuningParam(OPTIONS, SELECTION, SRC) for a
%   tuning panel's options (param, seriesParam), the figure's trial
%   selection (resolved: groupBy) and the dataset SRC (loadAnalysisSource:
%   trials, paramNames):
%     PARAM   OPTIONS.param when it is set; else the selection's first
%             groupBy parameter; else the first of SRC.paramNames
%             (alphabetical) that is numeric with two or more values; ""
%             when there is none (the panel is skipped: figureSkipReason)
%     SERIES  OPTIONS.seriesParam ("" = one curve)
%   Whether the trials have PARAM and SERIES is figureSkipReason's check.
%
%   See also computeTuningPanel, figureSkipReason, tuningCurve.

param = string(options.param);
series = string(options.seriesParam);
if param ~= ""; return; end
if isstruct(selection) && isfield(selection, 'groupBy') && ~isempty(selection.groupBy)
    g = string(selection.groupBy);
    g = g(g ~= "");
    if ~isempty(g); param = g(1); return; end
end
if ~(isfield(src, 'trials') && istable(src.trials) && height(src.trials) > 0); return; end
names = string.empty(1, 0);
if isfield(src, 'paramNames'); names = reshape(string(src.paramNames), 1, []); end
for p = names
    if p == series || ~ismember(p, string(src.trials.Properties.VariableNames)); continue; end
    v = src.trials.(p);
    if ~(isnumeric(v) || islogical(v)); continue; end
    v = double(v(:));
    if numel(unique(v(isfinite(v)))) >= 2
        param = p;
        return
    end
end
end
