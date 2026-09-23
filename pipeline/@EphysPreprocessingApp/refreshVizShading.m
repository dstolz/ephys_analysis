function refreshVizShading(obj, draw)
%refreshVizShading  Give the viewer the artifact periods to shade (and draw).
%   Orange: the detected artifacts of the Artifacts tab's Detect / Preview
%   of the plotted dataset while its settings still hold
%   (vizDetectedIntervals); red: the plotted dataset's manual periods.
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
v.Shading = struct('intervals', {det, man}, 'color', {[0.95 0.6 0.1], [0.85 0.2 0.2]}, ...
    'alpha', {0.15, 0.18});
if draw && ~isempty(obj.VizData)
    v.render();
end
end
