function onArrangeToggled(obj)
%onArrangeToggled  The preview's Arrange button: the panels moved and resized over the preview while it is on.
%   Notes the button's state (FigureArrange: session state, not a
%   preference) and colors the button while on. The overlay over the
%   preview (a move and resize box per panel, snapping, the guides) comes
%   with the next package: until then the status bar says so, and the
%   preview stays as it is. Turned off, any drag or Set corners under way
%   ends (cancelArrange).
%
%   See also EphysFigGenApp.cancelArrange, EphysFigGenApp.onSnapChanged.
b = obj.FigureArrangeButton;
on = ~isempty(b) && isvalid(b) && logical(b.Value);
obj.FigureArrange = on;
if ~isempty(b) && isvalid(b); styleButton(b, ternary(on, "active", "secondary")); end
if on
    obj.setStatus("Arrange: the overlay comes with the next package.");
else
    obj.cancelArrange("");
    obj.FigureArrangeFocus = false;
    obj.setStatus("Arrange off: the preview as usual.");
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
