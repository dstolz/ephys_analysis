function [trials, info, meta] = readBehavior(obj)
%readBehavior  Load the trials of this dataset: its Epsych2 session, or its TDT epocs.
%   [TRIALS, INFO, META] = ds.readBehavior() is readEpsychSession on
%   ds.BehaviorFile (set it directly, through the manifest, or with the
%   pipeline's behavior step / the app's Project tab). Without a session,
%   a TDT block whose TrialConfig.TrialLine is one of its epoc stores gives
%   the trials (behaviorSource "epocs"): one per epoc of that store on the
%   stream, in order, with a column per epoc store (the trial store's
%   values, and each other store's value at the trial's onset, NaN when
%   none is active; not "Tick"), in the same shapes as readEpsychSession:
%   INFO.Source is "TDT epocs" and INFO.WriteParams lists the parameter
%   columns; META.file is "" and META.responseCodeField "" (no response
%   codes). Errors with EphysDataset:readBehavior:NoFile when there is
%   neither.
%
%   See also readEpsychSession, EphysDataset.behaviorSource,
%   TDTReader.epocTrials, EphysDataset.behaviorStruct, matchEpsychSession.

[src, store] = obj.behaviorSource();
if src == "epocs"
    [trials, info, meta] = epocBehavior(obj, store);
    return
end
if obj.BehaviorFile == ""
    error('EphysDataset:readBehavior:NoFile', ...
        'No behavior file is associated with %s (set BehaviorFile), and it has no epoc store named by the trial line.', obj.Name);
end
if ~isfile(obj.BehaviorFile)
    error('EphysDataset:readBehavior:NoFile', ...
        'Behavior file not found: %s', obj.BehaviorFile);
end
[trials, info, meta] = readEpsychSession(obj.BehaviorFile);
end
