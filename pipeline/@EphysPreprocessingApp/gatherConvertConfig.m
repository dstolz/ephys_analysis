function cfg = gatherConvertConfig(obj)
%gatherConvertConfig  The Signals tab as the config's Signals section.
%   Channel lists are kept as typed text; EphysPipelineConfig.signalOptions
%   parses them (order-preserving) when a run starts.
%
%   See also applyConvertConfig, EphysPipelineConfig.signalOptions.

cfg = obj.Config.Signals;
if isempty(obj.ConvLFPCheckBox) || ~isvalid(obj.ConvLFPCheckBox)
    return   % controls not built yet
end
cfg.Enabled = logical(obj.SigEnableCheckBox.Value);
cfg.ExcludeHandling = string(obj.ConvExcludeHandlingDropDown.Value);

cfg.OutputDir  = strtrim(string(obj.ConvOutputDirField.Value));
cfg.Suffix     = string(obj.ConvSuffixField.Value);
cfg.MatVersion = string(obj.ConvMatVersionDropDown.Value);
cfg.Overwrite  = logical(obj.ConvOverwriteCheckBox.Value);
cfg.SeparateFiles = logical(obj.ConvSeparateFilesCheckBox.Value);

cfg.LFP   = logical(obj.ConvLFPCheckBox.Value);
cfg.MUA   = logical(obj.ConvMUACheckBox.Value);
cfg.SPIKE = logical(obj.ConvSPIKECheckBox.Value);
cfg.AUX   = logical(obj.ConvAUXCheckBox.Value);

cfg.LFP_Fs            = obj.ConvLFPFsField.Value;
cfg.LFP_HighpassOn    = logical(obj.ConvLFPHighpassCheckBox.Value);
cfg.LFP_HighpassHz    = obj.ConvLFPHighpassField.Value;
cfg.LFP_LowpassOn     = logical(obj.ConvLFPLowpassCheckBox.Value);
cfg.LFP_LowpassHz     = obj.ConvLFPLowpassField.Value;
cfg.LFP_NotchOn       = logical(obj.ConvLFPNotchCheckBox.Value);
cfg.LFP_NotchHz       = string(obj.ConvLFPNotchField.Value);
cfg.LFP_NotchBW       = obj.ConvLFPNotchBWField.Value;

cfg.MUA_Fs            = obj.ConvMUAFsField.Value;
cfg.MUA_IntegrationHz = obj.ConvMUAIntegrationField.Value;
cfg.MUA_bpLoHi        = [obj.ConvMUALoField.Value, obj.ConvMUAHiField.Value];

cfg.SPIKE_KeepOriginal = logical(obj.ConvSpikeOrigCheckBox.Value);
cfg.SPIKE_Fs           = obj.ConvSpikeFsField.Value;
cfg.SPIKE_bpLoHi       = [obj.ConvSpikeLoField.Value, obj.ConvSpikeHiField.Value];

cfg.LabelField   = string(obj.ConvLabelFieldDropDown.Value);
% Digital-line polarity is edited in the Trials tab's lines table; inverted
% lines not listed there (another dataset's lines) are kept.
L = obj.TrialsLinesTable.Data;
if istable(L) && height(L) > 0
    shown = string(L.Line);
    cfg.InvertedLines = reshape(unique([setdiff(obj.Config.Signals.InvertedLines, shown, 'stable'), ...
        reshape(shown(logical(L.Inverted)), 1, [])], 'stable'), 1, []);
else
    cfg.InvertedLines = obj.Config.Signals.InvertedLines;
end
cfg.KeepChannels = string(obj.ConvKeepChannelsField.Value);
cfg.BadMode      = string(obj.ConvBadModeDropDown.Value);
cfg.BadThreshold = obj.ConvBadThresholdField.Value;
cfg.BadList      = string(obj.ConvBadListField.Value);
cfg.ChannelRemap = string(obj.ConvRemapField.Value);
end
