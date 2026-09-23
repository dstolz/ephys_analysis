function onArtifactControlsChanged(obj)
%onArtifactControlsChanged  Sync enable states, then the config and the viewer
%   (what a run removes follows Enable and the two uses; a changed detection
%   setting marks the preview stale). A new Method takes its own default
%   threshold while the Threshold field still holds the previous method's
%   (9 robust SDs mean 9 uV to the microvolt methods, which default to 1500).
method = string(obj.ArtMethodDropDown.Value);
old = obj.Config.Artifacts.Method;
if method ~= old && obj.ArtThresholdField.Value == defaultThreshold(old)
    obj.ArtThresholdField.Value = defaultThreshold(method);
end
obj.ArtRmsWindowField.Enable = matlab.lang.OnOffSwitchState(method == "rms");
obj.ArtHighpassField.Enable  = matlab.lang.OnOffSwitchState(logical(obj.ArtFilterCheckBox.Value) ...
    && obj.Config.Artifacts.FilterType ~= "lowpass");
obj.onConfigChanged();
obj.refreshReferencePanel();
obj.drawArtifactView();
end


function thr = defaultThreshold(method)
%defaultThreshold  The threshold detectArtifacts uses for METHOD when given
%   none (asked of it, so the numbers live in one place).
[~, ~, st] = EphysDataset().detectArtifacts(0, Method=method, Fs=1);
thr = st.threshold;
end
