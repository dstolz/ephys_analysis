function [free, device, nRunning, nFinished] = sortingSlot(runs, maxRunning, devices)
%sortingSlot  Whether another Kilosort4 run may start now, and on which device.
%   [FREE, DEVICE] = sortingSlot(RUNS, MAXRUNNING, DEVICES) checks the
%   background runs RUNS with EphysDataset.sortRunState. RUNS is a struct
%   array with statusFile and device fields ([] for none), such as
%   EphysPipeline.LaunchedRuns or the results of
%   EphysDataset.launchSorting. FREE is true when fewer than MAXRUNNING of
%   them are still running. DEVICE is the torch device of DEVICES (a string
%   array such as ["cuda:0" "cuda:1"]) that the fewest running runs use,
%   the first one on a tie, so the runs spread over the GPUs; "" when
%   DEVICES is empty.
%
%   [FREE, DEVICE, NRUNNING, NFINISHED] also returns how many of RUNS are
%   running and how many have finished.
%
%   It never waits: waitForSortingSlot waits on it, and the app's monitor
%   calls it every tick to start queued runs.
%
%   See also waitForSortingSlot, EphysDataset.launchSorting,
%   EphysPipeline.runSorting.

arguments
    runs
    maxRunning (1,1) double {mustBePositive}
    devices string = strings(1, 0)
end

running = false(1, numel(runs));
for i = 1:numel(runs)
    running(i) = EphysDataset.sortRunState(runs(i).statusFile) == "running";
end
nRunning = nnz(running);
nFinished = numel(runs) - nRunning;
free = nRunning < maxRunning;

device = "";
devices = reshape(devices, 1, []);
if isempty(devices)
    return
end
used = zeros(1, numel(devices));
for i = find(running)
    d = string(runs(i).device);
    if isscalar(d)
        used = used + (devices == d);
    end
end
[~, j] = min(used);   % the first of the least used
device = devices(j);
end
