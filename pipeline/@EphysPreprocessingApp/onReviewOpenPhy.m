function onReviewOpenPhy(obj)
    % Open the Review tab's results folder in phy's template-gui.
    % Load/Browse/dataset-pick rewrite the field to the resolved folder
    % holding params.py, so the field is what gets launched.
    f = strtrim(obj.ReviewFolderField.Value);
    if isempty(f) || ~isfolder(f)
        uialert(obj.Fig, "Select a valid results folder first.", "phy");
        return
    end
    obj.launchPhy(f, f);
end
