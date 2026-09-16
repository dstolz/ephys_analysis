function applySpikesSection(obj, K)
%applySpikesSection  Spikes section -> Spikes tab.
K = EphysPipelineConfig.normalizeSection("Spikes", K);
obj.SpkEnableCheckBox.Value = logical(K.Enabled);
obj.setDropIfMember(obj.SpkSourceDropDown, K.Source);
obj.SpkFilterCheckBox.Value = logical(K.Filter);
obj.SpkBandLoField.Value = K.Band(1);
obj.SpkBandHiField.Value = K.Band(2);
obj.SpkFilterOrderField.Value = K.FilterOrder;
obj.setDropIfMember(obj.SpkPolarityDropDown, K.Polarity);
obj.setDropIfMember(obj.SpkThreshMethodDropDown, K.ThresholdMethod);
obj.SpkThresholdField.Value = numText(K.Threshold, "");
obj.SpkMaxAmpField.Value = numText(K.MaxAmplitudeUV, "Inf");
obj.setDropIfMember(obj.SpkAlignDropDown, K.Align);
obj.SpkAlignWindowField.Value = K.AlignWindowMs;
obj.SpkMinPeriodField.Value = K.MinPeriodMs;
obj.SpkWaveformsCheckBox.Value = logical(K.Waveforms);
obj.SpkWinBeforeField.Value = K.WindowMs(1);
obj.SpkWinAfterField.Value = K.WindowMs(2);
obj.setDropIfMember(obj.SpkWaveSourceDropDown, K.WaveformSource);
obj.setDropIfMember(obj.SpkEdgeDropDown, K.EdgeHandling);
obj.setDropIfMember(obj.SpkChannelsDropDown, K.Channels);
obj.SpkChannelListField.Value = char(K.ChannelList);
obj.SpkRejectArtifactsCheckBox.Value = logical(K.RejectArtifacts);
obj.SpkChunkField.Value = numText(K.MaxChunkSamples, "");
obj.SpkEdgePadField.Value = numText(K.EdgePadMs, "");
obj.SpkParallelCheckBox.Value = logical(K.UseParallel);
obj.SpkGroupsField.Value = char(strjoin(K.Groups, ", "));
obj.SpkIncludeNoiseCheckBox.Value = logical(K.IncludeNoise);
obj.SpkTemplatesCheckBox.Value = logical(K.Templates);
obj.SpkOutputDirField.Value = char(K.OutputDir);
obj.SpkSuffixField.Value = char(K.Suffix);
obj.setDropIfMember(obj.SpkMatVersionDropDown, K.MatVersion);
obj.SpkOverwriteCheckBox.Value = logical(K.Overwrite);
obj.syncSpikesEnableStates();
end


function t = numText(v, whenAuto)
if isempty(v) || isnan(v)
    t = char(whenAuto);
elseif isinf(v)
    t = 'Inf';
else
    t = char(string(v));
end
end
