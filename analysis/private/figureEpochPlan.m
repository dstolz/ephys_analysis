function P = figureEpochPlan(src, spec, LR)
%figureEpochPlan  Which panels of a figure are aligned, and what their epochTable calls read.
%   P = figureEpochPlan(SRC, SPEC, LR) for the figure SPEC (figureFor) on
%   the dataset SRC (loadAnalysisSource), LR figureSkipReason's layer
%   reasons, as figureCompute and figureEpochs read them. Per panel k:
%     known(k)     its type is a panel type
%     live(k)      aligned, with an enabled layer, not skipped for its own
%                  reason and not a spectral panel on the "range" time base
%     ownSel(k)    its selection is not the figure's
%     onFig(k)     live, on the figure's ref, window and selection: it
%                  takes the figure's epochs
%     skips{k}     figureSkipReason's reason per layer ("" = none)
%     panelSkip(k) ... and of the panel itself
%     base{k}, cols{k}   a live panel's own epochTable Baseline and Columns
%                  (figureBaselineHull; its sort and tuning parameters)
%   and for the figure's epochs: figureBase, the hull of the baseline
%   windows of the onFig panels, and figureCols, their sort and tuning
%   parameters (only those the trials have: epochTable copies them).
%
%   See also figureCompute, figureEpochs, figureBaselineHull, epochTable.

PT = EphysAnalysisConfig.panelTypes();
np = numel(spec.panels);
vars = string.empty(1, 0);
if istable(src.trials); vars = string(src.trials.Properties.VariableNames); end
P = struct('known', false(1, np), 'live', false(1, np), 'ownSel', false(1, np), 'onFig', false(1, np), ...
    'skips', {cell(1, np)}, 'panelSkip', strings(1, np), 'base', {cell(1, np)}, 'cols', {cell(1, np)});
for k = 1:np
    p = spec.panels(k);
    [P.skips{k}, P.panelSkip(k)] = reasonsOf(LR, p);
    sel = selectionOf(p, spec);
    row = PT.Type == p.type;
    P.known(k) = any(row);
    if ~P.known(k); continue; end
    hasOn = ~isempty(p.layers) && any([p.layers.enabled]);
    % a panel skipped for its own reason (e.g. a raster sorted by a parameter the trials lack) needs no epochs,
    % and gives the figure's epochTable none of its sort columns or baseline
    % a spectral panel on the range time base reads segments of the recording, not epochs
    onRange = isfield(p.options, 'timeBase') && p.options.timeBase == "range";
    P.live(k) = hasOn && PT.Aligned(row) && P.panelSkip(k) == "" && ~onRange;
    P.ownSel(k) = ~isequaln(sel, spec.selection);
    P.onFig(k) = P.live(k) && isequaln(p.ref, spec.ref) && isequaln(p.window, spec.window) && ~P.ownSel(k);
    if P.live(k)
        P.base{k} = figureBaselineHull(p);
        P.cols{k} = sortColumns(p, vars, sel, src);
    end
end
P.figureBase = figureBaselineHull(spec.panels(P.onFig));
P.figureCols = sortColumns(spec.panels(P.onFig), vars, spec.selection, src);
end


function s = selectionOf(p, spec)
%selectionOf  A panel's trial selection: its own (figureFor resolved it), else the figure's.
s = spec.selection;
if isfield(p, 'selection') && isstruct(p.selection); s = p.selection; end
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


function c = sortColumns(panels, vars, sel, src)
%sortColumns  The trial parameters PANELS' rasters (and heat maps of trials) sort their epochs by, and their tuning curves' x and series, as epochTable Columns.
%   Only those the trials have (VARS): a raster sorted by a missing one, or
%   a tuning curve over one, is skipped for it (figureSkipReason), never
%   the figure's epochs. SEL (the figure's selection) and SRC resolve a
%   tuning panel's param "" (figureTuningParam).
c = string.empty(1, 0);
for k = 1:numel(panels)
    p = panels(k);
    trialRows = (p.type == "heatmap" && isfield(p.options, 'rows') && p.options.rows == "trials") ...
        || (p.type == "eventTrace" && p.options.trials == "rows");   % sorted as a raster
    if (p.type == "raster" || trialRows) && isfield(p.options, 'rasterSort') && ~ismember(p.options.rasterSort, ["" "stop" "event" "latency"])
        c(end+1) = p.options.rasterSort; %#ok<AGROW>
    elseif p.type == "tuning" && isfield(p.options, 'param')
        [x, s] = figureTuningParam(p.options, sel, src);
        c = [c x s]; %#ok<AGROW>
    end
end
c = c(c ~= "");
c = reshape(unique(c(ismember(c, vars)), 'stable'), 1, []);
end
