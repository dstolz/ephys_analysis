function onSnapChanged(obj)
%onSnapChanged  The Layout section's Snap box or its step: Arrange's snapping and the arrow keys' nudge.
%   Snap (FigureSnap) and the step (FigureSnapStep: its value in the
%   Units shown; held exactly, the box shows it rounded: snapStepIn) are preferences (saved at once: savePreferences), not part of the
%   config: nothing is edited and no undo step is made. A step that is
%   not a number above 0 is refused: the status bar says so and the field
%   shows the step as it was.
%
%   See also EphysFigGenApp.onRectUnitsChanged, snapStepIn.
if obj.Applying; return; end
obj.FigureArrangeFocus = false;   % (an editor control: the arrow keys are its again)
E = obj.FigureEditor;
v = E.snapStep.Value;
u = obj.FigureRectUnits;
if isempty(v) || ~isscalar(v) || ~isfinite(v) || v <= 0
    showPanelPlace(obj);   % the step as it was
    obj.setStatus("The snap step is a number above 0.");
    return
end
obj.FigureSnap = logical(E.snap.Value);
old = obj.FigureSnapStep;
[~, d] = unitsShown([], "", u);
if isstruct(old) && isfield(old, 'value') && isfield(old, 'units') && isscalar(string(old.units)) && string(old.units) == u ...
        && isnumeric(old.value) && isscalar(old.value) && isfinite(old.value) && old.value > 0 ...
        && v == max(round(double(old.value), d), 10^-d)
    % the box shows the step it already holds (the Snap box was ticked, or the step typed as shown): its exact value stays
else
    obj.FigureSnapStep = struct('value', double(v), 'units', u);
end
obj.savePreferences();
word = u;
if u == "normalized"; word = "of the page (0-1)"; end
if obj.FigureSnap
    obj.setStatus(sprintf("Arrange snaps the panels to each other, the page and a step of %g %s; the arrow keys nudge by it.", v, word));
else
    obj.setStatus(sprintf("Arrange does not snap; the arrow keys nudge the selected panel by %g %s.", v, word));
end
end
