function [rate, sem, label, lo, hi, p] = normalizeRates(R, mode)
%normalizeRates  R.rate / R.sem and the error band's edges divided per unit ("unitPeak") or per PSTH ("groupPeak").
%   [RATE, SEM, LABEL, LO, HI, P] = normalizeRates(R, MODE) for a
%   spikePSTH result R and MODE "none" | "unitPeak" | "groupPeak" |
%   "allPeak" (a PSTH plot's normalize, a PSTH panel's options.normalize).
%   The divisor is the largest absolute value (the peak, for rates); a
%   unit or PSTH with none is NaN. LABEL is the y axis label of what comes
%   back. LO / HI: the band R.err holds (resultBounds), divided the same
%   way. P: the divisor ([] for "none"), for the member sessions
%   (memberRates). Used by drawPsthPanel.
%
%   See also drawPsthPanel.
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
