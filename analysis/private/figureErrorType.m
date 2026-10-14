function [type, nBoot] = figureErrorType(spec, panel)
%figureErrorType  The error a figure panel's compute makes for the bands or bars it draws.
%   [TYPE, NBOOT] = figureErrorType(SPEC, PANEL) is plotErrorType's rule by
%   panel type, for a figure SPEC (EphysAnalysisConfig.figureFor) and one
%   of its panels:
%     psth        SPEC.style.ErrorType ("sem", "std" or "ci95") with
%                 Style.ShowSEM on
%     continuous  the panel's own options.errorType ("sem", "std", "ci95"
%                 or "iqr") unless it is "off"
%     behavior    SPEC.style.ErrorType with Style.ShowSEM on, unless the
%                 panel's display is "box"
%   and "sem" otherwise (rasters, heat maps, waveforms, probe and
%   correlation maps draw no band): what every compute function makes
%   anyway, so no bootstrap is run for a band nobody sees. NBOOT is
%   SPEC.style.ErrorResamples. A layer that aggregates several units or
%   channels (aggregate "mean") takes the same type for its band across
%   them.
%
%   See also plotErrorType, errorBounds, EphysAnalysisRunner.computeFigure.

arguments
    spec (1,1) struct
    panel (1,1) struct
end
st = spec.style;
nBoot = st.ErrorResamples;
type = "sem";
switch panel.type
    case "psth"
        if st.ShowSEM; type = st.ErrorType; end
    case "continuous"
        if panel.options.errorType ~= "off"; type = panel.options.errorType; end
    case "behavior"
        if st.ShowSEM && panel.options.display ~= "box"; type = st.ErrorType; end
end
end
