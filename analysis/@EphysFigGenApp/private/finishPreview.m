function finishPreview(obj, spec, obs, src, drawnKey, dataKey, secsCompute, secs, opts)
%finishPreview  What follows a figure preview drawn: its time kept, what it was drawn from, the badge Drawn or Out of date, and the status line.
%   finishPreview(OBJ, SPEC, OBS, SRC, DRAWNKEY, DATAKEY, SECSCOMPUTE, SECS)
%   is the tail every preview shares -- refreshFigurePreview's figure, its
%   figure across sessions and its probe figure, and quickFigurePreview --
%   once renderFigure drew SPEC for the observation OBS (a figureObservations
%   row) on the dataset SRC in SECS s, SECSCOMPUTE of them computing:
%     - its time in two parts (keepCost: FigurePreviewCost, the data key
%       DATAKEY) and in all (FigurePreviewSeconds), which previewCost
%       predicts the next edit's redraw from; the first figure drawn after
%       the app starts is not counted, since it also loads the graphics
%       (FigurePreviewWarm)
%     - FigurePreviewDrawn = DRAWNKEY (figureViewKey as the preview started)
%     - the badge Drawn when DRAWNKEY is still the key of the figure as it
%       is now (figureViewFresh), else Out of date: what came in while it
%       computed (the runner's polls let callbacks run: Runner.PollFcn) --
%       an edit with Auto on or off, another dataset, observation or page,
%       a scan -- or a Preview press meanwhile (FigurePreviewRedo). An edit
%       undone meanwhile leaves it Drawn.
%     - the status line: "<id>, <observation> on <dataset> (0.4 s);
%       right-click to change colors, lines and fonts", with slowNote's
%       and batchNote's words
%   Timed=false leaves the time kept as it was (FigurePreviewCost and
%   FigurePreviewSeconds): a drawing that kept every panel took next to no
%   time, which says nothing of what the next edit that draws a panel
%   costs; a figure across sessions keeps its own (refreshFigurePreview).
%   Line=TEXT starts the status line instead of "<id>, <observation> on
%   <dataset> (0.4 s)" (a probe figure's tiles, a figure across sessions'
%   merged sessions: OBS and SRC are not read then), and Notes= names the
%   words after "right-click ...": "slow" (slowNote's), "batch"
%   (batchNote's); both by default.
%
%   See also refreshFigurePreview, quickFigurePreview, previewCost, figureViewFresh.
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
    opts.Line (1,1) string = ""
    opts.Notes (1,:) string = ["slow" "batch"]
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
if obj.FigurePreviewRedo || ~figureViewFresh(obj, obj.Config.figureIndex(spec.id))   % (the figure drawn: the selection may have moved meanwhile)
    obj.setFigurePreviewState("stale");
end
txt = opts.Line;
if txt == ""; txt = sprintf("%s, %s on %s (%.1f s)", spec.id, obs.label, src.name, secs); end
txt = txt + "; right-click to change colors, lines and fonts";
if ismember("slow", opts.Notes); txt = txt + slowNote(obj); end
if ismember("batch", opts.Notes); txt = txt + batchNote(spec); end
obj.FigurePreviewLabel.Text = txt;
end
