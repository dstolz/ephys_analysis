function showSignalFilter(obj, filters)
%showSignalFilter  The Data tab's Filters row: the signals' filters in words, the Filter... button amber while one is on.
%   obj.showSignalFilter(FILTERS) shows FILTERS (a Source.SignalFilter
%   struct; default the config's): "no signal filtered" when none is on,
%   else "LFP Theta 4-8 Hz, AUX low-pass 20 Hz (the others as recorded)"
%   (FilterDialog.describeSignals), the button amber (styleButton
%   "active") with each filter in full in its tooltip and the script
%   name, Source.SignalFilter. applySourceSection and
%   onConfigChanged("signalfilter") call it.
%
%   See also onSignalFilter, FilterDialog, showDownsample.
if nargin < 2; filters = sourceFilters(obj.Config.Source); end
b = obj.SignalFilterButton;
if isempty(b) || ~isvalid(b); return; end
words = FilterDialog.describeSignals(filters);
tip = "The filter each signal (LFP, MUA, SPIKE, AUX) is read through by every figure: each channel's whole " + ...
    "recording is filtered, at the rate the figures read it (Downsample...), before it is cut into epochs. A " + ...
    "band-pass for an EEG band, a notch for line noise, a low- or high-pass; a panel can add a filter of its own. ";
if words == ""
    styleButton(b);
    obj.SignalFilterLabel.Text = "no signal filtered";
    tip = tip + "Now no signal is filtered.";
else
    styleButton(b, "active");
    obj.SignalFilterLabel.Text = "filtered: " + words + " (the others as recorded)";
    full = strings(1, 0);
    for s = DatasetOutputs.SignalTypes
        d = SignalFilter.describe(filters.(s));
        if d ~= ""; full(end+1) = s + ": " + d; end %#ok<AGROW>
    end
    tip = tip + "Now:" + newline + strjoin(full, newline);
end
b.Tooltip = tip + newline + "Script name: Source.SignalFilter";
obj.SignalFilterLabel.Tooltip = b.Tooltip;
end
