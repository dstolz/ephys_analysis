function refreshVizShading(obj, draw)
%refreshVizShading  Give the viewer the artifact periods to shade (and draw).
%   Orange: the detected artifacts of the Artifacts tab's Detect / Preview
%   of the plotted dataset while its settings still hold, else those the
%   last run detected (<Name>_artifacts.json; vizDetectedIntervals);
%   purple: the plotted dataset's manual periods (artifactColors).
%   Both recording-relative seconds, on the plot's own time axis. None
%   with "Shade artifact periods" unticked. DRAW (default true) redraws.
%
%   See also vizDetectedIntervals, updateVizArtStatus, EphysTraceViewer.

if nargin < 2; draw = true; end
v = obj.Viewer;
if isempty(v) || ~isvalid(v); return; end
det = zeros(0, 2);
man = zeros(0, 2);
d = obj.currentVizDataset();
if ~isempty(d) && logical(obj.VizShadingCheckBox.Value)
    det = obj.vizDetectedIntervals();
    man = d.ManualArtifacts;
end
col = artifactColors();
v.Shading = struct('intervals', {det, man}, 'color', {col.auto, col.manual}, ...
    'alpha', {0.15, 0.2});
if draw && ~isempty(obj.VizData)
    v.render();
end
end
