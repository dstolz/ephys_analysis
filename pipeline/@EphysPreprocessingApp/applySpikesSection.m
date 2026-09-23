function applySpikesSection(obj, K)
%applySpikesSection  Spikes section -> Spikes tab.
%   Numbers in text fields are written in full (numberText), so gathering
%   them back changes nothing; values the controls cannot show are
%   reported (setControlValue).
K = EphysPipelineConfig.normalizeSection("Spikes", K);
obj.SpkEnableCheckBox.Value = logical(K.Enabled);
obj.setDropIfMember(obj.SpkSourceDropDown, K.Source, "Spikes.Source");
obj.SpkFilterCheckBox.Value = logical(K.Filter);
obj.setControlValue(obj.SpkBandLoField, K.Band(1), "Spikes.Band");
obj.setControlValue(obj.SpkBandHiField, K.Band(2), "Spikes.Band");
obj.setControlValue(obj.SpkFilterOrderField, K.FilterOrder, "Spikes.FilterOrder");
obj.setDropIfMember(obj.SpkPolarityDropDown, K.Polarity, "Spikes.Polarity");
obj.setDropIfMember(obj.SpkThreshMethodDropDown, K.ThresholdMethod, "Spikes.ThresholdMethod");
obj.SpkThresholdField.Value = numText(obj, K.Threshold, "");
obj.SpkMaxAmpField.Value = numText(obj, K.MaxAmplitudeUV, "Inf");
obj.setDropIfMember(obj.SpkAlignDropDown, K.Align, "Spikes.Align");
obj.setControlValue(obj.SpkAlignWindowField, K.AlignWindowMs, "Spikes.AlignWindowMs");
obj.setControlValue(obj.SpkMinPeriodField, K.MinPeriodMs, "Spikes.MinPeriodMs");
obj.SpkWaveformsCheckBox.Value = logical(K.Waveforms);
obj.setControlValue(obj.SpkWinBeforeField, K.WindowMs(1), "Spikes.WindowMs");
obj.setControlValue(obj.SpkWinAfterField, K.WindowMs(2), "Spikes.WindowMs");
obj.setDropIfMember(obj.SpkWaveSourceDropDown, K.WaveformSource, "Spikes.WaveformSource");
obj.setDropIfMember(obj.SpkEdgeDropDown, K.EdgeHandling, "Spikes.EdgeHandling");
obj.setDropIfMember(obj.SpkChannelsDropDown, K.Channels, "Spikes.Channels");
obj.SpkChannelListField.Value = char(K.ChannelList);
obj.SpkRejectArtifactsCheckBox.Value = logical(K.RejectArtifacts);
obj.SpkChunkField.Value = numText(obj, K.MaxChunkSamples, "");
obj.SpkEdgePadField.Value = numText(obj, K.EdgePadMs, "");
obj.SpkGroupsField.Value = char(strjoin(K.Groups, ", "));
obj.SpkIncludeNoiseCheckBox.Value = logical(K.IncludeNoise);
obj.SpkTemplatesCheckBox.Value = logical(K.Templates);
obj.SpkOutputDirField.Value = char(K.OutputDir);
obj.SpkSuffixField.Value = char(K.Suffix);
obj.setDropIfMember(obj.SpkMatVersionDropDown, K.MatVersion, "Spikes.MatVersion");
obj.SpkOverwriteCheckBox.Value = logical(K.Overwrite);
obj.syncSpikesEnableStates();
end


function t = numText(obj, v, whenAuto)
if isempty(v) || isnan(v)
    t = char(whenAuto);
elseif isinf(v)
    t = 'Inf';
else
    t = obj.numberText(v);
end
end
