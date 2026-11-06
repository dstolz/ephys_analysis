function onArrangeToggled(obj)
%onArrangeToggled  The preview's Arrange button: the panels moved and resized over the preview while it is on.
%   Notes the button's state (FigureArrange: session state, not a
%   preference) and colors the button while on. On, the preview of the
%   selected figure gets a box per panel (syncArrangeOverlay): drag a box
%   to move its panel, a handle to resize it, snapping to the other
%   panels, the page and the snap step (Alt held: no snapping), with smart
%   guides (onArrangeMoving, onArrangeMoved); a click on the page gives
%   the arrow keys to the overlay (nudgePanel); a box's right-click menu
%   has Set corners, Bring forward, Send back and Remove panel. The
%   selected panel's outline (markFigurePanel) gives way to its blue box,
%   and data tips and the right-click editors of the plot wait. The line
%   under the preview says how. When the preview does not show the
%   selected figure (not drawn, a probe figure) the status bar says why,
%   and the boxes come once it does.
%   Arrange needs the Image Processing Toolbox (its boxes are
%   images.roi.Rectangle): without a license the button goes back off and
%   the status bar says so.
%   Off, any drag or Set corners under way ends (cancelArrange), a
%   panel a press selected has the editor's rows filled
%   (finishPendingSelect), the boxes are hidden (kept for the next time:
%   syncArrangeOverlay) and the preview is as usual again. When Arrange
%   laid the preview out at places that change its labels (a time stack,
%   the top-left panel: FigureArrangeDirty, arrangedPreview left it out
%   of date), it is drawn again as after any edit -- when Auto's slider
%   and limit allow it (autoFigurePreview: from the runner's cache with
%   no busy card when it holds every step) -- a moment after the toggle
%   (a one-shot timer, FigureSettleTimer, settleArrange), so Arrange off
%   itself paints at once; the status bar says which. Else it stays out
%   of date, the badge and the status bar saying so (Preview draws it).
%   Arrange on again before that timer fires stops it (the redraw is then
%   due at the next Arrange off).
%
%   See also EphysFigGenApp.syncArrangeOverlay, EphysFigGenApp.cancelArrange, EphysFigGenApp.onSnapChanged, settleArrange.
b = obj.FigureArrangeButton;
on = ~isempty(b) && isvalid(b) && logical(b.Value);
noLicense = false;
if on && ~license('test', 'Image_Toolbox')
    b.Value = false;
    on = false;
    noLicense = true;
end
obj.FigureArrange = on;
if ~isempty(b) && isvalid(b); styleButton(b, ternary(on, "active", "secondary")); end
settle = false;
if stopSettleTimer(obj) && on; obj.FigureArrangeDirty = true; end   % (Arrange on again before the redraw after it came: due at the next off)
if ~on
    obj.cancelArrange("");
    finishPendingSelect(obj, "");   % (cancelArrange fills them too: a press that selected a box)
    obj.FigureArrangeFocus = false;
    k = obj.SelectedFigure;
    settle = obj.FigureArrangeDirty && ~noLicense && k >= 1 && k <= numel(obj.Config.Figures) ...
        && ~obj.Config.Figures(k).sessions.enabled && obj.FigurePreviewState == "stale" && previewShowsFigure(obj);   % (a session figure waits for Preview)
    obj.FigureArrangeDirty = false;
end
[shown, why] = obj.syncArrangeOverlay();
obj.markFigurePanel();   % its outline waits while Arrange is on
H = obj.FigurePreviewHint;
if ~isempty(H) && isvalid(H)
    if on
        H.Text = "Arrange: drag a box to move its panel, a handle to resize it (Alt: no snapping); click the page, " + ...
            "then the arrows nudge the selected panel (Shift x10, Ctrl a pixel, Alt resizes); right-click a box for more.";
    else
        H.Text = "Right-click the plot to change colors, fonts and labels.";
    end
end
if noLicense
    obj.setStatus("Arrange needs the Image Processing Toolbox (its move and resize boxes); this MATLAB has no license for it.");
elseif on && shown
    obj.setStatus("Arrange: drag the panels' boxes over the preview; they snap to each other, the page and the step (Alt: free). " + ...
        "Set corners places the selected panel by two clicks.");
elseif on
    obj.setStatus(why);
elseif settle && autoRedrawLimit(obj) > 0
    obj.setStatus("Arrange off: the preview is drawn again at the panels' places when Auto allows it, the labels with it.");
    t = timer('StartDelay', 0.3, 'ExecutionMode', 'singleShot', 'Tag', 'arrangeSettleTimer', ...
        'TimerFcn', @(~, ~) settleArrange(obj), 'StopFcn', @(t, ~) delete(t));
    obj.FigureSettleTimer = t;
    start(t);   % (after the toggle paints: the redraw is Auto's, as after any edit)
elseif settle
    obj.setStatus("Arrange off: the preview is out of date at the panels' new places (Auto is off); press Preview (Ctrl+P) to draw the labels again.");
else
    obj.setStatus("Arrange off: the preview as usual.");
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end


function stopped = stopSettleTimer(obj)
%stopSettleTimer  The redraw after Arrange off not to come (its timer stopped; it deletes itself); STOPPED: one was waiting.
t = obj.FigureSettleTimer;
obj.FigureSettleTimer = [];
stopped = ~isempty(t) && isvalid(t);
if stopped; stop(t); end
end
