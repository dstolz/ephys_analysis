function b = behaviorStruct(obj)
%behaviorStruct  The associated Epsych2 session as one struct, or [].
%   B = ds.behaviorStruct() loads BehaviorFile (see readBehavior) and packs
%   it for the exporters (toMat, spikesToMat, exportChronux, exportFieldTrip
%   save it as the "behavior" variable):
%     trials     table, one row per trial (readEpsychSession)
%     info       the Epsych2 Info snapshot
%     meta       file, stem, subject, startTime, nTrials, responseCodeField...
%     file, subject, startTime, nTrials   copied from meta for convenience
%   Returns [] when no behavior file is associated or it no longer exists.
%
%   See also EphysDataset.readBehavior, readEpsychSession.

b = [];
if obj.BehaviorFile == "" || ~isfile(obj.BehaviorFile)
    return
end
[trials, info, meta] = readEpsychSession(obj.BehaviorFile);
b = struct('trials', trials, 'info', info, 'meta', meta, 'file', obj.BehaviorFile, ...
    'subject', meta.subject, 'startTime', meta.startTime, 'nTrials', meta.nTrials);
end
