function setTrialPairing(obj, P, status, opts)
%setTrialPairing  Record (or approve) a trial pairing in the manifest.
%   ds.setTrialPairing(P) records the cuts of P (pairTrials: trials and
%   trial-line intervals dropped from the start or the end) as "unreviewed";
%   ds.setTrialPairing(P, "approved") marks it reviewed. The record
%   (TrialPairing) is written to the manifest under behavior.pairing, and
%   later pairTrials calls reuse it while the session and the trial-line
%   intervals match its fingerprint. ds.setTrialPairing([]) clears it.
%
%   Options
%     Auto   false (default): true records an approval as automatic
%            (auto_approved; see autoApproveTrialPairing)
%
%   See also EphysDataset.pairTrials, EphysDataset.autoApproveTrialPairing,
%   pairEpsychTrials.

arguments
    obj (1,1) EphysDataset
    P
    status (1,1) string {mustBeMember(status, ["unreviewed" "approved"])} = "unreviewed"
    opts.Auto (1,1) logical = false
end

if isempty(P)
    obj.TrialPairing = struct([]);
else
    obj.TrialPairing = struct('status', status, ...
        'auto_approved', opts.Auto && status == "approved", ...
        'cut_trials', double(reshape(P.cutTrials, 1, 2)), ...
        'cut_intervals', double(reshape(P.cutIntervals, 1, 2)), ...
        'fingerprint', string(P.fingerprint), 'trial_line', string(P.trialLine), ...
        'summary', string(P.summary), ...
        'updated', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end
obj.writeManifest();
end
