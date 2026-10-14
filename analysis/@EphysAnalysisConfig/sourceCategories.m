function T = sourceCategories()
%sourceCategories  The data categories a figure panel's layers draw, and the sources in each.
%   T = EphysAnalysisConfig.sourceCategories() has one row per category:
%     Category     "point" | "continuous" | "unit"
%     Label        name shown in the app
%     Sources      the layer sources (FigureSources) of the category
%     Aligned      true when the category is cut into epochs around events
%     Description  one line
%
%   units and detected belong to two categories, point (spike trains
%   around events) and unit (per-unit summaries: waveforms, probe maps,
%   correlations); the panel type decides which (categoryOf). panelTypes
%   names the categories each panel type accepts.
%
%   See also EphysAnalysisConfig.panelTypes, EphysAnalysisConfig.categoryOf.

rows = {
    "point",      "Point process",     ["units" "detected" "events"],   true,  "Event times: sorted units, threshold detections, or a digital / derived line's events"
    "continuous", "Continuous signal", ["LFP" "MUA" "SPIKE" "AUX"],     true,  "Sampled signals cut around each event: the LFP, MUA, SPIKE or AUX extract's channels"
    "unit",       "Unit summary",      ["units" "detected"],            false, "One summary per unit over the recording: its waveform, its place on the probe, its rate"
    };
n = size(rows, 1);
Category = strings(n, 1); Label = strings(n, 1); Description = strings(n, 1);
Sources = cell(n, 1); Aligned = false(n, 1);
for k = 1:n
    Category(k) = rows{k, 1};
    Label(k) = rows{k, 2};
    Sources{k} = rows{k, 3};
    Aligned(k) = rows{k, 4};
    Description(k) = rows{k, 5};
end
T = table(Category, Label, Sources, Aligned, Description);
end
