function [iv, why] = vizDetectedIntervals(obj)
%vizDetectedIntervals  The detected artifacts the Visualize plot shades orange.
%   [IV, WHY] = obj.vizDetectedIntervals(): IV [k x 2] (recording-relative
%   seconds) is the Artifacts tab's preview (Detect / Preview: the
%   detector a run uses, over the whole recording) when the plot shows the
%   active dataset it was made for and the detection settings are still
%   the ones it ran with. Orange is then what a run with these settings
%   detects. Otherwise IV is empty and WHY says what to do ("" when IV
%   holds the preview). Nothing is detected on the displayed (filtered,
%   referenced, decimated) data.
iv = zeros(0, 2);
d = obj.currentVizDataset();
V = obj.ArtView;
if isempty(d) || isempty(obj.currentDataset()) || d ~= obj.currentDataset()
    why = "";   % a plot of another dataset: syncVizDataset says so
elseif ~V.previewed
    why = "Detect / Preview on the Artifacts tab to see detected periods.";
elseif ~isequaln(rmfield(detectionSettings(obj), 'Enabled'), rmfield(V.settings, 'Enabled'))
    why = "The detection settings changed since the last Detect / Preview: preview again on the Artifacts tab to see detected periods.";
else
    iv = V.intervals;
    why = "";
end
end


function s = detectionSettings(obj)
%detectionSettings  The Artifacts tab's settings in the form the preview records.
s = EphysDataset.normalizeArtifactConfig(EphysPipelineConfig.artifactConfig(obj.gatherArtifactsSection()));
end
