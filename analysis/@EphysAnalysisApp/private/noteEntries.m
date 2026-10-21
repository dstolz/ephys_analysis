function E = noteEntries(obj)
%noteEntries  Every note of the scanned datasets, for the search window (NoteSearch): one row each, in dataset order.
%   Columns: dataset (its index in the Runner), name, then
%   DatasetNotes.list(AllSorts=true)'s level, id, label ("unit 12"), text,
%   updated and current (false: a unit's note on another sort). Nothing is
%   read: the notes are those in memory (Notes, read on Scan, written by
%   the notepad).
%
%   See also onSearchNotes, NoteSearch, DatasetNotes.
r = obj.Runner;
parts = {};
if ~isempty(r) && numel(obj.Notes) == numel(r.Keys)
    for k = 1:numel(r.Keys)
        L = obj.Notes(k).list(AllSorts=true);
        n = height(L);
        if n == 0; continue; end
        L = [table(repmat(k, n, 1), repmat(string(r.Names(k)), n, 1), 'VariableNames', ["dataset" "name"]) L]; %#ok<AGROW> one dataset's notes, not a growing list
        parts{end+1} = L; %#ok<AGROW>
    end
end
if isempty(parts)
    E = table(zeros(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), NaT(0, 1), false(0, 1), ...
        'VariableNames', ["dataset" "name" "level" "id" "label" "text" "updated" "current"]);
else
    E = vertcat(parts{:});
end
end
