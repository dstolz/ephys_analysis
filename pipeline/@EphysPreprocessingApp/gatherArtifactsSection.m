function A = gatherArtifactsSection(obj)
%gatherArtifactsSection  Artifacts section from the Artifacts tab.
A = obj.Config.Artifacts;
A.Enabled     = logical(obj.ArtEnableCheckBox.Value);
A.Method      = string(obj.ArtMethodDropDown.Value);
A.Threshold   = obj.ArtThresholdField.Value;
A.MergeGapMs  = obj.ArtMergeGapField.Value;
A.MinChannels = max(1, round(obj.ArtMinChannelsField.Value));
A.PadMs       = obj.ArtPadField.Value;
winMs = obj.ArtRmsWindowField.Value;
if winMs > 0; A.RmsWindowMs = winMs; else; A.RmsWindowMs = NaN; end
A.Filter       = logical(obj.ArtFilterCheckBox.Value);
A.FilterType   = "highpass";
A.FilterCutoff = max(obj.ArtHighpassField.Value, eps);
A.FilterOrder  = 4;
A.Fill           = string(obj.ArtFillDropDown.Value);
A.ApplyToSorting = logical(obj.ArtApplySortingCheckBox.Value);
A.ApplyToSpikes  = logical(obj.ArtApplySpikesCheckBox.Value);
A.CacheIntervals = logical(obj.ArtCacheCheckBox.Value);
end
