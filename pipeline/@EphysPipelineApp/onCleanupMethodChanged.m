function onCleanupMethodChanged(obj)
%onCleanupMethodChanged  Show what the chosen Removed files go method does; the folder and If a file is already there only for a move.
%   Called when the method, the folder or If a file is already there
%   changes. The preview says which files go, not how, so it is kept; for a
%   move the folder is checked again for the preview's files
%   (refreshCleanupMove) and the table shows what is there.
method = string(obj.CleanupMethodDropDown.Value);
move = method == "move";
set([obj.CleanupDestField, obj.CleanupDestButton, obj.CleanupIfExistsDropDown, obj.CleanupIfExistsLabel], ...
    "Enable", matlab.lang.OnOffSwitchState(move));
switch method
    case "delete"
        txt = "Deleted for good: the space is free at once.";
        btn = "Delete files...";
    case "recycle"
        txt = "They can be restored from the Recycle Bin; the space is freed only when it is emptied. " + ...
            "A file on a drive without a Recycle Bin (network, removable) or too large for it is skipped, not deleted.";
        btn = "Recycle files...";
    case "move"
        txt = "Each file goes to <folder>\<dataset key>\<its path in the dataset folder>. " + ...
            "The preview checks the folder for files already there (the In the folder column); ";
        switch string(obj.CleanupIfExistsDropDown.Value)
            case "skip"
                txt = txt + "such a file is skipped, and both stay as they are.";
            case "overwrite"
                txt = txt + "such a file replaces the one there, which is deleted only once the new one is in place " + ...
                    "(a folder is never replaced).";
            case "version"
                txt = txt + "then all that dataset's files go to a new folder, <dataset key>_v2 (or _v3, ...), " + ...
                    "so a set such as a sort run folder stays whole.";
        end
        btn = "Move files...";
end
obj.CleanupMethodNote.Text = txt + " Each dataset gets <Name>_cleanup.json saying what was removed and where it went.";
obj.CleanupRunButton.Text = btn;
obj.CleanupRunButton.Tooltip = "Act on the ticked Remove rows of the preview, after a confirmation.";
if ~isempty(obj.CleanupPlan)
    obj.refreshCleanupMove(true);
    obj.refreshCleanupTable();
end
end
