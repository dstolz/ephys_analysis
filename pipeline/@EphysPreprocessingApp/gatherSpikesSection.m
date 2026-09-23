function K = gatherSpikesSection(obj)
%gatherSpikesSection  Spikes section from the Spikes tab.
K = obj.Config.Spikes;
K.Enabled = logical(obj.SpkEnableCheckBox.Value);
K.Source  = string(obj.SpkSourceDropDown.Value);
K.Filter  = logical(obj.SpkFilterCheckBox.Value);
K.Band    = [obj.SpkBandLoField.Value, obj.SpkBandHiField.Value];
K.FilterOrder = max(1, round(obj.SpkFilterOrderField.Value));
K.Polarity = string(obj.SpkPolarityDropDown.Value);
K.ThresholdMethod = string(obj.SpkThreshMethodDropDown.Value);
K.Threshold = numOrNaN(obj.SpkThresholdField.Value);
K.MaxAmplitudeUV = numOrInf(obj.SpkMaxAmpField.Value);
K.Align = string(obj.SpkAlignDropDown.Value);
K.AlignWindowMs = obj.SpkAlignWindowField.Value;
K.MinPeriodMs = obj.SpkMinPeriodField.Value;
K.Waveforms = logical(obj.SpkWaveformsCheckBox.Value);
K.WindowMs = [obj.SpkWinBeforeField.Value, obj.SpkWinAfterField.Value];
K.WaveformSource = string(obj.SpkWaveSourceDropDown.Value);
K.EdgeHandling = string(obj.SpkEdgeDropDown.Value);
K.Channels = string(obj.SpkChannelsDropDown.Value);
K.ChannelList = string(strtrim(obj.SpkChannelListField.Value));
K.ArtifactMode = string(obj.SpkArtifactModeDropDown.Value);
K.MaxChunkSamples = numOrNaN(obj.SpkChunkField.Value);
K.EdgePadMs = numOrNaN(obj.SpkEdgePadField.Value);
K.Groups = parseList(obj.SpkGroupsField.Value);
K.IncludeNoise = logical(obj.SpkIncludeNoiseCheckBox.Value);
K.Templates = logical(obj.SpkTemplatesCheckBox.Value);
K.OutputDir = string(strtrim(obj.SpkOutputDirField.Value));
K.Suffix = string(strtrim(obj.SpkSuffixField.Value));
K.MatVersion = string(obj.SpkMatVersionDropDown.Value);
K.Overwrite = logical(obj.SpkOverwriteCheckBox.Value);
end


function v = numOrNaN(txt)
t = strtrim(string(txt));
if t == "" || lower(t) == "nan" || lower(t) == "auto"
    v = NaN;
else
    v = str2double(t);
    if isnan(v)
        error('EphysPreprocessingApp:SpikesNumber', '"%s" is not a number.', t);
    end
end
end


function v = numOrInf(txt)
t = strtrim(string(txt));
if t == "" || any(lower(t) == ["inf" "infinity" "none"])
    v = Inf;
else
    v = str2double(t);
    if isnan(v)
        error('EphysPreprocessingApp:SpikesNumber', '"%s" is not a number.', t);
    end
end
end


function s = parseList(txt)
s = strtrim(split(string(txt), [",", ";", " "]));
s = reshape(s(s ~= ""), 1, []);
end
