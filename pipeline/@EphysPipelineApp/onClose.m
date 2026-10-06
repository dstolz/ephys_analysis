function onClose(obj)
%onClose  Ask about unsaved changes, stop background work, persist prefs, close.
%   A background copy is not cancelled: the copy engine runs outside MATLAB, so
%   it finishes on its own. Closing only stops watching it, and the app says so
%   rather than leaving the copy looking abandoned. A scheduled copy is a
%   Windows task and does not depend on the app at all. With Kilosort4 runs
%   queued, it asks whether to keep the queue for next time (offered back
%   once the project is scanned again), drop it, or stay open. Background
%   runs going carry on as processes and are kept, to be followed again at
%   the next launch (keepKSRuns).
if ~obj.confirmDiscard(); return; end
if ~isempty(obj.CopyJob)
    answer = uiconfirm(obj.Fig, ...
        "A copy is still running. The files will finish copying on their own, but " + ...
        "nothing is left to verify them or write their session_manifest.json." + newline + newline + ...
        "Running Copy again later finishes the job: the sessions are checked and " + ...
        "any that are still incomplete are completed." + newline + newline + ...
        "Close anyway?", "Copy still running", ...
        "Options", ["Close anyway", "Stay open"], "DefaultOption", 2, "CancelOption", 2);
    if answer ~= "Close anyway"; return; end
end
keepQueue = false;
if ~isempty(obj.KSQueue)
    keep = "Keep the queue for next time";
    answer = uiconfirm(obj.Fig, ...
        sprintf("%d %s run(s) are queued and have not started. Their run files are written.", numel(obj.KSQueue), ...
        sortersLabel(arrayfun(@(q) string(q.prepared.resultsDir), obj.KSQueue))) + ...
        newline + newline + keep + ": once this project is scanned again, the app offers to queue them again." + ...
        newline + "Drop the queue: running the Sorting step again writes and starts them." + newline + newline + ...
        "The runs already going finish on their own either way; the app follows them again when it next opens.", ...
        "Sorting runs queued", "Options", [keep, "Drop the queue", "Cancel"], "DefaultOption", 1, "CancelOption", 3);
    if answer == "Cancel"; return; end
    keepQueue = answer == keep;
end
if obj.RunActive && ~isempty(obj.Pipe)
    obj.Pipe.cancel();
end
obj.stopTimers();
try
    obj.keepKSRuns(keepQueue);
catch ME
    warning('EphysPipelineApp:KeepRunsFailed', 'Could not keep the sorting runs for the next launch: %s', ME.message);
end
try
    obj.savePreferences();
catch ME
    warning('EphysPipelineApp:SavePrefsFailed', 'Could not save preferences: %s', ME.message);
end
delete(obj.Fig);
end
