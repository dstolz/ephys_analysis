function onSynthControlsChanged(obj)
%onSynthControlsChanged  A Synthetic-tab setting changed: resync, and flag the preview as old.
obj.syncSynthControls();
if ~isempty(obj.SynthModel)
    obj.SynthStatusLabel.Text = "Settings changed since the preview: Preview again to see them (Generate writes the current settings).";
    obj.SynthStatusLabel.FontColor = [0.55 0.35 0.0];
end
end
