function name = figureUnitsName(meta, L)
%figureUnitsName  A point layer's automatic name: the unit's label, or how many units it holds.
%   NAME = figureUnitsName(META, L) for the units META (selectUnits' table)
%   a figure layer L (figureFor's spec: source, aggregate) reads: one
%   unit's short label; else "<n> units" ("<n> detection channels" for
%   detected spikes), "mean of <n> units" with aggregate "mean".
%
%   See also figurePointLayer, computeRatePanel, computeTuningPanel.
n = height(meta);
if n == 1
    name = shortUnitLabels(meta.label);
    return
end
what = "units";
if L.source == "detected"; what = "detection channels"; end
name = n + " " + what;
if L.aggregate == "mean"; name = "mean of " + name; end
end
