function setPreviewState(obj, state, opts)
%setPreviewState  Show where the preview is: the badge under it, and a card over it while busy.
%   setPreviewState(obj, STATE) colors the badge left of the preview's
%   status line and gives it STATE's icon (analysis/icons/status/<STATE>.svg)
%   and word:
%     idle       no preview (no plot, no dataset)
%     computing  computePlot is running (amber spinner)
%     drawing    the result is being drawn (blue spinner)
%     drawn      the preview is the plot as it is now
%     stale      the plot changed since it was drawn, and auto-preview did
%                not redraw it (off, slow, or another tab): press Preview;
%                the Preview button turns orange (primary blue otherwise)
%     waiting    a large signal extract waits for the Preview button
%     skipped    the dataset cannot draw the plot
%     failed     computing or drawing it failed
%     canceled  the Cancel button on the card (onCancelPreview) stopped the
%                compute: press Preview to compute it
%   While computing or drawing, a card in the middle of the preview panel
%   says what (Message=) over the last plot, and the pointer is a watch;
%   while computing the card also has a Cancel button;
%   drawing the new plot clears the panel, the card with it. The spinners
%   are animated SVG, so they turn while MATLAB is busy.
%
%   The Sessions tab's preview has the same badge and card
%   (setSessionPreviewState); both are drawn by private/showPreviewState.
arguments
    obj (1,1) EphysAnalysisApp
    state (1,1) string {mustBeMember(state, ["idle" "computing" "drawing" "drawn" "stale" "waiting" "skipped" "failed" "canceled"])}
    opts.Message (1,1) string = ""
end
P = struct('Panel', obj.PreviewPanel, 'Badge', obj.PreviewBadge, 'StateProp', "PreviewState", ...
    'CancelFcn', @() obj.onCancelPreview(), 'Button', obj.PreviewButton);
showPreviewState(obj, P, state, Message=opts.Message);
end
