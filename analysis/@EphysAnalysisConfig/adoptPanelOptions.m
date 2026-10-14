function fig = adoptPanelOptions(fig, panelId)
%adoptPanelOptions  Apply one panel's options to every panel of its figure.
%   FIG = EphysAnalysisConfig.adoptPanelOptions(FIG, PANELID), for figure
%   FIG (a Figures entry):
%   - the panel's values of its type's common fields (commonFieldsOf)
%     become the figure's common options (FIG.common), as the panel draws
%     them: its own values when its common is false; when it is true they
%     are the common values already
%   - every panel's common is set to true, so each takes those values for
%     the common fields its type has
%   - the panel's other option fields (the type-specific ones, e.g. a
%     PSTH's histStyle, fill, normalize, yLim) are copied onto every other
%     panel of the same type; panels of other types keep theirs
%   Error: EphysAnalysisConfig:NoPanel.
%
%   See also EphysAnalysisConfig.relinkPanels, EphysAnalysisConfig.adoptPanelAlignment,
%   EphysAnalysisConfig.commonFieldsOf.

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
cf = EphysAnalysisConfig.commonFieldsOf(P.type);
if ~P.common
    for f = cf
        fig.common.(f) = P.options.(f);
    end
end
own = setdiff(string(fieldnames(P.options)).', cf, 'stable');
for j = 1:numel(fig.panels)
    fig.panels(j).common = true;
    if j == k || fig.panels(j).type ~= P.type; continue; end
    for f = own
        fig.panels(j).options.(f) = P.options.(f);
    end
end
end
