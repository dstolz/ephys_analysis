function spec = figureFor(obj, id)
%figureFor  A figure with every "default" resolved: what the compute draws.
%   SPEC = cfg.figureFor(ID) (ID a figure id or an index) is the Figures
%   entry with
%   - ref / window / selection taken from Defaults where "default"
%   - observe.kind added (observeKind of observe.data: "unit", "channel"
%     or "dataset"), and observe.units.source set to observe.data for
%     units or detected (else "units"; a complete UnitSelection, for
%     selectUnits)
%   - each panel's ref / window / selection taken from the figure's
%     (resolved) where "default", and two fields added: aligned
%     (panelTypes().Aligned of its type) and sharesTime (the type shares
%     time and both its ref and window were "default": it takes the
%     figure's time axis; a selection of its own does not change that; a
%     coherence panel shares it only over time, options.overTime, on the
%     aligned time base). A
%     panel whose selection differs from the figure's computes its own
%     epochs and groups (figureCompute)
%   - each panel's options completed against its type's DefaultOptions,
%     and, where the panel's common is true, the figure's common values
%     put in for every common field its type has (commonFieldsOf, via
%     panelOptions): bins, measure, baseline, maskAfterStop, waveform. A
%     waveforms panel never draws mode "off": a common waveform mode
%     "off" (the insets' default) becomes "both" for it. The panel's
%     common flag stays in the spec (the link state)
%   - each layer's category added (categoryOf: "point", "continuous",
%     "unit", or "" where the type does not draw the source) and
%     its units.source set to its source (a complete UnitSelection)
%   A panel of an unknown type keeps its empty options, with aligned and
%   sharesTime false. Error: EphysAnalysisConfig:NoFigure.
%
%   See also EphysAnalysisConfig.observeKind,
%   EphysAnalysisConfig.panelTypes.

if isnumeric(id)
    k = id;
else
    k = obj.figureIndex(id);
end
if k < 1 || k > numel(obj.Figures)
    error('EphysAnalysisConfig:NoFigure', 'No figure "%s".', string(id));
end
fig = obj.Figures(k);
spec = fig;
if isequal(spec.ref, "default");       spec.ref = obj.Defaults.EventRef;   end
if isequal(spec.window, "default");    spec.window = obj.Defaults.Window;  end
if isequal(spec.selection, "default"); spec.selection = obj.Defaults.Selection; end

unitDef = EphysAnalysisConfig.defaults("UnitSelection");
o = spec.observe;
o.kind = EphysAnalysisConfig.observeKind(fig);
u = o.units;
u.source = "units";
if o.kind == "unit"; u.source = o.data; end
o.units = orderfields(u, unitDef);
spec.observe = o;

T = EphysAnalysisConfig.panelTypes();
layer0 = resolvedLayer(EphysAnalysisConfig.defaults("Layer"), "psth", unitDef);
panel0 = EphysAnalysisConfig.defaults("Panel");
panel0.layers = repmat(layer0, 1, 0);
panel0.aligned = false;
panel0.sharesTime = false;
panels = repmat(panel0, 1, 0);
for j = 1:numel(fig.panels)
    p = fig.panels(j);
    row = T.Type == p.type;
    known = any(row);
    p.aligned = known && T.Aligned(row);
    linked = isequal(p.ref, "default") && isequal(p.window, "default");
    p.sharesTime = known && T.SharesTime(row) && linked;
    if isequal(p.ref, "default");    p.ref = spec.ref;       end
    if isequal(p.window, "default"); p.window = spec.window; end
    if isequal(p.selection, "default"); p.selection = spec.selection; end
    if known
        p.options = EphysAnalysisConfig.coerceStruct(T.DefaultOptions{row}, p.options, "options");
        p.options = EphysAnalysisConfig.panelOptions(fig, p);
        if p.type == "coherence"   % a coherogram over the epochs is drawn over time from the event
            p.sharesTime = linked && p.options.overTime && p.options.timeBase == "aligned";
        end
    end
    L = repmat(layer0, 1, 0);
    for i = 1:numel(p.layers)
        L(1, i) = resolvedLayer(p.layers(i), p.type, unitDef);
    end
    p.layers = L;
    panels(1, j) = p;
end
spec.panels = panels;
end


function L = resolvedLayer(L, type, unitDef)
%resolvedLayer  A layer with its category and a complete UnitSelection (units.source = its source).
u = L.units;
u.source = L.source;
L.units = orderfields(u, unitDef);
L.category = EphysAnalysisConfig.categoryOf(L.source, type);
end
