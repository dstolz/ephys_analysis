function onTrialsCutsChanged(obj)
%onTrialsCutsChanged  A cut spinner changed: re-pair with the cuts shown.
%   Nothing is saved until Approve (or Mark unreviewed).
s = obj.TrialsCutSpinners;
cuts = struct('trials', [s(1, 1).Value, s(1, 2).Value], 'intervals', [s(2, 1).Value, s(2, 2).Value]);
obj.repairTrials(cuts);
end
