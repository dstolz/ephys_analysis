function A = aurocCall(A, opts)
%aurocCall  Call units modulated up, down or not from their auROC, the cutoff taken over every unit given.
%   A = aurocCall(A, Cutoff=, Threshold=, Correction=, Alpha=) calls every
%   unit and group of A: aurocCurves' result, or any struct with its mean,
%   phasic and p [nUnits x nGroups] (the mean auROC, the mean |auROC - 0.5|
%   over the windows inside the modulation window, and the test's p).
%     "ci"      (default) as in Macedo-Lima, Hamlette & Caras 2024: c is the
%               upper bound of the 95% confidence interval of the mean
%               phasic modulation over every unit and group of A,
%               mean + t(0.975, n-1) x SD / sqrt(n) (tinv). A unit is
%               modulated upwards when its mean auROC is above 0.5 + c,
%               downwards when below 0.5 - c
%     "fixed"   the same with c = Threshold
%     "test"    p adjusted over every unit and group of A (pAdjust,
%               Correction); modulated when q is at most Alpha, upwards when
%               the mean auROC is above 0.5, downwards when below
%     "none"    no call
%   So the units of A are the pool. aurocCurves calls the units it measured;
%   to pool more (the paper pooled its 533 units), stack the mean, phasic
%   and p rows of several aurocCurves(..., Call=false) results and call them
%   together, as populationAnalysis does over its Family.
%
%   A gains (or has replaced) q, direction ("increase" | "decrease" |
%   "none"; "" for a unit and group with no mean auROC, or without a call),
%   modulated, cutoff (the Cutoff), cutoffValue (c; NaN for "test" and
%   "none") and nModulated / nIncrease / nDecrease [nGroups x 1].
%
%   Errors: aurocCall:BadOption, aurocCall:NoToolbox ("ci" needs tinv, of
%   the Statistics and Machine Learning Toolbox). Warnings (the "ci"
%   cutoff): aurocCall:NoCutoff (fewer than two units and groups with a
%   phasic modulation), aurocCall:WideCutoff (c >= 0.5, so no unit can be
%   called: too few units for the interval).
%
%   See also aurocCurves, populationAnalysis, pAdjust, tinv.

arguments
    A (1,1) struct
    opts.Cutoff (1,1) string = "ci"
    opts.Threshold (1,1) double = 0.1
    opts.Correction (1,1) string = "bh"
    opts.Alpha (1,1) double = 0.05
end

if ~ismember(opts.Cutoff, ["ci" "fixed" "test" "none"])
    error('aurocCall:BadOption', 'Cutoff is ci, fixed, test or none (got "%s").', opts.Cutoff);
end
if ~ismember(opts.Correction, ["bh" "holm" "bonferroni" "none"])
    error('aurocCall:BadOption', 'Correction is bh, holm, bonferroni or none (got "%s").', opts.Correction);
end
if ~(opts.Alpha > 0 && opts.Alpha <= 1)
    error('aurocCall:BadOption', 'Alpha must be in (0, 1] (got %g).', opts.Alpha);
end
if ~(opts.Threshold >= 0 && opts.Threshold < 0.5)
    error('aurocCall:BadOption', 'Threshold is |auROC - 0.5| and must be in [0, 0.5) (got %g).', opts.Threshold);
end
if opts.Cutoff == "ci" && ~(license('test', 'Statistics_Toolbox') && exist('tinv', 'file') > 0)
    error('aurocCall:NoToolbox', 'The 95%% CI cutoff needs the Statistics and Machine Learning Toolbox (tinv).');
end
mn = A.mean;
ph = A.phasic;
q = NaN(size(mn));
if opts.Cutoff == "test"; q(:) = pAdjust(A.p(:), opts.Correction); end
direction = strings(size(mn));
up = false(size(mn)); dn = false(size(mn));
c = NaN;
switch opts.Cutoff
    case "ci"
        v = ph(isfinite(ph));
        n = numel(v);
        if n >= 2
            c = mean(v) + tinv(0.975, n - 1) * std(v) / sqrt(n);
            if c >= 0.5
                warning('aurocCall:WideCutoff', ['The 95%% CI cutoff is +/-%.3g around 0.5, beyond the auROC''s ' ...
                    'range: with %d unit(s) and groups it is too wide to call any unit modulated. Pool more ' ...
                    'units (populationAnalysis), or use the fixed or test cutoff.'], c, n);
            end
        else
            warning('aurocCall:NoCutoff', ['The 95%% CI cutoff needs the phasic modulation of at least two ' ...
                'units (or groups); there is %d, so no unit is called modulated.'], n);
        end
    case "fixed"
        c = opts.Threshold;
end
switch opts.Cutoff
    case {"ci" "fixed"}
        up = mn > 0.5 + c;
        dn = mn < 0.5 - c;
    case "test"
        sig = q <= opts.Alpha;
        up = sig & mn > 0.5;
        dn = sig & mn < 0.5;
end
if opts.Cutoff ~= "none"
    direction(isfinite(mn)) = "none";
    direction(up) = "increase";
    direction(dn) = "decrease";
end
A.q = q;
A.direction = direction;
A.modulated = up | dn;
A.cutoff = opts.Cutoff;
A.cutoffValue = c;
A.nModulated = sum(up | dn, 1).';
A.nIncrease = sum(up, 1).';
A.nDecrease = sum(dn, 1).';
end
