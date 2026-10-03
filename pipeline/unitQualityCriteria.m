function c = unitQualityCriteria()
%unitQualityCriteria  Default good-unit criteria on the quality metrics (unitQualityPass).
%   C = unitQualityCriteria() returns the thresholds unitQualityPass applies,
%   one field per metric of unitQualityMetrics; NaN leaves a metric out:
%     isiViolationsRatioMax  0.5   pass when isiViolationsRatio < 0.5
%     presenceRatioMin       0.9   pass when presenceRatio > 0.9
%     amplitudeCutoffMax     0.1   pass when amplitudeCutoff < 0.1
%     snrMin                 NaN
%     driftPtpMax            NaN   (um)
%     firingRateMin          NaN   (Hz)
%     unknown                "pass": a metric that could not be computed
%                            (NaN: e.g. the amplitude cutoff of a unit with
%                            fewer than 2500 spikes) does not fail a unit;
%                            "fail" makes it fail
%   The three thresholds set are the Allen Institute's for its Visual
%   Coding Neuropixels units (isi_violations < 0.5, amplitude_cutoff < 0.1,
%   presence_ratio > 0.9), with the strict inequalities used there. The
%   pipeline config keeps its copy in Sorting.Quality (the Review tab and the
%   QC report), the analysis config in UnitSelection.quality (selectUnits).
%
%   See also unitQualityPass, unitQualityMetrics.
c = struct( ...
    'isiViolationsRatioMax', 0.5, ...
    'presenceRatioMin',      0.9, ...
    'amplitudeCutoffMax',    0.1, ...
    'snrMin',                NaN, ...
    'driftPtpMax',           NaN, ...
    'firingRateMin',         NaN, ...
    'unknown',               "pass");
end
