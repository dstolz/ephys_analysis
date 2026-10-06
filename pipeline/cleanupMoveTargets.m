function M = cleanupMoveTargets(T, destination, opts)
%cleanupMoveTargets  Where a clean up's move puts each Remove file, what is already there, and what then happens.
%   M = cleanupMoveTargets(T, DESTINATION) takes a planLocalCleanup table and
%   says, for each of its rows whose Action is "remove", where
%   runLocalCleanup(T, Method="move", Destination=DESTINATION) puts the file:
%   <DESTINATION>/<Key>/<its path below Root>. Each place is checked: one
%   already holding a file or a folder is taken. Nothing is changed on disk;
%   this is the move's preview, and runLocalCleanup calls it again at the
%   start of the move. Only the dataset folders <DESTINATION>/<Key> that
%   exist are listed (one listing each).
%
%   M = cleanupMoveTargets(T, DESTINATION, IfExists=HOW) says what the move
%   does with a file whose place is taken (default "skip"):
%     "skip"       the file is not moved: it stays where it is, and the one
%                  in the folder is left as it is
%     "overwrite"  the file replaces the one in the folder
%     "version"    every Remove file of that dataset goes to a new version
%                  folder instead, <DESTINATION>/<Key>_v<n> with n the first
%                  of 2, 3, ... that is not taken, so that a set of files
%                  (a sort run folder, say) stays whole; nothing in the
%                  folder is touched
%   A folder at a file's place is never replaced, so with "overwrite" that
%   file is skipped. Of two Remove files with the same place only the first
%   goes; the other is skipped.
%
%   M = cleanupMoveTargets(T, DESTINATION, IfExists=HOW, Checked=M0) reuses
%   the look at the folder in M0, an earlier result for the same plan and
%   DESTINATION, and only decides again what happens, after HOW or the rows
%   marked "remove" changed (rows M0 looked at may since be "keep"; a row
%   it did not look at is an error). Nothing is read from disk.
%
%   M has one row per row of T:
%     Target      the file's place in the folder ("" for a row not looked at)
%     Taken       what is already at Target: "" (nothing), "file" or "folder"
%     TakenBytes  the size of the file there (NaN otherwise)
%     TakenDate   when it was last changed (NaT otherwise)
%     Version     the dataset's first free version folder, <DESTINATION>/<Key>_v<n>;
%                 looked for only when a file of the dataset has its place
%                 taken ("" otherwise)
%     To          where the move puts the file: Target, the same path in the
%                 version folder, or "" when the file is not moved (and for
%                 a row that is not "remove")
%     Note        why a Remove file is not moved ("" when it is)
%
%   See also runLocalCleanup, planLocalCleanup.

arguments
    T table
    destination (1,1) string
    opts.IfExists (1,1) string {mustBeMember(opts.IfExists, ["skip" "overwrite" "version"])} = "skip"
    opts.Checked = []
end

dest = stripSep(strtrim(destination));
rm = T.Action == "remove";
if isempty(opts.Checked)
    M = look(T, rm, dest);
else
    M = opts.Checked;
    if ~istable(M) || height(M) ~= height(T) || ~all(ismember(["Target" "Taken" "Version"], M.Properties.VariableNames))
        error('cleanupMoveTargets:Checked', 'Checked must be an earlier result of cleanupMoveTargets for the same plan.');
    end
    if any(rm & M.Target == "")
        error('cleanupMoveTargets:Checked', ['Checked did not look at the place of %s: ' ...
            'call cleanupMoveTargets without it.'], T.File(find(rm & M.Target == "", 1)));
    end
end
M = decide(T, rm, M, opts.IfExists);
end


function M = look(T, rm, dest)
%look  Each Remove file's place in DEST and what is there now; a free version folder for each dataset with a taken place.
n = height(T);
M = table(strings(n, 1), strings(n, 1), nan(n, 1), NaT(n, 1), strings(n, 1), strings(n, 1), strings(n, 1), ...
    'VariableNames', {'Target', 'Taken', 'TakenBytes', 'TakenDate', 'Version', 'To', 'Note'});
for k = find(rm).'
    M.Target(k) = string(fullfile(dest, stripSep(T.Key(k)), relativePath(T.File(k), T.Root(k))));
end
for key = unique(T.Key(rm)).'
    base = fullfile(dest, stripSep(key));
    if ~isfolder(base); continue; end
    D = dir(fullfile(base, "**"));
    D = D(~ismember({D.name}, {'.', '..'}));
    if isempty(D); continue; end
    there = lower(string({D.folder}) + filesep + string({D.name}));
    rows = find(rm & T.Key == key);
    [hit, at] = ismember(lower(M.Target(rows)), there);
    for j = find(hit).'
        k = rows(j);
        e = D(at(j));
        if e.isdir
            M.Taken(k) = "folder";
        else
            M.Taken(k) = "file";
            M.TakenBytes(k) = e.bytes;
            M.TakenDate(k) = datetime(e.datenum, 'ConvertFrom', 'datenum');
        end
    end
    if any(hit)
        M.Version(rows) = freeVersion(dest, stripSep(key));
    end
end
end


function M = decide(T, rm, M, how)
%decide  Where each Remove file goes (To) under HOW, or why it stays (Note).
M.To(:) = "";
M.Note(:) = "";
taken = rm & M.Taken ~= "";
folder = rm & M.Taken == "folder";
M.Note(folder) = "a folder is at " + M.Target(folder) + ", and a file never replaces a folder";
switch how
    case "skip"
        go = rm & ~taken;
        file = rm & M.Taken == "file";
        M.Note(file) = "a file is already at " + M.Target(file) + " (IfExists ""skip"": both are left as they are)";
    case "overwrite"
        go = rm & ~folder;
    case "version"
        ver = rm & ismember(T.Key, unique(T.Key(taken)));
        go = rm & ~ver;
        none = ver & M.Version == "";
        M.Note(none) = "its place " + M.Target(none) + " is taken and no free version folder was found";
        for k = find(ver & ~none).'
            M.To(k) = string(fullfile(M.Version(k), relativePath(T.File(k), T.Root(k))));
        end
        M.Note(ver & ~none) = "";   % a folder there is no obstacle: the file goes to the version folder
end
M.To(go) = M.Target(go);
% one file per place: the first keeps it
moving = find(M.To ~= "");
[~, first] = unique(lower(M.To(moving)), 'stable');
dup = moving(setdiff(1:numel(moving), first));
M.Note(dup) = "another file of this clean up goes to " + M.To(dup);
M.To(dup) = "";
end


function v = freeVersion(dest, key)
%freeVersion  The first of <dest>/<key>_v2, _v3, ... that holds no file or folder ("" when none does up to _v999).
v = "";
for n = 2:999
    p = string(fullfile(dest, key + "_v" + n));
    if ~isfolder(p) && ~isfile(p)
        v = p;
        return
    end
end
end


function rel = relativePath(file, root)
%relativePath  FILE's path below ROOT (its name alone when it is not below ROOT).
root = stripSep(root);
if root ~= "" && startsWith(lower(file), lower(root) + filesep)
    rel = extractAfter(file, strlength(root) + 1);
else
    [~, b, e] = fileparts(file);
    rel = b + e;
end
end


function s = stripSep(s)
s = string(s);
s = strip(strrep(s, "/", filesep), 'right', filesep);
end
