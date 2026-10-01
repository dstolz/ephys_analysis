function refreshArtMarkShading(obj, draw)
%refreshArtMarkShading  Give the Mark manual periods view the periods to shade (and draw).
%   Orange: the detected artifacts of the last Detect / Preview of the
%   active dataset, with the bounds moved by hand
%   (EphysDataset.adjustArtifacts), while the detection settings still are
%   the ones it ran with; red: the shown dataset's manual periods. Both in
%   recording-relative seconds, the viewer's time axis. DRAW (default true)
%   redraws when the view is on screen.
%
%   See also syncArtMark, EphysTraceViewer, refreshVizShading.

if nargin < 2; draw = true; end
v = obj.ArtMarkViewer;
if isempty(v) || ~isvalid(v); return; end
det = zeros(0, 2);
man = zeros(0, 2);
d = obj.ArtMarkDataset;
if ~isempty(d) && isvalid(d)
    man = d.ManualArtifacts;
    V = obj.ArtView;
    active = obj.currentDataset();
    if V.previewed && ~isempty(active) && d == active
        cur = EphysDataset.normalizeArtifactConfig(EphysPipelineConfig.artifactConfig(obj.gatherArtifactsSection()));
        if isequaln(rmfield(cur, 'Enabled'), rmfield(V.settings, 'Enabled'))
            det = d.adjustArtifacts(V.intervals);
        end
    end
end
v.Shading = struct('intervals', {det, man}, 'color', {[0.95 0.6 0.1], [0.85 0.2 0.2]}, ...
    'alpha', {0.15, 0.18});
if draw && obj.artMarkActive()
    v.render();
end
end
