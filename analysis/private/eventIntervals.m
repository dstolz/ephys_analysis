function [on, off, hit, line] = eventIntervals(src, ref, t, shift)
%eventIntervals  The interval (onset and offset) of each event an event reference picked.
%   [ON, OFF, HIT, LINE] = eventIntervals(SRC, REF, T, SHIFT) takes the
%   events T [n x 1] of the eventRef REF that resolveEvents found in the
%   dataset SRC (loadAnalysisSource), with SHIFT [n x 1] what REF.offsetParam
%   moved each by (resolveEvents' fourth output), and finds the interval of
%   the line each one is an edge of: the line REF.line (a sequence's: the
%   line of the step REF.alignStep names, LINE; "Trial" is the trial line),
%   matched by its edge to within half a sample. ON and OFF [n x 1] are
%   that interval's onset and offset moved by what moved the event
%   (REF.offsetSec and SHIFT), on the clock of T; NaN where no interval of
%   the line has the event's edge (HIT false). Pure: no I/O, no graphics.
%   Errors: resolveEvents:NoLine (the line is not in SRC.events).
%
%   epochIntervals (an events layer's spans) and trialMeasure (kind
%   "duration") use it.
%
%   See also epochIntervals, trialMeasure, resolveEvents.

[line, edge, from] = alignedEvent(ref);
name = line;
if line == "Trial" || (src.trialLine ~= "" && line == src.trialLine)
    name = src.trialLine;
end
if ~isfield(src.events, name)
    error('resolveEvents:NoLine', '%s: no digital line "%s" (lines: %s).', ...
        src.name, name, strjoin(string(fieldnames(src.events)), ", "));
end
iv = double(src.events.(name));
if isempty(iv); iv = zeros(0, 2); end
if isfield(from, 'stitchGapSec')   % the intervals the events were found in: stitched, past the refractory period
    iv = cleanIntervals(iv, from.stitchGapSec, from.refractorySec);
end
col = 1 + (edge == "offset");
move = ref.offsetSec + shift(:);          % what moved each event from its recorded edge
raw = t(:) - move;
tol = 1e-6;
if isfinite(src.fs) && src.fs > 0; tol = 0.5 / src.fs; end
[hit, loc] = ismembertol(raw, iv(:, col), tol, 'DataScale', 1);
on = NaN(numel(raw), 1);
off = NaN(numel(raw), 1);
on(hit) = iv(loc(hit), 1) + move(hit);
off(hit) = iv(loc(hit), 2) + move(hit);
end


function [line, edge, from] = alignedEvent(ref)
%alignedEvent  The line and edge of the event an event reference aligns to (epochEvents' rule), and the reference or step FROM it is.
line = ref.line; edge = ref.edge; from = ref;
a = ref.alignStep;
if isinf(a)
    a = find([string.empty(1, 0) ref.sequence.relation] == "followedBy", 1, 'last');   % none without steps
end
if ~isempty(a) && a >= 1
    from = ref.sequence(a);
    line = from.line; edge = from.edge;
end
end
