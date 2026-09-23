function onVizArtToggle(obj, val)
    % Enter/leave artifact-marking mode (drives the left-drag gesture).
    % Marking is refused while a run is under way (refuseWhileRunning).
    if val && obj.refuseWhileRunning("Mark Artifacts")
        obj.VizArtButton.Value = false;
        val = false;
    end
    obj.VizArtMode = logical(val);
    if obj.VizArtMode
        obj.VizArtButton.Text = "Mark Artifacts: ON (drag to mark)";
        styleButton(obj.VizArtButton, "active");
        if isvalid(obj.Fig); obj.Fig.Pointer = "crosshair"; end
    else
        obj.VizArtButton.Text = "Mark Artifacts: off";
        styleButton(obj.VizArtButton);
        if isvalid(obj.Fig); obj.Fig.Pointer = "arrow"; end
    end
end
