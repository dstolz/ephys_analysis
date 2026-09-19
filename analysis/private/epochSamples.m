function [X, inside] = epochSamples(Y, base, s0, s1)
%epochSamples  Cut one epoch of a signal, NaN where it leaves the recording.
%   [X, INSIDE] = epochSamples(Y, BASE, S0, S1) returns rows BASE + (S0:S1)
%   of Y ([nSamples x nChan]) as a double [S1-S0+1 x nChan] block; rows
%   outside 1..nSamples are NaN and INSIDE is false. BASE is the event's
%   row under the "event" rule, round(t * Fs) for a digital-event time t
%   (ChronuxDataset.trials OnsetRule "event", TrialOnsetSample_<SIG>), so
%   offset 0 is the sample that produced the event.

rows = base + (s0:s1).';
ok = rows >= 1 & rows <= size(Y, 1);
X = NaN(numel(rows), size(Y, 2));
X(ok, :) = double(Y(rows(ok), :));
inside = all(ok);
end
