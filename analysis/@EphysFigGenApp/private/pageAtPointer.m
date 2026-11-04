function [p, inside] = pageAtPointer(obj)
%pageAtPointer  The window's pointer on the figure's page, 0-1 from its bottom-left corner, and whether it is on the page.
%   [P, INSIDE] = pageAtPointer(OBJ) reads the window's CurrentPoint (px
%   from its bottom-left corner) through the Arrange overlay's box in the
%   window (getpixelposition with the parents' offsets: a classic axes'
%   Position is its plot box), as the pipeline app's artifact view reads
%   its pointer (onArtViewInput). P is clamped to the page; INSIDE is
%   false off the page (2 px of slack) or with no overlay (P is [NaN NaN]).
%
%   See also cornerClick, EphysFigGenApp.startCornerMode.
p = [NaN NaN];
inside = false;
O = obj.FigureArrangeOverlay;
if ~isstruct(O) || isempty(O.axes) || ~isvalid(O.axes); return; end
box = getpixelposition(O.axes, true);
f = (double(obj.Fig.CurrentPoint) - box(1:2)) ./ max(box(3:4), 1);
slack = 2 ./ max(box(3:4), 1);
inside = all(f >= -slack & f <= 1 + slack);
p = min(max(f, 0), 1);
end
