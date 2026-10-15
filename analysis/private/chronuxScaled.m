function [Y, lo, hi] = chronuxScaled(S, lo, hi, scale)
%chronuxScaled  A Chronux power spectrum and its error bars in the scale drawn.
%   [Y, LO, HI] = chronuxScaled(S, LO, HI, SCALE): SCALE "db" gives
%   10*log10 of the power S and of its bars (the low bar clamped at realmin,
%   so a bar at or under zero stays finite); "log" and "linear" leave them
%   as they are ("log" is a log y axis, set by the caller). LO / HI may be
%   [] (no bars).
%
%   See also renderChronux, drawSpectrumPanel, chronuxAutoLimits.
Y = S;
if scale == "db"
    Y = 10 * log10(S);
    if ~isempty(lo); lo = 10 * log10(max(lo, realmin)); hi = 10 * log10(hi); end
end
end
