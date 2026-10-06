function s = cleanupMoveSentence(T, M, dest)
%cleanupMoveSentence  What a Clean up move finds in its folder, in words, for the ticked Remove files.
%   S = cleanupMoveSentence(T, M, DEST) takes the Clean up preview T (with
%   Include) and its cleanupMoveTargets result M, and says how many of the
%   files to move are already in folder DEST and what then happens to them
%   (skipped, overwriting, a new version folder). Each sentence starts with
%   a space, to follow the summary line or a confirmation's first line.
go = T.Action == "remove" & T.Include;
taken = go & M.Taken ~= "";
skip = go & M.To == "";
over = go & M.Taken == "file" & M.To ~= "" & strcmpi(M.To, M.Target);
ver = go & M.To ~= "" & ~strcmpi(M.To, M.Target);
if ~any(taken | skip | ver)
    s = " None of them is in the folder yet.";
    if ~isfolder(dest)
        s = s + " The folder does not exist yet: the move creates it.";
    end
    return
end
s = "";
if any(taken)
    s = s + sprintf(" %d of the files to move are already in the folder (In the folder column).", nnz(taken));
end
if any(over)
    s = s + sprintf(" %d would overwrite the file there.", nnz(over));
end
if any(ver)
    s = s + sprintf(" The files of %d dataset(s) would go to a new version folder (<dataset key>_v2, ...) instead.", ...
        numel(unique(T.Key(ver))));
end
if any(skip)
    s = s + sprintf(" %d would be skipped and stay here.", nnz(skip));
end
end
