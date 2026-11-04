function openNotePad(obj, idx, level, id, follows, opts)
%openNotePad  The notepad on the note of dataset IDX at LEVEL / ID: opened, or moved there (the note in it written first).
%   One notepad (NotePad) for the app, kept in NotePadWindow; it stays above
%   the app's window. FOLLOWS is what it follows from then on
%   (NotePadFollows, syncNoteButtons): "dataset" (the active dataset),
%   "observation" (the observation picked) or "" (it stays on this note).
%   When the note in it cannot be written (a read-only folder) it stays
%   there and the status bar says why. Front=true brings it to the front
%   (a note button pressed); following never does. Each note written
%   shows at once everywhere (refreshNotes).
%
%   See also NotePad, onNoteButton, onSearchNotes, syncNoteButtons.
arguments
    obj (1,1) EphysAnalysisApp
    idx (1,1) double
    level (1,1) string
    id (1,1) double
    follows (1,1) string {mustBeMember(follows, ["dataset" "observation" ""])}
    opts.Front (1,1) logical = false
end
if isempty(obj.Runner) || idx < 1 || idx > numel(obj.Notes); return; end
title = obj.Runner.Names(idx);
if level == "dataset"
    id = NaN;
else
    title = title + " · " + level + " " + id;
end
item = struct('notes', obj.Notes(idx), 'level', level, 'id', id, 'title', title);
p = obj.NotePadWindow;
if ~isempty(p) && isvalid(p)
    if ~p.open(item)
        obj.setStatus("The notepad stays on " + p.Item.title + ": " + p.StateLabel.Text);
        return
    end
    if opts.Front && p.Fig.Visible == "on"
        figure(p.Fig);
    end
else
    obj.NotePadWindow = NotePad(item, Parent=obj.Fig, Visible=obj.Fig.Visible == "on", ...
        SavedFcn=@(~) obj.refreshNotes());
end
obj.NotePadFollows = follows;
end
