function onCleanupMethodChanged(obj)
%onCleanupMethodChanged  Show what the chosen Removed files go method does; the folder field only for a move.
%   The preview says which files go, not how, so it is kept.
method = string(obj.CleanupMethodDropDown.Value);
move = method == "move";
obj.CleanupDestField.Enable = matlab.lang.OnOffSwitchState(move);
obj.CleanupDestButton.Enable = matlab.lang.OnOffSwitchState(move);
switch method
    case "delete"
        txt = "Deleted for good: the space is free at once.";
        btn = "Delete files...";
    case "recycle"
        txt = "They can be restored from the Recycle Bin; the space is freed only when it is emptied. " + ...
            "A file on a drive without a Recycle Bin (network, removable) or too large for it is skipped, not deleted.";
        btn = "Recycle files...";
    case "move"
        txt = "Each file goes to <folder>\<dataset key>\<its path in the dataset folder>; " + ...
            "a file already there is never overwritten.";
        btn = "Move files...";
end
obj.CleanupMethodNote.Text = txt + " Each dataset gets <Name>_cleanup.json saying what was removed and where it went.";
obj.CleanupRunButton.Text = btn;
obj.CleanupRunButton.Tooltip = "Act on the ticked Remove rows of the preview, after a confirmation.";
end
