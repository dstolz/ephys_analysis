function state = sortRunLive(statusFiles)
%sortRunLive  How each background sort run stands, a vanished process counted.
%   STATE = sortRunLive(STATUSFILES) is EphysDataset.sortRunState of each
%   status file (a string array; STATE is a string array of the same size:
%   "running", "done", "error" or "canceled"), with one addition: a run
%   whose launcher was killed - the computer restarted, the window was
%   closed - leaves no exit marker, so sortRunState reads "running" for
%   ever. About every 30 seconds, for the runs still "running" 30 seconds
%   after they were first seen here, one EphysDataset.sortRunProcesses
%   search counts the processes of all of them. A run with none left gets
%   its exit marker written (EphysDataset.SortExitMarker) and reads "error"
%   (the process exited without writing its status), here and for every
%   other reader of that status file.
%
%   It is what sortingSlot (a slot a dead run holds is free), the output
%   transfer's wait for a sort and EphysPipeline.activeRun ask.
%
%   See also sortingSlot, EphysDataset.sortRunState, EphysDataset.sortRunProcesses.

arguments
    statusFiles string
end

persistent seen checked
if isempty(seen)
    seen = containers.Map('KeyType', 'char', 'ValueType', 'double');      % when a run was first seen running
    checked = containers.Map('KeyType', 'char', 'ValueType', 'double');   % when its processes were last counted
end
period = 30;   % seconds

files = reshape(statusFiles, [], 1);
state = strings(size(files));
for k = 1:numel(files)
    state(k) = EphysDataset.sortRunState(files(k));
end

t = now * 86400; %#ok<TNOW1>
for k = reshape(find(state ~= "running"), 1, [])   % an ended run that starts again is new
    key = char(lower(files(k)));
    if isKey(seen, key); remove(seen, key); remove(checked, key); end
end
due = zeros(0, 1);
for k = reshape(find(state == "running"), 1, [])
    key = char(lower(files(k)));
    if ~isKey(seen, key)
        seen(key) = t;
        checked(key) = t;
    elseif t - seen(key) >= period && t - checked(key) >= period
        due(end+1, 1) = k; %#ok<AGROW>
    end
end
if ~isempty(due)
    n = EphysDataset.sortRunProcesses(reshape(files(due), 1, []));
    for j = 1:numel(due)
        k = due(j);
        checked(char(lower(files(k)))) = t;
        folder = fileparts(char(files(k)));
        if n(j) == 0 && isfolder(folder)
            fid = fopen(fullfile(folder, char(EphysDataset.SortExitMarker)), 'w');
            if fid >= 0; fclose(fid); end
            state(k) = EphysDataset.sortRunState(files(k));
        end
    end
end
state = reshape(state, size(statusFiles));
end
