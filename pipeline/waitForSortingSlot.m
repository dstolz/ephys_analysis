function device = waitForSortingSlot(runs, maxRunning, opts)
%waitForSortingSlot  Wait until fewer than MAXRUNNING Kilosort4 runs are going.
%   DEVICE = waitForSortingSlot(RUNS, MAXRUNNING) checks the background
%   runs RUNS (a struct array with statusFile and device fields, [] for
%   none; see sortingSlot) and returns as soon as fewer than MAXRUNNING of
%   them are still running, checking again every Period seconds until
%   then. Put it between writing a run's files and starting the run to cap
%   how many run at once:
%
%     launched = [];
%     for d = datasets
%         res = d.runSpikeInterface(Launch=false, ...);   % the run files
%         device = waitForSortingSlot(launched, 2, Devices=["cuda:0" "cuda:1"]);
%         res = d.launchSorting(res, Wait=false, Device=device);
%         launched = [launched, res];
%     end
%
%   Options
%     Devices  torch devices to share out (default none). DEVICE is the one
%              the fewest running runs use once the slot is free, "" when
%              there are none.
%     Period   seconds between checks (default 2)
%     TickFcn  called as TickFcn(nRunning, nFinished) before each wait
%              (e.g. to report progress); an error from it (e.g. a cancel)
%              ends the wait
%
%   See also sortingSlot, EphysDataset.launchSorting,
%   EphysDataset.sortRunState, EphysPipeline.runSorting.

arguments
    runs
    maxRunning (1,1) double {mustBePositive}
    opts.Devices string = strings(1, 0)
    opts.Period (1,1) double {mustBePositive} = 2
    opts.TickFcn = []
end

while true
    [free, device, nRunning, nFinished] = sortingSlot(runs, maxRunning, opts.Devices);
    if free
        return
    end
    if ~isempty(opts.TickFcn)
        opts.TickFcn(nRunning, nFinished);
    end
    pause(opts.Period);
end
end
