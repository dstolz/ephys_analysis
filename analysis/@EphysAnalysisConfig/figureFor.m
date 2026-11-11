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
%     coherence or phase coherence (itpc) panel shares it only over time,
%     options.overTime, on the aligned time base). A
%     panel whose selection differs from the figure's computes its own
%     epochs and groups (figureCompute)
%   - each panel's options completed against its type's DefaultOptions
%   - each layer's category added (categoryOf: "point", "continuous",
%     "unit", or "" where the type does not draw the source),
%     its units.source set to its source (a complete UnitSelection) and
%     its downsample added: Source.Downsample's rate (Hz) for its signal
%     (LFP / MUA / SPIKE / AUX), [] for the rate on file and for any
%     other source (figureSignalLayer and figureChronuxLayer read the
%     signal at it: selectChannels' Rate), and its filters: the
%     SignalFilter chain its signal is read through, Source.SignalFilter's
%     for its signal then the panel's options.filter, the enabled ones
%     alone (SignalFilter.chain: 1x0 for none and for any other source;
%     selectChannels' Filter, at the rate read)
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
rates = struct();   % none: a config made before Source.Downsample existed in this session (until clear classes)
if isfield(obj.Source, 'Downsample'); rates = obj.Source.Downsample; end
filters = struct();   % none: (as rates) a config made before Source.SignalFilter existed in this session
if isfield(obj.Source, 'SignalFilter'); filters = obj.Source.SignalFilter; end
layer0 = resolvedLayer(EphysAnalysisConfig.defaults("Layer"), "psth", unitDef, rates, filters, []);
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
        if ismember(p.type, ["coherence" "itpc"])   % a coherogram over the epochs is drawn over time from the event
            onEpochs = ~isfield(p.options, 'timeBase') || p.options.timeBase == "aligned";   % (an itpc panel has no other)
            p.sharesTime = linked && p.options.overTime && onEpochs;
        end
    end
    own = [];   % the panel's filter (the types that draw signals: options.filter)
    if isfield(p.options, 'filter'); own = p.options.filter; end
    L = repmat(layer0, 1, 0);
    for i = 1:numel(p.layers)
        L(1, i) = resolvedLayer(p.layers(i), p.type, unitDef, rates, filters, own);
    end
    p.layers = L;
    panels(1, j) = p;
end
spec.panels = panels;
end


function L = resolvedLayer(L, type, unitDef, rates, filters, own)
%resolvedLayer  A layer with its category, a complete UnitSelection (units.source = its source), its signal's rate and filters.
%   RATES is Source.Downsample: a signal layer's downsample is its signal's rate ([] = the rate on file); any other
%   layer's is []. FILTERS is Source.SignalFilter and OWN the panel's options.filter ([] = none): a signal layer's
%   filters are its signal's filter then OWN, the enabled ones (SignalFilter.chain); any other layer's none.
u = L.units;
u.source = L.source;
L.units = orderfields(u, unitDef);
L.category = EphysAnalysisConfig.categoryOf(L.source, type);
L.downsample = [];
if isfield(rates, L.source); L.downsample = rates.(L.source); end
F = [];
if ismember(L.source, EphysAnalysisConfig.SignalSources)
    if isfield(filters, L.source); F = SignalFilter.normalize(filters.(L.source)); end
    if ~isempty(own); F = [F, SignalFilter.normalize(own)]; end
end
L.filters = SignalFilter.chain(F);
end
