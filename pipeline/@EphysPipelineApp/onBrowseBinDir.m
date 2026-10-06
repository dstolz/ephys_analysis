function onBrowseBinDir(obj)
%onBrowseBinDir  Pick the folder the sorting .bin is written to (Sorting.BinDir).
start = strtrim(obj.SortBinDirField.Value);
if isempty(start) || ~isfolder(start); start = obj.OutputRootField.Value; end
if isempty(start) || ~isfolder(start); start = pwd; end
d = uigetdir(start, "Folder for the sorting .bin files (<folder>/<Name>.bin)");
figure(obj.Fig);
if isequal(d, 0); return; end
obj.SortBinDirField.Value = d;
obj.onConfigChanged();
end
