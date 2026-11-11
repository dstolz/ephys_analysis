function T = figureTemplates()
%figureTemplates  The figures addFigure starts from.
%   T = EphysAnalysisConfig.figureTemplates() has one row per template:
%     Template     its name, as addFigure takes it
%     Label        name shown in the app
%     Description  one line
%     Figure       the partial figure struct addFigure normalizes
%
%   "rasterPsth" (first, addFigure's default) is raster_1 on the page's
%   top half ([0 0.5 1 0.5]) flush over psth_1 on its bottom half ([0 0 1
%   0.5]), each with one units layer following the observed unit. Each
%   panel type that draws data has a template of its own: one panel
%   ("<type>_1") over the whole page ([0 0 1 1]) holding
%   defaultLayer(type) (a coherence panel two: the observed unit, then the
%   LFP of its channel, a spike-field coherence; a trial panel a trials
%   layer: Stim onset -> Trial offset, a scatter's x Trial onset -> Stim
%   onset); a legend panel has none
%   (it shows the other panels' legend). "blank" has no panels.
%
%   See also EphysAnalysisConfig.addFigure, EphysAnalysisConfig.panelTypes.

P = EphysAnalysisConfig.panelTypes();

rp = struct();
rp.panels = {panelOf("raster", [0 0.5 1 0.5]), panelOf("psth", [0 0 1 0.5])};

order = ["psth" "raster" "continuous" "eventTrace" "trialDist" "trialHist" "trialScatter" "heatmap" "waveforms" "probemap" "corrmap" "rate" "tuning" "spectrum" "spectrogram" "coherence" "itpc"];
n = numel(order) + 2;
Template = strings(n, 1); Label = strings(n, 1); Description = strings(n, 1); Figure = cell(n, 1);
Template(1) = "rasterPsth";
Label(1) = "Raster over PSTH (per unit)";
Description(1) = "A unit's raster flush above its PSTH, both following the observed unit";
Figure{1} = rp;
for k = 1:numel(order)
    t = order(k);
    row = P.Type == t;
    f = struct();
    f.panels = {panelOf(t, [0 0 1 1])};
    Template(k + 1) = t;
    Label(k + 1) = P.Label(row);
    Description(k + 1) = "One panel: " + P.Description(row);
    Figure{k + 1} = f;
end
Template(n) = "blank";
Label(n) = "Blank";
Description(n) = "An empty page, to add panels to";
Figure{n} = struct();
T = table(Template, Label, Description, Figure);
end


function p = panelOf(type, rect)
%panelOf  A panel of TYPE at RECT, holding the type's default layer (a coherence panel: its seed and partner).
L = EphysAnalysisConfig.defaultLayer(type);
if type == "coherence"   % the observed unit with its own channel's LFP: a spike-field coherence
    L2 = L;
    L2.source = "LFP";
    L = [L L2];
end
p = struct('id', type + "_1", 'type', type, 'rect', rect, 'layers', L);
end
