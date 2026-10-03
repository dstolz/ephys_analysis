function [pass, why, unknown] = unitQualityPass(Q, criteria)
%unitQualityPass  Which units meet the good-unit criteria on their quality metrics.
%   [PASS, WHY, UNKNOWN] = unitQualityPass(Q, CRITERIA) judges each unit of
%   Q - a units struct with the metric fields (EphysDataset.unitQuality,
%   readSortedUnits(Quality=true)), a unitTable, or the table unitQuality
%   returns - against CRITERIA (default unitQualityCriteria()):
%     PASS     [nUnits x 1] logical
%     WHY      [nUnits x 1] string: the criteria the unit fails, e.g.
%              "isiViolationsRatio 1.09 >= 0.5; presenceRatio 0.67 <= 0.9"
%              ("" when it passes)
%     UNKNOWN  [nUnits x 1] string: the criteria that could not be judged
%              because the metric is NaN (they pass or fail as
%              CRITERIA.unknown says)
%   A criterion whose threshold is NaN is not applied; a metric missing
%   from Q entirely is unknown for every unit.
%
%   See also unitQualityCriteria, unitQualityMetrics, EphysDataset.unitQuality.

arguments
    Q
    criteria (1,1) struct = unitQualityCriteria()
end
c = unitQualityCriteria();
for f = string(fieldnames(criteria)).'
    if ~isfield(c, f)
        error('unitQualityPass:BadCriterion', 'Unknown criterion "%s" (see unitQualityCriteria).', f);
    end
    c.(f) = criteria.(f);
end
if ~ismember(string(c.unknown), ["pass" "fail"])
    error('unitQualityPass:BadCriterion', 'criteria.unknown must be "pass" or "fail".');
end
if istable(Q)
    n = height(Q);
    get = @(m) Q.(m);
    has = @(m) ismember(m, Q.Properties.VariableNames);
elseif isstruct(Q) && isfield(Q, 'unitId')
    n = numel(Q.unitId);
    get = @(m) Q.(m);
    has = @(m) isfield(Q, m);
else
    error('unitQualityPass:BadInput', 'Q must be a units struct or a table of quality metrics.');
end
rules = [ ...
    "isiViolationsRatio" "isiViolationsRatioMax" "max"; ...
    "presenceRatio"      "presenceRatioMin"      "min"; ...
    "amplitudeCutoff"    "amplitudeCutoffMax"    "max"; ...
    "snr"                "snrMin"                "min"; ...
    "driftPtp"           "driftPtpMax"           "max"; ...
    "firingRate"         "firingRateMin"         "min"];
pass = true(n, 1);
why = strings(n, 1);
unknown = strings(n, 1);
for r = 1:size(rules, 1)
    m = rules(r, 1); lim = c.(rules(r, 2));
    if isnan(lim); continue; end
    if has(m)
        v = double(reshape(get(m), [], 1));
    else
        v = nan(n, 1);
    end
    if rules(r, 3) == "max"
        bad = v >= lim; rel = " >= ";
    else
        bad = v <= lim; rel = " <= ";
    end
    nk = isnan(v);
    for i = find(bad).'
        why(i) = why(i) + "; " + m + " " + sprintf("%.3g", v(i)) + rel + sprintf("%.3g", lim);
    end
    for i = find(nk).'
        unknown(i) = unknown(i) + ", " + m;
    end
    pass = pass & ~bad;
    if c.unknown == "fail"
        pass = pass & ~nk;
    end
end
why = regexprep(why, '^; ', '');
unknown = regexprep(unknown, '^, ', '');
end
