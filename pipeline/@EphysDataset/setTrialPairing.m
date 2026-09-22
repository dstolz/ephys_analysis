function file = setTrialPairing(obj, P, status, opts)
%setTrialPairing  Record (or approve) a trial pairing in the manifest.
%   ds.setTrialPairing(P) records the cuts of P (pairTrials: trials and
%   trial-line intervals dropped from the start or the end) as "unreviewed";
%   ds.setTrialPairing(P, "approved") marks it reviewed. The record
%   (TrialPairing) is written to the manifest under behavior.pairing, and
%   later pairTrials calls reuse it while the session and the trial-line
%   intervals match its fingerprint. ds.setTrialPairing([]) clears it.
%
%   An existing <outputFolder>/<Name>_behavior.mat is rewritten with P
%   (behaviorToMat) unless it already carries this record (status, cuts,
%   fingerprint), so the status the analysis and the exports read from that
%   file follows every approval, automatic ones included. No behavior file
%   is created here. FILE is the behavior file rewritten, "" when there was
%   none to rewrite; a failed rewrite warns
%   (EphysDataset:setTrialPairing:BehaviorFile) and returns "".
%
%   Options
%     Auto   false (default): true records an approval as automatic
%            (auto_approved; see autoApproveTrialPairing)
%
%   See also EphysDataset.pairTrials, EphysDataset.autoApproveTrialPairing,
%   EphysDataset.behaviorToMat, pairEpsychTrials.

arguments
    obj (1,1) EphysDataset
    P
    status (1,1) string {mustBeMember(status, ["unreviewed" "approved"])} = "unreviewed"
    opts.Auto (1,1) logical = false
end

file = "";
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
if ~isempty(P)
    file = updateBehaviorFile(obj, P, obj.TrialPairing);
end
end


function file = updateBehaviorFile(obj, P, rec)
%updateBehaviorFile  Rewrite <Name>_behavior.mat when its pairing is not REC.
file = string(fullfile(obj.outputFolder(), obj.Name + "_behavior.mat"));   % behaviorToMat's default
if ~isfile(file) || ~isfield(P, 'columns')
    file = "";
    return
end
try
    B = load(file, 'behavior');
    if isfield(B, 'behavior') && carries(B.behavior, rec)
        file = "";
        return
    end
    P.status = rec.status;
    P.autoApproved = rec.auto_approved;
    obj.behaviorToMat(File=file, Overwrite=true, Pairing=P);
catch ME
    warning('EphysDataset:setTrialPairing:BehaviorFile', ...
        'The trial pairing of %s is recorded in the manifest, but %s could not be rewritten: %s', ...
        obj.Name, file, ME.message);
    file = "";
end
end


function tf = carries(b, rec)
%carries  True when the behavior struct B already holds the pairing record REC.
tf = false;
if ~isfield(b, 'pairing') || ~isstruct(b.pairing) || ~isscalar(b.pairing); return; end
p = b.pairing;
if ~all(isfield(p, {'status' 'autoApproved' 'cutTrials' 'cutIntervals' 'fingerprint' 'trialLine'})); return; end
tf = string(p.status) == rec.status && logical(p.autoApproved) == rec.auto_approved ...
    && isequal(double(reshape(p.cutTrials, 1, [])), rec.cut_trials) ...
    && isequal(double(reshape(p.cutIntervals, 1, [])), rec.cut_intervals) ...
    && string(p.fingerprint) == rec.fingerprint && string(p.trialLine) == rec.trial_line;
end
