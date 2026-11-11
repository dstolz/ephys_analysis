function [y, Z, fRow] = logFrequencyRows(f, Z, maxRows)
%logFrequencyRows  A map over frequency on rows evenly spaced in log10 frequency, for a log frequency axis.
%   [Y, Z, FROW] = logFrequencyRows(F, Z) puts Z (its rows at the ascending
%   frequencies F, Hz: a spectrogram's [nF x nT], or [nF x nT x n]) on rows
%   evenly spaced in log10(Hz): Y (a column) the rows' centers in log10 Hz,
%   Z each row's bin's values (a bin repeated over the rows it spans:
%   nothing interpolated), FROW each row's bin's frequency, Hz. F's bins
%   reach from the midpoint with the bin below to the midpoint with the one
%   above (the outer ones as wide as their inner halves). A frequency at or
%   below 0 (the 0 Hz bin) has no place on a log axis and is left out; with
%   none above 0, Y, Z and FROW are empty. The rows are as many as make the
%   narrowest bin (the top one) at least one row high, at most MAXROWS
%   (default 4096; beyond that the narrowest bins share rows).
%
%   MATLAB spreads an image's rows evenly over a log axis too, so on one
%   they sit at the wrong frequencies. A log frequency axis is therefore a
%   linear axis of log10 Hz carrying this image, labeled in Hz by
%   logFrequencyTicks.
%
%   See also logFrequencyTicks, drawSpectrogramPanel, renderChronux.
arguments
    f double
    Z
    maxRows (1,1) double {mustBePositive} = 4096
end
f = reshape(f, [], 1);
sz = size(Z);
keep = find(f > 0);
if isempty(keep)
    y = zeros(0, 1);
    fRow = zeros(0, 1);
    Z = reshape(Z([], :), [0 sz(2:end)]);
    return
end
fk = f(keep);
if isscalar(fk)
    e = fk * [1 / sqrt(2); sqrt(2)];   % (one bin: half an octave either side)
else
    mid = (fk(1:end-1) + fk(2:end)) / 2;
    lo = 2 * fk(1) - mid(1);
    if lo <= 0; lo = fk(1) ^ 2 / mid(1); end   % (a first bin reaching 0: as wide in log10 as its upper half)
    e = [lo; mid; 2 * fk(end) - mid(end)];
end
e = log10(e);
n = min(maxRows, max(numel(fk), ceil((e(end) - e(1)) / min(diff(e)))));
y = e(1) + (e(end) - e(1)) * ((1:n).' - 0.5) / n;
idx = keep(discretize(y, e));
Z = reshape(Z(idx, :), [n sz(2:end)]);
fRow = f(idx);
end
