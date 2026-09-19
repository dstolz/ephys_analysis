function nodes = oeNodes(session)
%oeNodes  The Open Ephys Record Nodes of a session folder and their formats.
%   NODES = oeNodes(SESSION) is a struct array (id, folder, format) with one
%   entry per "Record Node <id>" sub-folder holding data in a supported
%   format ("binary" | "legacy" | "nwb"), sorted by id. A folder that holds
%   the data itself (GUI 0.4 sessions, or a Record Node folder copied on its
%   own) is one node with id "". Empty when SESSION holds no recording.

nodes = struct('id', {}, 'folder', {}, 'format', {});
session = string(session);
if ~isfolder(session); return; end
D = dir(session);
D = D([D.isdir] & ~ismember({D.name}, {'.', '..'}));
ids = []; folders = strings(0, 1);
for k = 1:numel(D)
    tok = regexp(D(k).name, '^Record Node\s*(\d+)$', 'tokens', 'once', 'ignorecase');
    if isempty(tok); continue; end
    ids(end+1, 1) = str2double(tok{1}); %#ok<AGROW>
    folders(end+1, 1) = string(fullfile(D(k).folder, D(k).name)); %#ok<AGROW>
end
[ids, order] = sort(ids);
folders = folders(order);
for k = 1:numel(ids)
    fmt = OpenEphysReader.nodeFormat(folders(k));
    if fmt == ""; continue; end
    nodes(end+1) = struct('id', string(ids(k)), 'folder', folders(k), 'format', fmt); %#ok<AGROW>
end
if isempty(ids)
    [~, leaf] = fileparts(char(session));
    fmt = OpenEphysReader.nodeFormat(session);
    if fmt ~= "" && isempty(regexp(leaf, '^Record Node', 'once', 'ignorecase'))
        nodes(1) = struct('id', "", 'folder', session, 'format', fmt);
    end
end
end
