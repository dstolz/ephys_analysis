function setTrialPairing(obj, P, status)
%setTrialPairing  Record (or approve) a trial pairing in the manifest.
%   ds.setTrialPairing(P) records the assignment of P (pairTrials) as
%   "unreviewed"; ds.setTrialPairing(P, "approved") marks it reviewed. The
%   record (TrialPairing) is written to the manifest under behavior.pairing,
%   and later pairTrials calls reuse it while the session and the trial-line
%   intervals match its fingerprint. ds.setTrialPairing([]) clears it.
%
%   See also EphysDataset.pairTrials, pairEpsychTrials.

arguments
    obj (1,1) EphysDataset
    P
    status (1,1) string {mustBeMember(status, ["unreviewed" "approved"])} = "unreviewed"
end

if isempty(P)
    obj.TrialPairing = struct([]);
else
    obj.TrialPairing = struct('status', status, 'assignment', {double(P.interval(:))}, ...
        'fingerprint', string(P.fingerprint), 'method', string(P.method), ...
        'trial_line', string(P.trialLine), 'summary', string(P.summary), ...
        'updated', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end
obj.writeManifest();
end
