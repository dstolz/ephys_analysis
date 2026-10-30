function s = gridFit(s, maxW, px)
%gridFit  S, cut short with an ellipsis if it is wider than MAXW.
if gridTextWidth(s, px) <= maxW; return; end
c = char(s);
while ~isempty(c) && gridTextWidth(string(c) + "...", px) > maxW
    c(end) = [];
end
s = string(c) + "...";
end


