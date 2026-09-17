function setRunBar(~, bar, frac)
%setRunBar  Show FRAC (0..1) on a Run-tab progress bar (two weighted columns).
if isempty(bar) || ~isvalid(bar); return; end
w = round(1000 * min(max(frac, 0), 1));
if w <= 0
    bar.ColumnWidth = {0, '1x'};
elseif w >= 1000
    bar.ColumnWidth = {'1x', 0};
else
    bar.ColumnWidth = {sprintf('%dx', w), sprintf('%dx', 1000 - w)};
end
end
