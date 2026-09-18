function sel = trialSelection(s, opts)
%trialSelection  Which trials take part and how they are grouped.
%   SEL = trialSelection(Name=Value) or trialSelection(S, Name=Value) returns
%   a complete, checked trial selection: EphysAnalysisConfig.defaults
%   ("TrialSelection") overlaid with struct S and then the options.
%
%   Fields
%     filter        expression over the columns of behavior.trials, e.g.
%                   "Depth > 0 & RespLatency < 500" or "Hit | Miss". Column
%                   names are used as they are (text columns compare with
%                   == "text"); the response words of respCodeBits (Hit,
%                   Miss, CR, FA, Reward, Punish, NoResponse, Response)
%                   stand for bitand(RespCode, bit) > 0 unless a column has
%                   that name; a single "=" means "=="; the functions abs,
%                   round, floor, ceil, fix, mod, rem, min, max, isnan,
%                   isfinite, ismissing, ismember, any, all, strcmp,
%                   strcmpi, contains, startsWith, endsWith, lower, upper,
%                   string, double, bitand, true, false, pi, NaN, Inf are
%                   allowed; nothing else is (the expression is never
%                   passed to eval). Columns whose names are not valid
%                   MATLAB identifiers can only be grouped by
%     response      any of the response words: keep trials that are any of
%                   them
%     pairingFlags  keep trials whose PairingFlag is one of these (default
%                   "ok"; [] keeps every flag, including unpaired trials,
%                   which have no events)
%     trials        explicit rows of behavior.trials to keep ([] = all)
%     groupBy       0, 1 or 2 trial parameters; one group per value (per
%                   pair of values)
%     groupOrder    "ascending" (default) | "descending" | "appearance"
%     maxGroups     more groups than this is an error (default 12)
%
%   The filter's syntax is checked here; its names are checked against the
%   trials when it is applied (selectTrials). Errors: trialSelection:BadValue,
%   trialSelection:BadFilter, trialSelection:UnknownField.
%
%   See also selectTrials, respCodeBits, epochTable.

arguments
    s = []
    opts.filter (1,1) string
    opts.response (1,:) string
    opts.pairingFlags (1,:) string
    opts.trials (1,:) double
    opts.groupBy (1,:) string
    opts.groupOrder (1,1) string
    opts.maxGroups (1,1) double
end

if isempty(s)
    s = struct();
elseif ~isstruct(s) || ~isscalar(s)
    error('trialSelection:BadValue', 'Pass a struct or Name=Value options.');
end
for f = string(fieldnames(opts)).'
    s.(f) = opts.(f);
end
[sel, unknown] = EphysAnalysisConfig.normalizeSection("TrialSelection", s);
if ~isempty(unknown)
    error('trialSelection:UnknownField', 'Unknown trial-selection field(s): %s.', strjoin(unknown, ", "));
end
sel.filter = strtrim(sel.filter);
sel.groupBy = strtrim(sel.groupBy);
sel.groupBy = sel.groupBy(sel.groupBy ~= "");
if isempty(sel.groupBy); sel.groupBy = string.empty(1, 0); end
[~, words] = respCodeBits();
bad = setdiff(sel.response, words);
if ~isempty(bad)
    error('trialSelection:BadValue', 'Unknown response word(s) %s (known: %s).', ...
        strjoin(bad, ", "), strjoin(words, ", "));
end
bad = setdiff(sel.pairingFlags, ["ok" "partial" "cut" "unpaired"]);
if ~isempty(bad)
    error('trialSelection:BadValue', 'Unknown pairing flag(s) %s (known: ok, partial, cut, unpaired).', strjoin(bad, ", "));
end
if numel(sel.groupBy) > 2
    error('trialSelection:BadValue', 'groupBy takes at most 2 parameters (got %d).', numel(sel.groupBy));
end
if numel(unique(sel.groupBy)) < numel(sel.groupBy)
    error('trialSelection:BadValue', 'groupBy names the same parameter twice.');
end
if ~ismember(sel.groupOrder, ["ascending" "descending" "appearance"])
    error('trialSelection:BadValue', 'groupOrder must be ascending, descending or appearance (got "%s").', sel.groupOrder);
end
if ~(sel.maxGroups >= 1 && sel.maxGroups == round(sel.maxGroups))
    error('trialSelection:BadValue', 'maxGroups must be a whole number >= 1.');
end
if any(~isfinite(sel.trials) | sel.trials < 1 | sel.trials ~= round(sel.trials))
    error('trialSelection:BadValue', 'trials must be whole trial rows >= 1.');
end
if sel.filter ~= ""
    tableFilterFcn(sel.filter);   % syntax only; raises trialSelection:BadFilter
end
end
