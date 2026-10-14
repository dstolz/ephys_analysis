function [rate, sem, label, lo, hi, p] = figNormalizeRates(R, mode)
%figNormalizeRates  R.rate / R.sem and the error band's edges divided per unit ("unitPeak") or per PSTH ("groupPeak").
%   [RATE, SEM, LABEL, LO, HI, P] = figNormalizeRates(R, MODE) for a
%   spikePSTH result R and MODE "none" | "unitPeak" | "groupPeak" |
%   "allPeak" (a PSTH panel's options.normalize). The divisor is the
%   largest absolute value (the peak, for rates); a unit or PSTH with none
%   is NaN. LABEL is the y axis label of what comes back. LO / HI: the band
%   R.err holds (resultBounds), divided the same way. P: the divisor ([]
%   for "none").
%
%   A copy of renderPSTH's local normalizeRates, so that no existing
%   renderer changes in phase 1 of the modular figures; phase 2
%   consolidates the two into one shared helper.
%
%   See also drawPsthPanel, renderPSTH.
p = [];
rate = R.rate;
sem = R.sem;
[lo, hi] = resultBounds(R, 'rate');
label = R.units;
switch mode
    case "unitPeak"
        p = max(abs(rate), [], [1 3]);
        label = "Normalized (unit peak = 1)";
    case "groupPeak"
        p = max(abs(rate), [], 1);
        label = "Normalized (each peak = 1)";
    case "allPeak"
        p = max(abs(rate), [], "all");
        label = "Normalized (overall peak = 1)";
    otherwise
        return
end
p(~(p > 0)) = NaN;
rate = rate ./ p;
sem = sem ./ p;
lo = lo ./ p;
hi = hi ./ p;
end
