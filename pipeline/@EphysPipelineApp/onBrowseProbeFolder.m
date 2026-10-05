function onBrowseProbeFolder(obj)
    % Prompt for the folder that holds probe .json files.
    start = obj.ProbeFolderField.Value;
    if isempty(start) || ~isfolder(start); start = obj.defaultProbeFolder(); end
    d = uigetdir(start, "Select folder containing Kilosort4 probe .json files");
    figure(obj.Fig);
    if isequal(d, 0); return; end
    obj.ProbeFolderField.Value = d;
    obj.refreshProbeList();
    obj.savePreferences();
end
