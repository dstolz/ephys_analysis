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
%             none)
%
%   M is a 1 x (lines x edges) struct array, line by line, onset before
%   offset, with fields
%     line    the line
%     edge    "onset" | "offset"
%     label   "<line> <edge>", e.g. "Trough onset" (the aesthetics group)
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
end

edges = opts.Edge;
if edges == "both"; edges = ["onset" "offset"]; end
M = struct('line', {}, 'edge', {}, 'label', {}, 'epoch', {}, 't', {});
if isempty(opts.Lines); return; end
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
end
