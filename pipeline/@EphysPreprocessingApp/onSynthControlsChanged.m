function onSynthControlsChanged(obj, what)
%onSynthControlsChanged  A Synthetic-tab setting changed: resync, and flag the preview as old.
%   WHAT = "schedule" (the rebuilt session's trial duration or lines) also
%   drops the loaded schedule, which was built from them; the next Preview
%   reads it again.
arguments
    obj (1,1) EphysPreprocessingApp
    what (1,1) string = ""
end
if what == "schedule" && obj.SynthSourceDropDown.Value == "session"
    obj.SynthSource = [];
    obj.SynthSourceKey = "";
end
obj.syncSynthControls();
if ~isempty(obj.SynthModel)
    obj.SynthStatusLabel.Text = "Settings changed since the preview: Preview again to see them (Generate writes the current settings).";
    obj.SynthStatusLabel.FontColor = [0.55 0.35 0.0];
end
end
