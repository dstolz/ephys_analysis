function onAnalysisControlsChanged(obj, what)
%onAnalysisControlsChanged  An Analysis-tab control changed.
%   WHAT is "enable", "output" (the figure files / report switches, which
%   the summary describes) or "file" (the analysis config was typed, chosen
%   or reloaded: it is read again). The working config is gathered
%   (onConfigChanged), and while the tab is shown its plan follows.
arguments
    obj (1,1) EphysPipelineApp
    what (1,1) string
end
obj.onConfigChanged();
if ismember(what, ["file" "output"])
    obj.refreshAnalysisSummary();
end
if obj.Tabs.SelectedTab == obj.TabAnalysis
    obj.refreshStepPlan("analysis");
end
end
