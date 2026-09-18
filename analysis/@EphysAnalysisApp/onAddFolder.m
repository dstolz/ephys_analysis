function onAddFolder(obj)
%onAddFolder  Add a dataset output folder to the folder list.
d = uigetdir(pwd, "Choose a dataset's output folder");
figure(obj.Fig);
if isequal(d, 0); return; end
v = string(obj.FoldersArea.Value);
v = v(strtrim(v) ~= "");
obj.FoldersArea.Value = cellstr([v(:); string(d)]);
obj.onConfigChanged("source");
end
