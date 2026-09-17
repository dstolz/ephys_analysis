function onReviewDatasetChanged(obj)
    % Point the folder field at the chosen dataset's results and load.
    rd = obj.ReviewDatasetDropDown.Value;
    if isempty(rd) || ~ischar(rd) || ~isfolder(rd); return; end
    obj.ReviewFolderField.Value = rd;
    obj.savePreferences();
    obj.loadReviewResults();
end
