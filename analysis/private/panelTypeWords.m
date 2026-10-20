function s = panelTypeWords(type)
%panelTypeWords  A panel type's name in running text, before "panel(s)": "probe map", "PSTH", "event-trace".
%   S = panelTypeWords(TYPE) is the Label of TYPE in
%   EphysAnalysisConfig.panelTypes with its first letter in lower case (an
%   all-capitals label such as PSTH kept), "event-trace" for "eventTrace"
%   (its label, Event traces, is plural), and TYPE itself for a type that
%   is not listed. Messages put it before "panels" so they need no article
%   ("probe map panels are not merged across sessions").
%
%   See also EphysAnalysisConfig.panelTypes, figureSessionSkipReason, figureSkipReason.

type = string(type);
if type == "eventTrace"; s = "event-trace"; return; end
T = EphysAnalysisConfig.panelTypes();
s = T.Label(T.Type == type);
if isempty(s); s = type; return; end
if s ~= upper(s); s = lower(extractBefore(s, 2)) + extractAfter(s, 1); end
end
