function onBrowseConvertOutput(obj)
    % Prompt for the folder that receives the derived-signal .mat files.
    start = obj.ConvOutputDirField.Value;
    if isempty(start) || ~isfolder(start); start = obj.RootPathField.Value; end
    if isempty(start) || ~isfolder(start); start = pwd; end
    d = uigetdir(start, "Select output folder for the converted .mat files");
    figure(obj.Fig);
    if isequal(d, 0); return; end
    obj.ConvOutputDirField.Value = d;
    obj.onConvertControlsChanged();
end
