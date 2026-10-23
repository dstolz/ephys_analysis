function S = epochSpikes(spikeTimes, E)
%epochSpikes  The spikes inside each epoch's window, s from its event.
%   S = epochSpikes(ST, E) cuts the spike trains ST ({nUnits x 1} spike
%   times, s, on the continuous clock: selectUnits; or one vector) into the
%   epochs of E (epochTable): S{e, u} is unit u's spikes inside epoch e's
%   window [tStart, tStop], s from the epoch's event, a column, in time
%   order. As spikePSTH's raster, the spikes are taken relative to
%   t0Continuous, the event on the spikes' clock, so a spike in the
%   event's own sample is at 0; the window, given on the clock of t0, is
%   moved there by the same shift. Both ends are in (a spike within 1e-9 s
%   of an end counts), and a spike inside two overlapping windows is in
%   both. Pure: no I/O, no graphics.
%
%   See also epochTable, figureEpochs, selectUnits, spikePSTH, epochEvents.

arguments
    spikeTimes
    E table
end

st = spikeTimes;
if ~iscell(st); st = {st}; end
st = st(:);
tol = 1e-9;   % s: an end's rounding (spikes and events on one sample grid)
a = double(E.t0Continuous(:));
shift = a - double(E.t0(:));
lo = double(E.tStart(:)) + shift - tol;   % the windows on the spikes' clock
hi = double(E.tStop(:)) + shift + tol;
nE = height(E);
nU = numel(st);
S = cell(nE, nU);
for u = 1:nU
    s = double(st{u}(:));
    if ~issorted(s); s = sort(s); end
    i1 = countBelow(s, lo) + 1;   % the first spike in each window
    i2 = countBelow(s, hi);       % ... and the last (NaN: a window that is not finite)
    for e = 1:nE
        if i2(e) >= i1(e)
            S{e, u} = s(i1(e):i2(e)) - a(e);
        else
            S{e, u} = zeros(0, 1);
        end
    end
end
end
