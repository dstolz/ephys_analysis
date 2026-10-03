function qc = judgeUnits(units, criteria)
%judgeUnits  The Review tab's QC verdicts: unitQualityPass of UNITS under CRITERIA.
%   QC.has is false when the units carry no quality metrics (then pass,
%   why and unknown are empty).
qc = struct('has', false, 'pass', false(0, 1), 'why', strings(0, 1), 'unknown', strings(0, 1));
if ~isfield(units, 'presenceRatio')
    return
end
[qc.pass, qc.why, qc.unknown] = unitQualityPass(units, criteria);
qc.has = true;
end
