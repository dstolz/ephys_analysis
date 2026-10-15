function T = legacyPlotKinds()
%legacyPlotKinds  The plot kinds of a version-1 config, for its migration only.
%   T = legacyPlotKinds() has one row per kind of config version 1's Plots
%   section: Kind, Label, Sources (what it read: "units" / "detected",
%   "LFP" / "MUA" / "SPIKE" / "AUX", or "trials"), Layouts (the first the
%   default) and DefaultLayout. legacyMigrate reads a version-1 file's
%   plots with it (an unknown kind is not migrated) and legacyPlotToFigure
%   resolves a plot's layout and names its kind in notes. Nothing else
%   uses it.
%
%   See also legacyMigrate, legacyPlotToFigure, legacyPlotDefaults.

spk = ["units" "detected"];
sig = ["LFP" "MUA" "SPIKE" "AUX"];
rows = {
    "psth",      "PSTH",             spk,       ["grid" "overlay"]
    "raster",    "Raster",           spk,       "grid"
    "evoked",    "Evoked potential", sig,       ["stack" "butterfly" "grid"]
    "rate",      "Firing rate",      spk,       ["bar" "box" "points"]
    "tuning",    "Tuning curve",     spk,       ["grid" "overlay"]
    "heatmap",   "Heatmap",          [spk sig], "groups"
    "probemap",  "Probe map",        spk,       "shanks"
    "corrmap",   "Unit correlation", spk,       "groups"
    "behavior",  "Behavior",         "trials",  ["points" "line" "box" "swarm" "violin"]
    "waveforms", "Unit waveforms",   spk,       ["grid" "probe"]
    };
n = size(rows, 1);
Kind = strings(n, 1); Label = strings(n, 1); DefaultLayout = strings(n, 1);
Sources = cell(n, 1); Layouts = cell(n, 1);
for k = 1:n
    Kind(k) = rows{k, 1};
    Label(k) = rows{k, 2};
    Sources{k} = rows{k, 3};
    Layouts{k} = rows{k, 4};
    DefaultLayout(k) = rows{k, 4}(1);
end
T = table(Kind, Label, Sources, Layouts, DefaultLayout);
end
