function onBrowseBehaviorDir(obj)
%onBrowseBehaviorDir  Add a folder to the Epsych2 session search list.
start = obj.RootPathField.Value;
if isempty(start) || ~isfolder(start); start = pwd; end
d = uigetdir(start, "Add a folder holding Epsych2 session .mat files");
figure(obj.Fig);
if isequal(d, 0); return; end
cur = strtrim(string(obj.BehSearchDirsField.Value));
if cur == ""
    obj.BehSearchDirsField.Value = d;
else
    obj.BehSearchDirsField.Value = char(cur + "; " + string(d));
end
obj.onConfigChanged();
end
