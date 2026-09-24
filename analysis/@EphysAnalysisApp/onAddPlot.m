function onAddPlot(obj, kind)
%onAddPlot  Add a plot of KIND (a kind name, or a partial plot struct) and edit it.
%   A kind name reads the kind's first source (units; LFP for an evoked
%   potential).
if isstring(kind) || ischar(kind)
    K = EphysAnalysisConfig.plotKinds();
    sources = K.Sources{K.Kind == string(kind)};
    kind = struct('kind', string(kind), 'source', sources(1));
end
cfg = obj.gatherConfig();
[cfg, id] = cfg.addPlot(kind);
obj.SelectedPlot = numel(cfg.Plots);
obj.applyConfig(cfg);
obj.PreviewPage = 1;
obj.PreviewSeconds = 0;
obj.setStatus("Added plot " + id + ".");
obj.autoPreview();
end
