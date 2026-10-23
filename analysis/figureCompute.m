function [F, K] = figureCompute(src, spec, opts)
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
%         only: E's rows of it, G that one row with n recounted. A group
%         with no epoch here is no error: F.skip says so and the panels on
%         the figure's selection are skipped with that reason
%     a panel with its own ref or window: its own epochTable with the
%         figure's selection; its groups are matched to G by label (each
%         epoch's groupIndex then indexes G; a per-group observation
%         keeps that group's epochs), or the panel is skipped
%     a panel with a selection of its own (Panel.selection): its own
%         epochTable and its own groups, not matched to G and not cut to
%         a per-group observation's group
%     a spectral panel on timeBase "range" takes no epochs (Ep = Gp = []):
%         it reads segments of the recording
%     each panel: figurePanelRegistry().(type).compute(src, panel, Ep, Gp,
%         ctx), every layer resolved for OBS by figureLayerItems and
%         computed as the panel type says (spikePSTH, epochEvents,
%         evokedPotential, unitWaveforms, unitSummary + probeMapValues,
%         unitCorrelation, firingRate, tuningCurve, and Chronux's
%         chronuxSpectrum, chronuxSpikeSpectrum, chronuxSpecgram,
%         chronuxSpikeSpecgram, chronuxCoherence, chronuxSpikeField,
%         chronuxUnitCoherence); errors from data the dataset
%         lacks for one layer or panel (no unit left, no event, no usable
%         epoch) skip only it
%   The error each panel draws as a band comes from figureErrorType
%   (by panel type).
%
%   F fields
%     kind "figure", id, spec (SPEC), dataset (SRC.name), observation (OBS
%     as a struct: kind, label, unitId, channel, column, shank, depth,
%     meta, group, groupLabel), epochs (E; [] when no panel is aligned), groups (G; []
%     likewise), skip ("" or why a per-group observation has no epoch),
%     created, and panels (one per SPEC.panels, in order):
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
%   runner does. What it may reuse is handed to it:
%   [F, K] = figureCompute(..., Reuse=K0) also returns K, what this compute
%   found or made (a struct row: kind "skip" | "epochs" | "panel", dataset
%   (SRC.key | SRC.folder), key, value, bytes, from: the index of the entry
%   of K0 it came from, 0 = made now), and takes from K0 (an earlier call's
%   K, or many of them joined: EphysAnalysisRunner.computeFigure keeps
%   them for the app's preview) every step whose inputs are the same:
%     skip    figureSkipReason's reasons, keyed by the figure's data spec
%     epochs  epochTable's E and G, keyed by its inputs (the figure's, or
%             a panel's own)
%     panel   a panel's computed layers, keyed by its data spec, its epochs
%             and groups, the observation, Observe, its selection and the
%             error its band takes (figureErrorType)
%   A data spec (figureDataSpec) leaves out what only the drawing reads
%   (titles, places, labels, notes, overlays, the grid, the aesthetics, a
%   layer's color and line style, the style but its error settings, the
%   options figureDataSpec lists): an edit of those reuses every step, an
%   edit of one panel's data computes that panel only. With no Reuse and
%   one output nothing is keyed. CHK (default [] = none) is a checkpoint: called with no
%   arguments between the steps, panels and layers, and passed as Check=
%   into spikePSTH, evokedPotential and unitWaveforms, so whatever it
%   throws stops the compute there (EphysAnalysisRunner.computeFigure
%   passes its own checkpoint while PollFcn is set, the app's preview:
%   after cancel() it throws EphysAnalysisRunner:Canceled). Errors:
%   EphysAnalysisRunner:FigureSkipped, EphysAnalysisRunner:NoObservation
%   (OBS omitted and the dataset offers none), and epochTable's for the
%   figure's own epochs.
%
%   See also EphysAnalysisRunner.computeFigure,
%   figureObservations, figureSkipReason, figurePanelRegistry,
%   EphysAnalysisConfig.figureFor, renderFigure.

arguments
    src (1,1) struct
    spec (1,1) struct
    opts.Observation = []
    opts.Check = []
    opts.Reuse = []
end

chk = opts.Check;   % the checkpoint the long steps call ([] = none)
tick(chk);
asked = spec;
asked.enabled = true;   % a disabled figure is still computed when asked (the preview)
C = struct('on', nargout > 1 || ~isempty(opts.Reuse), 'pool', opts.Reuse, 'dataset', "", ...
    'K', struct('kind', {}, 'dataset', {}, 'key', {}, 'value', {}, 'bytes', {}, 'from', {}));   % what is reused and kept
if C.on
    C.dataset = string(src.key) + "|" + string(src.folder);
    dataSpec = figureDataSpec(asked);
    [hit, v, C] = reuse(C, "skip", dataSpec);
end
if C.on && hit
    reason = v{1};
    LR = v{2};
else
    [reason, LR] = figureSkipReason(src, asked);
    if C.on; C = keep(C, "skip", dataSpec, {reason, LR}); end
end
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

reg = figurePanelRegistry();
np = numel(spec.panels);
plan = figureEpochPlan(src, asked, LR);   % which panels are aligned, on the figure's epochs or their own
known = plan.known; live = plan.live; onFig = plan.onFig; ownSel = plan.ownSel;
skipsOf = plan.skips;          % figureSkipReason's reason per layer of each panel
panelSkip = plan.panelSkip;    % ... and of each panel itself

E = [];
G = [];
groupGone = "";   % a per-group observation whose group has no epoch here: its panels on the figure's selection are skipped
if any(live)
    [E, G, C] = epochsOf(C, src, spec.ref, spec.window, spec.selection, plan.figureBase, plan.figureCols);
    if isfinite(obs.group) || obs.groupLabel ~= ""   % one figure per trial group: that group's epochs only
        [E, G, groupGone] = keepGroup(E, G, obs);
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
    if live(k) && ~ownSel(k) && groupGone ~= ""
        P.skip = groupGone;
    elseif live(k)
        if onFig(k)
            Gp = G;
            Ep = E;
        else
            try
                [Ep, Gp, P.skip, C] = panelEpochs(C, src, spec, p, G, plan.base{k}, plan.cols{k}, ownSel(k), obs);
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
    hit = false;
    if C.on   % the same data as a panel computed before (its looks may differ): its layers again
        [eType, nBoot] = figureErrorType(spec, p);
        key = struct('panel', {rmfield(dataSpec.panels(k), 'id')}, 'epochs', {Ep}, 'groups', {Gp}, 'observation', {obs}, ...
            'observe', {spec.observe}, 'selection', {selectionOf(p, spec)}, 'errorType', eType, 'nBoot', nBoot, 'skips', {skips});
        [hit, P.layers, C] = reuse(C, "panel", key);
    end
    if ~hit
        ctx = struct('check', [], 'checkpoint', @() tick(chk), 'observation', obs, 'observe', spec.observe, ...
            'ref', p.ref, 'window', p.window, 'selection', selectionOf(p, spec), 'style', spec.style, 'spec', spec, 'skips', skips);
        ctx.check = chk;
        R = reg.(p.type).compute(src, p, Ep, Gp, ctx);
        P.layers = R.layers;
        if C.on; C = keep(C, "panel", key, P.layers); end
    end
    panels(k) = P;
end
K = C.K;

F = struct();
F.kind = "figure";
F.id = spec.id;
F.spec = spec;
F.dataset = src.name;
F.observation = obs;
F.epochs = E;
F.groups = G;
F.panels = panels;
F.skip = groupGone;
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


function [E, G, reason] = keepGroup(E, G, obs)
%keepGroup  The epochs of one trial group (a per-group observation): E's rows of it, G that one row with its n.
%   A group with no epoch here (gone, or every epoch dropped) is no error:
%   REASON says so, E keeps no row and G that row (or none) with n 0, and
%   the caller skips the panels on the figure's selection.
reason = "";
g = groupOf(G, obs);
if isempty(g) || ~any(E.groupIndex == g)
    reason = "no epoch of trial group " + obs.groupLabel + " here";
    E = E([], :);
    G = G(g, :);
    G.n = zeros(height(G), 1);
    return
end
E = E(E.groupIndex == g, :);
E.groupIndex(:) = 1;
G = G(g, :);
G.n = height(E);
if ismember("index", string(G.Properties.VariableNames)); G.index = 1; end
end


function [Ep, Gp, reason, C] = panelEpochs(C, src, spec, p, G, base, cols, own, obs)
%panelEpochs  A panel's own epochs (its ref / window / selection), its groups those of G unless the selection is its own.
%   BASE and COLS are its epochTable Baseline and Columns (figureEpochPlan:
%   its baseline hull, its sort parameters the trials have). With a
%   selection of its own (OWN) the panel keeps its own
%   groups, whatever the figure's. On the figure's selection its groups
%   are matched to G by label; a per-group observation (OBS.groupLabel)
%   keeps that group's epochs only. C: what is reused and kept (epochsOf).
reason = "";
sel = selectionOf(p, spec);
[Ep, Gp, C] = epochsOf(C, src, p.ref, p.window, sel, base, cols);
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


function [E, G, C] = epochsOf(C, src, ref, win, sel, base, cols)
%epochsOf  epochTable's epochs and groups for these inputs, the ones kept when C holds them (C.on: reuse).
if C.on
    key = struct('ref', {ref}, 'window', {win}, 'selection', {sel}, 'baseline', {base}, 'columns', {cols});
    [hit, v, C] = reuse(C, "epochs", key);
    if hit
        E = v{1};
        G = v{2};
        return
    end
end
[E, G] = epochTable(src, ref, Window=win, Selection=sel, Baseline=base, Columns=cols);
if C.on; C = keep(C, "epochs", key, {E, G}); end
end


function [hit, v, C] = reuse(C, kind, key)
%reuse  The value of the entry of C.pool (Reuse) of this KIND, dataset and KEY, noted in C.K; HIT false when none.
hit = false;
v = [];
for i = 1:numel(C.K)   % made or found already in this compute (two panels on the same data)
    if C.K(i).kind == kind && isequaln(C.K(i).key, key)
        hit = true;
        v = C.K(i).value;
        return
    end
end
P = C.pool;
for i = 1:numel(P)
    if P(i).kind ~= kind || P(i).dataset ~= C.dataset || ~isequaln(P(i).key, key); continue; end
    hit = true;
    v = P(i).value;
    C.K(end+1) = struct('kind', kind, 'dataset', C.dataset, 'key', {key}, 'value', {v}, 'bytes', P(i).bytes, 'from', i);
    return
end
end


function C = keep(C, kind, key, v)
%keep  Note in C.K what was computed now: its KIND, KEY and value V (and its size).
w = whos('v');
C.K(end+1) = struct('kind', kind, 'dataset', C.dataset, 'key', {key}, 'value', {v}, 'bytes', w.bytes, 'from', 0);
end
