function ch = plotEditorChoices(kind, source)
%plotEditorChoices  The choices the plot editor's drop-downs offer a plot of KIND reading SOURCE.
%   CH.Sources, CH.Layouts and CH.WindowModes are the kind's
%   (EphysAnalysisConfig.plotKinds); CH.BaselineModes the modes its compute
%   takes (subtract only for signals, beyond "none"); CH.Orders the heatmap
%   and unit-correlation row orders (peak only for heatmaps).
K = EphysAnalysisConfig.plotKinds();
row = K(K.Kind == kind, :);
ch = struct('Sources', row.Sources{1}, 'Layouts', row.Layouts{1}, 'WindowModes', row.WindowModes{1}, ...
    'BaselineModes', "none", 'Orders', ["depth" "channel" "peak"]);
switch kind
    case {"psth" "raster" "heatmap"}
        ch.BaselineModes = ["none" "subtract" "zscore" "percent"];
        if ismember(source, EphysAnalysisConfig.SignalSources); ch.BaselineModes = ["none" "subtract"]; end
    case {"rate" "tuning"}
        ch.BaselineModes = ["none" "subtract" "ratio" "zscore"];
    case {"evoked" "corrmap"}
        ch.BaselineModes = ["none" "subtract"];
end
if kind == "corrmap"; ch.Orders = ["depth" "channel"]; end
end
