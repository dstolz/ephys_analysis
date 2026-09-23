function A = gatherArtifactsSection(obj)
%gatherArtifactsSection  Artifacts section from the Artifacts tab.
%   FilterType, FilterOrder and a band's upper edge have no control: they
%   keep the working config's values. The High-pass field is a high-pass
%   filter's cutoff, or a band-pass filter's lower edge (a low-pass
%   filter's cutoff is kept too).
A = obj.Config.Artifacts;
A.Reference        = string(obj.ArtRefDropDown.Value);
A.ReferenceBadLow  = obj.ArtRefLowField.Value;
A.ReferenceBadHigh = obj.ArtRefHighField.Value;
A.Enabled     = logical(obj.ArtEnableCheckBox.Value);
A.Method      = string(obj.ArtMethodDropDown.Value);
A.Threshold   = obj.ArtThresholdField.Value;
A.MergeGapMs  = obj.ArtMergeGapField.Value;
A.MinChannels = max(1, round(obj.ArtMinChannelsField.Value));
A.PadMs       = obj.ArtPadField.Value;
winMs = obj.ArtRmsWindowField.Value;
if winMs > 0; A.RmsWindowMs = winMs; else; A.RmsWindowMs = NaN; end
A.Filter       = logical(obj.ArtFilterCheckBox.Value);
if A.FilterType ~= "lowpass"
    A.FilterCutoff(1) = max(obj.ArtHighpassField.Value, eps);
end
A.Fill           = string(obj.ArtFillDropDown.Value);
A.ApplyToSorting = logical(obj.ArtApplySortingCheckBox.Value);
A.ApplyToSpikes  = logical(obj.ArtApplySpikesCheckBox.Value);
A.ApplyToSignals = logical(obj.ArtApplySignalsCheckBox.Value);
A.CacheIntervals = logical(obj.ArtCacheCheckBox.Value);
end
