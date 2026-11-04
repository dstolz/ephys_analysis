function onSnapChanged(obj)
%onSnapChanged  The Panels section's Snap box or its step: Arrange's snapping and the arrow keys' nudge.
%   Snap (FigureSnap) and the step (FigureSnapStep: its value in the
%   Units shown) are preferences (saved at once: savePreferences), not part of the
%   config: nothing is edited and no undo step is made. A step that is
%   not a number above 0 is refused: the status bar says so and the field
%   shows the step as it was.
%
%   See also EphysFigGenApp.onRectUnitsChanged, snapStepIn.
if obj.Applying; return; end
E = obj.FigureEditor;
v = E.snapStep.Value;
u = obj.FigureRectUnits;
if isempty(v) || ~isscalar(v) || ~isfinite(v) || v <= 0
    showPanelPlace(obj);   % the step as it was
    obj.setStatus("The snap step is a number above 0.");
    return
end
obj.FigureSnap = logical(E.snap.Value);
obj.FigureSnapStep = struct('value', double(v), 'units', u);
obj.savePreferences();
word = u;
if u == "normalized"; word = "of the page (0-1)"; end
if obj.FigureSnap
    obj.setStatus(sprintf("Arrange snaps the panels to each other, the page and a step of %g %s; the arrow keys nudge by it.", v, word));
else
    obj.setStatus(sprintf("Arrange does not snap; the arrow keys nudge the selected panel by %g %s.", v, word));
end
end
