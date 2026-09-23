function applyConvertConfig(obj, cfg)
%applyConvertConfig  Push a config Signals section into the Signals tab.
%   Missing fields take the section defaults; a value a control rejects is
%   left at the control's current value and reported (setControlValue).
%
%   See also gatherConvertConfig, EphysPipelineConfig.defaults.

if isempty(obj.ConvLFPCheckBox) || ~isvalid(obj.ConvLFPCheckBox); return; end

cfg = EphysPipelineConfig.normalizeSection("Signals", cfg);
obj.SigEnableCheckBox.Value = logical(cfg.Enabled);
obj.setDropIfMember(obj.ConvExcludeHandlingDropDown, cfg.ExcludeHandling, "Signals.ExcludeHandling");

obj.ConvOutputDirField.Value = char(string(cfg.OutputDir));
obj.ConvSuffixField.Value    = char(string(cfg.Suffix));
obj.setDropIfMember(obj.ConvMatVersionDropDown, cfg.MatVersion, "Signals.MatVersion");
obj.ConvOverwriteCheckBox.Value     = logical(cfg.Overwrite);
obj.ConvSeparateFilesCheckBox.Value = logical(cfg.SeparateFiles);

obj.ConvLFPCheckBox.Value   = logical(cfg.LFP);
obj.ConvMUACheckBox.Value   = logical(cfg.MUA);
obj.ConvSPIKECheckBox.Value = logical(cfg.SPIKE);
obj.ConvAUXCheckBox.Value   = logical(cfg.AUX);
obj.SigBlankArtifactsCheckBox.Value = logical(cfg.BlankArtifacts);

obj.setControlValue(obj.ConvLFPFsField, cfg.LFP_Fs, "Signals.LFP_Fs");
obj.ConvLFPHighpassCheckBox.Value = logical(cfg.LFP_HighpassOn);
obj.setControlValue(obj.ConvLFPHighpassField, cfg.LFP_HighpassHz, "Signals.LFP_HighpassHz");
obj.ConvLFPLowpassCheckBox.Value = logical(cfg.LFP_LowpassOn);
obj.setControlValue(obj.ConvLFPLowpassField, cfg.LFP_LowpassHz, "Signals.LFP_LowpassHz");
obj.ConvLFPNotchCheckBox.Value = logical(cfg.LFP_NotchOn);
obj.ConvLFPNotchField.Value = char(string(cfg.LFP_NotchHz));
obj.setControlValue(obj.ConvLFPNotchBWField, cfg.LFP_NotchBW, "Signals.LFP_NotchBW");
obj.setControlValue(obj.ConvMUAFsField, cfg.MUA_Fs, "Signals.MUA_Fs");
obj.setControlValue(obj.ConvMUAIntegrationField, cfg.MUA_IntegrationHz, "Signals.MUA_IntegrationHz");
if isnumeric(cfg.MUA_bpLoHi) && numel(cfg.MUA_bpLoHi) == 2
    obj.setControlValue(obj.ConvMUALoField, cfg.MUA_bpLoHi(1), "Signals.MUA_bpLoHi");
    obj.setControlValue(obj.ConvMUAHiField, cfg.MUA_bpLoHi(2), "Signals.MUA_bpLoHi");
end

obj.ConvSpikeOrigCheckBox.Value = logical(cfg.SPIKE_KeepOriginal);
obj.setControlValue(obj.ConvSpikeFsField, cfg.SPIKE_Fs, "Signals.SPIKE_Fs");
if isnumeric(cfg.SPIKE_bpLoHi) && numel(cfg.SPIKE_bpLoHi) == 2
    obj.setControlValue(obj.ConvSpikeLoField, cfg.SPIKE_bpLoHi(1), "Signals.SPIKE_bpLoHi");
    obj.setControlValue(obj.ConvSpikeHiField, cfg.SPIKE_bpLoHi(2), "Signals.SPIKE_bpLoHi");
end

obj.setDropIfMember(obj.ConvLabelFieldDropDown, cfg.LabelField, "Signals.LabelField");
obj.fillTrialsLines(EphysPipelineConfig.normalizeSection("Signals", cfg));   % line names + polarity
obj.ConvKeepChannelsField.Value = char(string(cfg.KeepChannels));
obj.setDropIfMember(obj.ConvBadModeDropDown, cfg.BadMode, "Signals.BadMode");
obj.setControlValue(obj.ConvBadThresholdField, cfg.BadThreshold, "Signals.BadThreshold");
obj.ConvBadListField.Value = char(string(cfg.BadList));
obj.ConvRemapField.Value   = char(string(cfg.ChannelRemap));

obj.syncConvertEnableStates();
end
