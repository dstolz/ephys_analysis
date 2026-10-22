function [fig, changed] = adoptPanelOptions(fig, panelId)
%adoptPanelOptions  Copy one panel's options and axis sides to the other panels of its figure.
%   FIG = EphysAnalysisConfig.adoptPanelOptions(FIG, PANELID), for figure
%   FIG (a Figures entry):
%   - the panel's values of the options several types share
%     (sharedFieldsOf: bins, measure, baseline, auroc, maskAfterStop,
%     the waveform inset, stack, stackSpacing and yLimMode) go to every
%     other panel whose type has them (yLim, in the type's units, only to
%     the panels of its type: a panel of another type taking "fixed" keeps
%     its own yLim; one with no yLim keeps its own yLimMode instead). The baseline (with its auroc settings)
%     goes only where the type takes its Mode: a PSTH or a heat map of
%     spikes none, subtract, zscore, percent or auroc; a rate or tuning
%     panel none, subtract, ratio or zscore; a continuous, unit
%     correlation or signal heat map panel none or subtract (a heat map
%     is of a signal when its first enabled layer reads one). Elsewhere
%     the panel keeps its own. The stack goes only where the type takes
%     its value (stackModes: "items" is a continuous panel's alone);
%     elsewhere the panel keeps its own stack and stackSpacing
%   - the panel's other options (the type-specific ones, e.g. a PSTH's
%     histStyle, fill, normalize, yLim; a waveforms panel's waveform) go
%     to every other panel of the same type
%   Panels of other types keep their other options.
%   - the panel's axis sides (xSide, ySide: layout, not options) go to
%     every other panel; its label texts (xLabel, yLabel), like its title,
%     stay each panel's own
%
%   [FIG, CHANGED] = ... also says what changed: a struct array, one entry
%   per other panel whose options or sides changed or that kept its
%   baseline, with
%     id      the panel's id
%     fields  the options (and xSide, ySide) whose values changed (a
%             string row)
%     kept    "baseline", "stack" and / or "yLimMode" when the panel
%             kept its own because its type does not take the value (a
%             "fixed" yLimMode: it has no yLim of its own), else empty
%             (a string row)
%   Error: EphysAnalysisConfig:NoPanel.
%
%   Whether a panel takes a value is panelTakes' rule.
%
%   See also EphysAnalysisConfig.sharedFieldsOf, EphysAnalysisConfig.panelTakes, EphysAnalysisConfig.relinkPanels,
%   EphysAnalysisConfig.adoptPanelAlignment.

arguments
    fig (1,1) struct
    panelId (1,1) string
end

k = [];
if ~isempty(fig.panels); k = find([fig.panels.id] == panelId, 1); end
if isempty(k)
    error('EphysAnalysisConfig:NoPanel', 'The figure has no panel "%s".', panelId);
end
P = fig.panels(k);
shared = EphysAnalysisConfig.sharedFieldsOf(P.type);
changed = struct('id', {}, 'fields', {}, 'kept', {});
for j = [1:k-1, k+1:numel(fig.panels)]
    Q = fig.panels(j);
    take = shared(ismember(shared, EphysAnalysisConfig.sharedFieldsOf(Q.type)));
    if Q.type == P.type
        take = string(fieldnames(P.options)).';   % the same type: every option
    end
    kept = string.empty(1, 0);
    fields = string.empty(1, 0);
    for f = take
        [ok, why] = EphysAnalysisConfig.panelTakes(P, Q, f);   % the baseline, stack and Y limits mode its type takes
        if ~ok
            if why ~= "" && ~ismember(why, kept); kept(end+1) = why; end %#ok<AGROW>
            continue
        end
        if ~isequaln(Q.options.(f), P.options.(f))   % (fillAlpha NaN = automatic: equal to NaN)
            Q.options.(f) = P.options.(f);
            fields(end+1) = f; %#ok<AGROW>
        end
    end
    for f = ["xSide" "ySide"]   % the axis sides, every panel's (a stacked PSTH, a y axis each side, keeps its ySide unused)
        if Q.(f) ~= P.(f)
            Q.(f) = P.(f);
            fields(end+1) = f; %#ok<AGROW>
        end
    end
    fig.panels(j) = Q;
    if ~isempty(fields) || ~isempty(kept)
        changed(end+1) = struct('id', Q.id, 'fields', fields, 'kept', kept); %#ok<AGROW>
    end
end
end
