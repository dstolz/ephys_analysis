function [trials, info, meta] = readBehavior(obj)
%readBehavior  Load the Epsych2 session associated with this dataset.
%   [TRIALS, INFO, META] = ds.readBehavior() is readEpsychSession on
%   ds.BehaviorFile (set it directly, through the manifest, or with the
%   pipeline's behavior step / the app's Project tab). Errors with
%   EphysDataset:readBehavior:NoFile when none is associated.
%
%   See also readEpsychSession, EphysDataset.behaviorStruct,
%   matchEpsychSession.

if obj.BehaviorFile == ""
    error('EphysDataset:readBehavior:NoFile', ...
        'No behavior file is associated with %s (set BehaviorFile).', obj.Name);
end
if ~isfile(obj.BehaviorFile)
    error('EphysDataset:readBehavior:NoFile', ...
        'Behavior file not found: %s', obj.BehaviorFile);
end
[trials, info, meta] = readEpsychSession(obj.BehaviorFile);
end
