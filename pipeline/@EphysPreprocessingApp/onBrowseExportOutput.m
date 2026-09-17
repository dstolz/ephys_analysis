function onBrowseExportOutput(obj)
%onBrowseExportOutput  Pick the folder for the export files.
start = obj.ExpOutputDirField.Value;
if isempty(start) || ~isfolder(start); start = obj.OutputRootField.Value; end
if isempty(start) || ~isfolder(start); start = pwd; end
d = uigetdir(start, "Output folder for the Chronux / FieldTrip files");
figure(obj.Fig);
if isequal(d, 0); return; end
obj.ExpOutputDirField.Value = d;
obj.onConfigChanged();
end
