function sp = chronuxOntoGrid(sp, tEnd)
%chronuxOntoGrid  Cut spike trials moved onto the analysis grid [0, tEnd].
%   SP = chronuxOntoGrid(SP, TEND): SP a struct array with field times (the
%   trials chronuxSpikeCut returns, stamped from the grid's start), TEND the
%   grid's last time (the last sample of the grid the analysis passes to
%   Chronux). A cut keeps the spikes a hair outside the grid (half a sample
%   for the spike-field analyses, whose cut is centered on the samples; up to
%   a sample after the last point for a window cut). Chronux's mtfftpt keeps
%   every spike of a trial when none of its spikes lies inside the grid, so a
%   trial whose only spikes sit in that margin would have its spectrum taken
%   with spikes outside the tapers (a NaN coherence, a wrong spectrum). Clamped
%   to the grid's ends they count where they round to.
%
%   See also chronuxSpikeCut, chronuxSpikeSpectrum, chronuxSpikeField, chronuxUnitCoherence.
for i = 1:numel(sp)
    sp(i).times = min(max(sp(i).times, 0), tEnd);
end
end
