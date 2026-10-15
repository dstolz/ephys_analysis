function T = figureTemplates()
%figureTemplates  The figures addFigure starts from.
%   T = EphysAnalysisConfig.figureTemplates() has one row per template:
%     Template     its name, as addFigure takes it
%     Label        name shown in the app
%     Description  one line
%     Figure       the partial figure struct addFigure normalizes
%
%   "rasterPsth" (first, addFigure's default) is a 2 x 1 grid of equal
%   rows drawn flush (spacing "none"): raster_1 over psth_1, each with one
%   units layer following the observed unit. Each panel type has a
%   template of its own: one panel ("<type>_1") holding
%   defaultLayer(type). "blank" is an empty 1 x 1 grid.
%
%   See also EphysAnalysisConfig.addFigure, EphysAnalysisConfig.panelTypes.

P = EphysAnalysisConfig.panelTypes();

rp = struct();
rp.grid = struct('rows', 2, 'cols', 1, 'rowHeights', [1 1], 'colWidths', [], 'spacing', "none");
rp.panels = {panelOf("raster", 1), panelOf("psth", 2)};

order = ["psth" "raster" "continuous" "heatmap" "waveforms" "probemap" "corrmap" "rate" "tuning"];
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
    f.panels = {panelOf(t, 1)};
    Template(k + 1) = t;
    Label(k + 1) = P.Label(row);
    Description(k + 1) = "One panel: " + P.Description(row);
    Figure{k + 1} = f;
end
Template(n) = "blank";
Label(n) = "Blank";
Description(n) = "An empty 1 x 1 grid, to add panels to";
Figure{n} = struct('grid', struct('rows', 1, 'cols', 1));
T = table(Template, Label, Description, Figure);
end


function p = panelOf(type, row)
%panelOf  A panel of TYPE in column 1 of ROW, holding the type's default layer.
p = struct('id', type + "_1", 'type', type, 'row', row, 'col', 1, ...
    'layers', EphysAnalysisConfig.defaultLayer(type));
end
