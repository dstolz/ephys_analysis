function showDownsample(obj, rates)
%showDownsample  The Data tab's Signals row: the signals' rates in words, the Downsample... button amber while one is set.
%   obj.showDownsample(RATES) shows RATES (a Source.Downsample struct;
%   default the config's): "every signal at its rate on file" when none is
%   set, else "downsampled: LFP 250 Hz, AUX 100 Hz (anti-aliased; the
%   others at their rate on file)" (DownsampleDialog.describe), the button
%   amber (styleButton "active") with the same in its tooltip and the
%   script name, Source.Downsample. applySourceSection and
%   onConfigChanged("downsample") call it.
%
%   See also onDownsample, DownsampleDialog.
if nargin < 2; rates = sourceRates(obj.Config.Source); end
b = obj.DownsampleButton;
if isempty(b) || ~isvalid(b); return; end
words = DownsampleDialog.describe(rates);
tip = "The rate each signal (LFP, MUA, SPIKE, AUX) is brought to before any figure reads it, low-pass " + ...
    "filtered first so nothing aliases (content up to 0.38 x the new rate passes unchanged): less memory, " + ...
    "faster previews, lighter figure files. ";
if words == ""
    styleButton(b);
    obj.DownsampleLabel.Text = "every signal at its rate on file";
    tip = tip + "Now every signal keeps its rate on file.";
else
    styleButton(b, "active");
    obj.DownsampleLabel.Text = "downsampled: " + words + " (anti-aliased; the others at their rate on file)";
    tip = tip + "Now: " + words + " (the others at their rate on file).";
end
b.Tooltip = tip + newline + "Script name: Source.Downsample";
obj.DownsampleLabel.Tooltip = b.Tooltip;
end
