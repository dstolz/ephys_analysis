function arrangeWidgetSet(w, rect)
%arrangeWidgetSet  Put an Arrange widget (arrangeWidget) at RECT, 0-1 of the page; nothing when it is there already.
%   A set fires none of the widget's events (only the pointer's drags do).
%
%   See also arrangeWidget.
rect = double(reshape(rect, 1, 4));
if ~isvalid(w) || isequal(w.Position, rect); return; end
w.Position = rect;
end
