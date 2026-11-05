function painted = paintEditFirst(obj, fig)
%paintEditFirst  Show a structural edit that computes nothing (panels removed or reordered) on the preview at once, before the editor is read back.
%   PAINTED = paintEditFirst(OBJ, FIG) is the first thing Remove panel
%   (onRemovePanel; Arrange's box menu goes there too) and Bring forward /
%   Send back (onPanelOrder) do: FIG is the selected figure as the edit
%   leaves it, made from obj.Config (EphysAnalysisConfig.removePanel,
%   orderPanel: no gatherConfig yet). When the preview shows the selected
%   figure laid out (previewShowsFigure: drawn or out of date; no session
%   or probe figure) its drawing is laid out as FIG's panels say
%   (layoutPreview: renderFigure LayoutOnly, by id: the panels removed go,
%   the rest are stacked in FIG's order at their rects; nothing drawn),
%   the selected panel outlined and the window painted with no callback
%   run (drawnow nocallbacks), whatever the Auto slider says. All of it
%   under Applying (restored after), so no editor callback reads the
%   editor back meanwhile. The edit then goes on as before
%   (commitFigureEdit), which settles the preview (quickFigurePreview) or
%   marks it out of date. PAINTED is true when the preview was laid out
%   so; false, and nothing done, otherwise (no drawing kept, a panel of
%   FIG not in it, a figure with no panel left).
%
%   See also onRemovePanel, onPanelOrder, layoutPreview, commitFigureEdit.
painted = false;
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || isempty(fig.panels); return; end
f0 = obj.Config.Figures(k);
if f0.sessions.enabled || f0.probe.enabled || ~isstruct(obj.FigurePreviewResult) || ~previewShowsFigure(obj); return; end
spec = obj.Config.figureFor(k);
spec.enabled = true;   % (as refreshFigurePreview draws it)
[in, at] = ismember([fig.panels.id], [spec.panels.id]);
if ~all(in); return; end   % a panel the drawing lacks: nothing to lay out
spec.panels = spec.panels(at);
for j = 1:numel(fig.panels); spec.panels(j).rect = fig.panels(j).rect; end
wasApplying = obj.Applying;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, wasApplying)); %#ok<NASGU>
painted = layoutPreview(obj, spec);
if painted; drawnow nocallbacks; end
end


function setApplying(obj, tf)
if isvalid(obj); obj.Applying = tf; end
end
