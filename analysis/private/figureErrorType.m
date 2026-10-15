function [type, nBoot] = figureErrorType(spec, panel)
%figureErrorType  The error a figure panel's compute makes for the bands or bars it draws.
%   [TYPE, NBOOT] = figureErrorType(SPEC, PANEL) is the rule by panel
%   type, for a figure SPEC (EphysAnalysisConfig.figureFor) and one
%   of its panels:
%     psth        SPEC.style.ErrorType ("sem", "std" or "ci95") with
%                 Style.ShowSEM on
%     continuous  the panel's own options.errorType ("sem", "std", "ci95"
%                 or "iqr") unless it is "off"
%     rate        SPEC.style.ErrorType with Style.ShowSEM, display "bar"
%                 (its error bars)
%     tuning      SPEC.style.ErrorType with Style.ShowSEM
%   and "sem" otherwise (rasters, heat maps, waveforms, probe and
%   correlation maps draw no band): what every compute function makes
%   anyway, so no bootstrap is run for a band nobody sees. NBOOT is
%   SPEC.style.ErrorResamples. A layer that aggregates several units or
%   channels (aggregate "mean") takes the same type for its band across
%   them.
%
%   See also errorBounds, EphysAnalysisRunner.computeFigure.

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
    case "rate"
        if st.ShowSEM && panel.options.display == "bar"; type = st.ErrorType; end
    case "tuning"
        if st.ShowSEM; type = st.ErrorType; end
end
end
