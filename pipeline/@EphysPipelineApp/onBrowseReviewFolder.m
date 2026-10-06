function onBrowseReviewFolder(obj)
    % Prompt for a sorted-output folder to review (any sorter's phy files).
    start = obj.ReviewFolderField.Value;
    if isempty(start) || ~isfolder(start); start = pwd; end
    d = uigetdir(start, "Select a sorted-output folder (holds params.py)");
    figure(obj.Fig);
    if isequal(d, 0); return; end
    obj.ReviewFolderField.Value = d;
    obj.savePreferences();
    obj.loadReviewResults();
end
