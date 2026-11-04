function arrangeWidgetLock(w, tf)
%arrangeWidgetLock  Lock an Arrange widget (arrangeWidget) while Set corners waits for its clicks (TF true), or free it again.
%   Locked, it can be neither dragged nor resized, and a click on its face
%   is not taken by it (FaceSelectable off), so the overlay under it gets
%   the click; a click on its edge still reaches its ROIClicked, which
%   Set corners also counts (onArrangeClicked).
%
%   See also arrangeWidget, EphysFigGenApp.startCornerMode.
if ~isvalid(w); return; end
allowed = 'all';
if tf; allowed = 'none'; end
if ~strcmp(w.InteractionsAllowed, allowed); w.InteractionsAllowed = allowed; end
if w.FaceSelectable == tf; w.FaceSelectable = ~tf; end
end
