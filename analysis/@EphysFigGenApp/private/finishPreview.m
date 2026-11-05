function finishPreview(obj, spec, obs, src, drawnKey, dataKey, secsCompute, secs, opts)
%finishPreview  What follows a figure preview drawn: its time kept, what it was drawn from, the badge Drawn and the status line.
%   finishPreview(OBJ, SPEC, OBS, SRC, DRAWNKEY, DATAKEY, SECSCOMPUTE, SECS)
%   is the tail refreshFigurePreview's preview and quickFigurePreview share,
%   once renderFigure drew SPEC for the observation OBS (a figureObservations
%   row) on the dataset SRC in SECS s, SECSCOMPUTE of them computing:
%     - its time in two parts (keepCost: FigurePreviewCost, the data key
%       DATAKEY) and in all (FigurePreviewSeconds), which previewCost
%       predicts the next edit's redraw from; the first figure drawn after
%       the app starts is not counted, since it also loads the graphics
%       (FigurePreviewWarm)
%     - FigurePreviewDrawn = DRAWNKEY (figureViewKey: the preview is current)
%     - the badge Drawn, or Out of date when an edit came in meanwhile
%       (FigurePreviewRedo)
%     - the status line: "<id>, <observation> on <dataset> (0.4 s); ...",
%       with slowNote's and batchNote's words
%   Timed=false leaves the time kept as it was (FigurePreviewCost and
%   FigurePreviewSeconds): a drawing that kept every panel took next to no
%   time, which says nothing of what the next edit that draws a panel costs.
%
%   See also refreshFigurePreview, quickFigurePreview, previewCost.
arguments
    obj (1,1) EphysFigGenApp
    spec (1,1) struct
    obs
    src
    drawnKey
    dataKey
    secsCompute (1,1) double
    secs (1,1) double
    opts.Timed (1,1) logical = true
end
if opts.Timed
    keepCost(obj, dataKey, secsCompute, secs - secsCompute);
    obj.FigurePreviewSeconds = secs;
    if ~obj.FigurePreviewWarm   % the first figure drawn also loads the graphics: its time does not stop auto-preview
        obj.FigurePreviewSeconds = 0;
        obj.FigurePreviewCost = struct('compute', 0, 'draw', 0, 'key', {dataKey});   % (nor its parts)
        obj.FigurePreviewWarm = true;
    end
end
obj.FigurePreviewDrawn = drawnKey;
obj.setFigurePreviewState("drawn");
if obj.FigurePreviewRedo; obj.setFigurePreviewState("stale"); end
L = obj.FigurePreviewLabel;
L.Text = sprintf("%s, %s on %s (%.1f s); right-click to change colors, lines and fonts", spec.id, obs.label, src.name, secs);
L.Text = L.Text + slowNote(obj) + batchNote(spec);
end
