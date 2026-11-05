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
%   event: its eventRefLabel with Detail=true, REF.which when it is
%   "last" or "nth" ("last Platform offset") and its shifts ("RespWindow
%   onset + RespLatency (ms)", " +0.05 s"). Pure: no I/O, no graphics.
%
%   E.g. eventLatency(src, E, eventRef(line="Platform", edge="offset")) is
%   how long after each epoch's event the animal left the platform;
%   a raster panel with rasterSort "event" sorts its rows by it
%   (R.rasterSortEvent, with fields label and t).
%
%   Errors: resolveEvents:NoLine (a line the recording lacks), eventRef's.
%
%   See also epochTable, epochWindow, epochEvents, figureCompute.

arguments
    src (1,1) struct
    E table
    ref
end

ref = eventRef(ref);
lat = stopTimes(src, ref, E.t0(:), E.trial(:)) - E.t0(:);
label = eventRefLabel(ref, Detail=true);
end
