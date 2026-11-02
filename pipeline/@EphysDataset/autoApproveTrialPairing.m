function [P, tf] = autoApproveTrialPairing(obj, P)
%autoApproveTrialPairing  Approve a pairing whose trial and interval counts match.
%   [P, TF] = ds.autoApproveTrialPairing(P) records P (pairTrials) in the
%   manifest as approved, marked automatic (auto_approved), when it is not
%   approved yet, cuts and drops nothing, the Epsych2 session has as many
%   trials as the trial line has intervals (at least one), the Epsych2
%   timestamps agree with the line's trial ends (P.timingMismatch is 0) and
%   no trial is paired with an interval cut off by the recording start or
%   end (no "partial" flag). TF says whether it did, and P comes back with
%   status, autoApproved, recorded and stale updated. Anything else is left
%   for review: a count mismatch, a timing mismatch (counts that agree by
%   chance, e.g. one glitch pulse and one missing pulse), a partial edge
%   interval, a pairing whose cuts or drops resolved a mismatch (those are
%   the user's to approve) and a pairing that is already approved. A
%   recorded "unreviewed" pairing without cuts is approved like a new one.
%   Behavior.AutoApprove turns this on for the behavior step and for the
%   app's Trials tab.
%
%   See also EphysDataset.pairTrials, EphysDataset.setTrialPairing.

arguments
    obj (1,1) EphysDataset
    P (1,1) struct
end

tf = P.status ~= "approved" && ~any(P.cutTrials) && ~any(P.cutIntervals) && isempty(P.dropIntervals) ...
    && P.nTrials > 0 && P.nTrials == P.nIntervals && P.timingMismatch == 0 && ~any(P.flag == "partial");
if ~tf; return; end
obj.setTrialPairing(P, "approved", Auto=true);
P.status = "approved";
P.autoApproved = true;
P.recorded = true;
P.stale = false;
end
