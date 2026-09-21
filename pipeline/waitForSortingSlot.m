function waitForSortingSlot(statusFiles, maxRunning, opts)
%waitForSortingSlot  Wait until fewer than MAXRUNNING Kilosort4 runs are going.
%   waitForSortingSlot(STATUSFILES, MAXRUNNING) checks the background runs
%   named by their ks4_status.json paths (EphysDataset.sortRunState) and
%   returns as soon as fewer than MAXRUNNING of them are still running,
%   checking again every Period seconds until then. Pass it as
%   BeforeLaunchFcn to EphysDataset.runSpikeInterface / runKilosort to cap
%   how many run at once:
%
%     launched = strings(0, 1);
%     for d = datasets
%         res = d.runSpikeInterface(Wait=false, ...
%             BeforeLaunchFcn=@() waitForSortingSlot(launched, 2));
%         launched(end+1) = res.statusFile;
%     end
%
%   Options
%     Period   seconds between checks (default 2)
%     TickFcn  called as TickFcn(nRunning, nFinished) before each wait
%              (e.g. to report progress); an error from it (e.g. a cancel)
%              ends the wait
%
%   See also EphysDataset.sortRunState, EphysPipeline.runSorting.

arguments
    statusFiles string
    maxRunning (1,1) double {mustBePositive}
    opts.Period (1,1) double {mustBePositive} = 2
    opts.TickFcn = []
end

statusFiles = statusFiles(:);
finished = false(size(statusFiles));
while true
    for i = find(~finished).'
        finished(i) = EphysDataset.sortRunState(statusFiles(i)) ~= "running";
    end
    nRunning = nnz(~finished);
    if nRunning < maxRunning
        return
    end
    if ~isempty(opts.TickFcn)
        opts.TickFcn(nRunning, nnz(finished));
    end
    pause(opts.Period);
end
end
