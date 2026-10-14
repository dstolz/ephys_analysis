function F = computeFigure(obj, src, spec, opts)
%computeFigure  Compute one figure for one observation of one dataset: every panel's layers, no graphics.
%   F = r.computeFigure(SRC, SPEC, Observation=OBS) with SRC from source(),
%   SPEC from Config.figureFor(id) and OBS one row of
%   figureObservations(SRC, SPEC) (a table row or a struct with kind,
%   unitId, channel, column; default: the first row) computes what
%   renderFigure draws: each panel's layers for that one observation (the
%   observed unit's spike train, the observed channel's column), the
%   panels' fixed layers as they name them. The steps:
%     [reason, layerReasons] = figureSkipReason(src, spec)   (a figure-level
%         reason throws EphysAnalysisRunner:FigureSkipped; a panel's or a
%         layer's is kept as its skip; Enabled is not checked: a disabled
%         figure is still computed when asked)
%     figure epochs, when any panel with an enabled layer is aligned:
%         [E, G] = epochTable(src, spec.ref, Window=spec.window,
%             Selection=spec.selection, Baseline=bFig, Columns=colsFig)
%         bFig: the hull of the baseline windows of the panels on the
%         figure's alignment, colsFig: their rasters' sort parameters
%         (Incomplete / Artifacts "keep" when the only aligned panels are
%         behavior panels)
%     a panel with its own ref or window: its own epochTable with the
%         figure's selection; its groups are matched to G by label (each
%         epoch's groupIndex then indexes G), or the panel is skipped
%     a behavior panel: its own epochTable with Columns = [options.param,
%         seriesParam, yParam], Incomplete="keep", Artifacts="keep"
%     each panel: figurePanelRegistry().(type).compute(src, panel, Ep, Gp,
%         ctx), every layer resolved for OBS by figureLayerItems and
%         computed as the panel type says (spikePSTH, epochEvents,
%         evokedPotential, unitWaveforms, behaviorValues, unitSummary +
%         probeMapValues, unitCorrelation); errors from data the dataset
%         lacks for one layer or panel (no unit left, no event, no usable
%         epoch) skip only it
%   The error each panel draws as a band comes from figureErrorType
%   (plotErrorType's rule by panel type).
%
%   F fields
%     kind "figure", id, spec (SPEC), dataset (SRC.name), observation (OBS
%     as a struct: kind, label, unitId, channel, column, shank, depth,
%     meta), epochs (E; [] when no panel is aligned), groups (G; []
%     likewise), created, and panels (one per SPEC.panels, in order):
%       id, type, sharesTime   as in SPEC
%       epochs   the panel's own epochs (a table), or [] = F.epochs (and []
%                for a panel that is not aligned)
%       groups   its groups: G (with n counting its own epochs when it has
%                them); [] for a panel that is not aligned
%       skip     "" or why the panel is not computed (every layer then
%                carries the same reason)
%       layers   one per SPEC.panels(k).layers, same order: name (the
%                layer's, or automatic: the unit's label, "LFP ch 7", the
%                event's label), source, binding, category, eventsAs, skip
%                ("" = computed; "disabled"; a reason), R (the result; []
%                when skipped) and meta (the units' or channels' table)
%   A skipped layer stays with its reason and R = []; the panel's other
%   layers are drawn. While PollFcn is set (the app's preview) the compute
%   can be stopped as computePlot's can: a checkpoint between the steps,
%   panels and layers, and Check= into spikePSTH, evokedPotential and
%   unitWaveforms; after cancel() the next one throws
%   EphysAnalysisRunner:Canceled. Errors: EphysAnalysisRunner:FigureSkipped,
%   EphysAnalysisRunner:NoObservation (OBS omitted and the dataset offers
%   none), and epochTable's for the figure's own epochs.
%
%   See also EphysAnalysisRunner.computePlot, figureObservations,
%   figureSkipReason, figurePanelRegistry, EphysAnalysisConfig.figureFor.

arguments
    obj (1,1) EphysAnalysisRunner
    src (1,1) struct
    spec (1,1) struct
    opts.Observation = []
end

chk = [];   % the checkpoint the long steps call, while the app's preview polls (PollFcn)
if ~isempty(obj.PollFcn); chk = @() obj.checkpoint(); end
obj.checkpoint();
asked = spec;
asked.enabled = true;   % a disabled figure is still computed when asked (the preview)
[reason, LR] = figureSkipReason(src, asked);
if reason ~= ""
    error('EphysAnalysisRunner:FigureSkipped', 'Figure "%s" cannot be computed for %s: %s.', spec.id, src.name, reason);
end
obs = opts.Observation;
if isempty(obs)
    T = figureObservations(src, spec);
    if height(T) == 0
        error('EphysAnalysisRunner:NoObservation', 'Figure "%s": %s offers no %s to draw it for.', ...
            spec.id, src.name, spec.observe.kind);
    end
    obs = T(1, :);
end
obs = observationOf(obs);
obj.checkpoint();

PT = EphysAnalysisConfig.panelTypes();
reg = figurePanelRegistry();
np = numel(spec.panels);
vars = string.empty(1, 0);   % the trial parameters epochTable can copy (Columns)
if istable(src.trials); vars = string(src.trials.Properties.VariableNames); end
known = false(1, np); live = false(1, np); onFig = false(1, np); isBehavior = false(1, np);
skipsOf = cell(1, np);       % figureSkipReason's reason per layer of each panel
panelSkip = strings(1, np);  % ... and of each panel itself
for k = 1:np
    p = spec.panels(k);
    [skipsOf{k}, panelSkip(k)] = reasonsOf(LR, p);
    row = PT.Type == p.type;
    known(k) = any(row);
    if ~known(k); continue; end
    hasOn = ~isempty(p.layers) && any([p.layers.enabled]);
    % a panel skipped for its own reason (e.g. a raster sorted by a parameter the trials lack) needs no epochs,
    % and gives the figure's epochTable none of its sort columns or baseline
    live(k) = hasOn && PT.Aligned(row) && panelSkip(k) == "";
    isBehavior(k) = p.type == "behavior";
    onFig(k) = live(k) && ~isBehavior(k) && isequaln(p.ref, spec.ref) && isequaln(p.window, spec.window);
end

E = [];
G = [];
if any(live)
    if all(isBehavior(live))
        [E, G] = epochTable(src, spec.ref, Window=spec.window, Selection=spec.selection, Incomplete="keep", Artifacts="keep");
    else
        [E, G] = epochTable(src, spec.ref, Window=spec.window, Selection=spec.selection, ...
            Baseline=baselineHull(spec.panels(onFig)), Columns=sortColumns(spec.panels(onFig), vars));
    end
    obj.checkpoint();
end

P0 = struct('id', "", 'type', "", 'epochs', [], 'groups', [], 'sharesTime', false, 'skip', "", ...
    'layers', figurePanelLayers(EphysAnalysisConfig.defaults("Panel")));
panels = repmat(P0, 1, np);
for k = 1:np
    obj.checkpoint();
    p = spec.panels(k);
    P = P0;
    P.id = p.id;
    P.type = p.type;
    P.sharesTime = p.sharesTime;
    skips = skipsOf{k};
    P.skip = panelSkip(k);
    hasOn = ~isempty(p.layers) && any([p.layers.enabled]);
    Ep = [];
    Gp = [];
    if live(k)
        if onFig(k)
            Gp = G;
            Ep = E;
        else
            try
                [Ep, Gp, P.skip] = panelEpochs(src, spec, p, G, skips, vars);
                P.epochs = Ep;
            catch ME
                % what figureSkipReason cannot see beforehand: no event, or no usable epoch, for this panel
                if ~ismember(string(ME.identifier), ["epochTable:NoEpochs" "resolveEvents:NoEvents"]); rethrow(ME); end
                P.skip = string(ME.message);
            end
            obj.checkpoint();
        end
        P.groups = Gp;
    end
    if P.skip ~= ""
        skips(:) = P.skip;
    end
    if ~known(k) || P.skip ~= "" || ~hasOn
        P.layers = figurePanelLayers(p, skips);
        panels(k) = P;
        continue
    end
    ctx = struct('check', [], 'checkpoint', @() obj.checkpoint(), 'observation', obs, 'observe', spec.observe, ...
        'ref', p.ref, 'window', p.window, 'selection', spec.selection, 'style', spec.style, 'spec', spec, 'skips', skips);
    ctx.check = chk;
    R = reg.(p.type).compute(src, p, Ep, Gp, ctx);
    P.layers = R.layers;
    panels(k) = P;
end

F = struct();
F.kind = "figure";
F.id = spec.id;
F.spec = spec;
F.dataset = src.name;
F.observation = obs;
F.epochs = E;
F.groups = G;
F.panels = panels;
F.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function o = observationOf(obs)
%observationOf  One observation as a struct (a figureObservations row, or a partial struct).
o = struct('kind', "unit", 'label', "", 'unitId', NaN, 'channel', NaN, 'column', NaN, 'shank', NaN, 'depth', NaN, 'meta', []);
if istable(obs)
    if height(obs) < 1
        error('EphysAnalysisRunner:NoObservation', 'Observation is an empty table: pass one row of figureObservations.');
    end
    obs = obs(1, :);
    for f = intersect(string(fieldnames(o)).', string(obs.Properties.VariableNames), 'stable')
        v = obs.(f);
        if iscell(v); v = v{1}; end
        o.(f) = v;
    end
elseif isstruct(obs) && isscalar(obs)
    for f = intersect(string(fieldnames(o)).', string(fieldnames(obs)).', 'stable')
        v = obs.(f);
        if iscell(v) && isscalar(v); v = v{1}; end
        o.(f) = v;
    end
else
    error('EphysAnalysisRunner:NoObservation', 'Observation is one row of figureObservations (a table row or a struct).');
end
o.kind = string(o.kind);
o.label = string(o.label);
for f = ["unitId" "channel" "column" "shank" "depth"]
    o.(f) = double(o.(f));
end
end


function [skips, panelReason] = reasonsOf(LR, p)
%reasonsOf  figureSkipReason's reasons for one panel: per layer, and its own.
skips = strings(1, numel(p.layers));
panelReason = "";
if isempty(LR); return; end
mine = LR([LR.panel] == p.id);
for e = mine
    if e.layer == 0
        panelReason = e.reason;
    elseif e.layer <= numel(skips)
        skips(e.layer) = e.reason;
    end
end
end


function [Ep, Gp, reason] = panelEpochs(src, spec, p, G, skips, vars)
%panelEpochs  A panel's own epochs (its ref / window, the figure's selection), its groups those of G.
%   A behavior panel copies its param and, when its layer is not skipped
%   (SKIPS: figureSkipReason's reason per layer, e.g. "no trial parameter
%   X"), the layer's seriesParam and yParam: only what the trials have
%   (VARS), so a missing parameter skips its layer, never the figure.
reason = "";
if p.type == "behavior"
    cols = p.options.param;
    j = find([p.layers.enabled], 1);
    if ~isempty(j) && p.layers(j).source == "trials" && (j > numel(skips) || skips(j) == "")
        cols = [cols p.layers(j).seriesParam];
        if p.layers(j).yParam ~= "stop"; cols(end+1) = p.layers(j).yParam; end
    end
    cols = reshape(unique(cols(cols ~= "" & ismember(cols, vars)), 'stable'), 1, []);
    [Ep, Gp] = epochTable(src, p.ref, Window=p.window, Selection=spec.selection, Columns=cols, ...
        Incomplete="keep", Artifacts="keep");
else
    [Ep, Gp] = epochTable(src, p.ref, Window=p.window, Selection=spec.selection, ...
        Baseline=baselineHull(p), Columns=sortColumns(p, vars));
end
if ~istable(G); return; end
[ok, at] = ismember(Gp.label, G.label);
if any(~ok & Gp.n > 0)
    reason = "its trial groups (" + strjoin(Gp.label(~ok & Gp.n > 0).', ", ") + ") are not the figure's";
    return
end
Ep.groupIndex = at(Ep.groupIndex);
Gq = G;
Gq.n = accumarray(Ep.groupIndex(:), 1, [height(G) 1]);
Gp = Gq;
end


function b = baselineHull(panels)
%baselineHull  [b0 b1] spanning the baseline windows of PANELS ([] = none): what epochTable must read.
b = [];
lo = Inf; hi = -Inf;
for k = 1:numel(panels)
    o = panels(k).options;
    if isfield(o, 'baseline') && isstruct(o.baseline) && o.baseline.Mode ~= "none" && numel(o.baseline.Window) == 2
        lo = min(lo, o.baseline.Window(1));
        hi = max(hi, o.baseline.Window(2));
    end
end
if isfinite(lo) && isfinite(hi); b = [lo hi]; end
end


function c = sortColumns(panels, vars)
%sortColumns  The trial parameters PANELS' rasters sort their epochs by, as epochTable Columns.
%   Only those the trials have (VARS): a raster sorted by a missing one is
%   skipped for it (figureSkipReason), never the figure's epochs.
c = string.empty(1, 0);
for k = 1:numel(panels)
    p = panels(k);
    if p.type == "raster" && isfield(p.options, 'rasterSort') && ~ismember(p.options.rasterSort, ["" "stop" "event"])
        c(end+1) = p.options.rasterSort; %#ok<AGROW>
    end
end
c = reshape(unique(c(ismember(c, vars)), 'stable'), 1, []);
end
