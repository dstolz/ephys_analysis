function h = renderPlot(R, spec, target, opts)
%renderPlot  Draw a computed result the way its plot spec says.
%   H = renderPlot(R, SPEC, TARGET, Page=P) dispatches on SPEC.kind (a plot
%   entry, e.g. from EphysAnalysisConfig.plotFor; [] = the defaults for
%   R.kind) to renderPSTH, renderRaster, renderEvoked, renderRates,
%   renderTuning, renderHeatmap, renderProbeMap or renderCorrMap, with SPEC.style, the
%   layout, and page P of a grid (plotPageCount pages). TARGET is an axes,
%   uiaxes, figure, uifigure, panel, tab, grid layout or tiled layout: the
%   app draws its previews into a panel, the runner into an invisible
%   classic figure (newExportFigure). It adds a title -- SPEC.title, else
%   "<Kind>: <line> <edge> (<n> epochs)" -- with the dataset and page as a
%   subtitle.
%
%   H: what the renderer returned plus title (the text used) and page.
%
%   See also plotPageCount, plotCaption, EphysAnalysisRunner.renderPlotFigures.

arguments
    R (1,1) struct
    spec
    target
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
end

spec = plotSpecFor(R, spec);
style = spec.style;
nPages = plotPageCount(R, spec);
page = min(opts.Page, nPages);
switch spec.kind
    case "psth"
        h = renderPSTH(R, target, Layout=spec.layout, WithRaster=spec.withRaster, HistStyle=spec.histStyle, Page=page, Style=style);
    case "raster"
        h = renderRaster(R, target, Page=page, Style=style);
    case "evoked"
        h = renderEvoked(R, target, Layout=spec.layout, Page=page, Style=style);
    case "rate"
        h = renderRates(R, target, Layout=spec.layout, Style=style);
    case "tuning"
        h = renderTuning(R, target, Layout=spec.layout, Page=page, Style=style);
    case "heatmap"
        h = renderHeatmap(R, target, Order=spec.order, Style=style);
    case "probemap"
        h = renderProbeMap(R, [], target, Style=style);
    case "corrmap"
        h = renderCorrMap(R, target, Order=spec.order, Style=style);
    otherwise
        error('renderPlot:BadKind', 'Unknown plot kind "%s".', spec.kind);
end

txt = spec.title;
if txt == ""; txt = autoTitle(R, spec); end
sub = strings(1, 0);
if isfield(R, 'dataset') && string(R.dataset) ~= ""; sub(end+1) = string(R.dataset); end
if nPages > 1; sub(end+1) = sprintf("page %d of %d", page, nPages); end
if ~isempty(h.layout)
    title(h.layout, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none');
    if ~isempty(sub)
        subtitle(h.layout, strjoin(sub, " | "), 'FontSize', style.FontSize, 'Interpreter', 'none');
    end
elseif ~isempty(h.axes)
    ax = h.axes(1);
    was = string(ax.Title.String);
    title(ax, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none');
    parts = [was(was ~= "") sub];
    if ~isempty(parts)
        subtitle(ax, strjoin(parts, " | "), 'FontSize', style.FontSize, 'Interpreter', 'none');
    end
end
h.title = txt;
h.page = page;
end


function t = autoTitle(R, spec)
%autoTitle  "<Kind>: <line> <edge> (<n> epochs)".
K = EphysAnalysisConfig.plotKinds();
label = K.Label(K.Kind == spec.kind);
if spec.kind == "probemap"
    what = "units";
    if spec.source == "detected"; what = "channels"; end
    t = sprintf("%s: %s (%d %s)", label, R.valueName, R.n, what);
    return
end
ev = "";
nEp = NaN;
if isfield(R, 'epochs') && istable(R.epochs)
    U = R.epochs.Properties.UserData;
    nEp = height(R.epochs);
    if isstruct(U) && isfield(U, 'ref')
        ev = U.ref.line + " " + U.ref.edge;
        if isfield(U, 'window') && U.window.mode == "between" && ~isempty(U.window.stop)
            ev = ev + " to " + U.window.stop.line + " " + U.window.stop.edge;
        end
    end
elseif isstruct(spec.ref)
    ev = spec.ref.line + " " + spec.ref.edge;
end
if ~isfinite(nEp) && isfield(R, 'n'); nEp = sum(R.n(:)); end
if spec.kind == "tuning"
    label = label + " (" + R.param + ")";
end
if spec.kind == "corrmap"
    type = "Pearson";
    if R.type == "spearman"; type = "Spearman"; end
    label = label + " (" + type + ", " + R.metric + " rate)";
end
t = label;
if ev ~= ""; t = t + ": " + ev; end
if isfinite(nEp); t = t + sprintf(" (%d epochs)", nEp); end
end
