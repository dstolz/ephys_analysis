function hk = drawTrialScatterPanel(ax, P, look)
%drawTrialScatterPanel  Draw a figure's trial scatter panel: a p1 stub, replaced by package p3 (trial-measure drawing).
%   HK = drawTrialScatterPanel(AX, P, LOOK) (figurePanelRegistry's draw for
%   "trialScatter") draws nothing but the panel's axes, tagged with its id, and
%   the reasons its layers were not computed (figLayerNotes; the p1
%   compute stub skips every layer). Package p3 replaces this stub.
%   HK: figDrawResult's.
%
%   See also figurePanelRegistry, computeTrialScatterPanel, renderFigure.

hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);
figLayerNotes(ax, P, look, false);
end
