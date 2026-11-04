function step = snapStepIn(step, units, pageCm, dpi)
%snapStepIn  The snap step (struct value, units) in other units: a length stays a length, a share of the page a share.
%   STEP = snapStepIn(STEP, UNITS, PAGECM, DPI) gives the snap step STEP
%   (FigureSnapStep: struct('value', 0.5, 'units', "cm")) in UNITS
%   (EphysAnalysisConfig.RectUnits) on the page PAGECM ([width height] cm)
%   at DPI: between cm, in and px the same length; between normalized and
%   % the same share of each side; from a length to a share of the page or
%   back, measured along the page's width (figureRectConvert, axis "x").
%   The value is rounded as the Panels section shows it (unitsShown), but
%   never to 0: the smallest value it can show instead. A STEP that is not
%   a positive value in known units becomes the default, 0.5 cm, first.
%
%   See also EphysFigGenApp.onSnapChanged, EphysFigGenApp.onRectUnitsChanged, unitsShown.
ok = isstruct(step) && isscalar(step) && isfield(step, 'value') && isfield(step, 'units') ...
    && isnumeric(step.value) && isscalar(step.value) && isfinite(step.value) && step.value > 0 ...
    && isscalar(string(step.units)) && ismember(string(step.units), EphysAnalysisConfig.RectUnits);
if ~ok; step = struct('value', 0.5, 'units', "cm"); end
from = string(step.units);
[v, d] = unitsShown(double(step.value), from, units, pageCm, dpi, "x");
step = struct('value', max(v, 10^-d), 'units', units);
end
