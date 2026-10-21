function m = noteMarks(obj, T, data)
%noteMarks  "✎ " before each observation of T (figureObservations' table on the active dataset) that has a note, else "".
%   As favoriteMarks: DATA is the figure's observe.data; a sorted unit's
%   note is by its id on the sort in use, a detection channel's
%   ("detected") and a channel's by their recording channel, the dataset's
%   its own. The mark goes after the star's ("★ ✎ unit 12").
%
%   See also favoriteMarks, markObservations, refreshFigureObservations, DatasetNotes.
n = 0;
if istable(T); n = height(T); end
m = strings(1, n);
if n == 0 || isempty(obj.Runner) || obj.ActiveIdx < 1 || numel(obj.Notes) < obj.ActiveIdx; return; end
notes = obj.Notes(obj.ActiveIdx);
if isempty(notes.Notes); return; end
on = false(1, n);
for kind = ["dataset" "unit" "channel"]
    rows = reshape(T.kind == kind, 1, []);
    if ~any(rows); continue; end
    switch kind
        case "dataset"
            on(rows) = notes.hasNote("dataset");
        case "unit"
            if data == "detected"
                on(rows) = notes.hasNote("channel", reshape(T.channel(rows), 1, []));
            else
                on(rows) = notes.hasNote("unit", reshape(T.unitId(rows), 1, []));
            end
        case "channel"
            on(rows) = notes.hasNote("channel", reshape(T.channel(rows), 1, []));
    end
end
m(on) = "✎ ";
end
