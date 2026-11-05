function arrangeWidgetSelect(w, level)
%arrangeWidgetSelect  Draw an Arrange widget (arrangeWidget) as selected or not: LEVEL 2 (or true) the primary (blue, a 2 px line), 1 another selected panel (blue, 1 px), 0 (or false) none.
%   The floating legend's (dashed) keeps its gray.
%
%   See also arrangeWidget, selectedPanelIds.
if ~isvalid(w); return; end
if islogical(level); level = 2 * level; end
legend = isequal(w.StripeColor, [1 1 1]);
if level >= 2
    look = {[0.05 0.45 0.95], 2, 0.08};
elseif level >= 1
    look = {[0.05 0.45 0.95], 1, 0.06};
elseif legend
    look = {[0.45 0.45 0.45], 1, 0.04};
else
    look = {[0.3 0.3 0.3], 1, 0.04};
end
if ~isequal(w.Color, look{1}); w.Color = look{1}; end
if w.LineWidth ~= look{2}; w.LineWidth = look{2}; end
if w.FaceAlpha ~= look{3}; w.FaceAlpha = look{3}; end
end
