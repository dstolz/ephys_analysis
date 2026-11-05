function P = computeTrialHistPanel(src, panel, E, G, ctx) %#ok<INUSL> a trial panel is not aligned: E and G are []
%computeTrialHistPanel  A figure's trial histogram panel: a trial measure's distribution per series.
%   P = computeTrialHistPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "trialHist"; CTX from EphysAnalysisRunner.computeFigure) is
%   computeTrialPanel(SRC, PANEL, CTX, "trialHist"):
%   the values per series; the bins (or the ECDF) are drawn, not
%   computed (drawTrialHistPanel).
%   A trial panel is not aligned to events, so E and G are [] and unused;
%   its trials are CTX.selection's (selectTrials). computeTrialPanel
%   lists R's fields.
%
%   See also computeTrialPanel, trialMeasure, trialPanelStats, figurePanelRegistry.

P = computeTrialPanel(src, panel, ctx, "trialHist");
end
