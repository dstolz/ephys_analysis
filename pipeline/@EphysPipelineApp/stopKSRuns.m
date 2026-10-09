function stopKSRuns(obj, names)
%stopKSRuns  Stop background sort runs (Kilosort4, SpikeInterface) that are going.
%   obj.stopKSRuns(NAMES) stops each running run in KSRuns whose dataset is
%   named in NAMES; obj.stopKSRuns() stops them all. Each goes through
%   EphysDataset.stopSortRun: its processes end and its status file
%   (ks4_status.json, si_status.json)
%   says "canceled". The monitor (pollKSRuns, called here at once) then
%   logs it as [stopped] and turns its result row into "canceled".
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
    what = EphysDataset.sorterLabel(EphysDataset.sorterOfRunDir(r.resultsDir));
    try
        [ok, msg] = EphysDataset.stopSortRun(r.statusFile);
    catch ME
        obj.log("[error] %s - could not stop %s: %s", r.Name, what, ME.message);
        continue
    end
    if ok
        obj.log("[sorting] %s: stopping %s (%s)", r.Name, what, msg);
    end
end
if ~isempty(running)
    obj.pollKSRuns();
end
end
