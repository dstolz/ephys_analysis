function [fig, changed] = adoptPanelOptions(fig, panelId)
%adoptPanelOptions  Copy one panel's options and axis sides to the other panels of its figure.
%   FIG = EphysAnalysisConfig.adoptPanelOptions(FIG, PANELID), for figure
%   FIG (a Figures entry):
%   - the panel's values of the options several types share
%     (sharedFieldsOf: bins, measure, baseline, auroc, maskAfterStop and
%     the waveform inset) go to every other panel whose type has them.
%     The baseline (with its auroc settings) goes only where the type
%     takes its Mode: a PSTH or a heat map of spikes none, subtract,
%     zscore, percent or auroc; a rate or tuning panel none, subtract,
%     ratio or zscore; a continuous, unit correlation or signal heat map
%     panel none or subtract (a heat map is of a signal when its first
%     enabled layer reads one). Elsewhere the panel keeps its own
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
%     kept    "baseline" when the panel kept its own because its type
%             does not take the Mode, else empty (a string row)
%   Error: EphysAnalysisConfig:NoPanel.
%
%   See also EphysAnalysisConfig.sharedFieldsOf, EphysAnalysisConfig.relinkPanels,
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
    first = "";
    on = [Q.layers.enabled];
    if any(on); first = Q.layers(find(on, 1)).source; end
    if ismember("baseline", take) && ismember("baseline", EphysAnalysisConfig.sharedFieldsOf(Q.type)) ...
            && ~ismember(P.options.baseline.Mode, EphysAnalysisConfig.baselineModes(Q.type, first))   % (a spectrogram's baseline is chronuxNormalize's: copied as is)
        take = setdiff(take, ["baseline" "auroc"], 'stable');
        kept = "baseline";
    end
    fields = string.empty(1, 0);
    for f = take
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
