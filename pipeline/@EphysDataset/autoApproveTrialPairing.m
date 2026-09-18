function [P, tf] = autoApproveTrialPairing(obj, P)
%autoApproveTrialPairing  Approve a pairing whose trial and interval counts match.
%   [P, TF] = ds.autoApproveTrialPairing(P) records P (pairTrials) in the
%   manifest as approved, marked automatic (auto_approved), when it is not
%   approved yet, cuts nothing, and the Epsych2 session has as many trials
%   as the trial line has intervals (at least one). TF says whether it did,
%   and P comes back with status, autoApproved, recorded and stale updated.
%   Anything else is left for review: a count mismatch, a pairing whose
%   cuts resolved one (those cuts are the user's to approve) and a pairing
%   that is already approved. A recorded "unreviewed" pairing without cuts
%   is approved like a new one. Behavior.AutoApprove turns this on for the
%   behavior step and for the app's Trials tab.
%
%   See also EphysDataset.pairTrials, EphysDataset.setTrialPairing.

arguments
    obj (1,1) EphysDataset
    P (1,1) struct
end

tf = P.status ~= "approved" && ~any(P.cutTrials) && ~any(P.cutIntervals) ...
    && P.nTrials > 0 && P.nTrials == P.nIntervals;
if ~tf; return; end
obj.setTrialPairing(P, "approved", Auto=true);
P.status = "approved";
P.autoApproved = true;
P.recorded = true;
P.stale = false;
end
