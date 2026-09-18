function tf = associateFolderBehavior(obj)
%associateFolderBehavior  Associate the Epsych2 session file kept in the recording folder.
%   TF = ds.associateFolderBehavior() sets BehaviorFile when none is
%   associated (BehaviorFile is "" or no longer exists) and the recording
%   folder holds exactly one Epsych2 session file (a .mat with Data and
%   Info) at its top level. That is where the app's Copy tab puts a
%   session's ePsych file, or its stitched file, next to the recording.
%   Returns true when it set BehaviorFile. With none, or several, nothing
%   changes: several files are left to the behavior step or to the user.
%   The manifest is not written here (EphysProject.refresh writes it).
%
%   The behavior, signals, spikes and export outputs do not hold Data and
%   Info, so an output folder next to the recording is never mistaken for
%   one.
%
%   See also findEpsychSessions, EphysProject.refresh, matchEpsychSession.

tf = false;
if obj.BehaviorFile ~= "" && isfile(obj.BehaviorFile); return; end
if obj.Folder == "" || ~isfolder(obj.Folder); return; end
T = findEpsychSessions(obj.Folder, Recursive=false);
if height(T) ~= 1; return; end
obj.BehaviorFile = T.File(1);
tf = true;
end
