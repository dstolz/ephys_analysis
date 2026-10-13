function [p, copied, notes] = copyPlotSettings(p, from, parts)
%copyPlotSettings  Give plot P the settings of plot FROM, part by part.
%   P = copyPlotSettings(P, FROM, PARTS) copies FROM's fields of the parts
%   PARTS (plotSettingParts' Part names, e.g. ["units" "style"]; default:
%   every part the two plots' kinds share) onto P, which may be of another
%   kind. P keeps its id, kind, title and enabled, and every part not
%   named. A part the two kinds do not share is not copied (a raster has
%   no aux signal to give a probe map). Within a part, what P's kind does
%   not take stays P's own:
%     units     FROM's source, when P's kind does not read it
%     window    FROM's own epoch window, when P's kind does not take its
%               mode (a "between" window onto a PSTH)
%     bins      FROM's baseline (mode and window), when P's kind and source
%               do not take its mode (an auROC baseline onto a raster)
%
%   [P, COPIED, NOTES] = ... also gives the parts copied (a string row)
%   and NOTES, a string row saying what was kept back and why (a part
%   named but not shared, or a value P's kind does not take).
%
%   See also plotSettingParts, EphysAnalysisConfig.normalizePlot.
arguments
    p (1,1) struct
    from (1,1) struct
    parts string = string(missing)
end
T = plotSettingParts(p.kind, from.kind);
if isscalar(parts) && ismissing(parts)
    parts = T.Part(T.Shared).';
end
parts = reshape(parts, 1, []);
bad = parts(~ismember(parts, T.Part));
if ~isempty(bad)
    error('copyPlotSettings:BadPart', 'Unknown part "%s" (parts: %s).', bad(1), strjoin(T.Part, ", "));
end
K = EphysAnalysisConfig.plotKinds();
row = K(K.Kind == p.kind, :);
own = p;
copied = string.empty(1, 0);
notes = string.empty(1, 0);
for part = T.Part(ismember(T.Part, parts)).'
    t = T(T.Part == part, :);
    if ~t.Shared
        notes(end+1) = t.Label + ": not copied, " + t.Reason + "."; %#ok<AGROW>
        continue
    end
    for f = t.Fields{1}
        p.(f) = from.(f);
    end
    switch part
        case "units"
            if ~ismember(from.source, row.Sources{1})
                p.source = own.source;
                notes(end+1) = sprintf("Source: kept %s (a %s plot does not read %s).", p.source, row.Label, from.source); %#ok<AGROW>
            end
        case "window"
            if isstruct(from.window) && ~ismember(from.window.mode, row.WindowModes{1})
                p.window = own.window;
                notes(end+1) = sprintf("Epoch window: not copied (a %s plot needs a fixed window).", row.Label); %#ok<AGROW>
            end
        case "bins"
            modes = baselineModes(p.kind, p.source);
            if ~ismember(from.baseline.Mode, modes)
                p.baseline = own.baseline;
                notes(end+1) = sprintf("Baseline: kept %s (a %s plot's baseline is %s).", p.baseline.Mode, row.Label, ...
                    strjoin(modes, ", ")); %#ok<AGROW>
            end
    end
    copied(end+1) = part; %#ok<AGROW>
end
end


function modes = baselineModes(kind, source)
%baselineModes  The baseline modes a plot of KIND reading SOURCE takes (as EphysAnalysisConfig.validate checks them).
switch kind
    case {"psth" "raster" "heatmap"}
        modes = ["none" "subtract" "zscore" "percent"];
        if kind ~= "raster"; modes(end+1) = "auroc"; end
        if ismember(source, EphysAnalysisConfig.SignalSources); modes = ["none" "subtract"]; end
    case {"rate" "tuning"}
        modes = ["none" "subtract" "ratio" "zscore"];
    case {"evoked" "corrmap"}
        modes = ["none" "subtract"];
    otherwise
        modes = "none";
end
end
