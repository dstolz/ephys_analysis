function ov = overlayRead(E, ov)
%overlayRead  Overlay OV with the values of the plot editor's overlay rows.
%   A position that is not a number reads as NaN (Validate says so, and
%   the overlay is not drawn); the fields without a row keep their values.
kind = split(string(E.ovKind.Value), "|");
ov.shape = kind(1);
ov.axis = kind(2);
ov.name = strtrim(string(E.ovName.Value));
ov.enabled = logical(E.ovEnabled.Value);
ov.value = number(E.ovValue.Value);
ov.from = number(E.ovFrom.Value);
ov.to = number(E.ovTo.Value);
ov.panel = string(E.ovPanel.Value);
ov.layer = string(E.ovLayer.Value);
ov.color = strtrim(string(E.ovColor.Value));
ov.alpha = E.ovAlpha.Value;
ov.faceColor = strtrim(string(E.ovFill.Value));
ov.faceAlpha = E.ovFillAlpha.Value;
ov.edgeColor = strtrim(string(E.ovEdge.Value));
ov.lineStyle = string(E.ovStyle.Value);
ov.lineWidth = E.ovWidth.Value;
end


function x = number(t)
x = str2double(strtrim(string(t)));
end
