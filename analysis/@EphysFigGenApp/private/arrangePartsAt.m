function arrangePartsAt(T, box)
%arrangePartsAt  A panel's drawn parts (arrangeParts) moved with its box during a drag: from the box they had to BOX, px.
%   arrangePartsAt(T, BOX) maps each part's Position as the drag started
%   (T.pos) the way the box goes from T.box0 to BOX ([x y width height]
%   px in the canvas): shifted with a move, scaled about the edges that
%   stay with a resize (one affine map of the box; a legend keeps its
%   size, its middle mapped), and places each color bar from its axes
%   again (its Location set anew). Nothing is measured
%   or laid out, so a step of a drag costs a few Position sets; the exact
%   layout comes when the drag is released (arrangedPreview).
%   arrangePartsAt(T, T.box0) puts them back where they were (Escape).
%
%   See also arrangeParts, EphysFigGenApp.onArrangeMoving, EphysFigGenApp.cancelArrange.
if isempty(T) || ~isstruct(T); return; end
b0 = T.box0;
s = box(3:4) ./ max(b0(3:4), eps);
for i = 1:numel(T.h)
    if ~isvalid(T.h(i)); continue; end
    p = T.pos(i, :);
    if isa(T.h(i), 'matlab.graphics.illustration.Legend')   % a legend keeps its size: its middle goes with the box
        c = box(1:2) + (p(1:2) + p(3:4) / 2 - b0(1:2)) .* s;
        q = [c - p(3:4) / 2, p(3:4)];
    else
        q = [box(1:2) + (p(1:2) - b0(1:2)) .* s, max(p(3:4) .* s, 1)];
    end
    if ~isequal(T.h(i).Position, q); T.h(i).Position = q; end
end
for i = 1:numel(T.cb)
    if isvalid(T.cb(i)); T.cb(i).Location = char(T.cbLoc(i)); end
end
end
