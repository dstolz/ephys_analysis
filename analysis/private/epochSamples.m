function [X, inside] = epochSamples(Y, base, s0, s1, cols)
%epochSamples  Cut one epoch of a signal, NaN where it leaves the recording.
%   [X, INSIDE] = epochSamples(Y, BASE, S0, S1, COLS) returns rows
%   BASE + (S0:S1) of the columns COLS of Y ([nSamples x nChan]) as a double
%   [S1-S0+1 x numel(COLS)] block, read straight from Y (no copy of the
%   whole signal); rows outside 1..nSamples are NaN and INSIDE is false.
%   BASE is the event's row, round(tc * Fs) + 1 for its time tc on the
%   continuous clock (E.t0Continuous: t - 1/Fs of the recording for a
%   digital-event time t = row/Fs), so offset 0 is the sample nearest the
%   one that produced the event.

rows = base + (s0:s1).';
ok = rows >= 1 & rows <= size(Y, 1);
X = NaN(numel(rows), numel(cols));
X(ok, :) = double(Y(rows(ok), cols));
inside = all(ok);
end
