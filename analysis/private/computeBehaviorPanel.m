function P = computeBehaviorPanel(src, panel, E, G, ctx) %#ok<INUSD>
%computeBehaviorPanel  A figure's behavior panel: a per-epoch value against a trial parameter.
%   P = computeBehaviorPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "behavior") has P.layers, one per layer of PANEL
%   (figurePanelLayers). E is the panel's own epochTable, made by
%   EphysAnalysisRunner.computeFigure with Columns = [options.param, the
%   layer's seriesParam and yParam], Incomplete="keep" and
%   Artifacts="keep" (every event's epoch: the window and the signals'
%   artifact periods do not concern behavior), as computePlot's behavior
%   plot. Its first enabled layer (trials) gets
%     y = E.(yParam), or 1000 * (E.t1 - E.t0) (ms) for yParam "stop"
%     R = behaviorValues(y, E.(options.param), Series=E.(seriesParam),
%         Param=, SeriesParam=, YName=, YUnits=, ErrorType=CTX.errorType,
%         ErrorResamples=)
%   plus R.epochs (E) and dataset. No finite value skips the layer with the
%   reason.
%
%   See also figurePanelRegistry, behaviorValues, renderBehavior.

o = panel.options;
w = panel.window;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the band this panel draws ("sem" where none)
[j, P.layers] = figureFirstLayer(P.layers, "A behavior panel");
if j == 0 || P.layers(j).skip ~= ""; return; end
L = panel.layers(j);
lay = P.layers(j);
ctx.checkpoint();
series = [];
if L.seriesParam ~= ""; series = E.(L.seriesParam); end
if L.yParam == "stop"
    y = 1000 * (E.t1 - E.t0);
    yName = "stop latency";
    if ~isempty(w.stop); yName = eventRefLabel(w.stop) + " latency"; end
    yUnits = "ms";
else
    y = E.(L.yParam);
    yName = L.yParam;
    yUnits = "";
end
try
    R = behaviorValues(y, E.(o.param), Series=series, Param=o.param, SeriesParam=L.seriesParam, ...
        YName=yName, YUnits=yUnits, ErrorType=ctx.errorType, ErrorResamples=ctx.nBoot);
catch ME
    P.layers(j).skip = figureLayerError(ME);
    return
end
R.epochs = E;
R.dataset = src.name;
lay.R = R;
if lay.name == ""; lay.name = yName; end
P.layers(j) = lay;
end
