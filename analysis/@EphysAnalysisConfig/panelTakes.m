function [tf, kept] = panelTakes(P, Q, path, opts)
%panelTakes  Whether panel Q can take panel P's option at PATH.
%   [TF, KEPT] = EphysAnalysisConfig.panelTakes(P, Q, PATH), PATH an
%   option ("stack") or a field of one ("baseline.Mode", "bins.BinSec"):
%   TF is true when Q has the option and its type takes P's value:
%   - Q's type is P's, or the option is one both types share
%     (sharedFieldsOf); a type's own options (a PSTH's histStyle, yLim
%     in the type's units) go only to panels of that type
%   - the baseline Mode (PATH "baseline", "baseline.Mode" or "auroc":
%     the auroc settings go with it) is one of Q's (baselineModes, by
%     its first enabled layer's source), where Q's type shares the
%     baseline
%   - the stack (PATH "stack" or "stackSpacing") is one of Q's type's
%     (stackModes: "items" is a continuous panel's alone)
%   - a "fixed" yLimMode goes to a panel of another type only when it
%     has limits of its own (its yLim, in its type's units)
%   - an error type (errorType) is one Q's type draws (PanelErrorTypes;
%     a continuous or trial panel's AuxErrorTypes add "iqr"), a trial
%     panel's testShow one Q's type takes (brackets only on a trial
%     distribution), and a waveform
%     (waveform, waveform.mode, waveform.ampScale) one Q's type offers
%     (a waveforms panel has no "off"; an inset no "common" range)
%   KEPT names the rule that refused it ("baseline", "stack",
%   "yLimMode", "errorType", "testShow" or "waveform"; "" when Q lacks the option or
%   does not share it).
%   AnyType=true lets an option go to a panel of another type that has
%   it, shared or not (its value still one Q's type takes, as above): the
%   panels the user selected together in the analysis app, whose editor
%   shows a row only when each of them has it (its spreadPanelEdit,
%   through changeTargets).
%   One rule for Apply to all panels (adoptPanelOptions), for the
%   changes applied to other figures (changeTargets) and for an edit of
%   several panels selected at once.
%
%   See also EphysAnalysisConfig.adoptPanelOptions, EphysAnalysisConfig.changeTargets.

arguments
    P (1,1) struct
    Q (1,1) struct
    path (1,1) string
    opts.AnyType (1,1) logical = false
end
tf = false;
kept = "";
f = extractBefore(path + ".", ".");
if ~isfield(P.options, f) || ~isfield(Q.options, f); return; end
same = Q.type == P.type;
if ~same && ~opts.AnyType ...
        && ~(ismember(f, EphysAnalysisConfig.sharedFieldsOf(P.type)) && ismember(f, EphysAnalysisConfig.sharedFieldsOf(Q.type)))
    return
end
if ismember(path, ["baseline" "baseline.Mode" "auroc"]) && isfield(P.options, 'baseline') ...
        && (opts.AnyType || ismember("baseline", EphysAnalysisConfig.sharedFieldsOf(Q.type)))   % (a spectrogram's baseline is chronuxNormalize's: its own)
    first = "";
    if ~isempty(Q.layers)
        on = [Q.layers.enabled];
        if any(on); first = Q.layers(find(on, 1)).source; end
    end
    if ~ismember(P.options.baseline.Mode, EphysAnalysisConfig.baselineModes(Q.type, first))
        kept = "baseline";
        return
    end
end
if ~same && ismember(path, ["stack" "stackSpacing"]) && ~ismember(P.options.stack, EphysAnalysisConfig.stackModes(Q.type))
    kept = "stack";   % e.g. a continuous panel's "items"
    return
end
if ~same && path == "yLimMode" && P.options.yLimMode == "fixed" && isempty(Q.options.yLim)
    kept = "yLimMode";   % "fixed" with no yLim of its own (the limits are in the type's units)
    return
end
if ~same && path == "errorType"
    types = EphysAnalysisConfig.PanelErrorTypes;
    if ismember(Q.type, ["continuous" EphysAnalysisConfig.TrialPanelTypes]); types = EphysAnalysisConfig.AuxErrorTypes; end
    if ~ismember(string(P.options.errorType), types)
        kept = "errorType";   % e.g. a continuous or trial panel's "iqr"
        return
    end
end
if ~same && path == "testShow" && ~ismember(string(P.options.testShow), trialTestShows(Q.type))
    kept = "testShow";   % a trial distribution's "brackets": a histogram or scatter has no categories to bracket
    return
end
if ~same && ismember(path, ["waveform" "waveform.mode" "waveform.ampScale"]) && isstruct(P.options.waveform)
    w = P.options.waveform;
    noOff = Q.type == "waveforms" && isfield(w, 'mode') && string(w.mode) == "off" && path ~= "waveform.ampScale";
    noCommon = ~ismember(Q.type, ["waveforms" "probemap"]) && isfield(w, 'ampScale') && string(w.ampScale) == "common" ...
        && path ~= "waveform.mode";
    if noOff || noCommon
        kept = "waveform";   % a waveforms panel always draws one; an inset has no range common to the units
        return
    end
end
tf = true;
end


function s = trialTestShows(type)
%trialTestShows  The options.testShow values a trial panel type takes: a distribution's brackets too.
s = ["text" "off"];
if type == "trialDist"; s = ["brackets" "text" "off"]; end
end
