function stopKSRuns(obj, names)
%stopKSRuns  Stop background Kilosort4 runs that are going.
%   obj.stopKSRuns(NAMES) stops each running run in KSRuns whose dataset is
%   named in NAMES; obj.stopKSRuns() stops them all. Each goes through
%   EphysDataset.stopSortRun: its processes end and its ks4_status.json
%   says "cancelled". The monitor (pollKSRuns, called here at once) then
%   logs it as [stopped] and turns its result row into "cancelled".
%   Queued runs are not touched (Stop queue drops those), so a slot freed
%   here goes to the next queued run.
%
%   See also onStopKSRuns, EphysDataset.stopSortRun.

running = find(~[obj.KSRuns.done]);
if nargin >= 2
    running = running(ismember([obj.KSRuns(running).Name], string(names)));
end
for i = running
    r = obj.KSRuns(i);
    try
        [ok, msg] = EphysDataset.stopSortRun(r.statusFile);
    catch ME
        obj.log("[error] %s - could not stop Kilosort4: %s", r.Name, ME.message);
        continue
    end
    if ok
        obj.log("[sorting] %s: stopping Kilosort4 (%s)", r.Name, msg);
    end
end
if ~isempty(running)
    obj.pollKSRuns();
end
end
