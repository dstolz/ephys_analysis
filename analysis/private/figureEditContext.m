function ctx = figureEditContext(F, spec, target, opts, root, design, follows, txt)
%figureEditContext  The right-click aesthetics editor's context of F drawn with SPEC on TARGET (PlotAesthetics.enableEditing): its redraw draws them again.
%   ROOT: what was drawn on (the canvas, or the one axes); TXT: the
%   figure's title. Its colormap field: "diverging" with a correlation map
%   or an auROC or baseline-normalized heat map or spectrogram, "heat"
%   with another heat map, a probe map, a spectrogram or a coherogram.
%
%   See also renderFigure, renderProbeFigure.
panels = spec.panels;
np = numel(panels);
types = strings(1, np);
sIds = strings(1, np);
for k = 1:np
    types(k) = panels(k).type;
    sIds(k) = panels(k).id;
end
G = F.groups;
mapField = "";
aurocMap = false;   % a heat map of auROCs is drawn in the diverging colormap
heat = types == "heatmap";
for k = find(types == "psth")   % a PSTH drawn as a heat map
    heat(k) = isfield(panels(k).options, 'display') && panels(k).options.display == "heatmap";
end
for k = find(heat)
    o = panels(k).options;
    aurocMap = aurocMap || (isfield(o, 'baseline') && isstruct(o.baseline) && o.baseline.Mode == "auroc");
end
for k = find(types == "spectrogram")   % a baseline-normalized spectrogram: diverging, centered on no change
    o = panels(k).options;
    aurocMap = aurocMap || (isfield(o, 'baseline') && isstruct(o.baseline) && o.baseline.Mode ~= "none");
end
cohgram = false;
for k = find(types == "coherence")
    cohgram = cohgram || (isfield(panels(k).options, 'overTime') && panels(k).options.overTime);
end
if any(types == "corrmap") || aurocMap
    mapField = "diverging";
elseif any(heat) || any(ismember(types, ["probemap" "spectrogram"])) || cohgram
    mapField = "heat";
end
ordinal = istable(G) && ismember('color', G.Properties.VariableNames) && isOrdinalGroups(G);
specRules = PlotAesthetics.normalizeRules(spec.aesthetics);
ctx = struct('kind', "figure", 'id', spec.id, 'title', txt, 'root', root, 'target', target, 'plotRules', specRules, ...
    'onRemember', {opts.OnRemember}, 'onGoto', {opts.OnGoto}, 'design', design, 'followsDesign', follows, 'ordinal', ordinal, 'mapField', mapField, ...
    'redraw', @(newRules) renderFigure(F, setfield(spec, 'aesthetics', newRules), target, Design=opts.Design, ...
        UserAesthetics=opts.UserAesthetics, Editable=opts.Editable, OnRemember=opts.OnRemember, OnGoto=opts.OnGoto, ...
        OnAxisEdit=opts.OnAxisEdit, OnSelect=opts.OnSelect, BatchYLim=opts.BatchYLim, Scale=opts.Scale));
ctx.panelTypes = struct('id', sIds, 'type', types);   % each tile's panel type by the id it is tagged with (PlotDesign.capture)
ctx.panelIds = sIds;   % "Move every panel's X axis to top": every panel of the figure
ctx.onAxisEdit = @(panel, change) axisEdited(F, spec, target, opts, panel, change);   % an axis label's or axes' menu (PlotAesthetics)
end


function axisEdited(F, spec, target, opts, panel, change)
%axisEdited  A right-click axis edit of the panels PANEL (ids; CHANGE: their new xLabel, yLabel, xSide or ySide).
%   OnAxisEdit keeps it (the app: in its config, then it draws the figure
%   again); without one the figure is drawn again here with it.
if ~isempty(opts.OnAxisEdit)
    opts.OnAxisEdit(panel, change);
    return
end
ks = find(ismember([spec.panels.id], panel));
if isempty(ks); return; end
for k = ks
    for f = string(fieldnames(change)).'
        spec.panels(k).(f) = change.(f);
    end
end
opts.InPlaceOnly = false;   % drawn as it was (Reuse: a label's text set on it)
args = namedargs2cell(opts);
renderFigure(F, spec, target, args{:});
end
