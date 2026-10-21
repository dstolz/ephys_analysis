function b = noteButton(obj, parent, what)
%noteButton  A note button ("✎") that opens the notepad (NotePad) on WHAT: "dataset" (the active one) or "observation" (the one picked).
%   Off until a scan; syncNoteButtons sets its look (sticky-note yellow
%   when there is a note) and tooltip (the note's first line), and a press
%   goes to onNoteButton.
%
%   See also syncNoteButtons, onNoteButton, starButton, DatasetNotes.
b = uibutton(parent, "Text", "✎", "Enable", "off", "Tooltip", noteTip(what), ...
    "ButtonPushedFcn", @(~, ~) obj.onNoteButton(what));
end
