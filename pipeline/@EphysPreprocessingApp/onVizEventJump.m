function onVizEventJump(obj, direction)
%onVizEventJump  The toolbar's arrows: the chosen event line's next (1) or previous (-1) onset.
%   Steps the Visualize plot to the onset of the line in the toolbar's
%   box (VizEventJumpDropDown), a quarter of the way into the window, the
%   window keeping its width (EphysTraceViewer.jumpToEvent). The status
%   line then says which onset it is (onVizViewChanged); with no onset
%   that way it says so and the view stays.
%
%   See also EphysTraceViewer.jumpToEvent, buildVisualizeTab, applyVizSettings.

v = obj.Viewer;
if isempty(v) || ~isvalid(v) || isempty(obj.VizData); return; end
name = string(obj.VizEventJumpDropDown.Value);
if name == ""; return; end
[t, ~, n] = v.jumpToEvent(name, direction);
if isempty(t)
    if n == 0
        msg = "No " + name + " onsets.";
    elseif direction > 0
        msg = "No later " + name + " onset.";
    else
        msg = "No earlier " + name + " onset.";
    end
    obj.VizStatusLabel.Text = msg;
    obj.VizStatusLabel.FontColor = [0.75 0.4 0];
end
end
