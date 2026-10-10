function [type, nBoot] = plotErrorType(spec, part)
%plotErrorType  The error a plot's compute makes for the bands or bars it draws.
%   [TYPE, NBOOT] = plotErrorType(SPEC) is SPEC.style.ErrorType ("sem",
%   "std" or "ci95") and SPEC.style.ErrorResamples for a plot that draws an
%   error with Style.ShowSEM on -- a PSTH (bands), an evoked stack or grid
%   (bands), a rate plot's bars, a tuning curve and a behavior plot's means
%   (but its box layout) -- and "sem" otherwise: what every compute
%   function makes anyway, so no bootstrap is run for a band nobody sees.
%   plotErrorType(SPEC, "aux") is the same for the mean aux signal of a
%   PSTH or raster (its bands). EphysAnalysisRunner.computePlot and
%   EphysAnalysisScript pass it to the compute functions (ErrorType=,
%   ErrorResamples=).
%
%   See also errorBounds, EphysAnalysisRunner.computePlot.

arguments
    spec (1,1) struct
    part (1,1) string {mustBeMember(part, ["main" "aux"])} = "main"
end
st = spec.style;
nBoot = st.ErrorResamples;
type = "sem";
if ~st.ShowSEM; return; end
layout = spec.layout;
if layout == ""
    K = EphysAnalysisConfig.plotKinds();
    layout = K.DefaultLayout(K.Kind == spec.kind);
end
if part == "aux"
    draws = ismember(spec.kind, ["psth" "raster"]) && spec.aux.mode ~= "off";
else
    switch spec.kind
        case "psth",     draws = true;
        case "evoked",   draws = layout ~= "butterfly";
        case "rate",     draws = layout == "bar";
        case "tuning",   draws = true;
        case "behavior", draws = layout ~= "box";
        otherwise,       draws = false;
    end
end
if draws; type = st.ErrorType; end
end
