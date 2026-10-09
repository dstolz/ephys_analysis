function items = overlayGather(E)
%overlayGather  The plot's overlays as the editor holds them, the one shown read from its rows.
%   ITEMS = overlayGather(E) takes the overlays kept in the list
%   (overlayList) and replaces the one whose rows are shown by what the
%   rows hold now (overlayRead); the list keeps the result, so picking
%   another overlay loses nothing.
H = E.ovList.UserData;
items = H.items;
k = H.shown;
if k >= 1 && k <= numel(items)
    items(k) = overlayRead(E, items(k));
    H.items = items;
    E.ovList.UserData = H;
end
end
