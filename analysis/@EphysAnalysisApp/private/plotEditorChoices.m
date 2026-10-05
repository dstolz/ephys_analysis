function ch = plotEditorChoices(kind, source)
%plotEditorChoices  The choices the plot editor's drop-downs offer a plot of KIND reading SOURCE.
%   CH.Sources, CH.Layouts and CH.WindowModes are the kind's
%   (EphysAnalysisConfig.plotKinds); CH.BaselineModes the modes its compute
%   takes (subtract only for signals, beyond "none"; auroc for a psth or
%   heatmap of spikes); CH.Orders the heatmap row orders (syncPlotEditor
%   adds "modulation" with an auROC baseline).
K = EphysAnalysisConfig.plotKinds();
row = K(K.Kind == kind, :);
ch = struct('Sources', row.Sources{1}, 'Layouts', row.Layouts{1}, 'WindowModes', row.WindowModes{1}, ...
    'BaselineModes', "none", 'Orders', ["probe" "peak"]);
switch kind
    case {"psth" "raster" "heatmap"}
        ch.BaselineModes = ["none" "subtract" "zscore" "percent"];
        if kind ~= "raster"; ch.BaselineModes(end+1) = "auroc"; end
        if ismember(source, EphysAnalysisConfig.SignalSources); ch.BaselineModes = ["none" "subtract"]; end
    case {"rate" "tuning"}
        ch.BaselineModes = ["none" "subtract" "ratio" "zscore"];
    case {"evoked" "corrmap"}
        ch.BaselineModes = ["none" "subtract"];
end
end
