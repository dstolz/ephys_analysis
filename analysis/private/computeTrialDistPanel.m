function P = computeTrialDistPanel(src, panel, E, G, ctx) %#ok<INUSL> a trial panel is not aligned: E and G are []
%computeTrialDistPanel  A figure's trial distribution panel: a trial measure per category and series.
%   P = computeTrialDistPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "trialDist"; CTX from EphysAnalysisRunner.computeFigure) is
%   computeTrialPanel(SRC, PANEL, CTX, "trialDist"):
%   options.categories x options.series, drawn as a swarm, box, violin,
%   points or line (drawTrialDistPanel), with the group tests.
%   A trial panel is not aligned to events, so E and G are [] and unused;
%   its trials are CTX.selection's (selectTrials). computeTrialPanel
%   lists R's fields.
%
%   See also computeTrialPanel, trialMeasure, trialPanelStats, figurePanelRegistry.

P = computeTrialPanel(src, panel, ctx, "trialDist");
end
