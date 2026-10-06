function D = listTree(root, recursive, opts)
%listTree  Files under a folder, listing each sub-folder once.
%   D = listTree(ROOT) is the dir struct (a column) of every file under
%   ROOT, its sub-folders included; listTree(ROOT, false) lists only the
%   files directly in ROOT. Folders are not returned. A ROOT that is not a
%   folder gives an empty struct.
%
%   Hidden folders (a name starting with ".", e.g. phy's ".phy" caches or
%   ".git") are not entered: no recording or pipeline output lives there,
%   and phy alone leaves hundreds of cache folders per sorting.
%
%   One walk serves every file name: filter D with matchFiles rather than
%   walking again per pattern. dir(fullfile(ROOT, '**', PATTERN)) walks the
%   whole tree for each pattern, which over a network share costs tens of
%   seconds a walk.
%
%   Options
%     Pattern  dir wildcards ("*.rhd", "recording.json"); keeps the files
%              whose name matches any of them (see matchFiles). Default:
%              every file.
%
%   See also matchFiles, dir.

arguments
    root (1,1) string
    recursive (1,1) logical = true
    opts.Pattern (1,:) string = string.empty(1, 0)
end

if ~isfolder(root)
    D = dir(root);
    D = D([]);
    return
end
found = cell(0, 1);
todo = root;
while ~isempty(todo)
    L = dir(todo(end));
    todo(end) = [];
    L = L(~ismember({L.name}, {'.', '..'}));
    isDir = [L.isdir];
    found{end+1, 1} = L(~isDir); %#ok<AGROW>
    sub = L(isDir & ~startsWith({L.name}, '.'));
    if recursive && ~isempty(sub)
        % Reversed onto the stack, so folders are listed in dir's order.
        todo = [todo, flip(string(fullfile({sub.folder}, {sub.name})))]; %#ok<AGROW>
    end
end
D = vertcat(found{:});
if ~isempty(opts.Pattern)
    D = matchFiles(D, opts.Pattern);
end
end
