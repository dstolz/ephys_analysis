function [units, detected, what] = figureUse(acfg)
%figureUse  What the Analysis step's figures read, and a line on them (overview, detail).
%   [UNITS, DETECTED, WHAT] = figureUse(ACFG): whether the enabled figures
%   and session figures of the analysis config ACFG read sorted units /
%   detected spikes -- what a figure observes (a unit observation's
%   observe.source) or an enabled layer's source -- and WHAT, "N
%   figure(s): <panel types>" or "no figure enabled".
ids = reshape(unique([acfg.enabledFigures() acfg.enabledSessionFigures()], 'stable'), 1, []);
units = false;
detected = false;
types = string.empty(1, 0);
for fid = ids
    fs = acfg.figureFor(fid);
    src = string.empty(1, 0);
    L = [fs.panels.layers];
    if ~isempty(L); src = [L([L.enabled]).source]; end
    if EphysAnalysisConfig.observeKind(fs) == "unit"; src(end+1) = fs.observe.source; end %#ok<AGROW>
    units = units || any(src == "units");
    detected = detected || any(src == "detected");
    types = [types fs.panels.type]; %#ok<AGROW>
end
if isempty(ids)
    what = "no figure enabled";
else
    what = sprintf("%d figure(s): %s", numel(ids), join(unique(types, "stable"), ", "));
end
end
