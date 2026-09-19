function onOpenExportFolder(obj)
%onOpenExportFolder  Open the first dataset's figure folder of the last run.
d = obj.LastExportFolder;
if d == "" || ~isfolder(d); return; end
if ispc
    winopen(d);
else
    web("file:///" + d, '-browser');
end
end
