function dd = datasetPicker(obj, parent)
%datasetPicker  A tab's Dataset dropdown, bound to the active dataset.
%   Every tab that works on one dataset shows the active dataset in one of
%   these. Choosing in any of them, in the Dataset menu or by clicking a
%   Project-table row makes that dataset active everywhere (selectDataset);
%   populateDatasetPickers fills them after a scan.
dd = uidropdown(parent, "Items", {'(scan first)'}, "Enable", "off", ...
    "Tooltip", "The active dataset: the same choice as the Dataset menu, the highlighted Project-table row and the Dataset box on every other tab.", ...
    "ValueChangedFcn", @(src, ~) picked(obj, src));
obj.DatasetPickers(end + 1) = dd;
end


function picked(obj, src)
if isnumeric(src.Value)
    obj.selectDataset(src.Value);
end
end
