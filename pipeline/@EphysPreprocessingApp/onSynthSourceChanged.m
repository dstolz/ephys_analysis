function onSynthSourceChanged(obj)
%onSynthSourceChanged  Timing from changed, or the active dataset did: drop a schedule that no longer applies.
%   The loaded schedule (SynthSource) belongs to one source: the task, or
%   one dataset read one way (SynthSourceKey). When that is no longer what
%   the tab shows, it and the preview are dropped; Load source or Preview
%   reads the new one.
key = obj.synthSourceKey();
if obj.SynthSourceKey ~= key
    had = ~isempty(obj.SynthSource) || ~isempty(obj.SynthModel);
    obj.SynthSource = [];
    obj.SynthSourceKey = "";
    obj.SynthModel = [];
    if had
        obj.renderSynthPreview();
        obj.SynthStatusLabel.Text = "Source changed: Load source or Preview to read it.";
        obj.SynthStatusLabel.FontColor = [0.3 0.3 0.3];
    end
end
obj.syncSynthControls();
end
