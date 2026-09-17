function onVizArtToggle(obj, val)
    % Enter/leave artifact-marking mode (drives the left-drag gesture).
    obj.VizArtMode = logical(val);
    if obj.VizArtMode
        obj.VizArtButton.Text = "Mark Artifacts: ON (drag to mark)";
        obj.VizArtButton.FontWeight = "bold";
        if isvalid(obj.Fig); obj.Fig.Pointer = "crosshair"; end
    else
        obj.VizArtButton.Text = "Mark Artifacts: off";
        obj.VizArtButton.FontWeight = "normal";
        if isvalid(obj.Fig); obj.Fig.Pointer = "arrow"; end
    end
end
