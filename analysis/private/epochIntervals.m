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
%   Times are on the clock of E.t0, as epochEvents' marks.
%   Errors: epochIntervals:NoOffsets (the line has events but none with an
%   offset after its onset: nothing runs from onset to offset), and
%   resolveEvents' (resolveEvents:NoLine, resolveEvents:NoTrials, ...).
%
%   See also epochEvents, resolveEvents, computeEventTracePanel, figurePointLayer.

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
[line, edge] = alignedEvent(ref);
I.line = line;
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
col = 1 + (edge == "offset");
move = ref.offsetSec + shift(:);          % what moved each event from its recorded edge
raw = x(:) - move;
tol = 1e-6;
if isfinite(src.fs) && src.fs > 0; tol = 0.5 / src.fs; end
[hit, loc] = ismembertol(raw, iv(:, col), tol, 'DataScale', 1);
on = iv(loc(hit), 1) + move(hit);
off = iv(loc(hit), 2) + move(hit);
ok = isfinite(on) & isfinite(off) & off > on;
if ~any(ok) && any(hit)
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


function [line, edge] = alignedEvent(ref)
%alignedEvent  The line and edge of the event an event reference aligns to (epochEvents' rule).
line = ref.line; edge = ref.edge;
a = ref.alignStep;
if isinf(a)
    a = find([string.empty(1, 0) ref.sequence.relation] == "followedBy", 1, 'last');   % none without steps
end
if ~isempty(a) && a >= 1
    line = ref.sequence(a).line; edge = ref.sequence(a).edge;
end
end
