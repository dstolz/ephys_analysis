function onClose(obj)
%onClose  Ask about unsaved changes, stop background work, persist prefs, close.
%   A background copy is not cancelled: the copy engine runs outside MATLAB, so
%   it finishes on its own. Closing only stops watching it, and the app says so
%   rather than leaving the copy looking abandoned. A scheduled copy is a
%   Windows task and does not depend on the app at all.
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
if obj.RunActive && ~isempty(obj.Pipe)
    obj.Pipe.cancel();
end
obj.stopKSMonitor();
obj.stopCopyMonitor();
t = obj.CopyScheduleTimer;   % only watches the scheduled copy's state
if ~isempty(t) && isvalid(t)
    stop(t);
    delete(t);
end
try
    obj.savePreferences();
catch ME
    warning('EphysPreprocessingApp:SavePrefsFailed', 'Could not save preferences: %s', ME.message);
end
delete(obj.Fig);
end
