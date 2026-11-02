function [file, saved] = setTrialPairing(obj, P, status, opts)
%setTrialPairing  Record (or approve) a trial pairing in the manifest.
%   ds.setTrialPairing(P) records the cuts of P (pairTrials: trials and
%   trial-line intervals dropped from the start or the end, and single
%   intervals dropped from the middle, dropIntervals) as "unreviewed";
%   ds.setTrialPairing(P, "approved") marks it reviewed. The record
%   (TrialPairing) is written to the manifest under behavior.pairing, and
%   later pairTrials calls reuse it while the session and the trial-line
%   intervals match its fingerprint. ds.setTrialPairing([]) clears it.
%
%   An existing <outputFolder>/<Name>_behavior.mat is rewritten with P
%   (behaviorToMat) unless it already carries this record (status, cuts,
%   drops, fingerprint; read from the file's small pairing variable, not the
%   trials), so the status the analysis and the exports read from that
%   file follows every approval, automatic ones included. No behavior file
%   is created here. FILE is the behavior file rewritten, "" when there was
%   none to rewrite; a failed rewrite warns
%   (EphysDataset:setTrialPairing:BehaviorFile) and returns "".
%
%   [FILE, SAVED] = ds.setTrialPairing(...) also says whether the manifest
%   was written (writeManifest): when it was not, the record holds only in
%   this dataset object, and writeManifest has warned why.
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
        'drop_intervals', double(reshape(P.dropIntervals, 1, [])), ...
        'fingerprint', string(P.fingerprint), 'trial_line', string(P.trialLine), ...
        'summary', string(P.summary), ...
        'updated', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end
saved = obj.writeManifest();
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
    if ismember('pairing', who('-file', file))    % a file without the copy is rewritten
        B = load(file, 'pairing');                % the small copy of behavior.pairing, not the trials
        if carries(B.pairing, rec)
            file = "";
            return
        end
    end
    P.status = rec.status;
    P.autoApproved = rec.auto_approved;
    obj.behaviorToMat(File=file, Overwrite=true, Pairing=P);
    obj.writeManifest();   % its processing block: how the file was made
catch ME
    warning('EphysDataset:setTrialPairing:BehaviorFile', ...
        'The trial pairing of %s is recorded in the manifest, but %s could not be rewritten: %s', ...
        obj.Name, file, ME.message);
    file = "";
end
end


function tf = carries(p, rec)
%carries  True when the behavior file's pairing summary P already holds the pairing record REC.
tf = false;
if ~isstruct(p) || ~isscalar(p); return; end
if ~all(isfield(p, {'status' 'autoApproved' 'cutTrials' 'cutIntervals' 'dropIntervals' 'fingerprint' 'trialLine'})); return; end
tf = string(p.status) == rec.status && logical(p.autoApproved) == rec.auto_approved ...
    && isequal(double(reshape(p.cutTrials, 1, [])), rec.cut_trials) ...
    && isequal(double(reshape(p.cutIntervals, 1, [])), rec.cut_intervals) ...
    && isequal(double(reshape(p.dropIntervals, 1, [])), double(reshape(rec.drop_intervals, 1, []))) ...
    && string(p.fingerprint) == rec.fingerprint && string(p.trialLine) == rec.trial_line;
end
