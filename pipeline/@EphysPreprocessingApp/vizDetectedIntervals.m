function [iv, why, source] = vizDetectedIntervals(obj)
%vizDetectedIntervals  The detected artifacts the Visualize plot shades orange.
%   [IV, WHY, SOURCE] = obj.vizDetectedIntervals(): IV [k x 2]
%   (recording-relative seconds) is, when the plot shows the active dataset,
%     SOURCE "preview"  the Artifacts tab's preview (Detect / Preview: the
%                       detector a run uses, over the whole recording)
%                       while the detection settings are still the ones it
%                       ran with: what a run with these settings detects
%     SOURCE "run"      else the automatic detection the last run used,
%                       from <Name>_artifacts.json (loaded with the plot):
%                       what was erased from the processed files shown
%   Otherwise IV is empty, SOURCE "" and WHY says what to do (WHY is also
%   set beside a "run" SOURCE when a preview would say more; "" with the
%   preview). Nothing is detected on the displayed (filtered, referenced,
%   decimated) data.
iv = zeros(0, 2);
source = "";
d = obj.currentVizDataset();
V = obj.ArtView;
if isempty(d) || isempty(obj.currentDataset()) || d ~= obj.currentDataset()
    why = "";   % a plot of another dataset: syncVizDataset says so
    return
elseif ~V.previewed
    why = "Detect / Preview on the Artifacts tab to see detected periods.";
elseif ~isequaln(rmfield(detectionSettings(obj), 'Enabled'), rmfield(V.settings, 'Enabled'))
    why = "The detection settings changed since the last Detect / Preview: preview again on the Artifacts tab to see detected periods.";
else
    iv = V.intervals;
    why = "";
    source = "preview";
    return
end
D = obj.VizData;
if isstruct(D) && isfield(D, 'artifacts') && isstruct(D.artifacts)
    iv = D.artifacts.intervals;
    source = "run";
end
end


function s = detectionSettings(obj)
%detectionSettings  The Artifacts tab's settings in the form the preview records.
s = EphysDataset.normalizeArtifactConfig(EphysPipelineConfig.artifactConfig(obj.gatherArtifactsSection()));
end
