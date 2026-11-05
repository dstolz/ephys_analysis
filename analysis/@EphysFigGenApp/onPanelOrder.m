function onPanelOrder(obj, step)
%onPanelOrder  Bring the selected panel forward or send it back: its place in the figure's drawing order.
%   onPanelOrder(OBJ, STEP): STEP +1 (the Panels section's Bring forward)
%   draws the selected panel after the next one, over it where the two
%   overlap; -1 (Send back) before the one drawn before it; Inf and -Inf
%   to the front and the back (EphysAnalysisConfig.orderPanel). The panel
%   stays selected (SelectedPanel follows it), no rect changes, and the
%   edit is one undo step, "Reorder panel" (commitFigureEdit). The
%   preview restacks at once (paintEditFirst), before the editor is read
%   back. At either end nothing moves and the status bar says so.
%
%   See also EphysAnalysisConfig.orderPanel, EphysAnalysisConfig.rectOverlaps.
arguments
    obj (1,1) EphysFigGenApp
    step (1,1) double {mustBeNonNan} = 1
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
np = numel(obj.Config.Figures(k).panels);
if j < 1 || j > np; return; end
id = obj.Config.Figures(k).panels(j).id;
if (step > 0 && j == np) || (step < 0 && j == 1)
    obj.setStatus(id + " is drawn " + ternary(step > 0, "last (in front) already.", "first (at the back) already."));
    return
end
paintEditFirst(obj, EphysAnalysisConfig.orderPanel(obj.Config.Figures(k), id, step));   % restacked on the preview at once, before the editor is read back
cfg = obj.gatherConfig();
[fig, q] = EphysAnalysisConfig.orderPanel(cfg.Figures(k), id, step);
cfg.Figures(k) = fig;
obj.SelectedPanel = q;
over = "";
if q > 1 && step > 0; over = " over " + fig.panels(q - 1).id; end
if q < numel(fig.panels) && step < 0; over = " under " + fig.panels(q + 1).id; end
commitFigureEdit(obj, cfg, sprintf("%s is drawn %d of %d%s.", id, q, numel(fig.panels), over), Action="Reorder panel");
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
