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
%   Off, any drag or Set corners under way ends (cancelArrange), the
%   boxes go and the preview is as usual again.
%
%   See also EphysFigGenApp.syncArrangeOverlay, EphysFigGenApp.cancelArrange, EphysFigGenApp.onSnapChanged.
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
if ~on
    obj.cancelArrange("");
    obj.FigureArrangeFocus = false;
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
else
    obj.setStatus("Arrange off: the preview as usual.");
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
