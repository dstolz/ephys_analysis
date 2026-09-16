function onBrowseRoot(obj)
    % Prompt for the parent directory to scan.
    start = obj.RootPathField.Value;
    if isempty(start) || ~isfolder(start); start = pwd; end
    d = uigetdir(start, "Select parent directory to scan for recordings");
    figure(obj.Fig);  % restore focus after modal dialog
    if isequal(d, 0); return; end
    obj.RootPathField.Value = d;
    obj.onConfigChanged();
end
