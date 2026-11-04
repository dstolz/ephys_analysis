function arrangeWidgetSelect(w, tf)
%arrangeWidgetSelect  Draw an Arrange widget (arrangeWidget) as the selected panel's (TF true: blue, a 2 px line) or as any other.
%   The floating legend's (dashed) keeps its gray.
%
%   See also arrangeWidget.
if ~isvalid(w); return; end
legend = isequal(w.StripeColor, [1 1 1]);
if tf
    look = {[0.05 0.45 0.95], 2, 0.08};
elseif legend
    look = {[0.45 0.45 0.45], 1, 0.04};
else
    look = {[0.3 0.3 0.3], 1, 0.04};
end
if ~isequal(w.Color, look{1}); w.Color = look{1}; end
if w.LineWidth ~= look{2}; w.LineWidth = look{2}; end
if w.FaceAlpha ~= look{3}; w.FaceAlpha = look{3}; end
end
