function hk = drawTrialDistPanel(ax, P, look)
%drawTrialDistPanel  Draw a figure's trial distribution panel: a p1 stub, replaced by package p3 (trial-measure drawing).
%   HK = drawTrialDistPanel(AX, P, LOOK) (figurePanelRegistry's draw for
%   "trialDist") draws nothing but the panel's axes, tagged with its id, and
%   the reasons its layers were not computed (figLayerNotes; the p1
%   compute stub skips every layer). Package p3 replaces this stub.
%   HK: figDrawResult's.
%
%   See also figurePanelRegistry, computeTrialDistPanel, renderFigure.

hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);
figLayerNotes(ax, P, look, false);
end
