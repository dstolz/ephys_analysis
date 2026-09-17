function applySIConfig(obj, cfg)
    % Push an SIConfig struct into the preprocessing controls.
    if isempty(obj.SIFilterCheckBox) || ~isvalid(obj.SIFilterCheckBox); return; end
    cfg = EphysDataset.normalizeSIConfig(cfg);
    obj.SIFilterCheckBox.Value    = logical(cfg.Filter);
    obj.SIFilterMinField.Value    = cfg.FilterFreqMin;
    obj.SIFilterMaxField.Value    = cfg.FilterFreqMax;
    obj.SICommonRefCheckBox.Value = logical(cfg.CommonReference);
    obj.setDropIfMember(obj.SIRefOperatorDropDown, cfg.ReferenceOperator);
    obj.SIDetectBadCheckBox.Value = logical(cfg.DetectBadChannels);
    obj.setDropIfMember(obj.SIBadMethodDropDown, cfg.BadChannelMethod);
    obj.setDropIfMember(obj.SIBadActionDropDown, cfg.BadChannelAction);
    obj.syncSIEnableStates();
end
