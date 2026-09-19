function T = plotKinds()
%plotKinds  The plot kinds: sources, layouts and window modes each accepts.
%   T = EphysAnalysisConfig.plotKinds() has one row per kind (in the order
%   of EphysAnalysisConfig.Kinds):
%     Kind           "psth" | "raster" | "evoked" | "rate" | "tuning" |
%                    "heatmap" | "probemap" | "corrmap"
%     Label          name shown in the app
%     Sources        sources it reads: "units" / "detected" (spike times)
%                    and / or "LFP" / "MUA" / "SPIKE" / "AUX" (signals)
%     Layouts        layouts it draws; the first is the default
%     DefaultLayout  Layouts(1)
%     WindowModes    "fixed", or "fixed" and "between"
%     Aligned        false for probemap (no events, no trials)
%     Description    one line
%
%   See also EphysAnalysisConfig, renderPlot.

spk = ["units" "detected"];
sig = ["LFP" "MUA" "SPIKE" "AUX"];
rows = {
    "psth",     "PSTH",             spk,       ["grid" "overlay"],            "fixed",             true,  "Peri-event firing rate per unit (with a raster), groups overlaid"
    "raster",   "Raster",           spk,       "grid",                        "fixed",             true,  "Spike rasters per unit, epochs sorted by group"
    "evoked",   "Evoked potential", sig,       ["stack" "butterfly" "grid"],  "fixed",             true,  "Event-locked average of LFP / MUA / SPIKE / AUX channels"
    "rate",     "Firing rate",      spk,       ["bar" "box" "points"],        ["fixed" "between"], true,  "Mean rate per unit and group in each epoch window"
    "tuning",   "Tuning curve",     spk,       ["grid" "overlay"],            ["fixed" "between"], true,  "Rate against a trial parameter, one curve per series"
    "heatmap",  "Heatmap",          [spk sig], "groups",                      "fixed",             true,  "Units or channels by time, one tile per group"
    "probemap", "Probe map",        spk,       "shanks",                      "fixed",             false, "A per-channel value (rate, spikes, units) drawn on the probe sites"
    "corrmap",  "Unit correlation", spk,       "groups",                      ["fixed" "between"], true,  "Pairwise correlation of the units' per-epoch mean or peak rates, one matrix per group"
    };
n = size(rows, 1);
Kind = strings(n, 1); Label = strings(n, 1); Description = strings(n, 1);
Sources = cell(n, 1); Layouts = cell(n, 1); WindowModes = cell(n, 1);
DefaultLayout = strings(n, 1); Aligned = false(n, 1);
for k = 1:n
    Kind(k) = rows{k, 1};
    Label(k) = rows{k, 2};
    Sources{k} = rows{k, 3};
    Layouts{k} = rows{k, 4};
    DefaultLayout(k) = rows{k, 4}(1);
    WindowModes{k} = rows{k, 5};
    Aligned(k) = rows{k, 6};
    Description(k) = rows{k, 7};
end
T = table(Kind, Label, Sources, Layouts, DefaultLayout, WindowModes, Aligned, Description);
end
