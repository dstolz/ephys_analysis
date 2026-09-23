function tf = refuseWhileRunning(obj, what)
%refuseWhileRunning  Refuse an action that changes the datasets a run holds.
%   TF = obj.refuseWhileRunning(WHAT) is true, with an alert titled WHAT,
%   while a Run is under way. A blocking run lets the app respond between
%   its progress events and processes the scanned datasets themselves, so
%   a scan or a per-dataset edit (probe, exclusions, reference channels,
%   manual periods, sorted-output and behavior associations, trial
%   pairings) would reach it part way through.
tf = obj.RunActive;
if tf
    uialert(obj.Fig, "Wait for the run to finish (or Cancel it): " + what + ...
        " changes the datasets the run is processing.", what);
end
end
