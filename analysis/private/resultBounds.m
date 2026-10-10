function [lo, hi, E] = resultBounds(R, meanField)
%resultBounds  A compute result's error band: the edges R.err holds, or R.(MEANFIELD) +/- R.sem.
%   [LO, HI, E] = resultBounds(R, MEANFIELD): with R.err (spikePSTH,
%   evokedPotential, firingRate, tuningCurve, behaviorValues and auxMean
%   make it: type, lo, hi, over, nBoot) its lo and hi, and E = R.err; a
%   result without one (made by hand, or before error types) has its mean
%   +/- SEM, and E says so (type "sem", over "epochs").
%
%   See also errorBounds, errorPatch.
if isfield(R, 'err') && isstruct(R.err) && all(isfield(R.err, {'type' 'lo' 'hi'}))
    lo = R.err.lo;
    hi = R.err.hi;
    E = R.err;
    return
end
m = R.(meanField);
lo = m - R.sem;
hi = m + R.sem;
E = struct('type', "sem", 'lo', lo, 'hi', hi, 'over', "epochs", 'nBoot', NaN);
end
