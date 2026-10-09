function overlayList(E, items, shown)
%overlayList  Keep the overlays ITEMS in the plot editor's list and pick the K-th (SHOWN).
%   overlayList(E, ITEMS, SHOWN) stores ITEMS (a 1 x n array of
%   defaults("Overlay")) and the index of the overlay whose rows the editor
%   shows in the list's UserData, struct('items', ITEMS, 'shown', SHOWN),
%   and lists them (overlayLabel) with SHOWN picked. SHOWN 0, or beyond
%   the list, picks the first when there is one. It does not fill the
%   rows: overlayShow does. overlayGather reads the rows back into the
%   overlay shown.
lb = E.ovList;
n = numel(items);
if n > 0 && ~(shown >= 1 && shown <= n); shown = 1; end
if n == 0; shown = 0; end
lb.UserData = struct('items', items, 'shown', shown);
if n == 0
    lb.ItemsData = [];
    lb.Items = {};
    return
end
labels = strings(1, n);
for k = 1:n
    labels(k) = overlayLabel(items(k), k);
end
if ~isequal(string(lb.Items), labels) || ~isequal(lb.ItemsData, 1:n)
    lb.ItemsData = [];
    lb.Items = cellstr(labels);
    lb.ItemsData = 1:n;
end
lb.Value = shown;
end
