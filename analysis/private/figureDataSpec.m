function d = figureDataSpec(spec)
%figureDataSpec  A figure spec without what only its drawing reads: what figureCompute's results depend on.
%   D = figureDataSpec(SPEC) for a spec of EphysAnalysisConfig.figureFor
%   is SPEC without
%     the figure's   id, autoId, enabled, title, grid and aesthetics, and
%                    its style but for ShowSEM, ErrorType and
%                    ErrorResamples (the error a band takes:
%                    figureErrorType)
%     each panel's   title, box, xLabel, yLabel, xSide, ySide, row, col,
%                    rowSpan, colSpan, size, align, valign, note and
%                    overlays, and the options of LookOptions (the draw
%                    functions' alone: the compute functions read none of
%                    them); a PSTH's latencyBox and onsetLine count only as
%                    on or off (they keep its raster rows: their looks are
%                    the drawing's), a raster's onsetLine not at all
%     each layer's   color and lineStyle
%   and with the probe block (probe) as its enabled alone: how the tiles of
%   a probe figure are picked and laid out changes no tile's compute.
%   The figure's latency block (latency) stays: the latencies are computed
%   from it (figureLatencies, keyed by the settings each rule reads).
%   figureCompute keys what it keeps with it (its Reuse): two specs with
%   the same D compute the same results, so an edit of the looks alone
%   computes nothing again. An option a compute function starts to read
%   leaves LookOptions; one left in it that only the drawing reads costs a
%   compute again, never a wrong figure.
%
%   See also figureCompute, figureErrorType, EphysAnalysisRunner.computeFigure.

LookFigure = ["id" "autoId" "enabled" "title" "grid" "aesthetics"];
LookPanel = ["title" "box" "xLabel" "yLabel" "xSide" "ySide" "row" "col" "rowSpan" "colSpan" "size" "align" "valign" ...
    "note" "overlays"];
LookLayer = ["color" "lineStyle"];
LookOptions = ["tickColor" "tickWidth" "backColor" "yTicks" "firstSpike" "fill" "fillAlpha" "histStyle" "normalize" ...
    "stack" "stackSpacing" "yLimMode" "yLim" "colormap" "cLim" "group" "order" "colorBy" "height" "alpha" "trialCount"];
ErrorStyle = ["ShowSEM" "ErrorType" "ErrorResamples"];

d = drop(spec, LookFigure);
if isfield(d, 'probe') && isstruct(d.probe) && isfield(d.probe, 'enabled')
    d.probe = d.probe.enabled;   % the tiles' choice and layout are the probe figure's: no tile computes them
end
if isfield(d, 'style') && isstruct(d.style)
    d.style = drop(d.style, setdiff(string(fieldnames(d.style)), ErrorStyle));
end
if ~isfield(d, 'panels') || isempty(d.panels); return; end
P = drop(d.panels, LookPanel);
for k = 1:numel(P)
    if isstruct(P(k).options)
        P(k).options = drop(P(k).options, LookOptions);
        if isfield(P(k).options, 'latencyBox') && isstruct(P(k).options.latencyBox)
            P(k).options.latencyBox = P(k).options.latencyBox.enabled;   % on or off: the raster rows kept
        end
        if isfield(P(k).options, 'onsetLine')
            P(k).options.onsetLine = P(k).type ~= "raster" && string(P(k).options.onsetLine) ~= "off";
        end
    end
    if isstruct(P(k).layers)
        P(k).layers = drop(P(k).layers, LookLayer);
    end
end
d.panels = P;
end


function s = drop(s, names)
%drop  S without those of the fields NAMES it has.
f = intersect(string(names), string(fieldnames(s)));
if ~isempty(f); s = rmfield(s, cellstr(f)); end
end
