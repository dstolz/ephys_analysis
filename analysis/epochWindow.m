function win = epochWindow(s, opts)
%epochWindow  The stretch of time each epoch covers around its event.
%   WIN = epochWindow(Name=Value) or epochWindow(S, Name=Value) returns a
%   complete, checked epoch window: EphysAnalysisConfig.defaults
%   ("EpochWindow") overlaid with struct S and then the options.
%
%   Fields
%     mode   "fixed" (default): each epoch spans [t0 + pre, t0 + post]
%            around its event t0 -- PSTHs, evoked potentials, heatmaps.
%            "between": each epoch spans [t0 + pre, t1 + post], where t1 is
%            the stop event that follows t0 -- rates and tuning over a
%            variable-length period, e.g. RespWindow onset -> offset (a
%            line whose intervals span trials, such as Platform, in
%            recording scope)
%     pre, post   seconds (fixed: pre <= post)
%     stop   [] or an eventRef (struct or line name): the event that ends the
%            epoch. Required in "between" mode. In "fixed" mode it still
%            fills t1 in epochTable, so renderers can mark it and psth can
%            drop the bins after it (MaskAfterStop)
%
%   Errors: epochWindow:BadValue, epochWindow:NoStop, epochWindow:UnknownField.
%
%   See also eventRef, epochTable.

arguments
    s = []
    opts.mode (1,1) string
    opts.pre (1,1) double
    opts.post (1,1) double
    opts.stop
end

if isempty(s)
    s = struct();
elseif ~isstruct(s) || ~isscalar(s)
    error('epochWindow:BadValue', 'Pass a struct or Name=Value options.');
end
for f = string(fieldnames(opts)).'
    s.(f) = opts.(f);
end
[win, unknown] = EphysAnalysisConfig.normalizeSection("EpochWindow", s);
if ~isempty(unknown)
    error('epochWindow:UnknownField', 'Unknown epoch-window field(s): %s.', strjoin(unknown, ", "));
end
if ~ismember(win.mode, ["fixed" "between"])
    error('epochWindow:BadValue', 'mode must be "fixed" or "between" (got "%s").', win.mode);
end
if ~(isfinite(win.pre) && isfinite(win.post))
    error('epochWindow:BadValue', 'pre and post must be finite.');
end
if win.mode == "fixed" && ~(win.pre <= win.post)
    error('epochWindow:BadValue', 'A fixed window needs pre <= post (got [%g %g]).', win.pre, win.post);
end
if ~isempty(win.stop)
    win.stop = eventRef(win.stop);
elseif win.mode == "between"
    error('epochWindow:NoStop', 'A "between" window needs a stop event.');
end
end
