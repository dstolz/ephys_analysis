function cfg = gatherSIConfig(obj)
    % Build an EphysDataset SIConfig struct from the Kilosort-tab
    % SpikeInterface preprocessing controls (see EphysDataset.SIConfig).
    cfg = EphysDataset.defaultSIConfig();
    if isempty(obj.SIFilterCheckBox) || ~isvalid(obj.SIFilterCheckBox)
        return   % controls not built yet; return defaults
    end
    cfg.Filter            = logical(obj.SIFilterCheckBox.Value);
    cfg.FilterFreqMin     = obj.SIFilterMinField.Value;
    cfg.FilterFreqMax     = obj.SIFilterMaxField.Value;
    cfg.CommonReference   = logical(obj.SICommonRefCheckBox.Value);
    cfg.ReferenceOperator = string(obj.SIRefOperatorDropDown.Value);
    cfg.DetectBadChannels = logical(obj.SIDetectBadCheckBox.Value);
    cfg.BadChannelMethod  = string(obj.SIBadMethodDropDown.Value);
    cfg.BadChannelAction  = string(obj.SIBadActionDropDown.Value);
end
