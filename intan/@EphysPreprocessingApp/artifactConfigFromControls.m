function cfg = artifactConfigFromControls(obj)
    % Build an ArtifactConfig struct from the tab controls. All timing
    % parameters are in milliseconds; detectArtifacts converts them to
    % samples with each dataset's Fs at run time.
    cfg = EphysDataset.defaultArtifactConfig();
    cfg.Enabled     = logical(obj.ArtEnableCheckBox.Value);
    cfg.Method      = string(obj.ArtMethodDropDown.Value);
    cfg.Threshold   = obj.ArtThresholdField.Value;
    cfg.MergeGapMs  = obj.ArtMergeGapField.Value;
    cfg.MinChannels = max(1, round(obj.ArtMinChannelsField.Value));
    cfg.PadMs       = obj.ArtPadField.Value;
    winMs = obj.ArtRmsWindowField.Value;
    if winMs > 0
        cfg.RmsWindowMs = winMs;
    else
        cfg.RmsWindowMs = NaN;   % auto (~1 ms) resolved at run time
    end
    % Pre-detection filter: part of the config so runs, the preview
    % and the Visualize overlay all detect on the same view.
    cfg.Filter       = logical(obj.ArtFilterCheckBox.Value);
    cfg.FilterType   = "highpass";
    cfg.FilterCutoff = max(obj.ArtHighpassField.Value, eps);
    cfg.FilterOrder  = 4;
end
