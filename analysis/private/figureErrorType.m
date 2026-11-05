function [type, nBoot] = figureErrorType(panel)
%figureErrorType  The error a figure panel's compute makes for the bands or bars it draws.
%   [TYPE, NBOOT] = figureErrorType(PANEL) is the rule by panel type, for
%   one panel of a figure (EphysAnalysisConfig.figureFor):
%     psth, tuning  the panel's options.errorType ("sem", "std" or "ci95")
%                   unless it is "off"
%     rate          the same, with display "bar" (its error bars)
%     continuous    the panel's options.errorType ("sem", "std", "ci95" or
%                   "iqr") unless it is "off"
%     trialDist, trialHist, trialScatter   the same (the error of each
%                   category's and series' summary, trialPanelStats)
%   and "sem" otherwise (rasters, heat maps, waveforms, probe and
%   correlation maps draw no band; a panel whose error is "off" draws
%   none): what every compute function makes anyway, so no bootstrap is
%   run for a band nobody sees. NBOOT is the panel's
%   options.errorResamples (1000 for a type without it). A layer that
%   aggregates several units or channels (aggregate "mean") takes the same
%   type for its band across them.
%
%   See also errorBounds, EphysAnalysisRunner.computeFigure.

arguments
    panel (1,1) struct
end
o = panel.options;
nBoot = 1000;
if isfield(o, 'errorResamples'); nBoot = o.errorResamples; end
type = "sem";
if ~isfield(o, 'errorType') || o.errorType == "off"; return; end
switch panel.type
    case {"psth" "tuning" "continuous"}
        type = o.errorType;
    case "rate"
        if o.display == "bar"; type = o.errorType; end
    case {"trialDist" "trialHist" "trialScatter"}
        type = o.errorType;
end
end
