function M = epochEvents(src, E, opts)
%epochEvents  The events of digital lines inside each epoch: raster marks.
%   M = epochEvents(SRC, E, Lines=, Edge=, Scope=) finds, for every epoch of
%   E (epochTable) of the dataset SRC (loadAnalysisSource), the onsets
%   and / or offsets of each line in Lines that fall in the epoch's window
%   [tStart, tStop]: every one of them, so a trial with several beam
%   crossings or licks gets a mark for each. Pure: no I/O, no graphics.
%
%   Options
%     Lines   digital lines (src.events; "Trial" = the paired trial line)
%     Edge    "onset" (default) | "offset" | "both"
%     Scope   "window" (default): every event in the epoch's window;
%             "trial": only those inside the epoch's own trial,
%             [TrialOnset, TrialOffset] (an epoch outside the trials gets
%             none); a sequence's events: those whose own trial (the one
%             holding the sequence's first event) is the epoch's
%     Sequences  event references with sequences (eventRef, a struct
%             array or a cell of them): each one's events (resolveEvents
%             over every trial, at its alignStep) are marked like a line's,
%             e.g. the first Trough onset after each trial's end. Edge does
%             not apply to them
%
%   M is a 1 x (lines x edges + sequences) struct array, line by line,
%   onset before offset, then the sequences, with fields
%     line    the line (a sequence: its aligned step's line)
%     edge    "onset" | "offset" (a sequence: its aligned step's edge)
%     label   "<line> <edge>", e.g. "Trough onset" (the aesthetics group);
%             a sequence's eventRefLabel, e.g. "Trial offset then Trough
%             onset"
%     epoch   [k x 1] the epoch (row of E) of each event
%     t       [k x 1] its time from the epoch's event t0, s
%   Times are the digital-event times of src.events (t = row/Fs, polarity
%   applied), on the clock of E.t0, so a mark sits where the spikes of
%   that sample sit in the raster (spikePSTH aligns them to
%   t0Continuous). Errors: epochEvents:NoLine, epochEvents:NoTrials (scope
%   "trial", or "Trial", without paired trials).
%
%   See also epochTable, spikePSTH, renderRaster.

arguments
    src (1,1) struct
    E table
    opts.Lines (1,:) string = string.empty(1, 0)
    opts.Edge (1,1) string {mustBeMember(opts.Edge, ["onset" "offset" "both"])} = "onset"
    opts.Scope (1,1) string {mustBeMember(opts.Scope, ["window" "trial"])} = "window"
    opts.Sequences = []
end

edges = opts.Edge;
if edges == "both"; edges = ["onset" "offset"]; end
M = struct('line', {}, 'edge', {}, 'label', {}, 'epoch', {}, 't', {});
seqs = opts.Sequences;
if isstruct(seqs); seqs = num2cell(seqs); end
if isempty(opts.Lines) && isempty(seqs); return; end
lo = E.tStart(:);
hi = E.tStop(:);
if opts.Scope == "trial"
    if ~src.hasTrials
        error('epochEvents:NoTrials', '%s has no paired trials to keep each epoch''s own events.', src.name);
    end
    tr = E.trial(:);
    has = isfinite(tr);
    lo(has) = max(lo(has), src.trials.TrialOnset(tr(has)));
    hi(has) = min(hi(has), src.trials.TrialOffset(tr(has)));
    lo(~has) = NaN; hi(~has) = NaN;   % outside the trials: none
end
nE = height(E);
for ln = opts.Lines
    name = ln;
    if ln == "Trial"
        if src.trialLine == ""
            error('epochEvents:NoTrials', '%s: "Trial" needs paired trials to name the trial line.', src.name);
        end
        name = src.trialLine;
    end
    if ~isfield(src.events, name)
        error('epochEvents:NoLine', '%s: no digital line "%s" to mark (lines: %s).', ...
            src.name, name, strjoin(string(fieldnames(src.events)), ", "));
    end
    iv = double(src.events.(name));
    if isempty(iv); iv = zeros(0, 2); end
    for ed = edges
        x = sort(iv(:, 1 + (ed == "offset")));
        ec = cell(nE, 1); tc = cell(nE, 1);
        for e = 1:nE
            if ~(lo(e) <= hi(e)); continue; end
            i1 = find(x >= lo(e), 1);
            i2 = find(x <= hi(e), 1, 'last');
            if isempty(i1) || isempty(i2) || i2 < i1; continue; end
            tc{e} = x(i1:i2) - E.t0(e);
            ec{e} = repmat(e, i2 - i1 + 1, 1);
        end
        M(end+1) = struct('line', ln, 'edge', ed, 'label', ln + " " + ed, ...
            'epoch', vertcat(ec{:}, zeros(0, 1)), 't', vertcat(tc{:}, zeros(0, 1))); %#ok<AGROW>
    end
end

% --- sequences: their events, each kept with the trial of its first event ---------
lo = E.tStart(:);
hi = E.tStop(:);
for q = 1:numel(seqs)
    ref = eventRef(seqs{q});
    try
        [x, xt] = resolveEvents(src, ref, []);
    catch ME
        if ME.identifier ~= "resolveEvents:NoEvents"; rethrow(ME); end
        x = zeros(0, 1); xt = zeros(0, 1);
    end
    [line, edge] = alignedEvent(ref);
    ec = cell(nE, 1); tc = cell(nE, 1);
    for e = 1:nE
        in = x >= lo(e) & x <= hi(e);
        if opts.Scope == "trial"
            in = in & xt == E.trial(e);   % NaN == NaN is false: an epoch outside the trials gets none
        end
        tc{e} = x(in) - E.t0(e);
        ec{e} = repmat(e, nnz(in), 1);
    end
    M(end+1) = struct('line', line, 'edge', edge, 'label', eventRefLabel(ref), ...
        'epoch', vertcat(ec{:}, zeros(0, 1)), 't', vertcat(tc{:}, zeros(0, 1))); %#ok<AGROW>
end
end


function [line, edge] = alignedEvent(ref)
%alignedEvent  The line and edge of the event an event reference aligns to.
line = ref.line; edge = ref.edge;
a = ref.alignStep;
if isinf(a)
    a = find([ref.sequence.relation] == "followedBy", 1, 'last');
end
if ~isempty(a) && a >= 1
    line = ref.sequence(a).line; edge = ref.sequence(a).edge;
end
end
