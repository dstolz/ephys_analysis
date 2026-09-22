function applyArtifactsSection(obj, A)
%applyArtifactsSection  Artifacts section -> Artifacts tab.
A = EphysPipelineConfig.normalizeSection("Artifacts", A);
obj.ArtEnableCheckBox.Value = logical(A.Enabled);
obj.setDropIfMember(obj.ArtMethodDropDown, A.Method);
obj.ArtThresholdField.Value   = A.Threshold;
obj.ArtMergeGapField.Value    = A.MergeGapMs;
obj.ArtMinChannelsField.Value = max(1, A.MinChannels);
obj.ArtPadField.Value         = A.PadMs;
if isfinite(A.RmsWindowMs); obj.ArtRmsWindowField.Value = A.RmsWindowMs; else; obj.ArtRmsWindowField.Value = 0; end
obj.ArtFilterCheckBox.Value = logical(A.Filter);
obj.ArtHighpassField.Value  = A.FilterCutoff(1);
obj.setDropIfMember(obj.ArtFillDropDown, A.Fill);
obj.ArtApplySortingCheckBox.Value = logical(A.ApplyToSorting);
obj.ArtApplySpikesCheckBox.Value  = logical(A.ApplyToSpikes);
obj.ArtCacheCheckBox.Value        = logical(A.CacheIntervals);
obj.ArtRmsWindowField.Enable = matlab.lang.OnOffSwitchState(A.Method == "rms");
obj.ArtHighpassField.Enable  = matlab.lang.OnOffSwitchState(logical(A.Filter));
end
