function P = computeTrialScatterPanel(src, panel, E, G, ctx) %#ok<INUSL> a trial panel is not aligned: E and G are []
%computeTrialScatterPanel  A figure's trial scatter panel: one trial measure against another, per trial.
%   P = computeTrialScatterPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "trialScatter"; CTX from EphysAnalysisRunner.computeFigure) is
%   computeTrialPanel(SRC, PANEL, CTX, "trialScatter"):
%   L.measure (y) against L.xMeasure (x), paired by trial, per series,
%   with the fits and correlations (drawTrialScatterPanel).
%   A trial panel is not aligned to events, so E and G are [] and unused;
%   its trials are CTX.selection's (selectTrials). computeTrialPanel
%   lists R's fields.
%
%   See also computeTrialPanel, trialMeasure, trialPanelStats, figurePanelRegistry.

P = computeTrialPanel(src, panel, ctx, "trialScatter");
end
