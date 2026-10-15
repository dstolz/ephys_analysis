function fig = adoptPanelAlignment(fig, panelId)
%adoptPanelAlignment  Make one panel's alignment the figure's, and every panel follow it.
%   FIG = EphysAnalysisConfig.adoptPanelAlignment(FIG, PANELID), for
%   figure FIG (a Figures entry): when the panel's ref / window / selection
%   are its own (structs), they become the figure's ref / window /
%   selection (a "default" part leaves the figure's as it is); then every
%   panel's ref, window and selection are set to "default", so every panel
%   takes the figure's alignment and trial groups.
%   Error: EphysAnalysisConfig:NoPanel.
%
%   See also EphysAnalysisConfig.adoptPanelOptions, EphysAnalysisConfig.relinkPanels.

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
if isstruct(P.ref); fig.ref = P.ref; end
if isstruct(P.window); fig.window = P.window; end
if isstruct(P.selection); fig.selection = P.selection; end
for j = 1:numel(fig.panels)
    fig.panels(j).ref = "default";
    fig.panels(j).window = "default";
    fig.panels(j).selection = "default";
end
end
