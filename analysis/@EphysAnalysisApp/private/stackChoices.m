function stackChoices(dd, type, v)
%stackChoices  The figure editor's Stack drop-down for a panel type: the stack values it takes, in words, showing V.
%   stackChoices(DD, TYPE, V) lists in DD the options.stack values the
%   panel type TYPE takes (EphysAnalysisConfig.stackModes) as "Off
%   (overlaid)", "One row per group" (a tuning panel's: "One row per
%   series"; a heat map's, a spectrogram's: "One image row per group") and
%   "One row per channel" (a continuous panel's "items"), and shows V (Off
%   when the type does not take it). A type that does not stack lists Off
%   alone (the row is hidden then: syncFigureEditor).
%
%   See also EphysAnalysisConfig.stackModes, applyFigureEditor, syncFigureEditor.
modes = EphysAnalysisConfig.stackModes(type);
if isempty(modes); modes = "off"; end
labels = strings(1, numel(modes));
for i = 1:numel(modes)
    switch modes(i)
        case "groups"
            labels(i) = "One row per group";
            if type == "tuning"; labels(i) = "One row per series"; end
            if ismember(type, ["heatmap" "spectrogram"]); labels(i) = "One image row per group"; end
        case "items"
            labels(i) = "One row per channel";
        otherwise
            labels(i) = "Off (overlaid)";
    end
end
v = string(v);
if ~ismember(v, modes); v = "off"; end
dd.ItemsData = [];
dd.Items = labels;
dd.ItemsData = modes;
dd.Value = v;
end
