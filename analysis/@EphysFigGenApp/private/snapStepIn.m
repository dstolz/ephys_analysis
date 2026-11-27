function step = snapStepIn(step, units, pageCm, dpi)
%snapStepIn  The snap step (struct value, units) in other units: a length stays a length, a share of the page a share.
%   STEP = snapStepIn(STEP, UNITS, PAGECM, DPI) gives the snap step STEP
%   (FigureSnapStep: struct('value', 0.5, 'units', "cm")) in UNITS
%   (EphysAnalysisConfig.RectUnits) on the page PAGECM ([width height] cm)
%   at DPI: between cm, in and px the same length; between normalized and
%   % the same share of each side; from a length to a share of the page or
%   back, measured along the page's width (figureRectConvert, axis "x").
%   The value is exact, not rounded to the digits the Layout section shows
%   (showPanelPlace rounds what the box displays: unitsShown): a step shown
%   in px and again in cm would otherwise come back changed (0.5 cm is 30 px
%   at 150 dpi, which is 0.51 cm), by every round trip of the units. A STEP
%   that is not a positive value in known units becomes the default, 0.5
%   cm, first.
%
%   See also EphysFigGenApp.onSnapChanged, EphysFigGenApp.onRectUnitsChanged, unitsShown.
ok = isstruct(step) && isscalar(step) && isfield(step, 'value') && isfield(step, 'units') ...
    && isnumeric(step.value) && isscalar(step.value) && isfinite(step.value) && step.value > 0 ...
    && isscalar(string(step.units)) && ismember(string(step.units), EphysAnalysisConfig.RectUnits);
if ~ok; step = struct('value', 0.5, 'units', "cm"); end
from = string(step.units);
v = double(step.value);
if from ~= units; v = figureRectConvert(v, from, units, pageCm, dpi, "x"); end
step = struct('value', v, 'units', units);
end
