function hk = drawTrialHistPanel(ax, P, look)
%drawTrialHistPanel  Draw a figure's trial histogram panel: a p1 stub, replaced by package p3 (trial-measure drawing).
%   HK = drawTrialHistPanel(AX, P, LOOK) (figurePanelRegistry's draw for
%   "trialHist") draws nothing but the panel's axes, tagged with its id, and
%   the reasons its layers were not computed (figLayerNotes; the p1
%   compute stub skips every layer). Package p3 replaces this stub.
%   HK: figDrawResult's.
%
%   See also figurePanelRegistry, computeTrialHistPanel, renderFigure.

hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);
figLayerNotes(ax, P, look, false);
end
