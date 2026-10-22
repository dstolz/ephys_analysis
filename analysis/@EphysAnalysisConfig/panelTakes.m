function [tf, kept] = panelTakes(P, Q, path)
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
%   KEPT names the rule that refused it ("baseline", "stack" or
%   "yLimMode"; "" when Q lacks the option or does not share it).
%   One rule for Apply to all panels (adoptPanelOptions) and for the
%   changes applied to other figures (changeTargets).
%
%   See also EphysAnalysisConfig.adoptPanelOptions, EphysAnalysisConfig.changeTargets.

arguments
    P (1,1) struct
    Q (1,1) struct
    path (1,1) string
end
tf = false;
kept = "";
f = extractBefore(path + ".", ".");
if ~isfield(P.options, f) || ~isfield(Q.options, f); return; end
same = Q.type == P.type;
if ~same && ~(ismember(f, EphysAnalysisConfig.sharedFieldsOf(P.type)) && ismember(f, EphysAnalysisConfig.sharedFieldsOf(Q.type)))
    return
end
if ismember(path, ["baseline" "baseline.Mode" "auroc"]) && isfield(P.options, 'baseline') ...
        && ismember("baseline", EphysAnalysisConfig.sharedFieldsOf(Q.type))   % (a spectrogram's baseline is chronuxNormalize's: its own)
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
tf = true;
end
