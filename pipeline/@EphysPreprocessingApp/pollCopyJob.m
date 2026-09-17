function pollCopyJob(obj)
%pollCopyJob  Timer callback: advance the background copy and show where it is.
%   copySessions(job) reads whatever the detached engine has reported since
%   the last tick, calls the job's ProgressFcn and LogFcn with it, and returns
%   the session table with each row's status as it now stands. When the batch
%   is finished the timer stops and finishCopyRun takes over.

job = obj.CopyJob;
if isempty(job)
    obj.stopCopyMonitor();
    return
end
try
    [R, job] = copySessions(job);
catch ME
    obj.CopyJob = [];
    obj.stopCopyMonitor();
    obj.setCopyRunning(false);
    obj.copyLog("ERROR: the background copy stopped: " + ME.message);
    obj.setStatus("Copy sessions failed: " + string(ME.message), "");
    uialert(obj.Fig, ME.message, "Copy sessions");
    return
end
obj.CopyJob = job;
obj.applyCopyResult(obj.CopyRows, R);

if ~job.Done
    return
end
obj.CopyJob = [];
obj.stopCopyMonitor();
obj.setCopyRunning(false);
obj.finishCopyRun(R);
end
