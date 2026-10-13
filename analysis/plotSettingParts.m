function T = plotSettingParts(kindTo, kindFrom)
%plotSettingParts  The parts of a plot's settings that copy from a plot of one kind to another.
%   T = plotSettingParts(KINDTO, KINDFROM) has one row per part, in the
%   plot editor's order of sections (copyPlotSettings copies them):
%     Part    the editor's section ("units", "ref", "window", "selection",
%             "bins", "kind", "marks", "style", "waveform", "aux", "note",
%             "overlays"), or "looks" (the remembered aesthetics)
%     Label   name shown in the app
%     Fields  the Plot fields it copies (a string row): "kind" holds the
%             options both kinds have, and the layout when the two kinds
%             have the same layouts
%     Shared  true when both kinds use the part
%     Reason  why the part is not shared ("" when it is)
%   KINDFROM defaults to KINDTO. A plot's id, kind, title and enabled are
%   never copied.
%
%   See also copyPlotSettings, EphysAnalysisConfig.plotKinds.
arguments
    kindTo (1,1) string
    kindFrom (1,1) string = kindTo
end
K = EphysAnalysisConfig.plotKinds();
for kd = [kindTo kindFrom]
    if ~ismember(kd, K.Kind)
        error('plotSettingParts:BadKind', 'Unknown plot kind "%s" (kinds: %s).', kd, strjoin(K.Kind, ", "));
    end
end
rows = {
    "units",     "Units & channels",  ["source" "units" "channels"]
    "ref",       "Event reference",   "ref"
    "window",    "Epoch window",      "window"
    "selection", "Trial selection",   "selection"
    "bins",      "Bins & baseline",   ["bins" "measure" "baseline" "auroc" "maskAfterStop"]
    "kind",      "Plot type options", string.empty(1, 0)
    "marks",     "Event marks",       "rasterEvents"
    "style",     "Appearance",        "style"
    "waveform",  "Unit waveform",     "waveform"
    "aux",       "Aux signals",       "aux"
    "note",      "Text note",         "note"
    "overlays",  "Overlays",          "overlays"
    "looks",     "Remembered looks",  "aesthetics"
    };
n = size(rows, 1);
Part = [rows{:, 1}].';
Label = [rows{:, 2}].';
Fields = rows(:, 3);
Shared = true(n, 1);
Reason = strings(n, 1);
labelOf = @(kd) K.Label(K.Kind == kd);
for i = 1:n
    if Part(i) == "kind"
        f = intersect(kindOptions(kindTo), kindOptions(kindFrom), 'stable');
        if isequal(K.Layouts{K.Kind == kindTo}, K.Layouts{K.Kind == kindFrom}) && numel(K.Layouts{K.Kind == kindTo}) > 1
            f = ["layout" f]; %#ok<AGROW>
        end
        Fields{i} = f;
        Shared(i) = ~isempty(f);
        if ~Shared(i); Reason(i) = "no options in common"; end
    elseif Part(i) == "waveform" && xor(kindTo == "waveforms", kindFrom == "waveforms") ...
            && uses("waveform", kindTo, K) && uses("waveform", kindFrom, K)
        Shared(i) = false;
        Reason(i) = "a unit waveforms plot's own settings, not an inset";
    elseif ~uses(Part(i), kindTo, K)
        Shared(i) = false;
        Reason(i) = labelOf(kindTo) + " has none";
    elseif ~uses(Part(i), kindFrom, K)
        Shared(i) = false;
        Reason(i) = labelOf(kindFrom) + " has none";
    end
end
T = table(Part, Label, Fields, Shared, Reason);
end


function tf = uses(part, kind, K)
%uses  Whether a plot of KIND has the editor section PART (syncPlotEditor's rowsUsed, by kind).
switch part
    case "units"
        tf = kind ~= "behavior";
    case {"ref" "window" "selection"}
        tf = K.Aligned(K.Kind == kind);
    case "bins"
        tf = ~ismember(kind, ["probemap" "behavior" "waveforms"]);
    case {"marks" "aux"}
        tf = ismember(kind, ["psth" "raster"]);
    case "waveform"
        tf = ismember(kind, ["psth" "raster" "tuning" "waveforms"]);
    otherwise
        tf = true;
end
end


function f = kindOptions(kind)
%kindOptions  The Plot fields of a kind's own options (the editor's options section).
raster = ["rasterSort" "rasterSortEvent" "rasterSortOrder" "rasterByGroup"];
switch kind
    case "psth"
        f = ["withRaster" raster "histStyle" "normalize" "fill" "fillAlpha" "stack" "stackSpacing" "stackRaster" ...
            "stackRasterEqual" "stackRasterTrials"];
    case "raster"
        f = raster;
    case "tuning"
        f = ["param" "seriesParam"];
    case "behavior"
        f = ["param" "seriesParam" "yParam" "xScale" "jitter"];
    case "probemap"
        f = "value";
    case "heatmap"
        f = "order";
    case "corrmap"
        f = ["metric" "correlation" "fisherZ"];
    otherwise
        f = string.empty(1, 0);
end
end
