function onBrowseSpikesOutput(obj)
%onBrowseSpikesOutput  Pick the folder for the spikes .mat files.
start = obj.SpkOutputDirField.Value;
if isempty(start) || ~isfolder(start); start = obj.OutputRootField.Value; end
if isempty(start) || ~isfolder(start); start = pwd; end
d = uigetdir(start, "Output folder for the spikes .mat files");
figure(obj.Fig);
if isequal(d, 0); return; end
obj.SpkOutputDirField.Value = d;
obj.onConfigChanged();
end
