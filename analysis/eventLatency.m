function [lat, label] = eventLatency(src, E, ref)
%eventLatency  Each epoch's latency to an event: e.g. a raster's sort key.
%   [LAT, LABEL] = eventLatency(SRC, E, REF) is, for every epoch of E
%   (epochTable) of the dataset SRC (loadAnalysisSource), the time in s
%   from the epoch's event t0 to the event of the eventRef REF (a struct or
%   a line name) that follows it, found as epochTable finds a stop event:
%   the first (REF.which) event of REF at or after t0, in the epoch's own
%   trial (its TrialEvents, so the offset of an interval that runs on past
%   the trial still counts) when the epoch has one and REF's scope is
%   "trial" or "auto", else over the recording. REF.offsetSec,
%   REF.offsetParam and REF.sequence apply as they do to a stop event. LAT
%   is [height(E) x 1], NaN where no such event follows. LABEL names the
%   event: its eventRefLabel, with REF.which when it is "last" or "nth"
%   ("last Platform offset") and its shifts ("RespWindow onset +
%   RespLatency (ms)", " +0.05 s"). Pure: no I/O, no graphics.
%
%   E.g. eventLatency(src, E, eventRef(line="Platform", edge="offset")) is
%   how long after each epoch's event the animal left the platform;
%   renderRaster(..., SortBy="event") sorts the rows by it (R.rasterSortEvent,
%   with fields label and t).
%
%   Errors: resolveEvents:NoLine (a line the recording lacks), eventRef's.
%
%   See also epochTable, epochWindow, epochEvents, renderRaster.

arguments
    src (1,1) struct
    E table
    ref
end

ref = eventRef(ref);
lat = stopTimes(src, ref, E.t0(:), E.trial(:)) - E.t0(:);
label = eventRefLabel(ref);
switch ref.which
    case "last", label = "last " + label;
    case "nth",  label = ordinal(ref.n) + " " + label;
end
if ref.offsetParam ~= ""; label = label + " + " + ref.offsetParam + " (" + ref.offsetParamUnit + ")"; end
if ref.offsetSec ~= 0; label = label + sprintf(" %+g s", ref.offsetSec); end
end


function s = ordinal(n)
suffix = "th";
if mod(n, 100) < 11 || mod(n, 100) > 13
    switch mod(n, 10)
        case 1, suffix = "st";
        case 2, suffix = "nd";
        case 3, suffix = "rd";
    end
end
s = n + suffix;
end
