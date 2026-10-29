function [PF, K] = figureProbeCompute(src, spec, opts)
%figureProbeCompute  Compute a probe figure on one dataset: the whole figure for every tile laid out on the probe, no graphics.
%   PF = figureProbeCompute(SRC, SPEC) with SRC from loadAnalysisSource
%   (EphysAnalysisRunner.source) and SPEC from Config.figureFor(id) of a
%   figure whose probe.enabled is true computes what renderFigure draws
%   (renderProbeFigure): the figure's panels for each observation
%   figureProbeTiles(SRC, SPEC) lays out on the probe, a tile each:
%     [reason, ~] = figureSkipReason(SRC, SPEC)   (a figure-level reason
%         -- no probe map, the dataset observed, what the figure observes
%         missing -- throws EphysAnalysisRunner:FigureSkipped, as
%         figureCompute does)
%     [T, left, sites] = figureProbeTiles(SRC, SPEC)
%     for each row i of T, in T's order: Check, ProgressFcn(i, n, label),
%         [F, Ki] = figureCompute(SRC, SPEC, Observation=T(i, :), Check=,
%         Reuse=POOL), POOL being Reuse plus what the tiles before it found
%         or made: the figure's epochs are one step every tile takes from
%         the first, and a tile computes only its own panels
%   A tile whose compute throws (but EphysAnalysisRunner:Canceled, which is
%   rethrown) is kept with its skip set to the error's message and F [].
%   No observation with a position: PF.tiles is empty, no error.
%
%   PF fields
%     kind         "probeFigure"
%     id, spec, dataset (SRC.name), created
%     observation  as figureCompute's F.observation: kind "probe", label
%                  what the tiles are ("23 units at their sites", "16 LFP
%                  channels at their sites"; "detections" for detected),
%                  unitId, channel, column, shank, depth and group NaN,
%                  meta {}, groupLabel ""
%     probe        SRC.probe (chanMap, xc, yc, kcoords)
%     sites        every site of the probe map, a row each: channel
%                  (1-based), x, y, shank (kcoords), included (it passes
%                  probe.shanks, channels and depthRange)
%     tiles        struct array, one per row of T in T's order:
%                  observation (the tile's F.observation), x, y (µm),
%                  shank, channel, F (figureCompute's result; [] when skip
%                  is set) and skip ("" or the error's message)
%     left         figureProbeTiles' counts (total, noPosition, filtered,
%                  overSite, overMax, kept)
%     nTiles       numel(tiles)
%     epochs, groups  the first computed tile's F.epochs and F.groups ([]
%                  when none): the figure's groups, for the page's legend
%
%   [PF, K] = figureProbeCompute(..., Reuse=K0) also returns every tile's
%   steps (figureCompute's K rows, each once: made now, from 0, or taken
%   from K0, from its index there), and takes from K0 every step whose
%   inputs are the same: EphysAnalysisRunner.computeProbeFigure keeps them
%   in its FigureCache, so the preview's look-only edit computes nothing.
%   The probe block counts only as on or off in each step's key
%   (figureDataSpec): the tiles' choice and layout compute no tile again.
%
%   Options
%     Check        a checkpoint ([] = none), called between the tiles and
%                  passed into figureCompute
%     Reuse        figureCompute K rows to take steps from ([] = none)
%     ProgressFcn  ProgressFcn(i, n, label) before tile i of n ([] = none)
%
%   It is pure: no runner, no graphics. Errors:
%   EphysAnalysisRunner:FigureSkipped, EphysAnalysisRunner:Canceled from
%   CHK.
%
%   See also figureProbeTiles, figureCompute, renderFigure,
%   EphysAnalysisRunner.computeProbeFigure, EphysAnalysisRunner.runDataset.

arguments
    src (1,1) struct
    spec (1,1) struct
    opts.Check = []
    opts.Reuse = []
    opts.ProgressFcn = []
end

chk = opts.Check;
tick(chk);
asked = spec;
asked.enabled = true;   % a disabled figure is still computed when asked (the preview)
reason = figureSkipReason(src, asked);
if reason ~= ""
    error('EphysAnalysisRunner:FigureSkipped', 'Figure "%s" cannot be computed for %s: %s.', spec.id, src.name, reason);
end
[T, left, sites] = figureProbeTiles(src, spec);
n = height(T);

K0 = emptyK();
if isstruct(opts.Reuse) && ~isempty(opts.Reuse); K0 = reshape(opts.Reuse, 1, []); end
n0 = numel(K0);
K = emptyK();
tile0 = struct('observation', [], 'x', NaN, 'y', NaN, 'shank', NaN, 'channel', NaN, 'F', [], 'skip', "");
tiles = repmat(tile0, 1, n);
E = [];
G = [];
gotGroups = false;
for i = 1:n
    tick(chk);
    if ~isempty(opts.ProgressFcn); opts.ProgressFcn(i, n, string(T.label(i))); end
    t = tile0;
    t.x = T.x(i);
    t.y = T.y(i);
    t.shank = T.shank(i);
    t.channel = T.channel(i);
    try
        [F, Ki] = figureCompute(src, spec, Observation=T(i, :), Check=chk, Reuse=[K0 K]);
        t.F = F;
        t.observation = F.observation;
        for j = 1:numel(Ki)   % each step once: made now, or taken from K0 (one taken from an earlier tile is in K already)
            e = Ki(j);
            if e.from == 0 || (e.from <= n0 && ~any([K.from] == e.from))
                K(end+1) = e; %#ok<AGROW>
            end
        end
        if ~gotGroups
            E = F.epochs;
            G = F.groups;
            gotGroups = true;
        end
    catch ME
        if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        t.skip = string(ME.message);
        t.observation = observationOf(T(i, :));
    end
    tiles(i) = t;
end

PF = struct();
PF.kind = "probeFigure";
PF.id = spec.id;
PF.spec = spec;
PF.dataset = src.name;
PF.observation = probeObservation(spec, n);
PF.probe = [];
if isfield(src, 'probe'); PF.probe = src.probe; end
PF.sites = sites;
PF.tiles = tiles;
PF.left = left;
PF.nTiles = numel(tiles);
PF.epochs = E;
PF.groups = G;
PF.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function tick(chk)
%tick  The checkpoint, when there is one.
if ~isempty(chk); chk(); end
end


function K = emptyK()
%emptyK  No figureCompute step (its K's fields), a 1 x 0 struct.
K = struct('kind', cell(1, 0), 'dataset', cell(1, 0), 'key', cell(1, 0), 'value', cell(1, 0), 'bytes', cell(1, 0), ...
    'from', cell(1, 0));
end


function o = probeObservation(spec, n)
%probeObservation  The page's observation: kind "probe", what its N tiles are ("23 units at their sites").
ob = spec.observe;
kind = "unit";
if isfield(ob, 'kind'); kind = string(ob.kind); end
if kind == "unit"
    what = ["unit" "units"];
    if ob.data == "detected"; what = ["detection" "detections"]; end
else
    what = [ob.data + " channel", ob.data + " channels"];
end
if n == 1
    label = "1 " + what(1) + " at its site";
else
    label = n + " " + what(2) + " at their sites";
end
o = struct('kind', "probe", 'label', label, 'unitId', NaN, 'channel', NaN, 'column', NaN, 'shank', NaN, 'depth', NaN, ...
    'meta', [], 'group', NaN, 'groupLabel', "");
o.meta = {};
end


function o = observationOf(row)
%observationOf  A tile's observation as figureCompute's F.observation, for a tile it could not compute.
o = struct('kind', "unit", 'label', "", 'unitId', NaN, 'channel', NaN, 'column', NaN, 'shank', NaN, 'depth', NaN, 'meta', [], ...
    'group', NaN, 'groupLabel', "");
for f = intersect(string(fieldnames(o)).', string(row.Properties.VariableNames), 'stable')
    v = row.(f)(1);
    if iscell(v); v = v{1}; end
    o.(f) = v;
end
o.kind = string(o.kind);
o.label = string(o.label);
o.groupLabel = string(o.groupLabel);
if ismissing(o.groupLabel); o.groupLabel = ""; end
end
