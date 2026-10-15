function fig = relinkPanels(fig)
%relinkPanels  Link every panel of a figure to the figure again.
%   FIG = EphysAnalysisConfig.relinkPanels(FIG), for figure FIG (a Figures
%   entry), sets every panel's ref, window and selection to "default" (the
%   figure's alignment and trial groups) and its common to true (the
%   figure's common options). The panels' own option values stay stored,
%   unused while linked.
%
%   See also EphysAnalysisConfig.adoptPanelOptions, EphysAnalysisConfig.adoptPanelAlignment.

arguments
    fig (1,1) struct
end

for j = 1:numel(fig.panels)
    fig.panels(j).ref = "default";
    fig.panels(j).window = "default";
    fig.panels(j).selection = "default";
    fig.panels(j).common = true;
end
end
