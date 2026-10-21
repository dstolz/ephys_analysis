function syncNoteButtons(obj)
%syncNoteButtons  The note buttons show the notes of what they open: the active dataset and the observation picked; an open notepad follows.
%   Sticky-note yellow, with the note's first line in the tooltip, when
%   there is a note; a plain "✎" when not. Off before a scan, and the
%   observation's while nothing it shows can have a note (observedItem
%   says why, in its tooltip). A notepad opened from one of them
%   (NotePadFollows "dataset" or "observation") moves to the new active
%   dataset or observation, the text in it written first (openNotePad);
%   one opened on a note of the search window stays on it.
%
%   See also noteButton, onNoteButton, observedItem, syncStarButtons.
notes = [];
if ~isempty(obj.Runner) && obj.ActiveIdx >= 1 && numel(obj.Notes) >= obj.ActiveIdx
    notes = obj.Notes(obj.ActiveIdx);
end
txt = "";
if ~isempty(notes); txt = notes.note("dataset"); end
for b = [obj.AlignDatasetNote obj.FiguresDatasetNote]
    if ~isvalid(b); continue; end
    look(b, ~isempty(notes), txt, noteTip("dataset"), "");
end
b = obj.FigureObservationNote;
if ~isempty(b) && isvalid(b)
    [level, id, why] = observedItem(obj);
    txt = "";
    if why == "" && ~isempty(notes); txt = notes.note(level, id); end
    look(b, why == "" && ~isempty(notes), txt, noteTip("observation"), why);
end
follow(obj);
end


function look(b, enabled, txt, tip, why)
%look  A note button's state, look and tooltip.
b.Enable = matlab.lang.OnOffSwitchState(enabled);
if txt ~= ""
    set(b, "BackgroundColor", [1 0.88 0.45], "FontColor", [0.30 0.22 0], "FontWeight", "bold", "FontSize", 16);
    first = strtrim(extractBefore(txt + newline, newline));
    if strlength(first) > 100; first = extractBefore(first, 98) + " ..."; end
    tip = ["Note: " + first; tip];
else
    set(b, "BackgroundColor", [0.89 0.92 0.96], "FontColor", [0.35 0.35 0.35], "FontWeight", "normal", "FontSize", 16);
end
if why ~= ""; tip(end) = tip(end) + " Now off: " + why + "."; end
b.Tooltip = tip;
end


function follow(obj)
%follow  An open notepad that follows the active dataset or the observation moves to it.
p = obj.NotePadWindow;
if isempty(p) || ~isvalid(p) || obj.NotePadFollows == "" || isempty(obj.Runner) || obj.ActiveIdx < 1
    return
end
if obj.NotePadFollows == "dataset"
    openNotePad(obj, obj.ActiveIdx, "dataset", NaN, "dataset");
    return
end
[level, id, why] = observedItem(obj);
if why == ""
    openNotePad(obj, obj.ActiveIdx, level, id, "observation");
end
end
