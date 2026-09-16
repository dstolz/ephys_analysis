function onBrowseReviewFolder(obj)
    % Prompt for a Kilosort4 results folder to review.
    start = obj.ReviewFolderField.Value;
    if isempty(start) || ~isfolder(start); start = pwd; end
    d = uigetdir(start, "Select a Kilosort4 results folder (contains params.py)");
    figure(obj.Fig);
    if isequal(d, 0); return; end
    obj.ReviewFolderField.Value = d;
    obj.savePreferences();
    obj.loadReviewResults();
end
