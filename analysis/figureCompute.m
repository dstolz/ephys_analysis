function F = figureCompute(src, spec, opts)
%figureCompute  Compute one figure for one observation of one dataset: every panel's layers, no graphics.
%   F = figureCompute(SRC, SPEC, Observation=OBS, Check=CHK) with SRC from
%   loadAnalysisSource (EphysAnalysisRunner.source), SPEC from
%   Config.figureFor(id) and OBS one row of
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
%         figure's alignment, colsFig: their rasters' sort parameters and
%         their tuning curves' parameters (figureTuningParam)
%         An observation of one trial group (a figureObservations row of
%         a perGroup figure: group, groupLabel) keeps that group's epochs
%         only: E's rows of it, G that one row with n recounted
%     a panel with its own ref or window: its own epochTable with the
%         figure's selection; its groups are matched to G by label (each
%         epoch's groupIndex then indexes G; a per-group observation
%         keeps that group's epochs), or the panel is skipped
%     a panel with a selection of its own (Panel.selection): its own
%         epochTable and its own groups, not matched to G and not cut to
%         a per-group observation's group
%     each panel: figurePanelRegistry().(type).compute(src, panel, Ep, Gp,
%         ctx), every layer resolved for OBS by figureLayerItems and
%         computed as the panel type says (spikePSTH, epochEvents,
%         evokedPotential, unitWaveforms, unitSummary + probeMapValues,
%         unitCorrelation, firingRate, tuningCurve); errors from data the dataset
%         lacks for one layer or panel (no unit left, no event, no usable
%         epoch) skip only it
%   The error each panel draws as a band comes from figureErrorType
%   (plotErrorType's rule by panel type).
%
%   F fields
%     kind "figure", id, spec (SPEC), dataset (SRC.name), observation (OBS
%     as a struct: kind, label, unitId, channel, column, shank, depth,
%     meta, group, groupLabel), epochs (E; [] when no panel is aligned), groups (G; []
%     likewise), created, and panels (one per SPEC.panels, in order):
%       id, type, sharesTime   as in SPEC
%       epochs   the panel's own epochs (a table), or [] = F.epochs (and []
%                for a panel that is not aligned)
%       groups   its groups: G (with n counting its own epochs when it has
%                them), or its own with a selection of its own; [] for a
%                panel that is not aligned
%       ownSelection  true when its groups are its own selection's
%                (renderFigure colors them apart, with a legend inside it)
%       skip     "" or why the panel is not computed (every layer then
%                carries the same reason)
%       layers   one per SPEC.panels(k).layers, same order: name (the
%                layer's, or automatic: the unit's label, "LFP ch 7", the
%                event's label), source, binding, category, eventsAs, skip
%                ("" = computed; "disabled"; a reason), R (the result; []
%                when skipped) and meta (the units' or channels' table)
%   A skipped layer stays with its reason and R = []; the panel's other
%   layers are drawn.
%
%   It is pure: no runner, no graphics, nothing kept between calls, so a
%   standalone script (EphysAnalysisScript.standalone) calls it as the
%   runner does. CHK (default [] = none) is a checkpoint: called with no
%   arguments between the steps, panels and layers, and passed as Check=
%   into spikePSTH, evokedPotential and unitWaveforms, so whatever it
%   throws stops the compute there (EphysAnalysisRunner.computeFigure
%   passes its own checkpoint while PollFcn is set, the app's preview:
%   after cancel() it throws EphysAnalysisRunner:Canceled). Errors:
%   EphysAnalysisRunner:FigureSkipped, EphysAnalysisRunner:NoObservation
%   (OBS omitted and the dataset offers none), and epochTable's for the
%   figure's own epochs.
%
%   See also EphysAnalysisRunner.computeFigure, EphysAnalysisRunner.computePlot,
%   figureObservations, figureSkipReason, figurePanelRegistry,
%   EphysAnalysisConfig.figureFor, renderFigure.

arguments
    src (1,1) struct
    spec (1,1) struct
    opts.Observation = []
    opts.Check = []
end

chk = opts.Check;   % the checkpoint the long steps call ([] = none)
tick(chk);
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
tick(chk);

PT = EphysAnalysisConfig.panelTypes();
reg = figurePanelRegistry();
np = numel(spec.panels);
vars = string.empty(1, 0);   % the trial parameters epochTable can copy (Columns)
if istable(src.trials); vars = string(src.trials.Properties.VariableNames); end
known = false(1, np); live = false(1, np); onFig = false(1, np); ownSel = false(1, np);
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
    ownSel(k) = ~isequaln(selectionOf(p, spec), spec.selection);
    onFig(k) = live(k) && isequaln(p.ref, spec.ref) && isequaln(p.window, spec.window) && ~ownSel(k);
end

E = [];
G = [];
if any(live)
    [E, G] = epochTable(src, spec.ref, Window=spec.window, Selection=spec.selection, ...
        Baseline=baselineHull(spec.panels(onFig)), Columns=sortColumns(spec.panels(onFig), vars, spec.selection, src));
    if isfinite(obs.group) || obs.groupLabel ~= ""   % one figure per trial group: that group's epochs only
        [E, G] = keepGroup(E, G, obs, spec.id);
    end
    tick(chk);
end

P0 = struct('id', "", 'type', "", 'epochs', [], 'groups', [], 'sharesTime', false, 'ownSelection', false, 'skip', "", ...
    'layers', figurePanelLayers(EphysAnalysisConfig.defaults("Panel")));
panels = repmat(P0, 1, np);
for k = 1:np
    tick(chk);
    p = spec.panels(k);
    P = P0;
    P.id = p.id;
    P.type = p.type;
    P.sharesTime = p.sharesTime;
    P.ownSelection = live(k) && ownSel(k);
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
                [Ep, Gp, P.skip] = panelEpochs(src, spec, p, G, vars, ownSel(k), obs);
                P.epochs = Ep;
            catch ME
                % what figureSkipReason cannot see beforehand: no event, or no usable epoch, for this panel
                if ~ismember(string(ME.identifier), ["epochTable:NoEpochs" "resolveEvents:NoEvents"]); rethrow(ME); end
                P.skip = string(ME.message);
            end
            tick(chk);
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
    ctx = struct('check', [], 'checkpoint', @() tick(chk), 'observation', obs, 'observe', spec.observe, ...
        'ref', p.ref, 'window', p.window, 'selection', selectionOf(p, spec), 'style', spec.style, 'spec', spec, 'skips', skips);
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


function tick(chk)
%tick  The checkpoint, when there is one.
if ~isempty(chk); chk(); end
end


function o = observationOf(obs)
%observationOf  One observation as a struct (a figureObservations row, or a partial struct).
o = struct('kind', "unit", 'label', "", 'unitId', NaN, 'channel', NaN, 'column', NaN, 'shank', NaN, 'depth', NaN, 'meta', [], ...
    'group', NaN, 'groupLabel', "");
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
o.groupLabel = string(o.groupLabel);
if isempty(o.groupLabel) || ismissing(o.groupLabel); o.groupLabel = ""; end
for f = ["unitId" "channel" "column" "shank" "depth" "group"]
    o.(f) = double(o.(f));
    if isempty(o.(f)); o.(f) = NaN; end
end
end


function s = selectionOf(p, spec)
%selectionOf  A panel's trial selection: its own (figureFor resolved it), else the figure's.
s = spec.selection;
if isfield(p, 'selection') && isstruct(p.selection); s = p.selection; end
end


function g = groupOf(G, obs)
%groupOf  The row of the groups table G that observation OBS draws (by its label, else its index; [] = none).
g = [];
if obs.groupLabel ~= ""; g = find(string(G.label) == obs.groupLabel, 1); end
if isempty(g) && obs.groupLabel == "" && isfinite(obs.group) && obs.group >= 1 && obs.group <= height(G)
    g = obs.group;
end
end


function [E, G] = keepGroup(E, G, obs, id)
%keepGroup  The epochs of one trial group (a per-group observation): E's rows of it, G that one row with its n.
g = groupOf(G, obs);
if isempty(g) || ~any(E.groupIndex == g)
    error('EphysAnalysisRunner:NoObservation', 'Figure "%s": no epoch of trial group "%s" here.', id, obs.groupLabel);
end
E = E(E.groupIndex == g, :);
E.groupIndex(:) = 1;
G = G(g, :);
G.n = height(E);
if ismember("index", string(G.Properties.VariableNames)); G.index = 1; end
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


function [Ep, Gp, reason] = panelEpochs(src, spec, p, G, vars, own, obs)
%panelEpochs  A panel's own epochs (its ref / window / selection), its groups those of G unless the selection is its own.
%   Its rasters' sort parameters are copied when the trials have them
%   (VARS). With a selection of its own (OWN) the panel keeps its own
%   groups, whatever the figure's. On the figure's selection its groups
%   are matched to G by label; a per-group observation (OBS.groupLabel)
%   keeps that group's epochs only.
reason = "";
sel = selectionOf(p, spec);
[Ep, Gp] = epochTable(src, p.ref, Window=p.window, Selection=sel, ...
    Baseline=baselineHull(p), Columns=sortColumns(p, vars, sel, src));
if own || ~istable(G); return; end
if isfinite(obs.group) || obs.groupLabel ~= ""
    Ep = Ep(string(Ep.group) == string(G.label(1)), :);
    if height(Ep) == 0
        reason = "no epoch of trial group " + string(G.label(1)) + " in its own window";
        return
    end
    Gp.n = accumarray(Ep.groupIndex(:), 1, [height(Gp) 1]);
end
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


function c = sortColumns(panels, vars, sel, src)
%sortColumns  The trial parameters PANELS' rasters (and heat maps of trials) sort their epochs by, and their tuning curves' x and series, as epochTable Columns.
%   Only those the trials have (VARS): a raster sorted by a missing one, or
%   a tuning curve over one, is skipped for it (figureSkipReason), never
%   the figure's epochs. SEL (the figure's selection) and SRC resolve a
%   tuning panel's param "" (figureTuningParam).
c = string.empty(1, 0);
for k = 1:numel(panels)
    p = panels(k);
    trialRows = p.type == "heatmap" && isfield(p.options, 'rows') && p.options.rows == "trials";   % sorted as a raster
    if (p.type == "raster" || trialRows) && isfield(p.options, 'rasterSort') && ~ismember(p.options.rasterSort, ["" "stop" "event"])
        c(end+1) = p.options.rasterSort; %#ok<AGROW>
    elseif p.type == "tuning" && isfield(p.options, 'param')
        [x, s] = figureTuningParam(p.options, sel, src);
        c = [c x s]; %#ok<AGROW>
    end
end
c = c(c ~= "");
c = reshape(unique(c(ismember(c, vars)), 'stable'), 1, []);
end
