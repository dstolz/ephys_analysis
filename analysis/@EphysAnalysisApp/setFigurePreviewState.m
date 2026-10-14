function setFigurePreviewState(obj, state, opts)
%setFigurePreviewState  Show where the Figures tab's preview is: its badge, and a card over it while busy.
%   setFigurePreviewState(obj, STATE) is setPreviewState for the figure
%   preview (FigurePreviewPanel, FigurePreviewBadge, FigurePreviewButton;
%   the state in FigurePreviewState; the card's Cancel, FigureCancelButton
%   while it computes, calls onCancelFigurePreview), with the same states:
%     idle       no preview (no figure, no scan, no dataset)
%     computing  computeFigure runs for the observation picked (cancelable)
%     drawing    renderFigure draws it
%     drawn      the preview is the figure as it is now
%     stale      the figure, the defaults or the dataset changed since it
%                was drawn, and it was not redrawn: press Preview
%     waiting    a large signal extract waits for the Preview button
%     skipped    the dataset cannot draw the figure, or has no observation
%     failed     computing or drawing it failed
%     canceled   Cancel stopped the compute
arguments
    obj (1,1) EphysAnalysisApp
    state (1,1) string {mustBeMember(state, ["idle" "computing" "drawing" "drawn" "stale" "waiting" "skipped" "failed" "canceled"])}
    opts.Message (1,1) string = ""
end
tips = struct( ...
    'idle', "Nothing is previewed: add a figure, scan and pick a dataset.", ...
    'computing', "Computing the figure for the observation picked.", ...
    'drawing', "Drawing the computed figure.", ...
    'drawn', "The preview is the figure as it is now, for the observation picked.", ...
    'stale', "The figure changed since this preview was drawn, and it was not redrawn (Auto is off, or the last " + ...
        "preview took " + obj.AutoPreviewSeconds + " s or more): press Preview.", ...
    'waiting', "A layer's signal extract is large, so it is read only when you press Preview.", ...
    'skipped', "The active dataset cannot draw this figure (the line below says why).", ...
    'failed', "The preview failed (the line below and the Log tab say why).", ...
    'canceled', "The preview was canceled before the figure was computed: press Preview.");
P = struct('Panel', obj.FigurePreviewPanel, 'Badge', obj.FigurePreviewBadge, 'StateProp', "FigurePreviewState", ...
    'CancelFcn', @() obj.onCancelFigurePreview(), 'Button', obj.FigurePreviewButton, 'Tips', tips);
showPreviewState(obj, P, state, Message=opts.Message);
obj.FigureCancelButton = matlab.ui.control.Button.empty;
card = findobj(obj.FigurePreviewPanel.Children, "flat", "Tag", "previewBusyCard");
if ~isempty(card) && state == "computing"; obj.FigureCancelButton = card.UserData.Cancel; end
end
