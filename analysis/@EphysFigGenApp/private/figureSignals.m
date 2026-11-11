function sigs = figureSignals(cfg)
%figureSignals  The signals (LFP, MUA, SPIKE, AUX) the enabled figures read: their enabled layers' and what they observe.
%   SIGS = figureSignals(CFG) is a string row in SignalSources order. The
%   Downsample and Filter dialogs name these signals in bold and mark the
%   others "no figure reads it" (onDownsample, onSignalFilter).
%
%   See also onDownsample, onSignalFilter.
sigs = strings(1, 0);
for f = reshape(cfg.Figures, 1, [])
    if ~f.enabled; continue; end
    sigs = [sigs, string(f.observe.data)]; %#ok<AGROW>
    for p = reshape(f.panels, 1, [])
        if isempty(p.layers); continue; end
        on = [p.layers.enabled];
        sigs = [sigs, reshape([p.layers(on).source], 1, [])]; %#ok<AGROW>
    end
end
sigs = intersect(EphysAnalysisConfig.SignalSources, sigs, 'stable');
end
