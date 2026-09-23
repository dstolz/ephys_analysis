function applyArtifactsSection(obj, A)
%applyArtifactsSection  Artifacts section -> Artifacts tab.
%   The High-pass field shows a high-pass filter's cutoff, or a band-pass
%   filter's lower edge; for a low-pass filter (a config written by hand or
%   a script: the tab offers none) it is off. Values the controls cannot
%   show are reported (setControlValue).
A = EphysPipelineConfig.normalizeSection("Artifacts", A);
obj.setDropIfMember(obj.ArtRefDropDown, A.Reference, "Artifacts.Reference");
obj.setControlValue(obj.ArtRefLowField, A.ReferenceBadLow, "Artifacts.ReferenceBadLow");
obj.setControlValue(obj.ArtRefHighField, A.ReferenceBadHigh, "Artifacts.ReferenceBadHigh");
obj.ArtEnableCheckBox.Value = logical(A.Enabled);
obj.setDropIfMember(obj.ArtMethodDropDown, A.Method, "Artifacts.Method");
obj.setControlValue(obj.ArtThresholdField, A.Threshold, "Artifacts.Threshold");
obj.setControlValue(obj.ArtMergeGapField, A.MergeGapMs, "Artifacts.MergeGapMs");
obj.setControlValue(obj.ArtMinChannelsField, A.MinChannels, "Artifacts.MinChannels");
obj.setControlValue(obj.ArtPadField, A.PadMs, "Artifacts.PadMs");
if isfinite(A.RmsWindowMs)
    obj.setControlValue(obj.ArtRmsWindowField, A.RmsWindowMs, "Artifacts.RmsWindowMs");
else
    obj.ArtRmsWindowField.Value = 0;
end
obj.ArtFilterCheckBox.Value = logical(A.Filter);
obj.setControlValue(obj.ArtHighpassField, A.FilterCutoff(1), "Artifacts.FilterCutoff");
obj.setDropIfMember(obj.ArtFillDropDown, A.Fill, "Artifacts.Fill");
obj.ArtApplySortingCheckBox.Value = logical(A.ApplyToSorting);
obj.ArtApplySpikesCheckBox.Value  = logical(A.ApplyToSpikes);
obj.ArtApplySignalsCheckBox.Value = logical(A.ApplyToSignals);
obj.ArtCacheCheckBox.Value        = logical(A.CacheIntervals);
obj.ArtRmsWindowField.Enable = matlab.lang.OnOffSwitchState(A.Method == "rms");
obj.ArtHighpassField.Enable  = matlab.lang.OnOffSwitchState(logical(A.Filter) && A.FilterType ~= "lowpass");
obj.refreshReferencePanel();
end
