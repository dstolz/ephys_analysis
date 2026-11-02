function s = latencyMethodText(L, form)
%latencyMethodText  A figure's latency block in words: how its first-spike latencies or its response onset are found.
%   S = latencyMethodText(L) for L, a figure's latency block
%   (defaults("Latency"); missing fields take their defaults), is the
%   per-trial rule as a caption says it, with its window and baseline:
%     "first"     "the first spike in [0 50] ms"
%     "surprise"  "the first spike of the first burst with a Poisson
%                 surprise of at least 3 (from 3 spikes; Legendy & Salcman
%                 1985) in [0 ms to the window's end], against the unit's
%                 baseline rate before the event"
%     "poisson"   "the spike at which the count of spikes since 0 ms first
%                 becomes improbable (p < 0.01) at the unit's baseline rate
%                 before the event (Chase & Young 2007), in [0 50] ms": the
%                 significance spike, which lags the response's first spike
%                 (firstSpikeLatency's latFirst)
%   S = latencyMethodText(L, "short") is the rule alone, for a data tip or
%   a row: "first spike", "Poisson surprise >= 3", "Poisson count
%   p < 0.01".
%   S = latencyMethodText(L, "onset") is the CUSUM onset's: "the CUSUM of
%   the PSTH in 2 ms bins over the baseline before the event (Page 1954;
%   Ellaway 1978), past 5 SD (an allowance of 1 SD a bin) for 5 ms, in
%   [0 ms to the window's end], kept where the unit's rate differs from its
%   baseline (signed rank test, p < 0.05)"; a fall ("down") or either way
%   ("both") is said after the bins.
%
%   See also figureCaption, figureLatencies, firstSpikeLatency, responseOnset.
arguments
    L (1,1) struct
    form (1,1) string {mustBeMember(form, ["long" "short" "onset"])} = "long"
end
L = EphysAnalysisConfig.normalizeSection("Latency", L);
win = windowText(L.minSec, L.maxSec);
base = "before the event";
if L.baseline == "window"; base = sprintf("in [%g %g] ms", 1000 * L.baselineWindow(1), 1000 * L.baselineWindow(end)); end
rate = "the unit's baseline rate";
if L.baselineRate == "trial"; rate = "each trial's baseline rate"; end
switch form
    case "short"
        switch L.method
            case "surprise", s = sprintf("Poisson surprise >= %g", L.surprise);
            case "poisson",  s = sprintf("Poisson count p < %g", L.alpha);
            otherwise,       s = "first spike";
        end
    case "onset"
        way = "";
        switch L.cusumDirection
            case "down", way = " (a fall)";
            case "both", way = " (a rise or a fall)";
        end
        gate = "";
        if L.cusumGate == "evoked"
            gate = sprintf(", kept where the unit's rate differs from its baseline (signed rank test, p < %g)", L.cusumGateAlpha);
        end
        s = sprintf("the CUSUM of the PSTH in %g ms bins%s over the baseline %s (Page 1954; Ellaway 1978), past %g SD " + ...
            "(an allowance of %g SD a bin) for %g ms, in %s%s", 1000 * L.cusumBinSec, way, base, L.cusumThreshold, ...
            L.cusumDrift, 1000 * L.cusumSustainSec, win, gate);
    otherwise
        switch L.method
            case "surprise"
                s = sprintf("the first spike of the first burst with a Poisson surprise of at least %g (from %d spikes; " + ...
                    "Legendy & Salcman 1985) in %s, against %s %s", L.surprise, L.minSpikes, win, rate, base);
            case "poisson"
                s = sprintf("the spike at which the count of spikes since %g ms first becomes improbable (p < %g) at %s %s " + ...
                    "(Chase & Young 2007), in %s", 1000 * L.minSec, L.alpha, rate, base, win);
            otherwise
                s = "the first spike in " + win;
        end
end
s = string(s);
end


function s = windowText(lo, hi)
%windowText  A latency window in ms: "[0 50] ms", "[5 ms to the window's end]".
if isfinite(hi)
    s = sprintf("[%g %g] ms", 1000 * lo, 1000 * hi);
else
    s = sprintf("[%g ms to the window's end]", 1000 * lo);
end
end
