function overlayShow(E, ov)
%overlayShow  Show overlay OV in the plot editor's overlay rows (overlayRead reads them back).
%   A value a drop-down does not offer stays listed (a colour, an outline)
%   or falls back to the default (a shape, panel, layer or line style),
%   and an opacity or width outside its box's limits is held to them.
combo = ov.shape + "|" + ov.axis;
if ~ismember(combo, string(E.ovKind.ItemsData)); combo = "line|x"; end
E.ovKind.Value = char(combo);
E.ovName.Value = char(ov.name);
E.ovEnabled.Value = ov.enabled;
E.ovValue.Value = numText(ov.value);
E.ovFrom.Value = numText(ov.from);
E.ovTo.Value = numText(ov.to);
E.ovPanel.Value = char(pickFrom(ov.panel, string(E.ovPanel.ItemsData), "all"));
E.ovLayer.Value = char(pickFrom(ov.layer, string(E.ovLayer.ItemsData), "over"));
offerItems(E.ovColor, string(E.ovColor.Items), ov.color);
E.ovAlpha.Value = unit(ov.alpha, 1);
offerItems(E.ovFill, string(E.ovFill.Items), ov.faceColor);
E.ovFillAlpha.Value = unit(ov.faceAlpha, 0.25);
offerItems(E.ovEdge, string(E.ovEdge.Items), ov.edgeColor);
E.ovStyle.Value = char(pickFrom(ov.lineStyle, string(E.ovStyle.ItemsData), "--"));
lim = E.ovWidth.Limits;
w = ov.lineWidth;
if ~isfinite(w); w = 1.5; end
E.ovWidth.Value = min(lim(2), max(lim(1), w));
end


function t = numText(x)
%numText  A position as text, with every digit it has (NaN and Inf as such).
t = char(sprintf('%.10g', x));
end


function v = pickFrom(v, allowed, default)
if ~ismember(v, allowed); v = default; end
end


function a = unit(a, default)
%unit  An opacity held to 0-1 (the default when it is not a number).
if ~isfinite(a); a = default; end
a = min(1, max(0, a));
end
