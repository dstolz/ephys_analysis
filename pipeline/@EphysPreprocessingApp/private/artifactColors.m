function c = artifactColors()
%artifactColors  The shading colours of the two kinds of artifact period.
%   C.auto is the colour of the detected (automatic) artifacts, orange, and
%   C.manual that of the manual periods, purple. The Artifacts tab's plot
%   and the Visualize tab shade them so; red stays the colour of the
%   samples a run removes (drawArtifactView), clear of both. C.selection,
%   blue, is the stretch selected with Measure on the Artifacts tab's plot
%   (measureArtifactSelection).
%
%   See also drawArtifactView, refreshVizShading.
c = struct('auto', [0.95 0.6 0.1], 'manual', [0.5 0.25 0.85], 'selection', [0.15 0.45 0.9]);
end
