function onProbeRowSelected(obj, evt)
    % ProbeTable row click -> update the active probe and its info/plot.
    if isempty(evt.Indices); return; end
    obj.SelectedProbeRow = evt.Indices(1);
    obj.onProbeSelected();
end
