function I = epochIntervals(src, E, ref)
%epochIntervals  The intervals (onset to offset) of an event reference's events in each epoch.
%   I = epochIntervals(SRC, E, REF) finds, for the dataset SRC
%   (loadAnalysisSource) and the epochs E (epochTable), the intervals of
%   the events the event reference REF picks (resolveEvents over every
%   trial or the recording: an events layer's eventMarkRef(L.event)), each
%   an onset with its own offset: the interval of the line (a sequence's:
%   the line of the step REF.alignStep names) whose REF.edge is the event,
%   moved by what moved the event (REF.offsetSec and REF.offsetParam's
%   shift). An interval belongs to every epoch whose window [tStart,
%   tStop] it overlaps, so one that started before the window or ends
%   after it is kept whole (the drawing clips it). Pure: no I/O, no
%   graphics. Fields of I:
%     line     the line drawn (REF.line, or the aligned step's)
%     label    eventRefLabel(REF)
%     epoch    [k x 1] the epoch (row of E) of each interval
%     on, off  [k x 1] its onset and offset, s from the epoch's event t0
%              (not clipped)
%     window   [nE x 2] each epoch's window, s from its event
%     nEpochs  height(E)
%   A reference that picks no event gives no interval (rows stay empty).
%   An interval whose offset is its onset (zero length) is kept when the
%   line has longer ones too. Times are on the clock of E.t0, as
%   epochEvents' marks.
%   Errors: epochIntervals:NoOffsets (the line has events but none with an
%   offset after its onset: nothing runs from onset to offset), and
%   resolveEvents' (resolveEvents:NoLine, resolveEvents:NoTrials, ...).
%
%   The intervals come from eventIntervals (trialMeasure's durations use
%   it too).
%
%   See also epochEvents, resolveEvents, eventIntervals, computeEventTracePanel, figurePointLayer.

arguments
    src (1,1) struct
    E table
    ref
end

ref = eventRef(ref);
nE = height(E);
I = struct('line', ref.line, 'label', eventRefLabel(ref), 'epoch', zeros(0, 1), 'on', zeros(0, 1), ...
    'off', zeros(0, 1), 'window', [E.tStart(:) - E.t0(:), E.tStop(:) - E.t0(:)], 'nEpochs', nE);
try
    [x, ~, ~, shift] = resolveEvents(src, ref, []);
catch ME
    if ME.identifier ~= "resolveEvents:NoEvents"; rethrow(ME); end
    return
end
[on, off, hit, line] = eventIntervals(src, ref, x, shift);   % each event's interval, moved as the event was
I.line = line;
on = on(hit);
off = off(hit);
ok = isfinite(on) & isfinite(off) & off >= on;   % a zero-length interval among others is kept (drawn at a minimum width)
if ~any(off(ok) > on(ok)) && any(hit)
    name = line;
    if line == "Trial" || (src.trialLine ~= "" && line == src.trialLine); name = src.trialLine; end
    error('epochIntervals:NoOffsets', ['%s: line %s has no offset after its onsets (every interval is a ' ...
        'single instant), so nothing runs from onset to offset.'], src.name, name);
end
on = on(ok);
off = off(ok);
[on, o] = sort(on);
off = off(o);
lo = E.tStart(:);
hi = E.tStop(:);
ec = cell(nE, 1); onc = cell(nE, 1); offc = cell(nE, 1);
for e = 1:nE
    in = on <= hi(e) & off >= lo(e);
    onc{e} = on(in) - E.t0(e);
    offc{e} = off(in) - E.t0(e);
    ec{e} = repmat(e, nnz(in), 1);
end
I.epoch = vertcat(ec{:}, zeros(0, 1));
I.on = vertcat(onc{:}, zeros(0, 1));
I.off = vertcat(offc{:}, zeros(0, 1));
end
