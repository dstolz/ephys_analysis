function fig = relinkPanels(fig)
%relinkPanels  Link every panel of a figure to the figure's alignment again.
%   FIG = EphysAnalysisConfig.relinkPanels(FIG), for figure FIG (a Figures
%   entry), sets every panel's ref, window and selection to "default" (the
%   figure's event reference, epoch window and trial selection). The
%   panels' options are their own and stay as they are.
%
%   See also EphysAnalysisConfig.adoptPanelOptions, EphysAnalysisConfig.adoptPanelAlignment.

arguments
    fig (1,1) struct
end

for j = 1:numel(fig.panels)
    fig.panels(j).ref = "default";
    fig.panels(j).window = "default";
    fig.panels(j).selection = "default";
end
end
