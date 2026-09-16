function onBrowseOutput(obj)
    % Prompt for the output root for .bin / Kilosort4 results.
    start = obj.OutputRootField.Value;
    if isempty(start) || ~isfolder(start); start = pwd; end
    d = uigetdir(start, "Select output root (per-dataset results go under <root>/<Name>)");
    figure(obj.Fig);
    if isequal(d, 0); return; end
    obj.OutputRootField.Value = d;
    obj.savePreferences();
end
