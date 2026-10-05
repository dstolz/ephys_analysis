function onOpenReviewFolder(obj)
    % Open the current results folder in the system file browser.
    f = strtrim(obj.ReviewFolderField.Value);
    if isempty(f) || ~isfolder(f)
        uialert(obj.Fig, "Select a valid results folder first.", "Review");
        return
    end
    openInSystem(f);
end
