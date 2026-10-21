function tip = noteTip(what)
%noteTip  The tooltip of a note button: what it opens the notepad on (WHAT "dataset" or "observation").
%   syncNoteButtons adds the note's first line, or why the button is off.
%
%   See also noteButton, syncNoteButtons.
if what == "dataset"
    tip = "The note on the active dataset: a little notepad, kept in <Name>_notes.json in its output folder. " + ...
        "Yellow: it has a note.";
else
    tip = "The note on the observation previewed: the sorted unit (with its sort), the channel (a detection channel's " + ...
        "note is its channel's) or, for a figure of the dataset, the dataset. The notepad follows the observation " + ...
        "as you step through them. Yellow: it has a note; ✎ in this list.";
end
end
